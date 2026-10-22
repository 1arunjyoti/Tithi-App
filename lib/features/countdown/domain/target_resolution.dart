import 'package:flutter/foundation.dart';

import '../../../models/festival.dart';
import '../../../models/hindu_month_system.dart';
import '../../../services/panchang_service.dart';
import '../../panchang/domain/occurrence_cache.dart';

// Shared "N festivals -> dated targets" resolution used by the countdown
// providers, the all-festivals screen, search, and export. Previously each
// implemented its own forward-scan loop; all now funnel through the
// occurrence-result cache ([findNextFestivalOccurrenceCached]) plus the
// helpers below, so a scan computed anywhere serves everywhere.

/// One festival with its next occurrence date (null when no occurrence
/// resolves inside the forward window — those sort last, undated).
typedef DatedFestival = ({Festival festival, DateTime? date});

/// Chronological order for dated festival lists: ascending next-occurrence
/// date (name breaks ties), undatable entries last by name.
List<DatedFestival> sortDatedFestivals(List<DatedFestival> items) {
  final sorted = items.toList();
  sorted.sort((a, b) {
    if (a.date == null && b.date == null) {
      return a.festival.name.compareTo(b.festival.name);
    }
    if (a.date == null) return 1;
    if (b.date == null) return -1;
    final byDate = a.date!.compareTo(b.date!);
    if (byDate != 0) return byDate;
    return a.festival.name.compareTo(b.festival.name);
  });
  return sorted;
}

/// One festival's next occurrence on/after [baseDate] (date-only), or null
/// on failure. One bad rule never fails the caller — it resolves dateless.
///
/// Resolution is ALWAYS Amanta-based: festival rules are stored in Amanta
/// and both scanners match with [HinduMonthSystem.amanta] hardcoded, so the
/// display system must not enter the cache key (it did before occ7, causing
/// a full re-scan of every festival on each Amanta↔Purnimant toggle for zero
/// new information). Callers needing the user's system for *labels* (e.g.
/// export's masaDisplay) keep it separately — it never affects dates.
Future<DateTime?> resolveOccurrenceDate({
  required PanchangService service,
  required Festival festival,
  required DateTime baseDate,
  required double latitude,
  required double longitude,
}) async {
  try {
    return await findNextFestivalOccurrenceCached(
      service: service,
      festival: festival,
      startDate: baseDate,
      latitude: latitude,
      longitude: longitude,
      monthSystem: HinduMonthSystem.amanta,
    );
  } catch (e) {
    // One bad rule must not fail the whole list; log and sort last.
    debugPrint('Occurrence resolve failed for ${festival.id}: $e');
    return null;
  }
}

/// Every occurrence of a `recurring` festival from [first] through [through].
///
/// [first] is the already-resolved occurrence on/after the window start;
/// [nextAfter] resolves the next occurrence on/after its argument. The search
/// restarts 25 days after the previous occurrence: the same tithi cannot
/// repeat sooner (a synodic month is ~29.5 days), so this skips the current
/// lunation without missing the next one.
///
/// The loop is defensive: it stops on a null, a date after [through], a
/// non-advancing date (bad rule), or [maxOccurrences] so one malformed
/// festival can never hang the screen. Twenty-four Ekadashis, twelve
/// Purnimas/Amavasyas fit comfortably under the cap.
@visibleForTesting
Future<List<DateTime>> collectRecurringOccurrences({
  required DateTime first,
  required DateTime through,
  required Future<DateTime?> Function(DateTime start) nextAfter,
  int maxOccurrences = 32,
}) async {
  final dates = <DateTime>[first];
  var previous = first;
  while (dates.length < maxOccurrences) {
    final next = await nextAfter(previous.add(const Duration(days: 25)));
    if (next == null || next.isAfter(through) || !next.isAfter(previous)) {
      break;
    }
    dates.add(next);
    previous = next;
  }
  return dates;
}

/// Every festival's date(s), sorted ([sortDatedFestivals]).
///
/// Non-recurring festivals resolve to a single next occurrence on/after
/// [baseDate] (which may fall after [through] when the festival does not
/// occur this year). When [through] is set, `recurring` festivals (Ekadashi,
/// Purnima, Amavasya, …) are expanded to every occurrence in
/// [baseDate]..[through], so a yearly list shows all 24 Ekadashis instead of
/// only the first one in January.
///
/// Resolved in small parallel batches: enough parallelism for throughput,
/// small enough to avoid FFI stampedes that jank the UI thread (matches
/// the month batch size). Resolution is Amanta-fixed (see above), so a
/// month-system toggle never re-scans.
Future<List<DatedFestival>> resolveDatedFestivals({
  required PanchangService service,
  required List<Festival> festivals,
  required DateTime baseDate,
  required double latitude,
  required double longitude,
  DateTime? through,
  int batchSize = 8,
}) async {
  Future<DateTime?> nextAfter(Festival festival, DateTime start) {
    return resolveOccurrenceDate(
      service: service,
      festival: festival,
      baseDate: start,
      latitude: latitude,
      longitude: longitude,
    );
  }

  Future<List<DatedFestival>> resolve(Festival festival) async {
    final first = await nextAfter(festival, baseDate);
    if (first == null || through == null || !festival.recurring) {
      return [(festival: festival, date: first)];
    }
    final dates = await collectRecurringOccurrences(
      first: first,
      through: through,
      nextAfter: (start) => nextAfter(festival, start),
    );
    return [for (final date in dates) (festival: festival, date: date)];
  }

  final out = <DatedFestival>[];
  for (var i = 0; i < festivals.length; i += batchSize) {
    final end = (i + batchSize).clamp(0, festivals.length);
    final batch = festivals.sublist(i, end);
    final resolved = await Future.wait(batch.map(resolve));
    out.addAll(resolved.expand((rows) => rows));
  }
  return sortDatedFestivals(out);
}
