import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/location_service.dart';
import '../services/notification_service.dart';
import '../services/solar_events_service.dart';
import '../core/location/location_defaults.dart';
import '../core/location/place_clock.dart';

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
  // The clock reads the service synchronously (see [placeClockProvider]); it
  // reports the device clock until the box is open, so refresh it now.
  ref.invalidate(placeClockProvider);
});

/// Clock driving "today" and reminder wall times (see [PlaceClock]).
///
/// Reads the service synchronously and must never *start* location init:
/// watching [locationInitProvider] here would make every widget that shows
/// today's date open Hive, path_provider, and the geocoder.
final placeClockProvider = Provider<PlaceClock>((ref) {
  return ref.watch(locationServiceProvider).placeClock;
});

/// Re-reads the place, its zone, the clock, and re-schedules reminders.
///
/// One call site instead of four invalidations: forgetting the clock is how
/// the day label and the reminder wall time drift apart again. Callers must
/// already have persisted the new place (or toggle) before invoking this.
void refreshPlaceContext(WidgetRef ref) {
  ref.invalidate(currentLocationProvider);
  ref.invalidate(homeLocationProvider);
  ref.invalidate(placeClockProvider);
  // Reminders are wall times on the same clock, so a place change has to
  // re-schedule them too; `init` returns early once initialized.
  unawaited(NotificationService().rescheduleAfterPlaceChange());
}

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

  final LocationData location;
  if (!isEnabled) {
    // Home Location when set, otherwise the app's default place.
    location = service.getHomeLocation() ?? LocationData.defaultLocation;
  } else {
    // GPS fix when available, otherwise the app's default place.
    location =
        await service.getCurrentLocation() ?? LocationData.defaultLocation;
  }

  // Publish the clock's zone so call sites that only know latitude/longitude
  // (detail sheets, notification scheduling, export, Bengali calendar, home
  // widget) resolve civil time on the same clock as the day label. Null means
  // "device zone", which is the live-location mode (see [PlaceClock]).
  solarEventsService.setPlaceTimezone(service.placeClock.zoneId);
  return location;
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
