import 'package:flutter/foundation.dart' show visibleForTesting;

import 'exceptions/jyotish_exception.dart';
import 'models/calculation_flags.dart';
import 'models/ephemeris_data_range.dart';
import 'models/geographic_location.dart';
import 'models/planet.dart';
import 'models/planet_position.dart';
import 'models/sun_moon_positions.dart';
import 'models/vedic_chart.dart';
import 'services/ephemeris_service.dart';
import 'services/vedic_chart_service.dart';

/// The main entry point for the Jyotish library.
///
/// This class provides a high-level API for calculating planetary positions
/// using Swiss Ephemeris.
///
/// Example:
/// ```dart
/// final jyotish = Jyotish();
/// await jyotish.initialize();
///
/// final position = await jyotish.getPlanetPosition(
///   planet: Planet.sun,
///   dateTime: DateTime.now(),
///   location: GeographicLocation(
///     latitude: 27.7172,
///     longitude: 85.3240,
///   ),
/// );
///
/// print('Sun longitude: ${position.longitude}');
/// ```
class Jyotish {
  /// Gets the singleton instance of Jyotish.
  factory Jyotish() {
    _instance ??= Jyotish._();
    return _instance!;
  }

  /// Creates a new instance of Jyotish.
  ///
  /// Use [initialize] to set up the Swiss Ephemeris data path before
  /// performing calculations.
  Jyotish._();
  static Jyotish? _instance;
  EphemerisService? _ephemerisService;
  VedicChartService? _vedicChartService;
  bool _isInitialized = false;
  Future<void>? _initializeFuture;
  int _initializeEpoch = 0;

  /// Initializes the Swiss Ephemeris library.
  ///
  /// [ephemerisPath] - Optional custom path to Swiss Ephemeris data files.
  /// If not provided, the library will look for data in the default locations.
  ///
  /// This method must be called before performing any calculations.
  ///
  /// Concurrent calls in one isolate share a single in-flight future, and a
  /// failed attempt can be retried. Swiss Ephemeris keeps process-global native
  /// state but Dart singletons are per isolate, so a background isolate must
  /// call `initialize()` itself; it does not inherit the foreground isolate's
  /// initialization.
  ///
  /// Throws [JyotishException] if initialization fails.
  Future<void> initialize({String? ephemerisPath}) {
    if (_isInitialized) {
      return Future.value();
    }
    return _initializeFuture ??= _initialize(ephemerisPath);
  }

  Future<void> _initialize(String? ephemerisPath) async {
    final epoch = _initializeEpoch;
    final service = EphemerisService();

    try {
      await service.initialize(ephemerisPath: ephemerisPath);

      if (epoch != _initializeEpoch) {
        service.dispose();
        throw JyotishException(
          'Jyotish initialization was cancelled by dispose().',
        );
      }

      _ephemerisService = service;
      _vedicChartService = VedicChartService(service);
      _isInitialized = true;
    } catch (e) {
      _initializeFuture = null;
      if (e is JyotishException) rethrow;
      throw JyotishException(
        'Failed to initialize Jyotish: ${e.toString()}',
        originalError: e,
      );
    }
  }

  /// Calculates the position of a planet at a given date, time, and location.
  ///
  /// [planet] - The planet to calculate the position for.
  /// [dateTime] - The date and time for the calculation.
  /// [location] - The geographic location for the calculation.
  /// [flags] - Optional calculation flags for customizing the calculation.
  ///
  /// Returns a [PlanetPosition] containing the calculated position data.
  ///
  /// Throws [JyotishException] if the library is not initialized or
  /// if the calculation fails.
  Future<PlanetPosition> getPlanetPosition({
    required Planet planet,
    required DateTime dateTime,
    required GeographicLocation location,
    CalculationFlags? flags,
  }) async {
    _ensureInitialized();

    try {
      return await _ephemerisService!.calculatePlanetPosition(
        planet: planet,
        dateTime: dateTime,
        location: location,
        flags: flags ?? CalculationFlags.defaultFlags(),
      );
    } catch (e) {
      throw JyotishException(
        'Failed to calculate planet position: ${e.toString()}',
        originalError: e,
      );
    }
  }

  /// Calculates positions for multiple planets at once.
  ///
  /// FFI calls are synchronous on the isolate, so these are not "parallel"
  /// calculations. The work is one ordered batch: global state is applied
  /// once, one error buffer is reused, and already-cached planets are skipped.
  ///
  /// [planets] - List of planets to calculate positions for.
  /// [dateTime] - The date and time for the calculation.
  /// [location] - The geographic location for the calculation.
  /// [flags] - Optional calculation flags for customizing the calculation.
  ///
  /// Returns a Map of [Planet] to [PlanetPosition].
  ///
  /// Throws [JyotishException] if the library is not initialized or
  /// if any calculation fails.
  Future<Map<Planet, PlanetPosition>> getMultiplePlanetPositions({
    required List<Planet> planets,
    required DateTime dateTime,
    required GeographicLocation location,
    CalculationFlags? flags,
  }) async {
    _ensureInitialized();

    try {
      return _ephemerisService!.calculatePlanetPositions(
        planets: planets,
        dateTime: dateTime,
        location: location,
        flags: flags ?? CalculationFlags.defaultFlags(),
      );
    } catch (e) {
      throw JyotishException(
        'Failed to calculate planet positions: ${e.toString()}',
        originalError: e,
      );
    }
  }

  /// Calculates the Sun and Moon together for a Panchang instant.
  ///
  /// This is the paired form of [getMultiplePlanetPositions] and avoids setting
  /// sidereal/topocentric state twice when tithi, yoga or karana need both
  /// longitudes.
  ///
  /// Throws [JyotishException] if the library is not initialized or if either
  /// calculation fails.
  Future<SunMoonPositions> getSunMoonPositions({
    required DateTime dateTime,
    required GeographicLocation location,
    CalculationFlags? flags,
  }) async {
    _ensureInitialized();

    try {
      return _ephemerisService!.calculateSunMoon(
        dateTime: dateTime,
        location: location,
        flags: flags ?? CalculationFlags.defaultFlags(),
      );
    } catch (e) {
      throw JyotishException(
        'Failed to calculate the Sun and Moon: ${e.toString()}',
        originalError: e,
      );
    }
  }

  /// Calculates positions for all major planets.
  ///
  /// This is a convenience method that calculates positions for:
  /// Sun, Moon, Mercury, Venus, Mars, Jupiter, Saturn, Uranus, Neptune, Pluto.
  ///
  /// [dateTime] - The date and time for the calculation.
  /// [location] - The geographic location for the calculation.
  /// [flags] - Optional calculation flags for customizing the calculation.
  ///
  /// Returns a Map of [Planet] to [PlanetPosition].
  Future<Map<Planet, PlanetPosition>> getAllPlanetPositions({
    required DateTime dateTime,
    required GeographicLocation location,
    CalculationFlags? flags,
  }) async {
    return getMultiplePlanetPositions(
      planets: Planet.majorPlanets,
      dateTime: dateTime,
      location: location,
      flags: flags,
    );
  }

  /// Calculates a complete Vedic astrology chart.
  ///
  /// This method provides comprehensive Vedic astrology data including:
  /// - All planetary positions in sidereal zodiac (Lahiri ayanamsa)
  /// - Rahu (North Node) and Ketu (South Node) positions
  /// - House placements for all planets
  /// - Planetary dignities (exaltation, debilitation, own sign, etc.)
  /// - Combustion status
  /// - Nakshatra and pada for all planets
  /// - Ascendant (Lagna) and house cusps
  ///
  /// [dateTime] - The date and time for the chart (usually birth time)
  /// [location] - The geographic location for the chart (usually birth place)
  /// [houseSystem] - House system to use (default: 'W' for Whole Sign)
  /// [includeOuterPlanets] - Include Uranus, Neptune, Pluto (default: false, not used in traditional Vedic astrology)
  ///
  /// Returns a [VedicChart] with complete chart information.
  ///
  /// Throws [JyotishException] if the library is not initialized or
  /// if the calculation fails.
  ///
  /// Example:
  /// ```dart
  /// final chart = await jyotish.calculateVedicChart(
  ///   dateTime: DateTime(1990, 5, 15, 14, 30),
  ///   location: GeographicLocation(latitude: 28.6139, longitude: 77.2090),
  /// );
  ///
  /// print('Ascendant: ${chart.ascendantSign}');
  /// print('Sun in house: ${chart.getPlanet(Planet.sun)?.house}');
  /// ```
  Future<VedicChart> calculateVedicChart({
    required DateTime dateTime,
    required GeographicLocation location,
    String houseSystem = 'W',
    bool includeOuterPlanets = false,
  }) async {
    _ensureInitialized();

    try {
      return await _vedicChartService!.calculateChart(
        dateTime: dateTime,
        location: location,
        houseSystem: houseSystem,
        includeOuterPlanets: includeOuterPlanets,
      );
    } catch (e) {
      throw JyotishException(
        'Failed to calculate Vedic chart: ${e.toString()}',
        originalError: e,
      );
    }
  }

  /// Reports the Swiss Ephemeris files and date ranges actually loaded.
  ///
  /// The package reports what is loaded and leaves the expected year range to
  /// the application. A null [EphemerisDataRange.planets] or
  /// [EphemerisDataRange.moon] means that file did not load and calculations
  /// are falling back to Moshier.
  Future<EphemerisDataRange> probeDataRange() async {
    _ensureInitialized();

    try {
      return await _ephemerisService!.probeDataRange();
    } catch (e) {
      throw JyotishException(
        'Failed to inspect the loaded ephemeris data range: ${e.toString()}',
        originalError: e,
      );
    }
  }

  /// Clears the in-memory planetary position cache.
  ///
  /// Cache keys already include every input, so this is only needed to release
  /// memory or force fresh native calculations. It is a no-op before
  /// [initialize].
  void clearCache() {
    _ephemerisService?.clearCache();
  }

  /// Disposes of resources used by the library.
  ///
  /// Call this method when you're done using the library to free up resources.
  /// It also cancels an in-flight initialization; a later call to [initialize]
  /// starts a fresh attempt.
  void dispose() {
    _initializeEpoch++;
    _initializeFuture = null;
    _ephemerisService?.dispose();
    _ephemerisService = null;
    _vedicChartService = null;
    _isInitialized = false;
  }

  /// Ensures that the library has been initialized.
  void _ensureInitialized() {
    if (!_isInitialized || _ephemerisService == null) {
      throw JyotishException(
        'Jyotish is not initialized. Call initialize() first.',
      );
    }
  }

  /// Gets whether the library has been initialized.
  bool get isInitialized => _isInitialized;

  /// Resets the singleton instance so that tests can start with a clean state.
  /// This should ONLY be used in test code.
  @visibleForTesting
  static void resetForTesting() {
    _instance?.dispose();
    _instance = null;
  }
}
