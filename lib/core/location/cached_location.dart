import 'package:hive/hive.dart';

import 'location_defaults.dart';

// P0-1: shared reader for the persisted last-known coordinates.
// Replaces raw 'cached_lat'/'cached_lng' string keys + Delhi defaults
// previously duplicated in the scheduler (2x) and calendar caches.
// Key spellings match LocationService's private keys by contract.

/// Hive keys for the persisted last-known coordinates.
const String kCachedLatKey = 'cached_lat';
const String kCachedLngKey = 'cached_lng';

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
