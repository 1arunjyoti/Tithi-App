import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:hive/hive.dart';
import 'package:nominatim_geocoding/nominatim_geocoding.dart';

import 'storage_service.dart';

/// Location data model
class LocationData {
  final double latitude;
  final double longitude;
  final String? cityName;
  final DateTime timestamp;

  const LocationData({
    required this.latitude,
    required this.longitude,
    this.cityName,
    required this.timestamp,
  });

  /// Default location (Delhi, India) when location is not available
  static LocationData get defaultLocation => LocationData(
    latitude: 28.6139,
    longitude: 77.2090,
    cityName: 'Delhi',
    timestamp: DateTime.now(),
  );

  @override
  String toString() =>
      'LocationData($latitude, $longitude, $cityName, $timestamp)';
}

/// Offline city entry for reverse-geocoding fallback (no network needed).
class _OfflineCity {
  const _OfflineCity({
    required this.city,
    required this.admin,
    required this.latitude,
    required this.longitude,
    required this.population,
  });

  final String city;
  final String admin;
  final double latitude;
  final double longitude;
  final int population;

  factory _OfflineCity.fromJson(Map<String, dynamic> json) {
    return _OfflineCity(
      city: json['city'] as String,
      admin: (json['admin'] as String?) ?? '',
      latitude: (json['lat'] as num).toDouble(),
      longitude: (json['lng'] as num).toDouble(),
      population: (json['pop'] as num?)?.toInt() ?? 0,
    );
  }
}

/// FOSS-compatible location service
/// Uses native Android LocationManager (not Google Play Services)
/// Uses OpenStreetMap Nominatim for reverse geocoding
class LocationService {
  LocationService();

  static const String _keyFirstLaunch = 'first_launch';
  static const String _keyLocationEnabled = 'location_enabled';
  static const String _keyCachedCity = 'cached_city';
  static const String _keyCachedLat = 'cached_lat';
  static const String _keyCachedLng = 'cached_lng';
  static const String _keyCachedAtMs = 'cached_at_ms';
  static const String _keyLastBackgroundAtMs = 'last_background_at_ms';
  // Home location keys
  static const String _keyHomeLat = 'home_lat';
  static const String _keyHomeLng = 'home_lng';
  static const String _keyHomeAddress = 'home_address';

  Box? _box;
  bool _isInitialized = false;
  List<_OfflineCity> _offlineCities = [];

  // In-memory cache for request deduplication and short-term caching
  Future<LocationData?>? _pendingLocationRequest;
  LocationData? _memoryCachedLocation;
  DateTime? _lastFetchTime;
  static const Duration _cacheDuration = Duration(seconds: 10);
  static const Duration _backgroundRefreshThreshold = Duration(minutes: 15);

  /// Initialize the location service
  Future<void> init() async {
    if (_isInitialized) return;

    try {
      // Initialize Hive box for settings persistence
      _box = await StorageService().openLocationSettingsBox();

      // Initialize Nominatim geocoding with cache
      await NominatimGeocoding.init(reqCacheNum: 50);

      // Load offline city index (best-effort: offline labels still work
      // even if Nominatim is unreachable).
      await _loadOfflineCities();

      _isInitialized = true;

      if (kDebugMode) {
        print('LocationService initialized');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error initializing LocationService: $e');
      }
      rethrow;
    }
  }

  /// Check if this is the first app launch
  Future<bool> isFirstLaunch() async {
    _ensureInitialized();
    final isFirst = _box?.get(_keyFirstLaunch, defaultValue: true) ?? true;
    return isFirst;
  }

  /// Mark first launch as complete
  Future<void> markFirstLaunchComplete() async {
    _ensureInitialized();
    await _box?.put(_keyFirstLaunch, false);
  }

  /// Check if user has enabled location in app
  Future<bool> isLocationEnabled() async {
    _ensureInitialized();
    return _box?.get(_keyLocationEnabled, defaultValue: false) ?? false;
  }

  /// Save user's location preference
  Future<void> setLocationEnabled(bool enabled) async {
    _ensureInitialized();
    await _box?.put(_keyLocationEnabled, enabled);
  }

  /// Check location permission status
  Future<LocationPermission> checkPermission() async {
    return await Geolocator.checkPermission();
  }

  /// Request location permission from user
  Future<LocationPermission> requestPermission() async {
    return await Geolocator.requestPermission();
  }

  /// Check if location services are enabled on device
  Future<bool> isLocationServiceEnabled() async {
    return await Geolocator.isLocationServiceEnabled();
  }

  /// Get current location with city name
  /// Uses forceLocationManager: true for FOSS compatibility (no Google Play Services)
  Future<LocationData?> getCurrentLocation() async {
    _ensureInitialized();

    // Check short-term memory cache (deduplication)
    if (_memoryCachedLocation != null &&
        _lastFetchTime != null &&
        DateTime.now().difference(_lastFetchTime!) < _cacheDuration) {
      if (kDebugMode) {
        print(
          'Returning memory cached location (valid for ${_cacheDuration.inSeconds}s)',
        );
      }
      return _memoryCachedLocation;
    }

    // Check if a request is already in progress
    if (_pendingLocationRequest != null) {
      if (kDebugMode) {
        print('Joining pending location request');
      }
      return _pendingLocationRequest;
    }

    // Warm-cache strategy:
    // If we have persisted location and app has not been backgrounded for
    // longer than threshold, use cached location immediately.
    final cachedLocation = await _getCachedLocation();
    if (cachedLocation != null && !await _shouldRefreshAfterBackground()) {
      if (kDebugMode) {
        print(
          'Returning persisted warm cache (background <= ${_backgroundRefreshThreshold.inMinutes}m)',
        );
      }
      _memoryCachedLocation = cachedLocation;
      _lastFetchTime = DateTime.now();
      return cachedLocation;
    }

    // Create new request
    _pendingLocationRequest = _fetchLocation();

    try {
      final result = await _pendingLocationRequest;
      // Update memory cache
      if (result != null) {
        _memoryCachedLocation = result;
        _lastFetchTime = DateTime.now();
      }
      return result;
    } finally {
      // Clear pending request flag
      _pendingLocationRequest = null;
    }
  }

  Future<LocationData?> _fetchLocation() async {
    try {
      // Check if location services are enabled
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (kDebugMode) {
          print('Location services are disabled');
        }
        return await _getCachedLocation();
      }

      // Check permission
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        // SMELL-7: Do NOT auto-request permission here. Permission requests
        // should only originate from explicit user actions in the UI.
        // Return cached location instead so background refreshes don't
        // unexpectedly pop a system dialog.
        if (kDebugMode) {
          print('Location permission denied – skipping auto-request');
        }
        return await _getCachedLocation();
      }

      if (permission == LocationPermission.deniedForever) {
        if (kDebugMode) {
          print('Location permission permanently denied');
        }
        return await _getCachedLocation();
      }

      // Try to get last known position first (faster) - not supported on web
      Position? position;
      if (!kIsWeb) {
        position = await Geolocator.getLastKnownPosition();
      }

      // If no last known position, get current position
      // Web uses standard LocationSettings, mobile uses AndroidSettings for FOSS
      position ??= await Geolocator.getCurrentPosition(
        locationSettings: kIsWeb
            ? const LocationSettings(
                accuracy: LocationAccuracy.medium,
                timeLimit: Duration(seconds: 15),
              )
            : AndroidSettings(
                accuracy: LocationAccuracy.medium,
                forceLocationManager: true, // FOSS: Use native LocationManager
                timeLimit: const Duration(seconds: 30),
              ),
      );

      // Get city name via reverse geocoding (online-first, offline fallback)
      var cityName = await getCityName(position.latitude, position.longitude);
      // Preserve last known label when both lookups fail.
      cityName ??= (await _getCachedLocation())?.cityName;

      // Cache the location
      await _cacheLocation(position.latitude, position.longitude, cityName);

      return LocationData(
        latitude: position.latitude,
        longitude: position.longitude,
        cityName: cityName,
        timestamp: DateTime.now(),
      );
    } catch (e) {
      if (kDebugMode) {
        print('Error getting location: $e');
      }
      return await _getCachedLocation();
    }
  }

  /// Dispose services
  Future<void> dispose() async {
    if (_box != null && _box!.isOpen) {
      await _box!.close();
    }
    _isInitialized = false;
  }

  /// Reverse geocode coordinates to city name.
  /// Online-first: tries OpenStreetMap Nominatim, falls back to the bundled
  /// offline city index when offline or when Nominatim returns nothing.
  Future<String?> getCityName(double latitude, double longitude) async {
    // 1. Online (preferred when available).
    try {
      final coordinate = Coordinate(latitude: latitude, longitude: longitude);

      final geocoding = await NominatimGeocoding.to
          .reverseGeoCoding(coordinate)
          .timeout(const Duration(seconds: 5));

      // Try to get city from the address (use available properties)
      final address = geocoding.address;
      String? city;
      if (address.city.isNotEmpty) {
        city = address.city;
      } else if (address.district.isNotEmpty) {
        city = address.district;
      } else if (address.suburb.isNotEmpty) {
        city = address.suburb;
      } else if (address.state.isNotEmpty) {
        city = address.state;
      }

      if (city != null && city.isNotEmpty) {
        if (kDebugMode) {
          print('Reverse geocoded: $latitude, $longitude -> $city');
        }
        return city;
      }
    } catch (e) {
      if (kDebugMode) {
        print('Online reverse geocoding unavailable, using offline index: $e');
      }
    }

    // 2. Offline fallback (bundled city index, no network).
    try {
      final offline = findNearestOfflineCity(latitude, longitude);
      if (offline != null) {
        if (kDebugMode) {
          print('Offline reverse geocoded: $latitude, $longitude -> $offline');
        }
        return offline;
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error in offline reverse geocoding: $e');
      }
    }
    return null;
  }

  /// Load bundled city index for offline reverse geocoding.
  /// Best-effort: failures leave [_offlineCities] empty (callers fall back
  /// to cached/default labels).
  Future<void> _loadOfflineCities() async {
    try {
      final raw = await rootBundle.loadString('assets/data/in_city.json');
      final List<dynamic> decoded = json.decode(raw) as List<dynamic>;
      final cities = <_OfflineCity>[];
      for (final entry in decoded) {
        try {
          if (entry is Map<String, dynamic>) {
            final city = _OfflineCity.fromJson(entry);
            if (city.city.isNotEmpty) {
              cities.add(city);
            }
          }
        } catch (_) {
          // Skip malformed entries.
          continue;
        }
      }
      _offlineCities = cities;
      if (kDebugMode) {
        print('Loaded ${_offlineCities.length} offline cities');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error loading offline cities: $e');
      }
      _offlineCities = [];
    }
  }

  /// Find nearest bundled city name using haversine distance.
  /// Returns null when the offline index is empty. Synchronous and cheap
  /// (linear scan over a few hundred entries). Ties prefer larger cities.
  String? findNearestOfflineCity(double latitude, double longitude) {
    if (_offlineCities.isEmpty) return null;
    _OfflineCity? best;
    var bestDist = double.infinity;
    for (final city in _offlineCities) {
      final d = _haversineKm(
        latitude,
        longitude,
        city.latitude,
        city.longitude,
      );
      if (d < bestDist - 1e-9 ||
          ((d - bestDist).abs() <= 1e-9 &&
              city.population > (best?.population ?? 0))) {
        bestDist = d;
        best = city;
      }
    }
    return best?.city;
  }

  static double _haversineKm(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const earthRadiusKm = 6371.0;
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);
    final a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) *
            cos(_toRadians(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);
    return 2 * earthRadiusKm * asin(sqrt(a));
  }

  static double _toRadians(double degrees) => degrees * pi / 180;

  /// Get cached location if available
  Future<LocationData?> _getCachedLocation() async {
    final lat = _box?.get(_keyCachedLat) as double?;
    final lng = _box?.get(_keyCachedLng) as double?;
    final city = _box?.get(_keyCachedCity) as String?;
    final cachedAtMs = _box?.get(_keyCachedAtMs) as int?;

    if (lat != null && lng != null) {
      return LocationData(
        latitude: lat,
        longitude: lng,
        cityName: city,
        timestamp: cachedAtMs != null
            ? DateTime.fromMillisecondsSinceEpoch(cachedAtMs)
            : DateTime.now(),
      );
    }

    return null;
  }

  /// Cache location for offline use
  Future<void> _cacheLocation(
    double latitude,
    double longitude,
    String? cityName,
  ) async {
    await _box?.put(_keyCachedLat, latitude);
    await _box?.put(_keyCachedLng, longitude);
    await _box?.put(_keyCachedAtMs, DateTime.now().millisecondsSinceEpoch);
    if (cityName != null) {
      await _box?.put(_keyCachedCity, cityName);
    }
    // Fresh GPS fetch satisfied any pending background-based refresh.
    await _box?.delete(_keyLastBackgroundAtMs);
  }

  /// Clear cached location data
  Future<void> clearCache() async {
    _ensureInitialized();
    await _box?.delete(_keyCachedLat);
    await _box?.delete(_keyCachedLng);
    await _box?.delete(_keyCachedCity);
    await _box?.delete(_keyCachedAtMs);
    if (kDebugMode) {
      print('Location cache cleared');
    }
  }

  /// Records when app transitions to background.
  Future<void> markAppBackgrounded() async {
    if (!_isInitialized) return;
    await _box?.put(_keyLastBackgroundAtMs, DateTime.now().millisecondsSinceEpoch);
  }

  Future<bool> _shouldRefreshAfterBackground() async {
    final backgroundAtMs = _box?.get(_keyLastBackgroundAtMs) as int?;
    if (backgroundAtMs == null) {
      return false;
    }

    final backgroundAt = DateTime.fromMillisecondsSinceEpoch(backgroundAtMs);
    final elapsed = DateTime.now().difference(backgroundAt);
    return elapsed > _backgroundRefreshThreshold;
  }

  /// SET home location manually
  Future<void> setHomeLocation(double lat, double lng, String address) async {
    _ensureInitialized();
    // SEC-3: validate coordinate ranges before persisting.
    if (lat < -90 || lat > 90) {
      throw ArgumentError.value(lat, 'lat', 'Latitude must be in [-90, 90]');
    }
    if (lng < -180 || lng > 180) {
      throw ArgumentError.value(lng, 'lng', 'Longitude must be in [-180, 180]');
    }
    await _box?.put(_keyHomeLat, lat);
    await _box?.put(_keyHomeLng, lng);
    await _box?.put(_keyHomeAddress, address);
  }

  /// GET home location manually
  /// Returns null if not set
  LocationData? getHomeLocation() {
    _ensureInitialized();
    final lat = _box?.get(_keyHomeLat) as double?;
    final lng = _box?.get(_keyHomeLng) as double?;
    final address = _box?.get(_keyHomeAddress) as String?;

    if (lat != null && lng != null) {
      return LocationData(
        latitude: lat,
        longitude: lng,
        cityName: address, // Using address as "city name" for UI display
        timestamp: DateTime.now(),
      );
    }
    return null;
  }

  void _ensureInitialized() {
    if (!_isInitialized) {
      throw Exception('LocationService not initialized. Call init() first.');
    }
  }
}
