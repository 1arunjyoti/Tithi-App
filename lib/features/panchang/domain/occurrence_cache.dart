import 'package:hive/hive.dart';

import '../../../core/format/date_only.dart';
import '../../../models/festival.dart';
import '../../../models/hindu_month_system.dart';
import '../../../services/panchang_service.dart';
import '../data/panchang_cache.dart';

// Occurrence-result cache for forward festival scans.
//
// Each countdown ID, the all-festivals screen, search, and export run
// independent up-to-380-day scans (2-3 FFI calls/day) over heavily
// overlapping ranges. This memoizes ANSWERS keyed by
// (festival, base-month, month system); location scope comes free because
// [preparePanchangCacheBox] clears the box on location change.
//
// Validity: a stored occurrence O for base-month M stays correct for any
// query base B with month(B) == M and B <= O — forward matches are
// date-ordered and the scan is deterministic per festival/location/mode,
// so O is still the first match >= B. Otherwise the entry is stale and the
// scan re-runs from B. Null results cache as -1 (invalid rules stay cheap).
//
// Why this instead of one shared scan pass: zero behavior change (pure
// memoization around the existing per-festival API, working with both the
// web and native service impls), composable across all five call sites, and
// Hive-persisted so repeat visits — including after restarts — are instant.
// A shared batch pass would change upfront-latency and memory tradeoffs and
// deserves its own design pass if profiles still hurt after this.

// Bump when scan semantics change (stale generations then miss cleanly).
const String _occPrefix = 'occ2';
const int _occMemoryMax = 200;

final Map<String, int> _occMemory = {};

String _occKey(String festivalId, DateTime month, int monthSystemIndex) =>
    '${_occPrefix}_${festivalId}_${month.year}-${month.month}_$monthSystemIndex';

void _storeOccMemory(String key, int millis) {
  if (_occMemory.length >= _occMemoryMax) {
    final toRemove = _occMemory.keys.take(_occMemoryMax ~/ 5).toList();
    for (final k in toRemove) {
      _occMemory.remove(k);
    }
  }
  _occMemory[key] = millis;
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
  final key = _occKey(festival.id, day, monthSystem.index);

  int? cachedMillis = _occMemory[key];
  Box<dynamic>? cacheBox;
  if (cachedMillis == null) {
    try {
      cacheBox = await preparePanchangCacheBox(latitude, longitude);
      final stored = cacheBox.get(key);
      if (stored is int) {
        cachedMillis = stored;
        _storeOccMemory(key, stored);
      }
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
  final millis =
      result == null ? -1 : result.millisecondsSinceEpoch;
  _storeOccMemory(key, millis);
  try {
    cacheBox ??= await preparePanchangCacheBox(latitude, longitude);
    await cacheBox.put(key, millis);
  } catch (_) {
    // Computed value still returned; caching is best-effort.
  }
  return result;
}
