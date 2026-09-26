import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/location_service.dart';
import '../core/location/location_defaults.dart';

/// Provider for LocationService instance
final locationServiceProvider = Provider<LocationService>((ref) {
  final service = LocationService();
  ref.onDispose(() {
    unawaited(service.dispose());
  });
  return service;
});

/// Provider that tracks if location service is initialized
final locationInitProvider = FutureProvider<void>((ref) async {
  final service = ref.read(locationServiceProvider);
  await service.init();
});

/// Gate for background work that must run AFTER the first-launch location
/// permission flow (`LocationPermissionWrapper` in main.dart).
///
/// Festival seeding + the month-batch computation are location-dependent
/// and expensive; starting them while the permission dialog is up contends
/// with the flow and computes once with fallback coordinates, then again
/// with the real ones. The wrapper completes this gate once the user
/// decides (granted → device location; denied/skipped/failed → default
/// location) — on later launches it completes immediately, so warm starts
/// behave exactly as before. Awaiting [Completer.future] never deadlocks:
/// the wrapper completes it in a `finally` block on every path.
final locationPermissionGateProvider =
    Provider<Completer<void>>((ref) => Completer<void>());

/// Provider for location enabled preference (reads from service)
final locationEnabledProvider = FutureProvider<bool>((ref) async {
  await ref.watch(locationInitProvider.future);
  final service = ref.read(locationServiceProvider);
  return service.isLocationEnabled();
});

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
    // Check if Home Location is set
    final home = service.getHomeLocation();
    if (home != null) {
      return home;
    }
    // Return default location if user disabled location and no home set
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
              latitude: location?.latitude ?? kDefaultLatitude,
              longitude: location?.longitude ?? kDefaultLongitude,
            ),
          );
    });

/// Action provider to refresh location
final refreshLocationProvider = FutureProvider.autoDispose
    .family<LocationData?, void>((ref, _) async {
      ref.invalidate(currentLocationProvider);
      return ref.read(currentLocationProvider.future);
    });

/// Provider for Home Location
final homeLocationProvider = Provider<LocationData?>((ref) {
  final service = ref.watch(locationServiceProvider);
  return service.getHomeLocation();
});
