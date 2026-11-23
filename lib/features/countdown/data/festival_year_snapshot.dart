import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

import '../../../models/festival.dart';
import '../../../services/storage_service.dart';
import '../../panchang/data/panchang_cache.dart';
import '../domain/target_resolution.dart';

// Persisted yearly festival list.
//
// The per-scan occurrence cache (features/panchang/domain/occurrence_cache)
// memoizes individual ephemeris scans, but rebuilding the all-festivals list
// still reads one entry per festival and re-expands every recurring vrat. That
// work is cheap once the box is warm, yet a cold start has to do it before the
// screen can paint. This snapshot stores the *finished* list as a single Hive
// record, so the screen's first frame after a launch (or after the OS evicted
// the process) is one box read.
//
// The rows are a pure function of the key: resolution always runs from Jan 1
// through Dec 31, so the list cannot change inside a year for the same
// location, calculation school/version and festival catalog. A new year, a
// moved place, a school switch, an engine bump or an edited catalog changes
// the key and misses cleanly; there is no time-based staleness to expire.
// Recurring expansions (24 Ekadashis, 12 Purnimas/Amavasyas) are already part
// of the stored rows.
const String _snapshotPrefix = 'year1';

/// Version of the occurrence-resolution semantics baked into a stored list.
///
/// The snapshot stores *answers*, so it must miss when the scanner changes
/// even if the catalog and calculation engine do not. Bump when
/// `PanchangService.findNextFestivalOccurrence` (or the vriddhi/recurring
/// expansion) changes which dates it returns.
///
/// 2: the search-start hint no longer lands after the base date. A January
/// scan for Pausha used to start on Oct 17, skipping Shattila Ekadashi
/// (Jan 14 2026) and storing the 2027 date; lists written by that scanner
/// must not be served.
const int _resolutionVersion = 2;

/// Identity of one persisted yearly list.
///
/// [locationSignature] carries the location (rounded cache grid), the
/// calculation version, the place-context version and the school. The catalog
/// fingerprint is separate because editing `assets/festivals.json` changes the
/// rules without changing the engine version. [_resolutionVersion] covers
/// code-only scanner changes, which neither of those fingerprints sees.
String festivalYearSnapshotKey({
  required DateTime yearStart,
  required double latitude,
  required double longitude,
  required int catalogVersion,
}) {
  return '${_snapshotPrefix}_${yearStart.year}_'
      '${locationSignature(latitude, longitude)}_$catalogVersion'
      '_r$_resolutionVersion';
}

/// Stored date as `YYYYMMDD` in the *local* calendar, not epoch millis.
///
/// A date-only value must survive a timezone change between launches; epoch
/// millis would decode to the previous/next local day after a flight.
int _encodeDate(DateTime date) =>
    date.year * 10000 + date.month * 100 + date.day;

DateTime? _decodeDate(int value) {
  final year = value ~/ 10000;
  final month = (value ~/ 100) % 100;
  final day = value % 100;
  if (year < 1800 || year > 2399) return null;
  if (month < 1 || month > 12 || day < 1 || day > 31) return null;
  final date = DateTime(year, month, day);
  // Reject 2026-02-31 style values instead of silently rolling into March.
  if (date.year != year || date.month != month || date.day != day) return null;
  return date;
}

/// Reads the persisted list for [yearStart], or null on a miss/corruption.
///
/// [festivals] is the current catalog: rows for ids it no longer contains are
/// dropped, and a record that knows none of them is treated as a miss (the
/// catalog changed without a version bump).
Future<List<DatedFestival>?> readFestivalYearSnapshot({
  required DateTime yearStart,
  required List<Festival> festivals,
  required double latitude,
  required double longitude,
  required int catalogVersion,
}) async {
  if (festivals.isEmpty) return null;
  final key = festivalYearSnapshotKey(
    yearStart: yearStart,
    latitude: latitude,
    longitude: longitude,
    catalogVersion: catalogVersion,
  );

  try {
    final box = await StorageService().openFestivalOccurrencesBox();
    final stored = box.get(key);
    if (stored is! Map) return null;

    final byId = {for (final festival in festivals) festival.id: festival};
    final rows = <DatedFestival>[];
    for (final entry in stored.entries) {
      final festival = byId[entry.key];
      if (festival == null) continue;
      final dates = entry.value;
      if (dates is! List || dates.isEmpty) {
        rows.add((festival: festival, date: null));
        continue;
      }
      for (final raw in dates) {
        if (raw is! int) continue;
        final date = _decodeDate(raw);
        if (date != null) rows.add((festival: festival, date: date));
      }
    }
    if (rows.isEmpty) return null;
    return sortDatedFestivals(rows);
  } catch (error) {
    debugPrint('Festival year snapshot read failed: $error');
    return null;
  }
}

/// Stores [items] as this year's resolved list.
///
/// Best-effort: a failed write only costs the next cold start a recompute.
/// Older records are pruned to the [_maxYearSnapshots] most recent years
/// (the record just written is always kept), so browsing earlier/later years
/// does not accumulate unbounded records while a switch back to a recently
/// browsed year still hits. A record's key carries the year, so a move or
/// upgrade simply misses — stale-location records age out through the same
/// cap.
Future<void> writeFestivalYearSnapshot({
  required DateTime yearStart,
  required List<DatedFestival> items,
  required double latitude,
  required double longitude,
  required int catalogVersion,
}) async {
  if (items.isEmpty) return;
  final key = festivalYearSnapshotKey(
    yearStart: yearStart,
    latitude: latitude,
    longitude: longitude,
    catalogVersion: catalogVersion,
  );

  final rows = <String, List<int>>{};
  for (final item in items) {
    final dates = rows.putIfAbsent(item.festival.id, () => <int>[]);
    final date = item.date;
    if (date != null) {
      dates.add(_encodeDate(date));
    }
  }

  try {
    final box = await StorageService().openFestivalOccurrencesBox();
    await box.put(key, rows);
    await _pruneYearSnapshots(box, keep: key);
  } catch (error) {
    debugPrint('Festival year snapshot write failed: $error');
  }
}

/// How many yearly snapshot records the box retains. Large enough that
/// stepping through adjacent years never evicts the year being left (the
/// user browses a handful of years at a time), small enough that the
/// `year1_` records cannot grow without bound.
const int _maxYearSnapshots = 8;

final RegExp _snapshotYearPattern = RegExp(r'^year1_(\d{4})_');

/// Deletes the oldest snapshot records past the cap, always keeping [keep]
/// (the record just written, even if it is a far-past/future year — dropping
/// it would make the very next visit re-scan).
Future<void> _pruneYearSnapshots(
  Box<dynamic> box, {
  required String keep,
}) async {
  final byYear = <String, int>{};
  for (final k in box.keys.whereType<String>()) {
    final match = _snapshotYearPattern.firstMatch(k);
    if (match != null) byYear[k] = int.parse(match.group(1)!);
  }
  if (byYear.length <= _maxYearSnapshots) return;
  final sorted = byYear.keys.toList()
    ..sort((a, b) => byYear[b]!.compareTo(byYear[a]!));
  final evict = sorted.skip(_maxYearSnapshots).where((k) => k != keep).toList();
  for (final k in evict) {
    await box.delete(k);
  }
}
