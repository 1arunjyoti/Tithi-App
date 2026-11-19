import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/location_service.dart';
import '../services/notification_service.dart';
import '../services/solar_events_service.dart';
import '../core/location/location_defaults.dart';
import '../core/location/place_clock.dart';
import '../core/location/place_grid.dart';
import '../core/perf/startup_timeline.dart';

/// Provider for LocationService instance
final locationServiceProvider = Provider<LocationService>((ref) {
  final service = LocationService();
  ref.onDispose(() {
    unawaited(service.dispose());
  });
  return service;
});

/// Bumped whenever the synchronous place snapshot may have changed.
///
/// [locationInitProvider] bumps it once storage is open and the persisted fix
/// is readable. Nothing here starts location work: a consumer that only wants
/// the snapshot never triggers Hive, path_provider or the geocoder.
final locationSnapshotRevisionProvider = StateProvider<int>((ref) => 0);

/// Provider that tracks if location service is initialized
final locationInitProvider = FutureProvider<void>((ref) async {
  final service = ref.read(locationServiceProvider);
  await service.init();
  StartupTimeline.mark('location-init');
  // The clock reads the service synchronously (see [placeClockProvider]); it
  // reports the device clock until the box is open, so refresh it now.
  ref.invalidate(placeClockProvider);
  // Publish the seeded place snapshot (see [persistedLocationProvider]).
  ref.read(locationSnapshotRevisionProvider.notifier).state++;
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
/// decides on a first launch. On later launches it completes as soon as the
/// *saved* place is readable, without waiting for a fresh GPS fix or reverse
/// geocode: [persistedLocationProvider] already answers with the previous
/// session's place, and the device fix is fetched in the background.
/// Awaiting [Completer.future] never deadlocks: the wrapper completes it in a
/// `finally` block on every path.
final locationPermissionGateProvider = Provider<Completer<void>>(
  (ref) => Completer<void>(),
);

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

/// Last place the app used, read synchronously once storage is open.
///
/// This is the seed that keeps a cold start off the Delhi fallback while the
/// device fix (and its reverse geocode) is still in flight.
final persistedLocationProvider = Provider<LocationData?>((ref) {
  ref.watch(locationSnapshotRevisionProvider);
  return ref.watch(locationServiceProvider).lastKnownLocation;
});

/// Place panchang should compute with right now.
///
/// Starts at the persisted place and adopts a fresh fix only when it lands in a
/// different [placeGridKey] cell (~1.1 km). Returning the previously published
/// instance inside the same cell is deliberate: a new `LocationData` would
/// notify every panchang provider and restart the month batch for a fix that
/// moved a few metres.
class CalculationLocationNotifier extends Notifier<LocationData?> {
  LocationData? _published;

  @override
  LocationData? build() {
    final fresh = ref.watch(currentLocationProvider).valueOrNull;
    final persisted = ref.watch(persistedLocationProvider);
    final candidate = fresh ?? persisted;
    if (candidate == null) return _published;

    final current = _published;
    if (current != null &&
        samePlaceGrid(
          latitudeA: current.latitude,
          longitudeA: current.longitude,
          latitudeB: candidate.latitude,
          longitudeB: candidate.longitude,
        )) {
      return current;
    }
    _published = candidate;
    StartupTimeline.mark('place-ready', {
      'source': fresh != null ? 'device' : 'persisted',
    });
    return candidate;
  }
}

final calculationLocationProvider =
    NotifierProvider<CalculationLocationNotifier, LocationData?>(
      CalculationLocationNotifier.new,
    );

/// Provider for coordinates (for panchang calculations).
///
/// Publishes the persisted place immediately instead of waiting for
/// [currentLocationProvider]: a cold start must not sit on the Delhi fallback
/// (or a skeleton) while GPS and Nominatim answer. Before storage opens there is
/// nothing to seed, so the old contract applies and the caller's fallback is
/// used.
final coordinatesProvider =
    Provider<AsyncValue<({double latitude, double longitude})>>((ref) {
      final location = ref.watch(calculationLocationProvider);
      if (location != null) {
        return AsyncData((
          latitude: location.latitude,
          longitude: location.longitude,
        ));
      }
      return ref
          .watch(currentLocationProvider)
          .whenData(
            (value) => (
              latitude: value?.latitude ?? kDefaultLatitude,
              longitude: value?.longitude ?? kDefaultLongitude,
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
