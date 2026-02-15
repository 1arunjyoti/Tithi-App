import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/panchang_data.dart';
import '../services/panchang_service.dart';
import '../services/sunrise_calculator.dart';
import 'festival_provider.dart';
import 'location_provider.dart';
import 'calendar_provider.dart';

/// Provider for PanchangService (already exists, re-export)
final panchangServiceProvider = Provider<PanchangService>((ref) {
  return PanchangService();
});

/// Provider that tracks if the panchang service is initialized
final panchangInitProvider = FutureProvider<void>((ref) async {
  final service = ref.read(panchangServiceProvider);
  await service.init();
});

/// Provider for panchang data of a specific date
final panchangForDateProvider = FutureProvider.family<PanchangData, DateTime>((
  ref,
  date,
) async {
  // Ensure service is initialized
  await ref.watch(panchangInitProvider.future);
  // Ensure festivals are loaded
  await ref.watch(festivalInitProvider.future);

  final service = ref.read(panchangServiceProvider);
  final festivals = ref.read(festivalProvider);

  // Get user's Hindu month system preference (Amanta or Purnimant)
  final monthSystem = ref.watch(hinduMonthSystemProvider);

  // Get user's location coordinates (defaults to Delhi if unavailable)
  final coords = ref.watch(coordinatesProvider);
  double latitude = 28.6139;
  double longitude = 77.2090;
  if (coords is AsyncData<({double latitude, double longitude})>) {
    latitude = coords.value.latitude;
    longitude = coords.value.longitude;
  }

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

  final rawTithi = await service.calculateTithi(
    sunriseTime,
    latitude: latitude,
    longitude: longitude,
  );
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
    FutureProvider.family<Map<DateTime, PanchangData>, DateTime>((
      ref,
      focusedMonth,
    ) async {
      // Ensure service is initialized
      await ref.watch(panchangInitProvider.future);
      await ref.watch(festivalInitProvider.future);

      final service = ref.read(panchangServiceProvider);
      final festivals = ref.read(festivalProvider);
      final monthSystem = ref.watch(hinduMonthSystemProvider);

      final coords = ref.watch(coordinatesProvider);
      double latitude = 28.6139;
      double longitude = 77.2090;
      if (coords is AsyncData<({double latitude, double longitude})>) {
        latitude = coords.value.latitude;
        longitude = coords.value.longitude;
      }

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

      final Map<DateTime, PanchangData> monthData = {};

      // Pre-calculate all dates in the visible calendar grid
      for (
        var date = startDate;
        date.isBefore(endDate) || date.isAtSameMomentAs(endDate);
        date = date.add(const Duration(days: 1))
      ) {
        final normalizedDate = DateTime(date.year, date.month, date.day);

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

        final rawTithi = await service.calculateTithi(
          sunriseTime,
          latitude: latitude,
          longitude: longitude,
        );

        final masa = await service.calculateMasa(
          sunriseTime,
          rawTithi,
          latitude: latitude,
          longitude: longitude,
        );

        monthData[normalizedDate] = PanchangData.fromRawTithi(
          date: normalizedDate,
          rawTithi: rawTithi,
          masa: masa,
          allFestivals: festivals,
          monthSystem: monthSystem,
          sunrise: sunriseTime,
          sunset: sunsetTime,
        );
      }

      return monthData;
    });
