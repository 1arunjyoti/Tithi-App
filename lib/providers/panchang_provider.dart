import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import '../models/festival.dart';
import '../models/hindu_month_system.dart';
import '../models/panchang_data.dart';
import '../services/panchang_service.dart';
import '../services/storage_service.dart';
import '../services/sunrise_calculator.dart';
import '../utils/date_utils.dart';
import 'festival_provider.dart';
import 'location_provider.dart';
import 'calendar_provider.dart';

const _panchangLocationSignatureKey = '__location_signature__';

// Sync in-memory stale cache for selected-date UI (EventList + Paksha).
// panchangForDateProvider is an autoDispose family, so tapping another date
// shows a loading spinner for a frame while FFI resolves — the flash below
// the calendar. Stale content renders instantly; fresh data replaces it.
final Map<DateTime, PanchangData> _panchangUiCache = {};
const int _panchangUiCacheMax = 100;

DateTime _normalizeUiDate(DateTime d) => DateTime(d.year, d.month, d.day);

/// Last successful [PanchangData] for [date], if any.
PanchangData? cachedPanchangUiSync(DateTime date) {
  return _panchangUiCache[_normalizeUiDate(date)];
}

void storePanchangUiSync(DateTime date, PanchangData data) {
  if (_panchangUiCache.length >= _panchangUiCacheMax) {
    final toRemove =
        _panchangUiCache.keys.take(_panchangUiCacheMax ~/ 5).toList();
    for (final k in toRemove) {
      _panchangUiCache.remove(k);
    }
  }
  _panchangUiCache[_normalizeUiDate(date)] = data;
}

String _dateKey(DateTime date) => panchangDateKey(date);

String _locationSignature(double latitude, double longitude) {
  return '${latitude.toStringAsFixed(4)}_${longitude.toStringAsFixed(4)}';
}

String _cacheKey(
  DateTime date,
  double latitude,
  double longitude, [
  String suffix = '',
]) {
  return '${_dateKey(date)}_${_locationSignature(latitude, longitude)}${suffix.isNotEmpty ? "_$suffix" : ""}';
}

Future<Box<dynamic>> _preparePanchangCacheBox(
  double latitude,
  double longitude,
) async {
  final cacheBox = await StorageService().openPanchangCacheBox();
  final expectedSignature = _locationSignature(latitude, longitude);
  final storedSignature =
      cacheBox.get(_panchangLocationSignatureKey) as String?;

  if (storedSignature != expectedSignature) {
    await cacheBox.clear();
    await cacheBox.put(_panchangLocationSignatureKey, expectedSignature);
  }

  return cacheBox;
}

double? _getCachedRawTithi(
  Box<dynamic> cacheBox,
  DateTime date,
  double latitude,
  double longitude, {
  String suffix = '',
}) {
  final cached = cacheBox.get(_cacheKey(date, latitude, longitude, suffix));
  if (cached is num) {
    return cached.toDouble();
  }
  return null;
}

Future<void> _storeCachedRawTithi(
  Box<dynamic> cacheBox,
  DateTime date,
  double latitude,
  double longitude,
  double rawTithi, {
  String suffix = '',
}) async {
  await cacheBox.put(_cacheKey(date, latitude, longitude, suffix), rawTithi);
}

// ---------------------------------------------------------------------------
// SMELL-03: Shared computation helpers – eliminate the duplicated 5-point
// tithi calculation block that previously existed in both panchangForDateProvider
// and the computeDateEntry closure inside monthlyPanchangProvider.
// ---------------------------------------------------------------------------

/// Resolves a single raw-tithi value: returns the cached value if present,
/// otherwise computes it via [service] and stores it in [cacheBox].
Future<double> _resolveTithiPoint(
  Box<dynamic> cacheBox,
  DateTime normalizedDate,
  double latitude,
  double longitude,
  PanchangService service,
  DateTime time, {
  String suffix = '',
}) async {
  final cached = _getCachedRawTithi(
    cacheBox, normalizedDate, latitude, longitude,
    suffix: suffix,
  );
  if (cached != null) return cached;
  final computed = await service.calculateTithi(
    time, latitude: latitude, longitude: longitude,
  );
  await _storeCachedRawTithi(
    cacheBox, normalizedDate, latitude, longitude, computed,
    suffix: suffix,
  );
  return computed;
}

/// Locates the first tithi boundary after [sunrise] — i.e. the end of the
/// sunrise (udaya) tithi — within the window ([sunrise], [nextSunrise]].
///
/// [segments] must be time-ordered (time, rawTithi) points starting at
/// [sunrise] and ending at [nextSunrise] (the provider passes its five
/// checkpoints). The first segment straddling the boundary brackets it;
/// bisection via [getRawTithi] then refines it to ~1-minute precision.
///
/// Returns null when no boundary falls in the window (the sunrise tithi
/// still prevails at the next sunrise), or when the refined instant fails
/// validation (wrong tithi just past it, or outside the window) — callers
/// then show the single udaya tithi as before.
///
/// Tithi increases monotonically, so at most the exit from the sunrise
/// tithi is searched even in squeeze cases where two boundaries fall in
/// one window (e.g. Oct 4 2026: Ashtami → Navami → Dashami): surfacing the
/// first one already makes the "lost" tithi (Navami) visible again.
Future<({int toIndex, DateTime at})?> findSunriseTithiTransition({
  required DateTime sunrise,
  required DateTime nextSunrise,
  required double rawTithiAtSunrise,
  required List<({DateTime time, double rawTithi})> segments,
  required Future<double> Function(DateTime time) getRawTithi,
}) async {
  int norm(double raw) => raw.floor().clamp(1, 30);

  final from = norm(rawTithiAtSunrise);
  final to = from % 30 + 1;

  // Ordered, strictly increasing points within [sunrise, nextSunrise].
  final points = segments
      .where((s) => !s.time.isBefore(sunrise) && !s.time.isAfter(nextSunrise))
      .toList()
    ..sort((a, b) => a.time.compareTo(b.time));
  if (points.isEmpty || points.first.time.isAfter(sunrise)) {
    points.insert(0, (time: sunrise, rawTithi: rawTithiAtSunrise));
  }

  // First segment leaving the sunrise tithi brackets the boundary.
  // (Two boundaries can never fall in one short segment: tithis last
  // 19-26h while checkpoint segments span a few hours.)
  DateTime? lo;
  DateTime? hi;
  for (var i = 0; i + 1 < points.length; i++) {
    if (norm(points[i].rawTithi) == from && norm(points[i + 1].rawTithi) != from) {
      lo = points[i].time;
      hi = points[i + 1].time;
      break;
    }
  }
  if (lo == null || hi == null) return null;
  if (!hi.isAfter(sunrise)) return null;
  DateTime low = lo;
  DateTime high = hi;

  // Bisect the exit-from-`from` instant to ~1 minute.
  var guard = 0;
  while (high.difference(low).inMinutes > 1 && guard++ < 60) {
    final mid = low.add(Duration(minutes: high.difference(low).inMinutes ~/ 2));
    if (norm(await getRawTithi(mid)) == from) {
      low = mid;
    } else {
      high = mid;
    }
  }

  // Validate: inside the window, and the expected tithi prevails just after.
  if (!high.isAfter(sunrise) || high.isAfter(nextSunrise)) return null;
  if (norm(await getRawTithi(high.add(const Duration(minutes: 2)))) != to) {
    return null;
  }
  return (toIndex: to, at: high);
}

/// Computes [PanchangData] for a single normalised date.
/// All five tithi checkpoints (sunrise, madhyahna, aparahna, nishita,
/// nextSunrise) are resolved through [_resolveTithiPoint] so results are
/// automatically cached to / served from the Hive panchang cache box.
///
/// When [includeTransition] is true, the first tithi boundary after sunrise
/// is also located (via [findSunriseTithiTransition], bracketed by the five
/// checkpoints and refined by bisection) so the day can show two tithis
/// ("Ashtami → Navami"). This costs extra ephemeris calls, so only the
/// single-day path enables it — the month batch leaves it off.
Future<PanchangData> _computePanchangData({
  required DateTime normalizedDate,
  required PanchangService service,
  required List<Festival> festivals,
  required HinduMonthSystem monthSystem,
  required double latitude,
  required double longitude,
  required Box<dynamic> cacheBox,
  bool includeTransition = false,
}) async {
  final sunriseTime = SunriseCalculator.calculateSunriseIST(
    date: normalizedDate, latitude: latitude, longitude: longitude,
  );
  final sunsetTime = SunriseCalculator.calculateSunsetIST(
    date: normalizedDate, latitude: latitude, longitude: longitude,
  );
  final nextSunriseTime = SunriseCalculator.calculateSunriseIST(
    date: normalizedDate.add(const Duration(days: 1)),
    latitude: latitude, longitude: longitude,
  );

  final madhyahnaTime = sunriseTime.add(
    Duration(minutes: sunsetTime.difference(sunriseTime).inMinutes ~/ 2),
  );
  final aparahnaTime = sunriseTime.add(
    Duration(minutes: sunsetTime.difference(sunriseTime).inMinutes * 3 ~/ 4),
  );
  final nishitaTime = sunsetTime.add(
    Duration(minutes: nextSunriseTime.difference(sunsetTime).inMinutes ~/ 2),
  );

  final rawTithi = await _resolveTithiPoint(
    cacheBox, normalizedDate, latitude, longitude, service, sunriseTime,
  );
  final rawTithiMadhyahna = await _resolveTithiPoint(
    cacheBox, normalizedDate, latitude, longitude, service, madhyahnaTime,
    suffix: 'madhyahna',
  );
  final rawTithiAparahna = await _resolveTithiPoint(
    cacheBox, normalizedDate, latitude, longitude, service, aparahnaTime,
    suffix: 'aparahna',
  );
  final rawTithiNishita = await _resolveTithiPoint(
    cacheBox, normalizedDate, latitude, longitude, service, nishitaTime,
    suffix: 'nishita',
  );
  final rawTithiNextSunrise = await _resolveTithiPoint(
    cacheBox, normalizedDate, latitude, longitude, service, nextSunriseTime,
    suffix: 'nextSunrise',
  );

  // PERF-1: Cache masa computation by date to avoid redundant FFI + astronomical
  // calculations. Masa rarely changes between consecutive days.
  final masaCacheKey = _cacheKey(normalizedDate, latitude, longitude, 'masa');
  final masaNextCacheKey = _cacheKey(normalizedDate, latitude, longitude, 'masaNext');

  var masa = cacheBox.get(masaCacheKey) as String?;
  masa ??= await service.calculateMasa(
    sunriseTime, rawTithi, latitude: latitude, longitude: longitude,
  );
  await cacheBox.put(masaCacheKey, masa);

  var masaNextSunrise = cacheBox.get(masaNextCacheKey) as String?;
  masaNextSunrise ??= await service.calculateMasa(
    nextSunriseTime, rawTithiNextSunrise,
    latitude: latitude, longitude: longitude,
  );
  await cacheBox.put(masaNextCacheKey, masaNextSunrise);

  // Daytime transition (single-day path only): locate the end of the
  // sunrise tithi so squeeze cases (short tithi touching no sunrise)
  // still surface both tithis. Best-effort — a null result simply means
  // the day shows its single udaya tithi as before.
  //
  // Positive results persist in the Hive cache box (same location-scoped
  // keys as the tithi checkpoints): without this, every tap on a
  // transition day re-ran the ~18-call FFI bisection, and the card visibly
  // flashed when the month-batch preview (no transition) swapped for the
  // resolved data. Repeat visits are now zero-FFI and identical, so no
  // swap is perceptible. (No-transition days need no entry: the
  // checkpoint scan already returns null with zero FFI calls.)
  DateTime? transitionTime;
  int? transitionIndex;
  if (includeTransition) {
    final transTimeKey =
        _cacheKey(normalizedDate, latitude, longitude, 'transitionTime');
    final transIndexKey =
        _cacheKey(normalizedDate, latitude, longitude, 'transitionIndex');
    final cachedTime = cacheBox.get(transTimeKey);
    final cachedIndex = cacheBox.get(transIndexKey);
    if (cachedTime is int && cachedIndex is int) {
      final at = DateTime.fromMillisecondsSinceEpoch(cachedTime);
      if (cachedIndex >= 1 &&
          cachedIndex <= 30 &&
          at.isAfter(sunriseTime) &&
          !at.isAfter(nextSunriseTime)) {
        transitionTime = at;
        transitionIndex = cachedIndex;
      }
    } else {
      try {
        final found = await findSunriseTithiTransition(
          sunrise: sunriseTime,
          nextSunrise: nextSunriseTime,
          rawTithiAtSunrise: rawTithi,
          segments: [
            (time: sunriseTime, rawTithi: rawTithi),
            (time: madhyahnaTime, rawTithi: rawTithiMadhyahna),
            (time: aparahnaTime, rawTithi: rawTithiAparahna),
            (time: nishitaTime, rawTithi: rawTithiNishita),
            (time: nextSunriseTime, rawTithi: rawTithiNextSunrise),
          ],
          getRawTithi: (t) => service.calculateTithi(
            t, latitude: latitude, longitude: longitude,
          ),
        );
        transitionTime = found?.at;
        transitionIndex = found?.toIndex;
        if (found != null) {
          await cacheBox.put(
            transTimeKey,
            found.at.millisecondsSinceEpoch,
          );
          await cacheBox.put(transIndexKey, found.toIndex);
        }
      } catch (e) {
        debugPrint('Tithi transition search skipped: $e');
      }
    }
  }

  return PanchangData.fromRawTithi(
    date: normalizedDate,
    rawTithi: rawTithi,
    masa: masa,
    allFestivals: festivals,
    monthSystem: monthSystem,
    sunrise: sunriseTime,
    sunset: sunsetTime,
    rawTithiMadhyahna: rawTithiMadhyahna,
    rawTithiAparahna: rawTithiAparahna,
    rawTithiNishita: rawTithiNishita,
    rawTithiNextSunrise: rawTithiNextSunrise,
    masaNextSunrise: masaNextSunrise,
    tithiTransitionTime: transitionTime,
    transitionTithiIndex: transitionIndex,
  );
}

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
        orElse: () => (latitude: 28.6139, longitude: 77.2090),
      );
    });

/// Provider that tracks if the panchang service is initialized
final panchangInitProvider = FutureProvider<void>((ref) async {
  final service = ref.read(panchangServiceProvider);
  await service.init();
});

/// Provider for panchang data of a specific date
final panchangForDateProvider = FutureProvider.autoDispose
    .family<PanchangData, DateTime>((ref, date) async {
      // Ensure service is initialized
      await ref.watch(panchangInitProvider.future);
      // Ensure festivals are loaded
      await ref.watch(festivalInitProvider.future);

      final service = ref.read(panchangServiceProvider);
      final festivals = ref.read(festivalProvider);
      final monthSystem = ref.watch(hinduMonthSystemProvider);

      final coords = ref.watch(resolvedCoordinatesProvider);
      final latitude = coords.latitude;
      final longitude = coords.longitude;
      final cacheBox = await _preparePanchangCacheBox(latitude, longitude);

      final data = await _computePanchangData(
        normalizedDate: DateTime(date.year, date.month, date.day),
        service: service,
        festivals: festivals,
        monthSystem: monthSystem,
        latitude: latitude,
        longitude: longitude,
        cacheBox: cacheBox,
        // Single-day detail: also locate the daytime tithi transition so
        // squeeze cases show two tithis (month batch skips this for speed).
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

/// Batch provider for monthly panchang data
/// Pre-loads entire month to eliminate N+1 query pattern in calendar.
/// autoDispose with a 5-minute keepAlive: TableCalendar swipes back/forth
/// between the same 2-3 months, so recently visited/precached months stay
/// warm for instant landing instead of recomputing ~210 FFI calls — but
/// each entry holds ~42 PanchangData, so idle months are released rather
/// than retained for the whole session (unbounded family growth).
final monthlyPanchangProvider = FutureProvider.autoDispose
    .family<Map<DateTime, PanchangData>, DateTime>((ref, focusedMonth) async {
      final keepAliveLink = ref.keepAlive();
      final releaseTimer = Timer(
        const Duration(minutes: 5),
        keepAliveLink.close,
      );
      ref.onDispose(releaseTimer.cancel);

      // Ensure service is initialized
      await ref.watch(panchangInitProvider.future);
      await ref.watch(festivalInitProvider.future);

      final service = ref.read(panchangServiceProvider);
      final festivals = ref.read(festivalProvider);
      final monthSystem = ref.watch(hinduMonthSystemProvider);

      final coords = ref.watch(resolvedCoordinatesProvider);
      final latitude = coords.latitude;
      final longitude = coords.longitude;
      final cacheBox = await _preparePanchangCacheBox(latitude, longitude);

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

      final dates = <DateTime>[];
      for (
        var date = startDate;
        date.isBefore(endDate) || date.isAtSameMomentAs(endDate);
        date = date.add(const Duration(days: 1))
      ) {
        dates.add(DateTime(date.year, date.month, date.day));
      }

      const batchSize = 8;
      final monthData = <DateTime, PanchangData>{};

      Future<MapEntry<DateTime, PanchangData>> computeDateEntry(
        DateTime normalizedDate,
      ) async {
        return MapEntry(
          normalizedDate,
          await _computePanchangData(
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

      for (var i = 0; i < dates.length; i += batchSize) {
        final end = (i + batchSize) > dates.length
            ? dates.length
            : i + batchSize;
        final batch = dates.sublist(i, end);
        final entries = await Future.wait(batch.map(computeDateEntry));
        for (final entry in entries) {
          monthData[entry.key] = entry.value;
        }
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
