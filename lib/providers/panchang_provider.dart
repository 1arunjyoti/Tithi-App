import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import '../models/panchang_data.dart';
import '../services/panchang_service.dart';
import '../services/storage_service.dart';
import '../services/sunrise_calculator.dart';
import 'festival_provider.dart';
import 'location_provider.dart';
import 'calendar_provider.dart';

const _panchangLocationSignatureKey = '__location_signature__';

String _dateKey(DateTime date) {
  final normalized = DateTime(date.year, date.month, date.day);
  final month = normalized.month.toString().padLeft(2, '0');
  final day = normalized.day.toString().padLeft(2, '0');
  return '${normalized.year}-$month-$day';
}

String _locationSignature(double latitude, double longitude) {
  return '${latitude.toStringAsFixed(4)}_${longitude.toStringAsFixed(4)}';
}

String _cacheKey(DateTime date, double latitude, double longitude) {
  return '${_dateKey(date)}_${_locationSignature(latitude, longitude)}';
}

Future<Box<dynamic>> _preparePanchangCacheBox(
  double latitude,
  double longitude,
) async {
  final cacheBox = await StorageService().openPanchangCacheBox();
  final expectedSignature = _locationSignature(latitude, longitude);
  final storedSignature = cacheBox.get(_panchangLocationSignatureKey) as String?;

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
  double longitude,
) {
  final cached = cacheBox.get(_cacheKey(date, latitude, longitude));
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
  double rawTithi,
) async {
  await cacheBox.put(_cacheKey(date, latitude, longitude), rawTithi);
}

/// Provider for PanchangService (already exists, re-export)
final panchangServiceProvider = Provider<PanchangService>((ref) {
  return PanchangService();
});

/// Synchronous coordinates provider with Delhi fallback baked in.
final resolvedCoordinatesProvider = Provider<({double latitude, double longitude})>((
  ref,
) {
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
final panchangForDateProvider =
    FutureProvider.autoDispose.family<PanchangData, DateTime>((ref, date) async {
  // Ensure service is initialized
  await ref.watch(panchangInitProvider.future);
  // Ensure festivals are loaded
  await ref.watch(festivalInitProvider.future);

  final service = ref.read(panchangServiceProvider);
  final festivals = ref.read(festivalProvider);

  // Get user's Hindu month system preference (Amanta or Purnimant)
  final monthSystem = ref.watch(hinduMonthSystemProvider);

  // Get user's location coordinates (defaults to Delhi if unavailable)
  final coords = ref.watch(resolvedCoordinatesProvider);
  final latitude = coords.latitude;
  final longitude = coords.longitude;
  final cacheBox = await _preparePanchangCacheBox(latitude, longitude);

  // Calculate actual sunrise time for this date and location
  // Hindu day traditionally starts at sunrise, so tithi at sunrise
  // determines which tithi "owns" that Gregorian date
  final sunriseTime = SunriseCalculator.calculateSunriseIST(
    date: date,
    latitude: latitude,
    longitude: longitude,
  );

  final sunsetTime = SunriseCalculator.calculateSunsetIST(
    date: date,
    latitude: latitude,
    longitude: longitude,
  );

  final normalizedDate = DateTime(date.year, date.month, date.day);
  var rawTithi = _getCachedRawTithi(
    cacheBox,
    normalizedDate,
    latitude,
    longitude,
  );

  if (rawTithi == null) {
    rawTithi = await service.calculateTithi(
      sunriseTime,
      latitude: latitude,
      longitude: longitude,
    );
    await _storeCachedRawTithi(
      cacheBox,
      normalizedDate,
      latitude,
      longitude,
      rawTithi,
    );
  }
  final masa = await service.calculateMasa(
    sunriseTime,
    rawTithi,
    latitude: latitude,
    longitude: longitude,
  );

  // If masa is not yet calculated correctly or returns 'Unknown', we might want to fallback or just pass it.

  return PanchangData.fromRawTithi(
    date: date,
    rawTithi: rawTithi,
    masa: masa,
    allFestivals: festivals,
    monthSystem: monthSystem,
    sunrise: sunriseTime,
    sunset: sunsetTime,
  );
  });

/// Provider for today's panchang
final todayPanchangProvider = FutureProvider<PanchangData>((ref) async {
  final today = DateTime.now();
  return ref.watch(panchangForDateProvider(today).future);
});

/// Provider for current paksha (for theming)
final currentPakshaProvider = Provider<AsyncValue<String>>((ref) {
  return ref.watch(todayPanchangProvider).whenData((data) => data.paksha);
});

/// Batch provider for monthly panchang data
/// Pre-loads entire month to eliminate N+1 query pattern in calendar
final monthlyPanchangProvider =
    FutureProvider.autoDispose.family<Map<DateTime, PanchangData>, DateTime>((
      ref,
      focusedMonth,
    ) async {
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
        final sunriseTime = SunriseCalculator.calculateSunriseIST(
          date: normalizedDate,
          latitude: latitude,
          longitude: longitude,
        );

        final sunsetTime = SunriseCalculator.calculateSunsetIST(
          date: normalizedDate,
          latitude: latitude,
          longitude: longitude,
        );

        final cachedRawTithi = _getCachedRawTithi(
          cacheBox,
          normalizedDate,
          latitude,
          longitude,
        );

        final resolvedRawTithi =
            cachedRawTithi ??
            await service.calculateTithi(
              sunriseTime,
              latitude: latitude,
              longitude: longitude,
            );

        if (cachedRawTithi == null) {
          await _storeCachedRawTithi(
            cacheBox,
            normalizedDate,
            latitude,
            longitude,
            resolvedRawTithi,
          );
        }

        final masa = await service.calculateMasa(
          sunriseTime,
          resolvedRawTithi,
          latitude: latitude,
          longitude: longitude,
        );

        return MapEntry(
          normalizedDate,
          PanchangData.fromRawTithi(
            date: normalizedDate,
            rawTithi: resolvedRawTithi,
            masa: masa,
            allFestivals: festivals,
            monthSystem: monthSystem,
            sunrise: sunriseTime,
            sunset: sunsetTime,
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
