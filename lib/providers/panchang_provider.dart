import 'dart:async';

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

/// Computes [PanchangData] for a single normalised date.
/// All five tithi checkpoints (sunrise, madhyahna, aparahna, nishita,
/// nextSunrise) are resolved through [_resolveTithiPoint] so results are
/// automatically cached to / served from the Hive panchang cache box.
Future<PanchangData> _computePanchangData({
  required DateTime normalizedDate,
  required PanchangService service,
  required List<Festival> festivals,
  required HinduMonthSystem monthSystem,
  required double latitude,
  required double longitude,
  required Box<dynamic> cacheBox,
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
