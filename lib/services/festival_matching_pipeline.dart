import '../models/festival.dart';
import '../models/panchang_data.dart';

export '../models/festival.dart'
    show matchesFestivalOnDay, hinduNakshatras, nakshatraForLongitude;

/// Shared festival-matching pipeline: the single source of truth for Vriddhi
/// (extended tithi spanning two sunrises) handling.
///
/// Background: Bisuddha Siddhanta / Drik tithi timings can leave the same
/// tithi prevailing at two consecutive sunrises (e.g. Shashthi on Oct 16+17
/// 2026). The per-day matcher ([PanchangData.fromRawTithi]) evaluates each
/// Gregorian day in isolation, so a festival then matches on BOTH days.
/// Whether that is correct depends on the tradition:
/// - Durga Puja Shashthi (Bengali): observed on both days → `'both'`.
/// - Sharad Navratri sequence days: the sequence advances, so each form is
///   observed on the FIRST day of the run → `'first'`.
///
/// All consumers — the month grid, the single-day sheet, the export service,
/// countdown/search (via `findNextFestivalOccurrence`), and notification
/// scheduling — must go through this file so they can never disagree:
/// - Map-shaped day sets (UI month grid, notification window): run
///   [applyVriddhiFilter] once over the whole map.
/// - Forward-scan occurrence finders (export, countdown, search): route each
///   candidate through [resolveVriddhiCandidate].
/// - Nakshatra-override day matches: [matchesFestivalOnDay] (defined in the
///   festival model, re-exported here).

/// Dominant-tithi grace window (Drik convention, docs 6.2): a tithi that
/// begins within this long after sunrise counts for that Gregorian day.
/// Single definition shared by the UI batch (checkpoint instant), the
/// forward scanners, and the notification path so all agree.
const Duration kDominantTithiGrace = Duration(minutes: 60);

/// Normalized Vriddhi preference: `'first'`, `'second'`, or `'both'`.
///
/// Unknown/empty values fall back to `'both'` (legacy behavior: keep every
/// matching sunrise), so existing entries without the field are unaffected.
String normalizeVriddhiPreference(String? raw) {
  switch (raw?.trim().toLowerCase()) {
    case 'first':
      return 'first';
    case 'second':
      return 'second';
    default:
      return 'both';
  }
}

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// Trims duplicate festival matches across consecutive-day runs.
///
/// For every festival with a `first`/`second` preference, groups the days it
/// matched on into runs of consecutive Gregorian dates and keeps only the
/// run's first (or last) day. Festivals with `'both'` (the default) are left
/// untouched. Days are rebuilt via [PanchangData.copyWith]; tithi/masa and
/// all other fields are preserved.
///
/// Input keys need not be normalized; output preserves the original keys.
Map<DateTime, PanchangData> applyVriddhiFilter(
  Map<DateTime, PanchangData> days,
) {
  if (days.isEmpty) return days;

  // date-only key -> original key (first seen wins; duplicates collapse).
  final originalKeyOf = <DateTime, DateTime>{};
  // festival id -> sorted date-only days it matched on (only for
  // festivals with a non-'both' preference).
  final matchedDaysOf = <String, List<DateTime>>{};
  // festival id -> preference (static per festival; first seen wins).
  final preferenceOf = <String, String>{};

  for (final entry in days.entries) {
    final day = _dateOnly(entry.key);
    originalKeyOf.putIfAbsent(day, () => entry.key);
    for (final festival in entry.value.festivals) {
      final pref = normalizeVriddhiPreference(
        festival.panchangRules.vriddhi,
      );
      if (pref == 'both') continue;
      preferenceOf.putIfAbsent(festival.id, () => pref);
      (matchedDaysOf[festival.id] ??= <DateTime>[]).add(day);
    }
  }
  if (matchedDaysOf.isEmpty) return days;

  // festival id -> date-only days to drop it from.
  final removals = <String, Set<DateTime>>{};
  for (final id in matchedDaysOf.keys) {
    final dates = matchedDaysOf[id]!..sort();
    final pref = preferenceOf[id]!;
    var runStart = 0;
    for (var i = 1; i <= dates.length; i++) {
      final continues =
          i < dates.length &&
          dates[i].difference(dates[i - 1]).inDays == 1;
      if (continues) continue;
      final runLength = i - runStart;
      if (runLength > 1) {
        final drop = removals.putIfAbsent(id, () => <DateTime>{});
        if (pref == 'first') {
          // Keep run[0] (the sequence advances from here).
          for (var j = runStart + 1; j < i; j++) {
            drop.add(dates[j]);
          }
        } else {
          // 'second': keep run[i-1].
          for (var j = runStart; j < i - 1; j++) {
            drop.add(dates[j]);
          }
        }
      }
      runStart = i;
    }
  }
  if (removals.isEmpty) return days;

  final result = Map<DateTime, PanchangData>.from(days);
  final dropByDay = <DateTime, Set<String>>{};
  removals.forEach((id, dateSet) {
    for (final day in dateSet) {
      (dropByDay[day] ??= <String>{}).add(id);
    }
  });
  dropByDay.forEach((day, ids) {
    final originalKey = originalKeyOf[day];
    if (originalKey == null) return;
    final current = result[originalKey];
    if (current == null) return;
    final kept = current.festivals.where((f) => !ids.contains(f.id)).toList();
    if (kept.length != current.festivals.length) {
      result[originalKey] = current.copyWith(festivals: kept);
    }
  });
  return result;
}

/// Resolution of one forward-scan candidate against Vriddhi runs.
///
/// [candidate] is the first matching day the scan found (>= [baseDate]);
/// [matchesDay] must answer "does [festival] match on this Gregorian day?"
/// with the SAME matching logic the scan itself used. Returns the observance
/// day, or null [occurrence] with a [resumeFrom] day when the run's
/// observance already passed (caller must continue scanning from there).
///
/// - `'both'` (or Solar / tithi-less rules): [candidate] unchanged.
/// - `'second'`: walks forward to the run end and returns it.
/// - `'first'`: walks back to the run start. When the run started before
///   [baseDate], the observance is in the past → null occurrence and
///   [resumeFrom] set past the run end so the scan skips the whole run.
Future<({DateTime? occurrence, DateTime resumeFrom})>
resolveVriddhiCandidate({
  required Festival festival,
  required DateTime candidate,
  required DateTime baseDate,
  required Future<bool> Function(DateTime day) matchesDay,
  int maxRunScan = 4,
}) async {
  final base = _dateOnly(baseDate);
  var cand = _dateOnly(candidate);
  final pref = normalizeVriddhiPreference(festival.panchangRules.vriddhi);

  if (pref == 'both' ||
      festival.conditions == 'Solar' ||
      festival.tithi < 1) {
    return (occurrence: cand, resumeFrom: cand);
  }

  if (pref == 'second') {
    var last = cand;
    for (var i = 0; i < maxRunScan; i++) {
      final next = _dateOnly(last.add(const Duration(days: 1)));
      if (await matchesDay(next)) {
        last = next;
      } else {
        break;
      }
    }
    return (occurrence: last, resumeFrom: last);
  }

  // 'first': find the run boundaries around the candidate.
  var runStart = cand;
  for (var i = 0; i < maxRunScan; i++) {
    final prev = _dateOnly(runStart.subtract(const Duration(days: 1)));
    if (await matchesDay(prev)) {
      runStart = prev;
    } else {
      break;
    }
  }
  if (runStart.isBefore(base)) {
    // Observance already passed: skip the whole run.
    var runEnd = cand;
    for (var i = 0; i < maxRunScan; i++) {
      final next = _dateOnly(runEnd.add(const Duration(days: 1)));
      if (await matchesDay(next)) {
        runEnd = next;
      } else {
        break;
      }
    }
    return (
      occurrence: null,
      resumeFrom: _dateOnly(runEnd.add(const Duration(days: 1))),
    );
  }
  return (occurrence: runStart, resumeFrom: runStart);
}
