import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../services/moon_phase_service.dart';
import '../../../services/location_service.dart';
import '../../../providers/location_provider.dart';
import '../../../providers/panchang_provider.dart';
import '../../../core/location/location_defaults.dart';

/// Helper to get LocationData value or null from AsyncValue
LocationData? _getLocationOrNull(AsyncValue<LocationData?> asyncValue) {
  return asyncValue.maybeWhen(data: (location) => location, orElse: () => null);
}

/// Provider for moon phase data
/// Uses location if available, otherwise falls back to defaults
final moonPhaseDataProvider = FutureProvider<MoonPhaseData>((ref) async {
  ref.keepAlive();
  // A Panjika switch replaces the service behind `moonPhaseServiceProvider`;
  // await the shared init so the new instance is ready (and this provider
  // rebuilds with it) instead of calling `init()` concurrently.
  await ref.watch(panchangInitProvider.future);
  final moonPhaseService = ref.watch(moonPhaseServiceProvider);

  // Try to get location, but don't block on it
  final locationAsync = ref.watch(currentLocationProvider);
  final location = _getLocationOrNull(locationAsync);

  return moonPhaseService.getMoonPhaseData(
    latitude: location?.latitude ?? kDefaultLatitude,
    longitude: location?.longitude ?? kDefaultLongitude,
  );
});

/// Provider for upcoming Amavasya dates (next 6)
final upcomingAmavasyasProvider = FutureProvider<List<DateTime>>((ref) async {
  ref.keepAlive();
  await ref.watch(panchangInitProvider.future);
  final moonPhaseService = ref.watch(moonPhaseServiceProvider);

  final locationAsync = ref.watch(currentLocationProvider);
  final location = _getLocationOrNull(locationAsync);

  return moonPhaseService.getUpcomingAmavasyas(
    latitude: location?.latitude ?? kDefaultLatitude,
    longitude: location?.longitude ?? kDefaultLongitude,
  );
});

/// Provider for upcoming Purnima dates (next 6)
final upcomingPurnimasProvider = FutureProvider<List<DateTime>>((ref) async {
  ref.keepAlive();
  await ref.watch(panchangInitProvider.future);
  final moonPhaseService = ref.watch(moonPhaseServiceProvider);

  final locationAsync = ref.watch(currentLocationProvider);
  final location = _getLocationOrNull(locationAsync);

  return moonPhaseService.getUpcomingPurnimas(
    latitude: location?.latitude ?? kDefaultLatitude,
    longitude: location?.longitude ?? kDefaultLongitude,
  );
});
