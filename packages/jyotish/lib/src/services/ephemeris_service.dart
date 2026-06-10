import 'dart:ffi' as ffi;

import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';

import '../bindings/swisseph_bindings.dart';
import '../exceptions/jyotish_exception.dart';
import '../models/calculation_flags.dart';
import '../models/geographic_location.dart';
import '../models/planet.dart';
import '../models/planet_position.dart';

/// Service for calculating planetary positions using Swiss Ephemeris.
///
/// This service provides high-level methods for astronomical calculations
/// using the Swiss Ephemeris library.
class EphemerisService {
  SwissEphBindings? _bindings;
  bool _isInitialized = false;
  
  /// Cache for planet position calculations (key: planet_julianDay_lat_lon_flags)
  final Map<String, PlanetPosition> _positionCache = {};
  
  /// Maximum cache size to prevent memory issues
  static const int _maxCacheSize = 1000;

  /// Initializes the Swiss Ephemeris service.
  ///
  /// [ephemerisPath] - Optional path to Swiss Ephemeris data files.
  /// If not provided, the library will use its default search paths.
  ///
  /// Throws [InitializationException] if initialization fails.
  Future<void> initialize({String? ephemerisPath}) async {
    if (_isInitialized) {
      return;
    }

    try {
      _bindings = SwissEphBindings();

      // Set ephemeris path if provided
      if (ephemerisPath != null) {
        _bindings!.setEphemerisPath(ephemerisPath);
      }

      // Test that the library is working
      final version = _bindings!.getVersion();
      if (kDebugMode) {
        print('Swiss Ephemeris initialized. Version: $version');
      }

      _isInitialized = true;
    } catch (e, stackTrace) {
      throw InitializationException(
        'Failed to initialize Swiss Ephemeris: ${e.toString()}',
        originalError: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// Calculates the position of a planet.
  ///
  /// [planet] - The planet to calculate.
  /// [dateTime] - The date and time for calculation.
  /// [location] - The geographic location for calculation.
  /// [flags] - Calculation flags.
  ///
  /// Returns a [PlanetPosition] with the calculated data.
  ///
  /// Throws [CalculationException] if calculation fails.
  Future<PlanetPosition> calculatePlanetPosition({
    required Planet planet,
    required DateTime dateTime,
    required GeographicLocation location,
    required CalculationFlags flags,
  }) async {
    if (!_isInitialized || _bindings == null) {
      throw CalculationException('EphemerisService is not initialized');
    }

    // Generate cache key
    final julianDay = _dateTimeToJulianDay(dateTime);
    final cacheKey = '${planet.swissEphId}_${julianDay.toStringAsFixed(6)}_${location.latitude.toStringAsFixed(4)}_${location.longitude.toStringAsFixed(4)}_${flags.toSwissEphFlag()}';
    
    // Check cache first
    if (_positionCache.containsKey(cacheKey)) {
      return _positionCache[cacheKey]!;
    }
    
    // Enforce cache size limit
    if (_positionCache.length >= _maxCacheSize) {
      // Remove oldest entries (simple FIFO)
      final keysToRemove = _positionCache.keys.take(_maxCacheSize ~/ 4).toList();
      for (final key in keysToRemove) {
        _positionCache.remove(key);
      }
    }

    try {
      // Set topocentric position if required
      if (flags.useTopocentric) {
        _bindings!.setTopocentric(
          location.longitude,
          location.latitude,
          location.altitude,
        );
      }

      // Convert DateTime to Julian Day
      final julianDay = _dateTimeToJulianDay(dateTime);

      // Set sidereal mode and get ayanamsa for this date
      // Only needed if we're doing sidereal calculations (not tropical)
      double ayanamsa = 0.0;
      if (!flags.useTropical) {
        _bindings!.setSiderealMode(
          flags.siderealModeConstant,
          0.0,
          0.0,
        );
        ayanamsa = _bindings!.getAyanamsaUT(julianDay);
      }

      // Calculate position (tropical, then we subtract ayanamsa if sidereal)
      final errorBuffer = malloc<ffi.Char>(256);
      try {
        final results = _bindings!.calculateUT(
          julianDay: julianDay,
          planetId: planet.swissEphId,
          flags: flags.toSwissEphFlag(),
          errorBuffer: errorBuffer,
        );

        if (results == null) {
          final error = errorBuffer.cast<Utf8>().toDartString();
          throw JyotishException(
            'Failed to calculate position for ${planet.displayName}: $error',
          );
        }

        // Convert tropical to sidereal by subtracting ayanamsa (only if not tropical mode)
        if (!flags.useTropical) {
          results[0] = (results[0] - ayanamsa + 360) % 360;
        }

        final position = PlanetPosition.fromSwissEph(
          planet: planet,
          dateTime: dateTime,
          results: results,
        );
        
        // Store in cache
        _positionCache[cacheKey] = position;
        
        return position;
      } finally {
        malloc.free(errorBuffer);
      }
    } catch (e, stackTrace) {
      if (e is CalculationException) rethrow;
      throw CalculationException(
        'Error calculating planet position: ${e.toString()}',
        originalError: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// Converts a DateTime to Julian Day number.
  double _dateTimeToJulianDay(DateTime dateTime) {
    // Convert to UTC
    final utc = dateTime.toUtc();

    // Calculate hour as decimal
    final hour = utc.hour +
        (utc.minute / 60.0) +
        (utc.second / 3600.0) +
        (utc.millisecond / 3600000.0);

    return _bindings!.julianDay(
      year: utc.year,
      month: utc.month,
      day: utc.day,
      hour: hour,
      isGregorian: true,
    );
  }

  /// Gets the ayanamsa (sidereal offset) for a given date and time.
  ///
  /// [dateTime] - The date and time to calculate for.
  /// [mode] - The sidereal mode to use.
  ///
  /// Returns the ayanamsa in degrees.
  Future<double> getAyanamsa({
    required DateTime dateTime,
    required SiderealMode mode,
  }) async {
    if (!_isInitialized || _bindings == null) {
      throw CalculationException('EphemerisService is not initialized');
    }

    try {
      // Set sidereal mode
      _bindings!.setSiderealMode(mode.constant, 0.0, 0.0);

      // Convert DateTime to Julian Day
      final julianDay = _dateTimeToJulianDay(dateTime);

      // Get ayanamsa
      return _bindings!.getAyanamsaUT(julianDay);
    } catch (e, stackTrace) {
      throw CalculationException(
        'Error calculating ayanamsa: ${e.toString()}',
        originalError: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// Calculates house cusps and ascendant/midheaven.
  ///
  /// [dateTime] - The date and time for calculation.
  /// [location] - The geographic location for calculation.
  /// [houseSystem] - The house system to use ('P' = Placidus, 'K' = Koch, etc.)
  ///
  /// Returns a map with 'cusps' and 'ascmc' arrays.
  ///
  /// Throws [CalculationException] if calculation fails.
  Future<Map<String, List<double>>> calculateHouses({
    required DateTime dateTime,
    required GeographicLocation location,
    String houseSystem = 'P',
  }) async {
    if (!_isInitialized || _bindings == null) {
      throw CalculationException('EphemerisService is not initialized');
    }

    try {
      // Convert DateTime to Julian Day
      final julianDay = _dateTimeToJulianDay(dateTime);

      // Calculate houses
      final result = _bindings!.calculateHouses(
        julianDay: julianDay,
        latitude: location.latitude,
        longitude: location.longitude,
        houseSystem: houseSystem,
      );

      if (result == null) {
        throw CalculationException('Failed to calculate houses');
      }

      return result;
    } catch (e, stackTrace) {
      throw CalculationException(
        'Error calculating houses: ${e.toString()}',
        originalError: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// Disposes of resources.
  void dispose() {
    if (_isInitialized && _bindings != null) {
      _bindings!.close();
      _isInitialized = false;
    }
  }

  /// Gets whether the service is initialized.
  bool get isInitialized => _isInitialized;
}
