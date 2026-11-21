import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/async/keep_alive.dart';
import '../features/countdown/data/festival_year_snapshot.dart';
import '../features/countdown/domain/target_resolution.dart';
import 'calendar_provider.dart';
import 'festival_provider.dart';
import 'panchang_provider.dart';

/// All bundled festivals with [year]'s occurrence dates, ascending from
/// January — past festivals first, then the upcoming ones (for the current
/// year the screen auto-scrolls to those on open), undatable entries last.
/// Recurring entries (Ekadashi, Purnima, Amavasya) appear once per
/// occurrence, not once per catalog entry, so the yearly list shows all 24
/// Ekadashis.
///
/// The year is the family parameter: the screen's year selector picks it and
/// each year resolves (and caches) independently, so 2025, 2026 and 2027
/// show their own dates, not today's year.
///
/// Each festival reuses the vriddhi-aware
/// [PanchangService.findNextFestivalOccurrence] forward scan (the same source
/// the countdowns use), run in small parallel batches. Scanning forward from
/// Jan 1 of [year] is correct for past years too — the first match on/after
/// that date lands inside the year.
///
/// Perf: the completed list is persisted as one Hive record per
/// year/location/school/catalog generation ([readFestivalYearSnapshot]), so a
/// revisit (or a launch after process death) paints from disk instead of
/// rebuilding ~150 scans. Resolution always runs from Jan 1 through Dec 31,
/// so a stored list cannot go stale inside the year; a moved place,
/// school/engine bump or catalog edit changes the key and misses cleanly.
///
/// A 5-minute timed `keepAlive` (same pattern as `monthlyPanchangProvider`)
/// still releases the in-memory list when the screen has been closed for a
/// while; reopening then costs one box read. The watch on [todayDateProvider]
/// refreshes the lists at midnight (the key only changes on Jan 1), and a
/// location change invalidates via [resolvedCoordinatesProvider].
final allFestivalOccurrencesProvider = FutureProvider.autoDispose
    .family<List<DatedFestival>, int>((ref, year) async {
      ref.keepAliveFor(const Duration(minutes: 5));

      await ref.watch(panchangInitProvider.future);
      await ref.watch(festivalInitProvider.future);

      final festivals = ref.read(festivalProvider);
      if (festivals.isEmpty) return const [];
      // Watch (not read) so a midnight rollover re-resolves: the year key
      // only changes on Jan 1, when the new year's list must first appear.
      ref.watch(todayDateProvider);
      final yearStart = DateTime(year);
      final coords = ref.watch(resolvedCoordinatesProvider);
      // Read the service first: building it resolves the persisted school,
      // which is part of the snapshot key. Reading it after the snapshot
      // could look up the wrong generation on a cold start.
      final service = ref.read(panchangServiceProvider);
      final catalogVersion = ref
          .read(festivalRepositoryProvider)
          .catalogVersion;

      final snapshot = await readFestivalYearSnapshot(
        yearStart: yearStart,
        festivals: festivals,
        latitude: coords.latitude,
        longitude: coords.longitude,
        catalogVersion: catalogVersion,
      );
      if (snapshot != null) return snapshot;

      try {
        // Shared resolver (features/countdown/domain): batched cached
        // scans — one bad rule resolves dateless instead of failing.
        // Recurring vrats (Ekadashi, Purnima, Amavasya) expand to every
        // occurrence through Dec 31, so the yearly list shows all of them.
        // No month-system watch: resolution is Amanta-fixed, so toggling
        // Amanta↔Purnimant no longer re-scans (rows show dates, not masas).
        final resolved = await resolveDatedFestivals(
          service: service,
          festivals: festivals,
          baseDate: yearStart,
          through: DateTime(year, 12, 31),
          latitude: coords.latitude,
          longitude: coords.longitude,
        );
        await writeFestivalYearSnapshot(
          yearStart: yearStart,
          items: resolved,
          latitude: coords.latitude,
          longitude: coords.longitude,
          catalogVersion: catalogVersion,
        );
        return resolved;
      } catch (e, st) {
        debugPrint('allFestivalOccurrences failed: $e\n$st');
        rethrow;
      }
    });
