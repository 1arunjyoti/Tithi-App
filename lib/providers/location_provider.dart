import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../services/location_service.dart';

/// Provider for LocationService singleton
final locationServiceProvider = Provider<LocationService>((ref) {
  return LocationService();
});

/// Provider that tracks if location service is initialized
final locationInitProvider = FutureProvider<void>((ref) async {
  final service = ref.read(locationServiceProvider);
  await service.init();
});

/// Provider for location enabled preference
final locationEnabledProvider = StateProvider<bool>((ref) => false);

/// Provider for first launch check
final isFirstLaunchProvider = FutureProvider<bool>((ref) async {
  await ref.watch(locationInitProvider.future);
  final service = ref.read(locationServiceProvider);
  return await service.isFirstLaunch();
});

/// Provider for current location data
final currentLocationProvider = FutureProvider<LocationData?>((ref) async {
  await ref.watch(locationInitProvider.future);

  final service = ref.read(locationServiceProvider);
  final isEnabled = await service.isLocationEnabled();

  if (!isEnabled) {
    // Return default location if user disabled location
    return LocationData.defaultLocation;
  }

  final location = await service.getCurrentLocation();
  return location ?? LocationData.defaultLocation;
});

/// Provider for city name only (derived from location)
final cityNameProvider = Provider<AsyncValue<String>>((ref) {
  return ref
      .watch(currentLocationProvider)
      .whenData((location) => location?.cityName ?? 'Delhi');
});

/// Provider for coordinates (for panchang calculations)
final coordinatesProvider =
    Provider<AsyncValue<({double latitude, double longitude})>>((ref) {
      return ref
          .watch(currentLocationProvider)
          .whenData(
            (location) => (
              latitude: location?.latitude ?? 28.6139,
              longitude: location?.longitude ?? 77.2090,
            ),
          );
    });

/// Action provider to refresh location
final refreshLocationProvider = FutureProvider.family<LocationData?, void>((
  ref,
  _,
) async {
  ref.invalidate(currentLocationProvider);
  return ref.read(currentLocationProvider.future);
});
