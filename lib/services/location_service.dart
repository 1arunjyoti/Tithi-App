import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:nominatim_geocoding/nominatim_geocoding.dart';

import 'storage_service.dart';
import '../core/location/location_defaults.dart';

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
    latitude: kDefaultLatitude,
    longitude: kDefaultLongitude,
    cityName: 'Delhi',
    timestamp: DateTime.now(),
  );

  @override
  String toString() =>
      'LocationData($latitude, $longitude, $cityName, $timestamp)';
}

/// Why a place lookup produced no results. Lets the UI say something true
/// instead of rendering an empty list for a request that actually failed.
enum PlaceSearchError {
  /// Device offline, or the request timed out.
  offline,

  /// Nominatim throttled the client (HTTP 429).
  rateLimited,

  /// Nominatim returned a non-success status (5xx, 403, ...).
  server,

  /// Unexpected payload, or a platform failure we did not classify.
  unknown,
}

/// Result of [LocationService.searchPlaces].
///
/// Sealed so callers must handle the failure variant, matching the
/// `WeatherResult` pattern used elsewhere in the app.
sealed class PlaceSearchOutcome {
  const PlaceSearchOutcome();
}

/// Lookup succeeded; [results] may still be empty (a genuine "no match").
final class PlaceSearchSuccess extends PlaceSearchOutcome {
  const PlaceSearchSuccess(this.results);

  final List<PlaceSearchResult> results;
}

/// Lookup failed before producing a usable answer.
final class PlaceSearchFailure extends PlaceSearchOutcome {
  const PlaceSearchFailure(this.error);

  final PlaceSearchError error;
}

/// A place returned by a forward-geocoding (text) search.
class PlaceSearchResult {
  const PlaceSearchResult({
    required this.latitude,
    required this.longitude,
    required this.displayName,
  });

  final double latitude;
  final double longitude;

  /// Human-readable label, e.g. "Connaught Place, New Delhi, India".
  final String displayName;

  /// Parses one Nominatim `/search` row. Returns null for malformed rows or
  /// out-of-range coordinates so a single bad entry cannot break the list.
  static PlaceSearchResult? fromNominatim(Map<String, dynamic> json) {
    final lat = double.tryParse(json['lat']?.toString() ?? '');
    final lon = double.tryParse(json['lon']?.toString() ?? '');
    if (lat == null || lon == null) return null;
    if (lat < -90 || lat > 90 || lon < -180 || lon > 180) return null;

    final displayName = (json['display_name'] as String?)?.trim();
    if (displayName == null || displayName.isEmpty) return null;

    return PlaceSearchResult(
      latitude: lat,
      longitude: lon,
      displayName: displayName,
    );
  }
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
  /// [httpClient] is for tests: production callers use the default lazily
  /// created client (see [_httpClient]). An injected client is owned by the
  /// caller and is never closed by [dispose].
  LocationService({http.Client? httpClient})
    : _injectedHttpClient = httpClient,
      _ownsHttpClient = httpClient == null;

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

  /// Contactable User-Agent required by the OSM Nominatim usage policy.
  /// Names the app and gives a contact point instead of a library default.
  static const String _nominatimUserAgent =
      'Tithi (app.tithi.pro; +https://tithiapp.netlify.app)';

  /// Nominatim rejects queries shorter than 3 characters; the picker gates on
  /// this too so no request is sent for a stray keystroke.
  static const int minSearchQueryLength = 3;

  /// Nominatim's usage policy: absolute maximum of 1 request per second.
  static const Duration _minSearchInterval = Duration(seconds: 1);

  /// Upper bound on a single place lookup.
  static const Duration _searchTimeout = Duration(seconds: 8);

  Box? _box;
  bool _isInitialized = false;
  List<_OfflineCity> _offlineCities = [];

  final http.Client? _injectedHttpClient;
  final bool _ownsHttpClient;
  http.Client? _ownedHttpClient;

  /// Shared client so repeated searches reuse the keep-alive connection
  /// instead of paying a fresh TLS handshake per keystroke. Recreated after
  /// [dispose] so a late search cannot use a closed client.
  http.Client get _httpClient =>
      _injectedHttpClient ?? (_ownedHttpClient ??= http.Client());

  /// Start of the most recent Nominatim request, for [_respectNominatimRateLimit].
  DateTime? _lastSearchRequestAt;

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

      // Try to get last known position first (faster).
      Position? position = await Geolocator.getLastKnownPosition();

      // If no last known position, get current position
      // Android uses LocationManager (FOSS), with a fused fallback.
      position ??= await getCurrentPositionWithFallback();

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

  /// Resolves the current position, preferring the FOSS LocationManager
  /// (no Google Play Services) and falling back to the fused provider only
  /// when the GPS fix times out (indoors, emulators without mock location).
  ///
  /// The fallback keeps the FOSS-first behavior: outdoors/de-googled flows
  /// are unchanged, and where Play Services is absent the fused call throws
  /// immediately, degrading to the same cached fallback as before.
  ///
  /// This *forces a new fix*, so both attempts can time out — callers acting
  /// on a user tap should prefer [tryResolvePosition], which returns the OS's
  /// last known position without waiting for a fix at all.
  ///
  /// [fossTimeout] / [fusedTimeout] are overridable so interactive callers
  /// can fail fast instead of holding the UI for the full 30s + 20s.
  Future<Position> getCurrentPositionWithFallback({
    Duration fossTimeout = const Duration(seconds: 30),
    Duration fusedTimeout = const Duration(seconds: 20),
  }) async {
    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: AndroidSettings(
          accuracy: LocationAccuracy.medium,
          forceLocationManager: true, // FOSS: Use native LocationManager
          timeLimit: fossTimeout,
        ),
      );
    } on TimeoutException {
      if (kDebugMode) {
        print('GPS fix timed out, falling back to fused provider');
      }
      // forceLocationManager defaults to false: fused provider
      // (WiFi/cell), which fixes indoors where GPS cannot.
      return Geolocator.getCurrentPosition(
        locationSettings: AndroidSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: fusedTimeout,
        ),
      );
    }
  }

  /// Best-effort one-shot position for interactive UI actions (e.g. the home
  /// location picker's "my location" button).
  ///
  /// Ordering mirrors [_fetchLocation]: the OS's **last known position**
  /// first, then a fresh fix. The last known position is served from the
  /// platform cache, so it returns instantly and needs no GPS fix — which is
  /// the whole point: on a stationary/indoor device a forced fix can burn the
  /// full timeout and still fail (see [getCurrentPositionWithFallback]).
  ///
  /// Never throws. Returns null when nothing resolves, so callers can show a
  /// single honest "could not get your location" state instead of an
  /// exception from deep inside a tap handler.
  Future<Position?> tryResolvePosition({
    Duration fossTimeout = const Duration(seconds: 10),
    Duration fusedTimeout = const Duration(seconds: 10),
  }) async {
    try {
      final lastKnown = await Geolocator.getLastKnownPosition();
      if (lastKnown != null) return lastKnown;
    } catch (e) {
      if (kDebugMode) {
        print('Last known position unavailable: $e');
      }
    }

    try {
      return await getCurrentPositionWithFallback(
        fossTimeout: fossTimeout,
        fusedTimeout: fusedTimeout,
      );
    } catch (e) {
      if (kDebugMode) {
        print('Could not resolve current position: $e');
      }
      return null;
    }
  }

  /// Dispose services.
  ///
  /// Closes the owned HTTP client so its keep-alive sockets and connection
  /// pool are released rather than being held for the app's lifetime. Callers
  /// that injected a client keep ownership of it.
  Future<void> dispose() async {
    if (_box != null && _box!.isOpen) {
      await _box!.close();
    }
    if (_ownsHttpClient) {
      _ownedHttpClient?.close();
      _ownedHttpClient = null;
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

  /// Forward geocode free-text [query] into place candidates via the
  /// OpenStreetMap Nominatim `/search` endpoint.
  ///
  /// Never throws: transport, status and payload failures come back as a
  /// [PlaceSearchFailure] so the caller can show an honest state (and offer a
  /// retry) rather than pretending the search merely matched nothing.
  ///
  /// Callers should debounce input; this method additionally enforces
  /// Nominatim's "at most 1 request/second" policy itself, because exceeding
  /// it gets the client IP blocked, which would take search down entirely.
  Future<PlaceSearchOutcome> searchPlaces(
    String query, {
    int limit = 6,
    String? languageCode,
  }) async {
    final trimmed = query.trim();
    if (trimmed.length < minSearchQueryLength) {
      return const PlaceSearchSuccess([]);
    }

    await _respectNominatimRateLimit();

    try {
      final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
        'q': trimmed,
        'format': 'jsonv2',
        'limit': '$limit',
        'addressdetails': '1',
        if (languageCode != null && languageCode.isNotEmpty)
          'accept-language': languageCode,
      });

      final client = _httpClient;
      // Stamp the attempt (not the response) so the rate-limit window tracks
      // request starts, as the policy specifies.
      _lastSearchRequestAt = DateTime.now();
      final response = await client
          .get(uri, headers: {'User-Agent': _nominatimUserAgent})
          .timeout(_searchTimeout);

      if (response.statusCode == 429) {
        if (kDebugMode) {
          print('Place search throttled (HTTP 429)');
        }
        return const PlaceSearchFailure(PlaceSearchError.rateLimited);
      }
      if (response.statusCode != 200) {
        if (kDebugMode) {
          print('Place search failed with status ${response.statusCode}');
        }
        return const PlaceSearchFailure(PlaceSearchError.server);
      }

      // Decode the bytes ourselves: `Response.body` falls back to latin1 when
      // the response omits a charset, which mangles Indic place names.
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! List) {
        return const PlaceSearchFailure(PlaceSearchError.unknown);
      }

      final results = <PlaceSearchResult>[];
      for (final entry in decoded) {
        if (entry is Map<String, dynamic>) {
          final place = PlaceSearchResult.fromNominatim(entry);
          if (place != null) results.add(place);
        }
      }
      return PlaceSearchSuccess(results);
    } on TimeoutException catch (e) {
      if (kDebugMode) {
        print('Place search timed out: $e');
      }
      return const PlaceSearchFailure(PlaceSearchError.offline);
    } on http.ClientException catch (e) {
      // Covers socket failures, DNS errors and connection resets on both the
      // VM and web clients (`package:http` wraps SocketException here).
      if (kDebugMode) {
        print('Place search network error: $e');
      }
      return const PlaceSearchFailure(PlaceSearchError.offline);
    } catch (e) {
      if (kDebugMode) {
        print('Error searching places: $e');
      }
      return const PlaceSearchFailure(PlaceSearchError.unknown);
    }
  }

  /// Waits out the remainder of Nominatim's 1-request-per-second window.
  ///
  /// Only ever blocks when a request was sent very recently, so a single
  /// search (the common case) never waits.
  Future<void> _respectNominatimRateLimit() async {
    final last = _lastSearchRequestAt;
    if (last == null) return;

    final elapsed = DateTime.now().difference(last);
    final remaining = _minSearchInterval - elapsed;
    if (remaining <= Duration.zero) return;

    if (kDebugMode) {
      print('Throttling place search for ${remaining.inMilliseconds}ms');
    }
    await Future<void>.delayed(remaining);
  }

  /// Load bundled city index for offline reverse geocoding.
  /// Best-effort: failures leave [_offlineCities] empty (callers fall back
  /// to cached/default labels).
  Future<void> _loadOfflineCities() async {
    try {
      final raw = await rootBundle.loadString('assets/data/in_city.json');
      // Decode off the main thread: like the festival catalog, parsing the
      // whole index inline drops frames during startup (this runs inside
      // LocationService.init, which blocks the home screen).
      final List<dynamic> decoded =
          await compute(jsonDecode, raw) as List<dynamic>;
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
    await _box?.put(
      _keyLastBackgroundAtMs,
      DateTime.now().millisecondsSinceEpoch,
    );
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
