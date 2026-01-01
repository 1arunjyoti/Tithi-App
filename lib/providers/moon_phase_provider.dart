import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/moon_phase_service.dart';
import '../services/location_service.dart';
import 'location_provider.dart';

/// Helper to get LocationData value or null from AsyncValue
LocationData? _getLocationOrNull(AsyncValue<LocationData?> asyncValue) {
  return asyncValue.maybeWhen(data: (location) => location, orElse: () => null);
}

/// Provider for moon phase data
/// Uses location if available, otherwise falls back to defaults
final moonPhaseDataProvider = FutureProvider<MoonPhaseData>((ref) async {
  final moonPhaseService = ref.watch(moonPhaseServiceProvider);

  // Try to get location, but don't block on it
  final locationAsync = ref.watch(currentLocationProvider);
  final location = _getLocationOrNull(locationAsync);

  return moonPhaseService.getMoonPhaseData(
    latitude: location?.latitude ?? 28.6139,
    longitude: location?.longitude ?? 77.2090,
  );
});

/// Provider for upcoming Amavasya dates (next 6)
final upcomingAmavasyasProvider = FutureProvider<List<DateTime>>((ref) async {
  final moonPhaseService = ref.watch(moonPhaseServiceProvider);

  final locationAsync = ref.watch(currentLocationProvider);
  final location = _getLocationOrNull(locationAsync);

  return moonPhaseService.getUpcomingAmavasyas(
    latitude: location?.latitude ?? 28.6139,
    longitude: location?.longitude ?? 77.2090,
  );
});

/// Provider for upcoming Purnima dates (next 6)
final upcomingPurnimasProvider = FutureProvider<List<DateTime>>((ref) async {
  final moonPhaseService = ref.watch(moonPhaseServiceProvider);

  final locationAsync = ref.watch(currentLocationProvider);
  final location = _getLocationOrNull(locationAsync);

  return moonPhaseService.getUpcomingPurnimas(
    latitude: location?.latitude ?? 28.6139,
    longitude: location?.longitude ?? 77.2090,
  );
});
