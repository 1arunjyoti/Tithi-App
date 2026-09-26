import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/async/keep_alive.dart';
import '../features/panchang/data/panchang_cache.dart';
import '../features/panchang/domain/tithi_transitions.dart';
import '../models/festival.dart';
import '../models/panchang_data.dart';
import '../services/festival_matching_pipeline.dart';
import '../services/panchang_service.dart';
import '../services/sunrise_calculator.dart';
import 'festival_provider.dart';
import 'location_provider.dart';
import 'calendar_provider.dart';
import '../core/location/location_defaults.dart';
import '../core/format/date_only.dart';

export '../features/panchang/data/panchang_cache.dart'
    show
        cachedPanchangUiSync,
        storePanchangUiSync,
        preparePanchangCacheBox,
        panchangCacheKey,
        panchangMasaCacheSuffix,
        readPanchangCacheDouble,
        readPanchangCacheString;
export '../features/panchang/domain/tithi_transitions.dart'
    show
        TithiCheckpoints,
        findSunriseTithiTransition,
        resolveTithiCheckpoints,
        resolveDayTransition,
        computePanchangData,
        bisectNakshatraEdge;

// Phase 2: cache keys, Hive box prep, and UI-sync LRU live in
// features/panchang/data/panchang_cache.dart (re-exported above for
// backward compatibility with existing imports).

// Phase 2: tithi math lives in
// features/panchang/domain/tithi_transitions.dart (re-exported above).

/// Provider for PanchangService (already exists, re-export)
final panchangServiceProvider = Provider<PanchangService>((ref) {
  return PanchangService();
});

/// Synchronous coordinates provider with Delhi fallback baked in.
final resolvedCoordinatesProvider =
    Provider<({double latitude, double longitude})>((ref) {
      final coords = ref.watch(coordinatesProvider);
      return coords.maybeWhen(
        data: (value) => (latitude: value.latitude, longitude: value.longitude),
        orElse: () => (latitude: kDefaultLatitude, longitude: kDefaultLongitude),
      );
    });

/// Provider that tracks if the panchang service is initialized
///
/// Holds the native ephemeris setup (asset file copy + Jyotish init — the
/// first launch's biggest main-thread stall) until the location permission
/// flow resolves, same as [festivalInitProvider]: the month batch awaits
/// both inits anyway, so nothing downstream is delayed beyond the gate,
/// and the copy no longer contends with the permission dialog.
final panchangInitProvider = FutureProvider<void>((ref) async {
  await ref.watch(locationPermissionGateProvider).future;
  final service = ref.read(panchangServiceProvider);
  await service.init();
});

/// Provider for panchang data of a specific date.
///
/// Single source of truth for festival matches: a Vriddhi-filtered month
/// record. Gregorian views supply it through [monthlyPanchangProvider];
/// Hindu/Bengali adaptive views publish their equivalent resolved record to
/// the UI cache. This provider only resolves the daytime tithi transition on
/// top (the month batches skip that search for speed).
/// On cold start / deep-link the month batch loads first (~30 Hive-cached
/// FFI reads); the direct-compute fallback below runs only if that fails.
final panchangForDateProvider = FutureProvider.autoDispose
    .family<PanchangData, DateTime>((ref, date) async {
      final normalized = DateTime(date.year, date.month, date.day);
      final adaptiveGridEntry = cachedPanchangUiSync(normalized);
      // Ensure service is initialized
      await ref.watch(panchangInitProvider.future);

      final service = ref.read(panchangServiceProvider);
      final coords = ref.watch(resolvedCoordinatesProvider);
      final latitude = coords.latitude;
      final longitude = coords.longitude;
      final cacheBox = await preparePanchangCacheBox(latitude, longitude);

      // Hindu/Bengali adaptive grids have already computed this record,
      // including its Vriddhi-filtered festivals. Reuse it and resolve only
      // the optional intraday transition; requesting monthlyPanchangProvider
      // here would redo an entire Gregorian month on every cold date tap.
      if (adaptiveGridEntry != null) {
        try {
          final checkpoints = await resolveTithiCheckpoints(
            normalizedDate: normalized,
            service: service,
            latitude: latitude,
            longitude: longitude,
            cacheBox: cacheBox,
          );
          final transition = await resolveDayTransition(
            normalizedDate: normalized,
            service: service,
            latitude: latitude,
            longitude: longitude,
            cacheBox: cacheBox,
            checkpoints: checkpoints,
          );
          final data = transition.at == null || transition.index == null
              ? adaptiveGridEntry.copyWith(clearTransition: true)
              : adaptiveGridEntry.copyWith(
                  tithiTransitionTime: transition.at,
                  transitionTithiIndex: transition.index,
                );
          storePanchangUiSync(normalized, data);
          return data;
        } catch (e) {
          // The cached daily record is complete enough for the selected-date
          // UI. A failed optional transition lookup must not fall through to
          // an expensive duplicate month batch.
          debugPrint('Cached single-day transition lookup skipped: $e');
          return adaptiveGridEntry;
        }
      }

      // Ensure festivals are loaded before the cold month/direct paths.
      await ref.watch(festivalInitProvider.future);

      try {
        final monthData = await ref.watch(
          monthlyPanchangProvider(DateTime(normalized.year, normalized.month))
              .future,
        );
        final entry = monthData[normalized];
        if (entry != null) {
          // Month batch skips the transition search: resolve it here for the
          // two-tithi display ("Ashtami → Navami") on squeeze days.
          final checkpoints = await resolveTithiCheckpoints(
            normalizedDate: normalized,
            service: service,
            latitude: latitude,
            longitude: longitude,
            cacheBox: cacheBox,
          );
          final transition = await resolveDayTransition(
            normalizedDate: normalized,
            service: service,
            latitude: latitude,
            longitude: longitude,
            cacheBox: cacheBox,
            checkpoints: checkpoints,
          );
          final data = (transition.at == null || transition.index == null)
              ? entry.copyWith(clearTransition: true)
              : entry.copyWith(
                  tithiTransitionTime: transition.at,
                  transitionTithiIndex: transition.index,
                );
          // Feed the stale-UI LRU so date taps render instantly next time.
          storePanchangUiSync(date, data);
          return data;
        }
      } catch (e) {
        debugPrint('Month-map single-day lookup failed, falling back: $e');
      }

      final festivals = ref.read(festivalProvider);
      final monthSystem = ref.watch(hinduMonthSystemProvider);
      final data = await computePanchangData(
        normalizedDate: normalized,
        service: service,
        festivals: festivals,
        monthSystem: monthSystem,
        latitude: latitude,
        longitude: longitude,
        cacheBox: cacheBox,
        // Single-day detail: also locate the daytime tithi transition so
        // squeeze cases show two tithis (month batch skips this for speed).
        // NOTE: this fallback path is unfiltered for Vriddhi; it runs only
        // when the month map itself failed to load.
        includeTransition: true,
      );
      // Feed the stale-UI LRU so date taps render instantly next time.
      storePanchangUiSync(date, data);
      return data;
    });

/// Provider for today's panchang.
/// Watches [todayDateProvider] so it automatically refreshes at midnight
/// without requiring an app restart (BUG-03 fix).
final todayPanchangProvider = FutureProvider<PanchangData>((ref) async {
  final today = ref.watch(todayDateProvider);
  return ref.watch(panchangForDateProvider(today).future);
});

/// Provider for current paksha (for theming)
final currentPakshaProvider = Provider<AsyncValue<String>>((ref) {
  return ref.watch(todayPanchangProvider).whenData((data) => data.paksha);
});

/// Current-time source for live-tithi evaluation. Defaults to the wall
/// clock; tests override it with a fixed instant to simulate boundary
/// crossings deterministically (widget-test pumps advance fake timers but
/// not the wall clock, so time-travel assertions need this seam).
final liveNowProvider = Provider<DateTime>((ref) => DateTime.now());

/// Intraday tithi-change ticker for the live hero.
///
/// Watches today's single-day record and arms a single one-shot [Timer] for
/// the next tithi boundary strictly in the future (transition instant, or —
/// once flipped — the follow-on end of the incoming tithi on kshaya days,
/// resolved through [tithiTimingsProvider] only then). Firing bumps the
/// tick so [livePanchangProvider] relabels; the timer is cancelled and
/// re-armed on every rebuild (date tap, midnight rollover, reload).
/// Dormant while browsing non-today dates and on boundary-free (vriddhi)
/// days. No polling, no FFI at fire time for the common single flip.
class LiveTithiTickNotifier extends AutoDisposeNotifier<int> {
  Timer? _timer;
  int _tick = 0;

  /// Grace after a boundary before flipping, mirroring the midnight
  /// refresh's +1s: the stored instant is minute-precise, so firing
  /// marginally late guarantees `now` compares past it.
  static const _flipGrace = Duration(seconds: 1);

  @override
  int build() {
    ref.onDispose(() {
      _timer?.cancel();
      _timer = null;
    });
    final selected = ref.watch(selectedDateProvider);
    final today = ref.watch(todayDateProvider);
    _timer?.cancel();
    _timer = null;
    if (!isSameDay(selected, today)) return _tick;

    final day = ref.watch(panchangForDateProvider(today)).valueOrNull;
    if (day == null ||
        !day.hasTithiTransition ||
        day.tithiTransitionTime == null) {
      return _tick;
    }
    final now = ref.watch(liveNowProvider);
    final transitionTime = day.tithiTransitionTime!;
    if (now.isBefore(transitionTime)) {
      _arm(transitionTime, now);
      return _tick;
    }
    // Already flipped: chain onto the incoming tithi's end when it is a
    // second INTRADAY boundary (kshaya squeeze). A normal next-day end
    // falls past tomorrow's sunrise and arms nothing — midnight rollover
    // owns the date change.
    final transitionIndex = day.transitionTithiIndex;
    if (transitionIndex == null) return _tick;
    final coords = ref.watch(resolvedCoordinatesProvider);
    final followOnEnd = ref
        .watch(
          tithiTimingsProvider((
            date: day.date,
            tithiIndex: transitionIndex,
            latitude: coords.latitude,
            longitude: coords.longitude,
          )),
        )
        .valueOrNull
        ?.end;
    if (followOnEnd == null) return _tick;
    final nextSunrise = SunriseCalculator.calculateSunriseIST(
      date: day.date.add(const Duration(days: 1)),
      latitude: coords.latitude,
      longitude: coords.longitude,
    );
    if (followOnEnd.isAfter(transitionTime) &&
        followOnEnd.isAfter(now) &&
        followOnEnd.isBefore(nextSunrise)) {
      _arm(followOnEnd, now);
    }
    return _tick;
  }

  void _arm(DateTime instant, DateTime now) {
    final delay = instant.difference(now) + _flipGrace;
    if (delay.isNegative) return;
    _timer = Timer(delay, () {
      _tick++;
      state = _tick;
    });
  }
}

final liveTithiTickProvider =
    NotifierProvider.autoDispose<LiveTithiTickNotifier, int>(
      LiveTithiTickNotifier.new,
    );

/// Day record with the displayed label advanced to the tithi prevailing
/// right now ([PanchangData.withLiveLabel]) — but only for today. Browsed
/// dates stay frozen on their sunrise labels. Festivals, masa and the
/// sunrise record are preserved untouched (sunrise pinning), so only the
/// label — title, timings queries keyed by it, hero chip — goes live.
///
/// The kshaya follow-on boundary is resolved here (same [tithiTimingsProvider]
/// instance the tick provider watches, so one lookup serves both) and only
/// once flipped; pre-flip this costs zero extra FFI.
final livePanchangProvider = FutureProvider.autoDispose
    .family<PanchangData, DateTime>((ref, day) async {
      ref.watch(liveTithiTickProvider);
      final base = await ref.watch(panchangForDateProvider(day).future);
      final today = ref.watch(todayDateProvider);
      if (!isSameDay(day, today)) return base;
      final now = ref.watch(liveNowProvider);
      DateTime? followOnTime;
      int? followOnIndex;
      if (base.hasTithiTransition &&
          base.tithiTransitionTime != null &&
          base.transitionTithiIndex != null &&
          !now.isBefore(base.tithiTransitionTime!)) {
        // Best-effort: a failing ephemeris lookup here must never take down
        // the hero — the first flip needs zero FFI, so degrade to it.
        try {
          final coords = ref.watch(resolvedCoordinatesProvider);
          final timings = await ref.watch(
            tithiTimingsProvider((
              date: base.date,
              tithiIndex: base.transitionTithiIndex!,
              latitude: coords.latitude,
              longitude: coords.longitude,
            )).future,
          );
          final nextSunrise = SunriseCalculator.calculateSunriseIST(
            date: base.date.add(const Duration(days: 1)),
            latitude: coords.latitude,
            longitude: coords.longitude,
          );
          if (timings != null &&
              timings.end.isAfter(base.tithiTransitionTime!) &&
              timings.end.isBefore(nextSunrise)) {
            followOnTime = timings.end;
            followOnIndex = base.transitionTithiIndex! % 30 + 1;
          }
        } catch (_) {
          // Follow-on stays unresolved: label holds the flipped-to tithi.
        }
      }
      return base.withLiveLabel(
        now,
        followOnTime: followOnTime,
        followOnIndex: followOnIndex,
      );
    });

/// Batch provider for monthly panchang data
/// Pre-loads entire month to eliminate N+1 query pattern in calendar.
/// autoDispose with a 5-minute keepAlive: TableCalendar swipes back/forth
/// between the same 2-3 months, so recently visited/precached months stay
/// warm for instant landing instead of recomputing ~210 FFI calls — but
/// each entry holds ~42 PanchangData, so idle months are released rather
/// than retained for the whole session (unbounded family growth).
final monthlyPanchangProvider = FutureProvider.autoDispose
    .family<Map<DateTime, PanchangData>, DateTime>((ref, focusedMonth) async {
      ref.keepAliveFor(const Duration(minutes: 5));

      // Ensure service is initialized
      await ref.watch(panchangInitProvider.future);
      await ref.watch(festivalInitProvider.future);

      final service = ref.read(panchangServiceProvider);
      final festivals = ref.read(festivalProvider);
      final monthSystem = ref.watch(hinduMonthSystemProvider);

      final coords = ref.watch(resolvedCoordinatesProvider);
      final latitude = coords.latitude;
      final longitude = coords.longitude;
      final cacheBox = await preparePanchangCacheBox(latitude, longitude);

      // Generate dates for the entire month view (including previous/next month overflow)
      final firstDayOfMonth = DateTime(focusedMonth.year, focusedMonth.month);
      final lastDayOfMonth = DateTime(
        focusedMonth.year,
        focusedMonth.month + 1,
        0,
      );

      // Include days from previous month to fill first week
      final startDate = firstDayOfMonth.subtract(
        Duration(days: firstDayOfMonth.weekday % 7),
      );
      // Include days from next month to fill last week
      final endDate = lastDayOfMonth.add(
        Duration(days: 7 - (lastDayOfMonth.weekday % 7)),
      );

      // Grid dates are derived from [startDate]/[endDate] below; the
      // computation set is padded by 2 days for Vriddhi edge runs.
      const batchSize = 8;
      // Full computation map, padded by 2 days on each side: Vriddhi runs
      // can straddle the grid edge, and trimming a run without its neighbor
      // would keep the wrong day. Padding days are Hive-cached, so the cost
      // is ~zero on repeat visits. Only grid dates are returned.
      final fullData = <DateTime, PanchangData>{};

      Future<MapEntry<DateTime, PanchangData>> computeDateEntry(
        DateTime normalizedDate,
      ) async {
        return MapEntry(
          normalizedDate,
          await computePanchangData(
            normalizedDate: normalizedDate,
            service: service,
            festivals: festivals,
            monthSystem: monthSystem,
            latitude: latitude,
            longitude: longitude,
            cacheBox: cacheBox,
          ),
        );
      }

      final paddedStart = startDate.subtract(const Duration(days: 2));
      final paddedEnd = endDate.add(const Duration(days: 2));
      final allDates = <DateTime>[];
      for (
        var date = paddedStart;
        date.isBefore(paddedEnd) || date.isAtSameMomentAs(paddedEnd);
        date = date.add(const Duration(days: 1))
      ) {
        allDates.add(DateTime(date.year, date.month, date.day));
      }

      for (var i = 0; i < allDates.length; i += batchSize) {
        final end = (i + batchSize) > allDates.length
            ? allDates.length
            : i + batchSize;
        final batch = allDates.sublist(i, end);
        final entries = await Future.wait(batch.map(computeDateEntry));
        for (final entry in entries) {
          fullData[entry.key] = entry.value;
        }
      }

      // Single code path for Vriddhi trimming: the month map (padded) is
      // filtered once here; every consumer reads the filtered result.
      final filtered = applyVriddhiFilter(fullData);
      final monthData = <DateTime, PanchangData>{};
      for (
        var date = startDate;
        date.isBefore(endDate) || date.isAtSameMomentAs(endDate);
        date = date.add(const Duration(days: 1))
      ) {
        final key = DateTime(date.year, date.month, date.day);
        final value = filtered[key];
        if (value != null) monthData[key] = value;
      }

      return monthData;
    });

/// Provider to calculate the exact start and end times for a specific Tithi on-demand.
/// [tithiIndex] is the full 1-30 tithi index (1-15 = Shukla, 16-30 = Krishna),
/// i.e. the festival's OBSERVED tithi ([Festival.resolveTithiIndex]) — which
/// can differ from the day's sunrise tithi when a timingOverride applies.
/// NOTE: do NOT pass the 1-15 paksha-relative [PanchangData.tithiNumber] here —
/// doing so silently resolves Krishna tithis to the wrong (Shukla) fortnight.
///
/// Returns null when the tithi has no occurrence near [date] (Kshaya /
/// skipped tithi): the nearest occurrence would belong to another lunation,
/// so callers must hide timings instead of showing a wrong-month span.
final tithiTimingsProvider =
    FutureProvider.family<
      ({DateTime start, DateTime end})?,
      ({DateTime date, int tithiIndex, double latitude, double longitude})
    >((ref, params) async {
      final service = ref.read(panchangServiceProvider);
      if (!service.isInitialized) {
        await service.init();
      }

      // Calculate start and end times via binary search in the native service
      final startTime = await service.calculateTithiStartTime(
        params.date,
        params.tithiIndex,
        latitude: params.latitude,
        longitude: params.longitude,
      );

      final endTime = await service.calculateTithiEndTime(
        params.date,
        params.tithiIndex,
        latitude: params.latitude,
        longitude: params.longitude,
      );

      // Guard: a tithi lasts <26h, so a span starting/ending more than 2
      // days from the festival day belongs to another lunation (Kshaya).
      if (startTime.difference(params.date).inDays.abs() > 2 ||
          endTime.difference(params.date).inDays.abs() > 2) {
        return null;
      }

      return (start: startTime, end: endTime);
    });

// Phase 2: canonical implementation lives in
// features/panchang/domain/tithi_transitions.dart as [bisectNakshatraEdge].
// Kept as a thin alias so existing call-sites keep working.
Future<DateTime?> _bisectNakshatraEdge({
  required DateTime lo,
  required DateTime hi,
  required int sunriseIndex,
  required bool findStart,
  required Future<int?> Function(DateTime time) indexAt,
}) =>
    bisectNakshatraEdge(
      lo: lo,
      hi: hi,
      sunriseIndex: sunriseIndex,
      findStart: findStart,
      indexAt: indexAt,
    );

/// Provider for the sunrise nakshatra's span on a specific date.
///
/// Resolves the nakshatra prevailing at sunrise through [PanchangService]
/// (Lahiri-sidereal Moon longitude folded into 27 segments of 13°20′) and
/// bisects both its start (backward) and end (forward) to ~1-minute
/// precision, so the sheet can show "Rohini until 3:42 PM" with elapsed
/// progress.
///
/// Returns null when the nakshatra can't be resolved (the web fallback has
/// no ephemeris) or a boundary search fails: callers hide the card instead
/// of showing a wrong span — same hide-on-null contract as
/// [tithiTimingsProvider].
final nakshatraTimingsProvider = FutureProvider.family<
  ({int index, String nakshatra, DateTime start, DateTime end})?,
  ({DateTime date, double latitude, double longitude})
>((ref, params) async {
  final service = ref.read(panchangServiceProvider);
  if (!service.isInitialized) {
    await service.init();
  }

  final normalized = DateTime(
    params.date.year,
    params.date.month,
    params.date.day,
  );
  final sunrise = SunriseCalculator.calculateSunriseIST(
    date: normalized,
    latitude: params.latitude,
    longitude: params.longitude,
  );

  Future<int?> indexAt(DateTime time) async {
    final name = await service.calculateNakshatra(
      time,
      latitude: params.latitude,
      longitude: params.longitude,
    );
    if (name == null) return null;
    final idx = hinduNakshatras.indexOf(name);
    return idx >= 0 ? idx : null;
  }

  final sunriseIndex = await indexAt(sunrise);
  if (sunriseIndex == null) return null;

  // Bracket both edges in 2h steps (a nakshatra lasts ~19-26h, so the
  // first bracket closes within ~13 probes; 48h caps runaway searches).
  const step = Duration(hours: 2);
  const cap = Duration(hours: 48);
  Future<({DateTime inner, DateTime outer})?> bracket(int sign) async {
    DateTime inner = sunrise;
    DateTime outer = sunrise.add(step * sign);
    for (var i = 0; i < 24; i++) {
      final idx = await indexAt(outer);
      if (idx == null) return null;
      if (idx != sunriseIndex) return (inner: inner, outer: outer);
      inner = outer;
      outer = outer.add(step * sign);
      if ((outer.difference(sunrise).inHours).abs() >= cap.inHours) break;
    }
    return null;
  }

  // The two edges are independent (all state is immutable or scoped to
  // the stateless [indexAt] closure), so bracket and bisect them
  // concurrently to halve the cold-open probe latency.
  final brackets = await Future.wait([bracket(1), bracket(-1)]);
  final endBracket = brackets[0];
  final startBracket = brackets[1];
  if (endBracket == null || startBracket == null) return null;

  final edges = await Future.wait([
    _bisectNakshatraEdge(
      lo: endBracket.inner,
      hi: endBracket.outer,
      sunriseIndex: sunriseIndex,
      findStart: false,
      indexAt: indexAt,
    ),
    _bisectNakshatraEdge(
      lo: startBracket.outer,
      hi: startBracket.inner,
      sunriseIndex: sunriseIndex,
      findStart: true,
      indexAt: indexAt,
    ),
  ]);
  final end = edges[0];
  final start = edges[1];
  if (end == null || start == null) return null;

  // Guard: a span reaching absurdly far from the day is a failed search,
  // not a real nakshatra (same 2-day rule as the tithi timings).
  if (start.difference(normalized).inDays.abs() > 2 ||
      end.difference(normalized).inDays.abs() > 2) {
    return null;
  }

  return (
    index: sunriseIndex,
    nakshatra: hinduNakshatras[sunriseIndex],
    start: start,
    end: end,
  );
});

/// Provider for the sunrise yoga's and karana's end times on a date.
///
/// Yoga uses the SUM of the sidereal longitudes (ayanamsa enters twice —
/// the most ayanamsa-sensitive panchanga element) and karana the halved
/// elongation; both indices come from a single Sun+Moon probe per instant
/// via [PanchangService.calculateSunMoonLongitudes], and each end is
/// bisected to ~1-minute precision (yoga spans ~24h like nakshatras,
/// karanas ~12h, so the bracket steps differ).
///
/// Returns null when longitudes are unavailable (web fallback) or a search
/// fails: callers hide the card instead of showing a wrong span — same
/// hide-on-null contract as [tithiTimingsProvider].
final yogaKaranaTimingsProvider = FutureProvider.family<
  ({
    int yogaIndex,
    String yoga,
    DateTime yogaEnd,
    int karanaIndex,
    String karana,
    DateTime karanaEnd,
  })?,
  ({DateTime date, double latitude, double longitude})
>((ref, params) async {
  final service = ref.read(panchangServiceProvider);
  if (!service.isInitialized) {
    await service.init();
  }

  final normalized = DateTime(
    params.date.year,
    params.date.month,
    params.date.day,
  );
  final sunrise = SunriseCalculator.calculateSunriseIST(
    date: normalized,
    latitude: params.latitude,
    longitude: params.longitude,
  );

  Future<({int yoga, int karana})?> indexesAt(DateTime time) async {
    final longs = await service.calculateSunMoonLongitudes(
      time,
      latitude: params.latitude,
      longitude: params.longitude,
    );
    if (longs == null) return null;
    return (
      yoga: yogaIndexFor(longs.sun, longs.moon),
      karana: karanaIndexFor(longs.sun, longs.moon),
    );
  }

  /// First instant after [sunrise] where [select] leaves [target]:
  /// bracket in [step] increments (capped at 48h), then bisect to 1 min.
  Future<DateTime?> spanEnd({
    required int Function(({int yoga, int karana}) idx) select,
    required int target,
    required Duration step,
  }) async {
    DateTime inner = sunrise;
    DateTime outer = sunrise.add(step);
    var bracketed = false;
    for (var i = 0; i < 48; i++) {
      final idx = await indexesAt(outer);
      if (idx == null) return null;
      if (select(idx) != target) {
        bracketed = true;
        break;
      }
      inner = outer;
      outer = outer.add(step);
      if (outer.difference(sunrise).abs() >= const Duration(hours: 48)) break;
    }
    if (!bracketed) return null;
    var guard = 0;
    while (outer.difference(inner).inMinutes > 1 && guard++ < 60) {
      final mid =
          inner.add(Duration(minutes: outer.difference(inner).inMinutes ~/ 2));
      final idx = await indexesAt(mid);
      if (idx == null) return null;
      if (select(idx) == target) {
        inner = mid;
      } else {
        outer = mid;
      }
    }
    return outer;
  }

  final atSunrise = await indexesAt(sunrise);
  if (atSunrise == null) return null;

  // Independent searches over the same stateless probe: run together.
  final ends = await Future.wait([
    spanEnd(
      select: (idx) => idx.yoga,
      target: atSunrise.yoga,
      step: const Duration(hours: 2),
    ),
    spanEnd(
      select: (idx) => idx.karana,
      target: atSunrise.karana,
      step: const Duration(hours: 1),
    ),
  ]);
  final yogaEnd = ends[0];
  final karanaEnd = ends[1];
  if (yogaEnd == null || karanaEnd == null) return null;

  // Guard: spans reaching absurdly far are failed searches (same 2-day
  // rule as the tithi/nakshatra timings).
  if (yogaEnd.difference(normalized).inDays.abs() > 2 ||
      karanaEnd.difference(normalized).inDays.abs() > 2) {
    return null;
  }

  return (
    yogaIndex: atSunrise.yoga,
    yoga: yogaNames[atSunrise.yoga],
    yogaEnd: yogaEnd,
    karanaIndex: atSunrise.karana,
    karana: karanaNameForIndex(atSunrise.karana),
    karanaEnd: karanaEnd,
  );
});
