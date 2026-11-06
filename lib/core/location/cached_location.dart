import 'package:hive/hive.dart';

import 'location_defaults.dart';
import 'place_clock.dart';

// P0-1: shared reader for the persisted last-known coordinates.
// Replaces raw 'cached_lat'/'cached_lng' string keys + Delhi defaults
// previously duplicated in the scheduler (2x) and calendar caches.
// Key spellings match LocationService's private keys by contract.

/// Hive keys for the persisted last-known coordinates.
const String kCachedLatKey = 'cached_lat';
const String kCachedLngKey = 'cached_lng';

/// Hive key for the persisted IANA zone of the last-known place.
const String kCachedTimezoneKey = 'cached_timezone';

/// Hive keys for how the place was chosen (see [PlaceClock]).
const String kLocationEnabledKey = 'location_enabled';
const String kHomeTimezoneKey = 'home_timezone';

/// Place clock derived from the location box.
///
/// Used by the background isolate, which has no `LocationService`: the same
/// rule (live location -> device, manual place -> its zone, neither -> Delhi)
/// must hold in both isolates or the day label and the reminder wall time
/// disagree.
PlaceClock readPlaceClock(Box<dynamic> box) {
  final enabled =
      box.get(kLocationEnabledKey, defaultValue: false) as bool? ?? false;
  final home = box.get(kHomeTimezoneKey) as String?;
  return resolvePlaceClock(
    locationEnabled: enabled,
    homeTimezoneId: home,
  );
}

/// Last-known coordinates from [box], falling back to Delhi defaults.
({double latitude, double longitude}) readCachedLatLng(Box<dynamic> box) {
  final lat =
      (box.get(kCachedLatKey, defaultValue: kDefaultLatitude) as num?)
          ?.toDouble() ??
      kDefaultLatitude;
  final lng =
      (box.get(kCachedLngKey, defaultValue: kDefaultLongitude) as num?)
          ?.toDouble() ??
      kDefaultLongitude;
  return (latitude: lat, longitude: lng);
}

/// Last-known IANA zone from [box], or null when the place never resolved one.
///
/// Mirrors [readCachedLatLng] so the background isolate can publish the same
/// place context as the UI isolate without constructing `LocationService`.
String? readCachedTimezoneId(Box<dynamic> box) {
  final raw = box.get(kCachedTimezoneKey) as String?;
  if (raw == null) return null;
  final trimmed = raw.trim();
  return trimmed.isEmpty ? null : trimmed;
}
