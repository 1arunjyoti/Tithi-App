import 'package:hive/hive.dart';

import '../../../core/format/date_only.dart';
import '../../../models/festival.dart';
import '../../../models/hindu_month_system.dart';
import '../../../services/panchang_service.dart';
import '../data/panchang_cache.dart';

// Occurrence-result cache for forward festival scans.
//
// Each countdown ID, the all-festivals screen, search, and export run
// independent up-to-420-day scans (2-3 FFI calls/day) over heavily
// overlapping ranges. This memoizes ANSWERS keyed by
// (festival, base-month, month system, location); the location signature
// is part of the key so results computed for one set of coordinates are
// never reused after a location change. The Hive box is still cleared on
// location change via [preparePanchangCacheBox] as a second layer, but the
// in-memory map no longer depends on it (it is checked first).
//
// Validity: a stored occurrence O for base-month M stays correct for any
// query base B with month(B) == M and B <= O — forward matches are
// date-ordered and the scan is deterministic per festival/location/mode,
// so O is still the first match >= B. Otherwise the entry is stale and the
// scan re-runs from B.
//
// Null results are deliberately NOT cached: a null means "no match in the
// 420-day window", but the window slides with B, so a later B in the same
// month can legitimately find an occurrence just beyond the earlier window
// (e.g. Kshaya-skip years). Caching null month-wide would hide it for up to
// a month. Legacy -1 entries (written by earlier generations) are ignored
// on read and never written anymore.
//
// Why this instead of one shared scan pass: zero behavior change (pure
// memoization around the existing per-festival API, working with both the
// web and native service impls), composable across all five call sites, and
// Hive-persisted so repeat visits — including after restarts — are instant.
// A shared batch pass would change upfront-latency and memory tradeoffs and
// deserves its own design pass if profiles still hurt after this.

// Bump when scan semantics change (stale generations then miss cleanly).
// occ3: location signature added to the key (occ2 omitted it, so a location
// change reused the old location's in-memory occurrence).
// occ4: festival search-start no longer rolls over to next year (it skipped
// imminent occurrences e.g. Mahalaya 2026 from Oct 2026, caching the 2027
// date under the Oct key — stale occ3 entries must miss).
// occ5: forward scanners gained the Kshaya fallback (previously a Kshaya
// tithi matched the calendar grid but the scan skipped it and cached next
// year's date — stale occ4 entries must miss).
// occ6: countdown dates are Amanta-fixed (the month-system watch was
// removed, so Purnimant-indexed occ5 entries are orphaned — purge them).
// occ7: ALL resolution paths are Amanta-fixed (all-festivals, search and
// export no longer key by the display system — stale occ6 Purnimant entries,
// which the January-preserving TTL would otherwise keep forever, must go).
const String _occPrefix = 'occ7';
// Countdown/all-festivals/search/export share this box: ~150 festivals ×
// a few retained months fit comfortably; evict oldest first past the cap so
// hot (current-month) entries aren't churned by cold (January/export) ones.
const int _occMemoryMax = 500;

final Map<String, int> _occMemory = {};

String _occKey(
  String festivalId,
  DateTime month,
  int monthSystemIndex,
  double latitude,
  double longitude,
) =>
    '${_occPrefix}_${festivalId}_${month.year}-${month.month}_${monthSystemIndex}_${locationSignature(latitude, longitude)}';

void _storeOccMemory(String key, int millis) {
  if (_occMemory.length >= _occMemoryMax) {
    final toRemove = _occMemory.keys.take(_occMemoryMax ~/ 5).toList();
    for (final k in toRemove) {
      _occMemory.remove(k);
    }
  }
  _occMemory[key] = millis;
}

// One-time purge of pre-fix generations (occ2_*..occ6_*) so upgrades don't
// leave stale keys beside occ7 indefinitely, plus TTL eviction of occ7
// entries whose base-month is long past (the box otherwise grows without
// bound: one key per festival × month × system × location). Runs once per
// process on first box access; best-effort.
// Generation purges run once per process; TTL eviction re-runs whenever the
// calendar month rolls over (a process alive across month boundaries would
// otherwise accumulate dead months until restart).
bool _occOldGenerationPurged = false;
int? _occLastEvictionMonthKey;

Future<void> _purgeOldOccurrenceGenerations(Box<dynamic> box) async {
  if (_occOldGenerationPurged) {
    // Generations already purged: still re-evict on month rollover.
    final now = DateTime.now();
    final monthKey = now.year * 12 + now.month;
    if (_occLastEvictionMonthKey != monthKey) {
      try {
        await _evictAgedOccurrenceKeys(box);
        _occLastEvictionMonthKey = monthKey;
      } catch (_) {
        // Best-effort.
      }
    }
    return;
  }
  _occOldGenerationPurged = true;
  try {
    final stale = box.keys
        .whereType<String>()
        .where(
          (k) =>
              k.startsWith('occ2_') ||
              k.startsWith('occ3_') ||
              k.startsWith('occ4_') ||
              k.startsWith('occ5_') ||
              k.startsWith('occ6_'),
        )
        .toList();
    for (final k in stale) {
      await box.delete(k);
    }
    await _evictAgedOccurrenceKeys(box);
    final now = DateTime.now();
    _occLastEvictionMonthKey = now.year * 12 + now.month;
  } catch (_) {
    // Caching is best-effort; stale keys simply miss and age out.
  }
}

/// Deletes current-generation occurrence keys whose base-month can no longer
/// be queried: countdowns query the current month, the all-festivals screen
/// and export query January. Anything else is dead weight from past months
/// (base dates only move forward). January of this/next year is always kept.
Future<void> _evictAgedOccurrenceKeys(Box<dynamic> box) async {
  try {
    final now = DateTime.now();
    final nowMonths = now.year * 12 + now.month;
    final pattern = RegExp('^${_occPrefix}_(.+)_([0-9]+)-([0-9]+)_([0-9]+)_(.+)\$');
    final evict = <String>[];
    for (final key in box.keys.whereType<String>()) {
      if (!key.startsWith('${_occPrefix}_')) continue;
      final match = pattern.firstMatch(key);
      if (match == null) continue;
      final year = int.tryParse(match.group(2) ?? '');
      final month = int.tryParse(match.group(3) ?? '');
      if (year == null || month == null || month < 1 || month > 12) continue;
      // January bases serve the all-festivals screen + year export.
      if (month == 1 && (year == now.year || year == now.year + 1)) continue;
      final ageMonths = nowMonths - (year * 12 + month);
      // Keep the current month and the two previous months (midnight
      // rollover + slow readers); drop anything older or futuristic.
      if (ageMonths < 0 || ageMonths > 2) evict.add(key);
    }
    for (final k in evict) {
      await box.delete(k);
    }
  } catch (_) {
    // Eviction is best-effort; leftovers just occupy a few bytes.
  }
}

/// Cached wrapper for [PanchangService.findNextFestivalOccurrence].
/// Returns the date-only occurrence (callers previously truncated
/// themselves; centralizing keeps every consumer consistent).
Future<DateTime?> findNextFestivalOccurrenceCached({
  required PanchangService service,
  required Festival festival,
  required DateTime startDate,
  required double latitude,
  required double longitude,
  required HinduMonthSystem monthSystem,
}) async {
  final day = dateOnly(startDate);
  final key = _occKey(
    festival.id,
    day,
    monthSystem.index,
    latitude,
    longitude,
  );

  int? cachedMillis = _occMemory[key];
  Box<dynamic>? cacheBox;
  if (cachedMillis == null) {
    try {
      cacheBox = await preparePanchangCacheBox(latitude, longitude);
      await _purgeOldOccurrenceGenerations(cacheBox);
      final stored = cacheBox.get(key);
      if (stored is int && stored >= 0) {
        cachedMillis = stored;
        _storeOccMemory(key, stored);
      }
      // Legacy -1 (null-result) entries are ignored: a null window slides
      // with B (see above), so they must miss and re-scan.
    } catch (_) {
      // Cache unavailable: fall through to compute.
    }
  }
  if (cachedMillis != null && cachedMillis >= 0) {
    final occurrence = DateTime.fromMillisecondsSinceEpoch(cachedMillis);
    if (!occurrence.isBefore(day)) return occurrence;
  }

  final computed = await service.findNextFestivalOccurrence(
    festival,
    startDate: day,
    latitude: latitude,
    longitude: longitude,
  );
  final result = computed == null ? null : dateOnly(computed);
  if (result == null) return null;
  final millis = result.millisecondsSinceEpoch;
  _storeOccMemory(key, millis);
  try {
    cacheBox ??= await preparePanchangCacheBox(latitude, longitude);
    await cacheBox.put(key, millis);
  } catch (_) {
    // Computed value still returned; caching is best-effort.
  }
  return result;
}
