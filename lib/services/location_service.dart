import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:hive/hive.dart';
import 'package:nominatim_geocoding/nominatim_geocoding.dart';

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

/// FOSS-compatible location service
/// Uses native Android LocationManager (not Google Play Services)
/// Uses OpenStreetMap Nominatim for reverse geocoding
class LocationService {
  static const String _boxName = 'location_settings';
  static const String _keyFirstLaunch = 'first_launch';
  static const String _keyLocationEnabled = 'location_enabled';
  static const String _keyCachedCity = 'cached_city';
  static const String _keyCachedLat = 'cached_lat';
  static const String _keyCachedLng = 'cached_lng';
  // Home location keys
  static const String _keyHomeLat = 'home_lat';
  static const String _keyHomeLng = 'home_lng';
  static const String _keyHomeAddress = 'home_address';

  Box? _box;
  bool _isInitialized = false;

  /// Initialize the location service
  Future<void> init() async {
    if (_isInitialized) return;

    try {
      // Initialize Hive box for settings persistence
      _box = await Hive.openBox(_boxName);

      // Initialize Nominatim geocoding with cache
      await NominatimGeocoding.init(reqCacheNum: 50);

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

    try {
      // Check if location services are enabled
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (kDebugMode) {
          print('Location services are disabled');
        }
        return _getCachedLocation();
      }

      // Check permission
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (kDebugMode) {
            print('Location permission denied');
          }
          return _getCachedLocation();
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (kDebugMode) {
          print('Location permission permanently denied');
        }
        return _getCachedLocation();
      }

      // Try to get last known position first (faster)
      Position? position = await Geolocator.getLastKnownPosition();

      // If no last known position, get current position using native LocationManager (FOSS)
      position ??= await Geolocator.getCurrentPosition(
        locationSettings: AndroidSettings(
          accuracy: LocationAccuracy.medium,
          forceLocationManager:
              true, // FOSS: Use native LocationManager, not Google
          timeLimit: const Duration(seconds: 30),
        ),
      );

      // Get city name via reverse geocoding
      final cityName = await getCityName(position.latitude, position.longitude);

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
      return _getCachedLocation();
    }
  }

  /// Reverse geocode coordinates to city name using OpenStreetMap Nominatim
  Future<String?> getCityName(double latitude, double longitude) async {
    try {
      final coordinate = Coordinate(latitude: latitude, longitude: longitude);

      final geocoding = await NominatimGeocoding.to.reverseGeoCoding(
        coordinate,
      );

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

      if (kDebugMode) {
        print('Reverse geocoded: $latitude, $longitude -> $city');
      }

      return city;
    } catch (e) {
      if (kDebugMode) {
        print('Error reverse geocoding: $e');
      }
      return null;
    }
  }

  /// Get cached location if available
  Future<LocationData?> _getCachedLocation() async {
    final lat = _box?.get(_keyCachedLat) as double?;
    final lng = _box?.get(_keyCachedLng) as double?;
    final city = _box?.get(_keyCachedCity) as String?;

    if (lat != null && lng != null) {
      return LocationData(
        latitude: lat,
        longitude: lng,
        cityName: city,
        timestamp: DateTime.now(),
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
    if (cityName != null) {
      await _box?.put(_keyCachedCity, cityName);
    }
  }

  /// Clear cached location data
  Future<void> clearCache() async {
    _ensureInitialized();
    await _box?.delete(_keyCachedLat);
    await _box?.delete(_keyCachedLng);
    await _box?.delete(_keyCachedCity);
    if (kDebugMode) {
      print('Location cache cleared');
    }
  }

  /// SET home location manually
  Future<void> setHomeLocation(double lat, double lng, String address) async {
    _ensureInitialized();
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
