import 'dart:ffi' as ffi;


import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';

import '../bindings/swisseph_bindings.dart';
import '../exceptions/jyotish_exception.dart';
import '../models/calculation_flags.dart';
import '../models/ephemeris_data_range.dart';
import '../models/ephemeris_provenance.dart';
import '../models/geographic_location.dart';
import '../models/planet.dart';
import '../models/planet_position.dart';
import '../models/sun_moon_positions.dart';

/// Service for calculating planetary positions using Swiss Ephemeris.
///
/// This service provides high-level methods for astronomical calculations
/// using the Swiss Ephemeris library.
class EphemerisService {
  SwissEphBindings? _bindings;
  bool _isInitialized = false;
  Future<void>? _initializeFuture;
  int _initializeEpoch = 0;

  /// Version of the cached calculation semantics.
  ///
  /// Part of every cache key. Bump it whenever a change alters the numbers
  /// produced for the same inputs (frame handling, ayanamsa application,
  /// returned-flag interpretation), so a long-lived process cannot mix old and
  /// new results.
  static const int calculationVersion = 2;

  /// Cache for planet position calculations.
  ///
  /// Typed keys make the frame part of identity: a tropical lookup cannot hit
  /// a sidereal entry, and a topocentric entry at one altitude cannot satisfy
  /// a request at another. Geocentric entries omit the location entirely,
  /// because the Earth's centre does not move with the observer.
  final Map<_PositionCacheKey, PlanetPosition> _positionCache = {};

  /// Maximum cache size to prevent memory issues
  static const int _maxCacheSize = 1000;

  /// Initializes the Swiss Ephemeris service.
  ///
  /// [ephemerisPath] - Optional path to Swiss Ephemeris data files.
  /// If not provided, the library will use its default search paths.
  ///
  /// Concurrent calls share one in-flight initialization. A failed attempt
  /// clears that future, so the caller can retry. The path is fixed for the
  /// lifetime of this service; [dispose] before initializing with another path.
  ///
  /// Swiss Ephemeris keeps process-global native state. Each isolate has its
  /// own [EphemerisService], so a background isolate must call this itself;
  /// it cannot reuse the foreground isolate's initialized object. Do not
  /// dispose one isolate's service while another is calculating.
  ///
  /// Throws [InitializationException] if initialization fails.
  Future<void> initialize({String? ephemerisPath}) {
    if (_isInitialized) {
      return Future.value();
    }
    return _initializeFuture ??= _initialize(ephemerisPath);
  }

  Future<void> _initialize(String? ephemerisPath) async {
    final epoch = _initializeEpoch;
    SwissEphBindings? bindings;

    try {
      final version = SwissEphBindings.withNativeLock(() {
        bindings = SwissEphBindings();
        if (ephemerisPath != null) {
          bindings!.setEphemerisPath(ephemerisPath);
        }
        return bindings!.getVersion();
      });

      if (epoch != _initializeEpoch) {
        SwissEphBindings.withNativeLock(() => bindings!.close());
        throw InitializationException(
          'Swiss Ephemeris initialization was cancelled by dispose().',
        );
      }

      _bindings = bindings!;
      _isInitialized = true;

      if (kDebugMode) {
        print('Swiss Ephemeris initialized. Version: $version');
      }
    } catch (e, stackTrace) {
      _initializeFuture = null;
      if (e is InitializationException) rethrow;
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
    final positions = calculatePlanetPositions(
      planets: [planet],
      dateTime: dateTime,
      location: location,
      flags: flags,
    );
    return positions[planet]!;
  }

  /// Calculates several planets at one instant as a single batch.
  ///
  /// Swiss Ephemeris calls are synchronous, so an async `Future.wait` over
  /// them does not run anything in parallel; it only interleaves futures while
  /// each call blocks the isolate. This method does the work once, in order:
  ///
  /// - applies topocentric and sidereal global state once per batch;
  /// - allocates one native error buffer instead of one per planet;
  /// - skips planets already cached under the same typed key.
  ///
  /// Each returned [PlanetPosition] keeps its own provenance, because a
  /// missing asteroid file can fall back independently from the Sun.
  ///
  /// Throws [ArgumentError] for an unsupported frame combination and
  /// [CalculationException] if a native calculation fails.
  Map<Planet, PlanetPosition> calculatePlanetPositions({
    required List<Planet> planets,
    required DateTime dateTime,
    required GeographicLocation location,
    required CalculationFlags flags,
  }) {
    _ensureInitialized();
    _validateFlags(flags);

    if (planets.isEmpty) return const {};

    final julianDay = _dateTimeToJulianDay(dateTime);
    final uniquePlanets = planets.toSet().toList(growable: false);
    final keys = <Planet, _PositionCacheKey>{
      for (final planet in uniquePlanets)
        planet: _cacheKey(
          planet: planet,
          dateTime: dateTime,
          location: location,
          flags: flags,
        ),
    };

    final missing = [
      for (final planet in uniquePlanets)
        if (!_positionCache.containsKey(keys[planet])) planet,
    ];

    if (missing.isNotEmpty) {
      SwissEphBindings.withNativeLock(() {
        final bindings = _bindings!;
        final nativeSidereal = flags.useNativeSidereal && !flags.useTropical;

        if (flags.useTopocentric) {
          bindings.setTopocentric(
            location.longitude,
            location.latitude,
            location.altitude,
          );
        }

        double ayanamsa = 0.0;
        if (!flags.useTropical) {
          bindings.setSiderealMode(flags.siderealModeConstant, 0.0, 0.0);
          if (!nativeSidereal) {
            ayanamsa = bindings.getAyanamsaUT(julianDay);
          }
        }

        final errorBuffer = malloc<ffi.Char>(256);
        try {
          for (final planet in missing) {
            final position = _calculateOne(
              bindings: bindings,
              planet: planet,
              dateTime: dateTime,
              julianDay: julianDay,
              flags: flags,
              ayanamsa: ayanamsa,
              errorBuffer: errorBuffer,
            );
            _store(keys[planet]!, position);
          }
        } finally {
          malloc.free(errorBuffer);
        }
      });
    }

    final result = <Planet, PlanetPosition>{};
    for (final planet in uniquePlanets) {
      final position = _positionCache[keys[planet]]!;
      _ensureRequiredBackend(flags, position.provenance, planet);
      result[planet] = position;
    }
    return result;
  }

  /// Calculates the Sun and Moon together for a Panchang instant.
  ///
  /// Tithi, yoga and karana need both bodies. This is [calculatePlanetPositions]
  /// with the pair fixed, so both values share one state setup and one cache
  /// lookup pass.
  SunMoonPositions calculateSunMoon({
    required DateTime dateTime,
    required GeographicLocation location,
    required CalculationFlags flags,
  }) {
    final positions = calculatePlanetPositions(
      planets: const [Planet.sun, Planet.moon],
      dateTime: dateTime,
      location: location,
      flags: flags,
    );
    return SunMoonPositions(
      sun: positions[Planet.sun]!,
      moon: positions[Planet.moon]!,
    );
  }

  /// Calculates one planet using state already applied for the batch.
  PlanetPosition _calculateOne({
    required SwissEphBindings bindings,
    required Planet planet,
    required DateTime dateTime,
    required double julianDay,
    required CalculationFlags flags,
    required double ayanamsa,
    required ffi.Pointer<ffi.Char> errorBuffer,
  }) {
    // The buffer is reused across the batch; clear it so a previous planet's
    // warning cannot be reported as this planet's warning.
    errorBuffer.value = 0;

    final calculation = bindings.calculateUT(
      julianDay: julianDay,
      planetId: planet.swissEphId,
      flags: flags.toSwissEphFlag(),
      errorBuffer: errorBuffer,
    );

    if (calculation == null) {
      final error = errorBuffer.cast<Utf8>().toDartString();
      throw CalculationException(
        'Failed to calculate position for ${planet.displayName}: $error',
      );
    }

    final nativeSidereal = flags.useNativeSidereal && !flags.useTropical;
    if (nativeSidereal &&
        (calculation.returnedFlags & SwissEphBindings.SEFLG_SIDEREAL) == 0) {
      throw CalculationException(
        'Swiss Ephemeris did not confirm the requested sidereal frame for '
        '${planet.displayName}.',
      );
    }

    final provenance = EphemerisProvenance(
      requestedFlags: flags.toSwissEphFlag(),
      returnedFlags: calculation.returnedFlags,
      backend: EphemerisBackend.fromFlags(calculation.returnedFlags),
      warning: calculation.warning,
    );
    _ensureRequiredBackend(flags, provenance, planet);

    final results = List<double>.of(calculation.values);

    // Historical path: the native call was tropical, so convert here. The
    // native sidereal path already returned sidereal longitude and must not be
    // converted a second time.
    if (!flags.useTropical && !nativeSidereal) {
      results[0] = (results[0] - ayanamsa + 360) % 360;
    }

    return PlanetPosition.fromSwissEph(
      planet: planet,
      dateTime: dateTime,
      results: results,
      provenance: provenance,
    );
  }

  _PositionCacheKey _cacheKey({
    required Planet planet,
    required DateTime dateTime,
    required GeographicLocation location,
    required CalculationFlags flags,
  }) {
    return _PositionCacheKey(
      planetId: planet.swissEphId,
      instantMicroseconds: dateTime.toUtc().microsecondsSinceEpoch,
      swissFlags: flags.toSwissEphFlag(),
      useTropical: flags.useTropical,
      siderealModeConstant: flags.useTropical ? 0 : flags.siderealModeConstant,
      topocentric: flags.useTopocentric,
      latitude: flags.useTopocentric ? location.latitude : null,
      longitude: flags.useTopocentric ? location.longitude : null,
      altitude: flags.useTopocentric ? location.altitude : null,
      calculationVersion: calculationVersion,
    );
  }

  void _store(_PositionCacheKey key, PlanetPosition position) {
    if (_positionCache.length >= _maxCacheSize &&
        !_positionCache.containsKey(key)) {
      final keysToRemove =
          _positionCache.keys.take(_maxCacheSize ~/ 4).toList();
      for (final oldKey in keysToRemove) {
        _positionCache.remove(oldKey);
      }
    }
    _positionCache[key] = position;
  }

  void _validateFlags(CalculationFlags flags) {
    // Ayanamsa is an ecliptic-longitude offset. Subtracting it from an
    // equatorial right ascension mixes frames and silently returns a wrong
    // position, so refuse the combination instead of guessing which frame the
    // caller meant.
    if (flags.useEquatorial && !flags.useTropical) {
      throw ArgumentError(
        'Equatorial coordinates are tropical; a sidereal equatorial request '
        'cannot be produced by subtracting ayanamsa from right ascension. '
        'Set useTropical: true or request ecliptic coordinates.',
      );
    }
    if (flags.requireSwissEphemeris && !flags.useSwissEphemeris) {
      throw ArgumentError(
        'requireSwissEphemeris cannot be combined with '
        'useSwissEphemeris: false.',
      );
    }
    if (flags.useNativeSidereal && flags.useTropical) {
      throw ArgumentError(
        'useNativeSidereal cannot be combined with useTropical: true.',
      );
    }
  }

  void _ensureInitialized() {
    if (!_isInitialized || _bindings == null) {
      throw CalculationException('EphemerisService is not initialized');
    }
  }

  /// Rejects a position whose backend does not meet the caller's requirement.
  void _ensureRequiredBackend(
    CalculationFlags flags,
    EphemerisProvenance? provenance,
    Planet planet,
  ) {
    if (!flags.requireSwissEphemeris) return;

    if (provenance == null) {
      throw EphemerisBackendException(
        'No backend provenance is available for ${planet.displayName}, so '
        'Swiss Ephemeris output cannot be guaranteed.',
      );
    }

    if (!provenance.isHighPrecision) {
      final warning = provenance.warning == null
          ? ''
          : ' Native warning: ${provenance.warning}';
      throw EphemerisBackendException(
        'Swiss Ephemeris data was required for ${planet.displayName}, but the '
        'library used ${provenance.backend.label}.$warning',
      );
    }
  }

  /// Reports which Swiss Ephemeris files actually loaded and their date range.
  ///
  /// A J2000 Sun and Moon calculation opens both files first;
  /// `swe_get_current_file_data()` is only populated after a calculation. A
  /// null [EphemerisDataRange.planets] or [EphemerisDataRange.moon] means that
  /// slot is using an analytical fallback, not that the package expected a
  /// different asset name. The package deliberately does not assert a range;
  /// the application decides which years its install must cover.
  Future<EphemerisDataRange> probeDataRange() async {
    _ensureInitialized();
    return await SwissEphBindings.withNativeLockAsync<EphemerisDataRange>(() {
      final bindings = _bindings!;
      final julianDay = bindings.julianDay(
        year: 2000,
        month: 1,
        day: 1,
        hour: 12.0,
      );
      final errorBuffer = malloc<ffi.Char>(256);
      try {
        for (final planet in [Planet.sun, Planet.moon]) {
          errorBuffer.value = 0;
          bindings.calculateUT(
            julianDay: julianDay,
            planetId: planet.swissEphId,
            flags: SwissEphBindings.SEFLG_SWIEPH,
            errorBuffer: errorBuffer,
          );
        }
      } finally {
        malloc.free(errorBuffer);
      }

      return EphemerisDataRange(
        planets: _readFileRange(0),
        moon: _readFileRange(1),
        asteroids: _readFileRange(2),
      );
    });
  }

  EphemerisFileRange? _readFileRange(int ifno) {
    final raw = _bindings!.getCurrentFileData(ifno: ifno);
    if (raw == null) return null;
    if (raw.path.isEmpty ||
        !raw.startJulianDay.isFinite ||
        !raw.endJulianDay.isFinite ||
        raw.endJulianDay <= raw.startJulianDay) {
      return null;
    }

    final start = _bindings!.julianDayToUtcDateTime(raw.startJulianDay);
    final end = _bindings!.julianDayToUtcDateTime(raw.endJulianDay);
    if (!end.isAfter(start)) return null;

    return EphemerisFileRange(
      ifno: raw.ifno,
      path: raw.path,
      startUtc: start,
      endUtc: end,
      denum: raw.denum,
    );
  }

  /// Converts a DateTime to Julian Day number.
  double _dateTimeToJulianDay(DateTime dateTime) {
    // Convert to UTC
    final utc = dateTime.toUtc();

    // Calculate hour as decimal
    final hour = utc.hour +
        (utc.minute / 60.0) +
        (utc.second / 3600.0) +
        (utc.millisecond / 3600000.0) +
        (utc.microsecond / 3600000000.0);

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
    _ensureInitialized();

    try {
      return await SwissEphBindings.withNativeLockAsync<double>(() {
        _bindings!.setSiderealMode(mode.constant, 0.0, 0.0);
        final julianDay = _dateTimeToJulianDay(dateTime);
        return _bindings!.getAyanamsaUT(julianDay);
      });
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
  /// [houseSystem] - The house system to use ('P' = Placidus, 'K' = Koch,
  /// etc.). The returned label is the caller's responsibility; the raw cusps
  /// follow this code.
  /// [flags] - When supplied and not tropical, cusps and the ascendant/MC are
  /// returned in the sidereal frame chosen by `flags.siderealMode`. When null
  /// (the default) the result is tropical, matching the historical API.
  ///
  /// Returns a map with 'cusps' and 'ascmc' arrays.
  ///
  /// Throws [ArgumentError] for an invalid house code or an equatorial request,
  /// and [CalculationException] if the calculation itself fails.
  Future<Map<String, List<double>>> calculateHouses({
    required DateTime dateTime,
    required GeographicLocation location,
    String houseSystem = 'P',
    CalculationFlags? flags,
  }) async {
    _ensureInitialized();

    final systemCode = houseSystem.toUpperCase();
    if (systemCode.length != 1) {
      throw ArgumentError.value(
        houseSystem,
        'houseSystem',
        'Expected a single Swiss Ephemeris house-system code',
      );
    }
    if (flags?.useEquatorial ?? false) {
      throw ArgumentError(
        'House cusps are ecliptic; equatorial flags do not apply to houses.',
      );
    }

    try {
      return await SwissEphBindings.withNativeLockAsync<Map<String, List<double>>>(
        () {
        final julianDay = _dateTimeToJulianDay(dateTime);
        final sidereal = flags != null && !flags.useTropical;

        if (sidereal) {
          _bindings!.setSiderealMode(flags.siderealModeConstant, 0.0, 0.0);
        }

        final result = _bindings!.calculateHouses(
          julianDay: julianDay,
          latitude: location.latitude,
          longitude: location.longitude,
          houseSystem: systemCode,
          flags: sidereal ? SwissEphBindings.SEFLG_SIDEREAL : 0,
        );

        if (result == null) {
          throw CalculationException('Failed to calculate houses');
        }

        return result;
        },
      );
    } catch (e, stackTrace) {
      throw CalculationException(
        'Error calculating houses: ${e.toString()}',
        originalError: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// Clears cached positions.
  ///
  /// Keys already include every input and [calculationVersion], so this is
  /// only needed to release memory or to force a fresh native calculation
  /// (for example after changing the ephemeris path by recreating the service).
  void clearCache() {
    _positionCache.clear();
  }

  /// Number of cached positions. Exposed for tests.
  @visibleForTesting
  int get positionCacheSize => _positionCache.length;

  /// Disposes of resources and cancels an in-flight initialization.
  void dispose() {
    _initializeEpoch++;
    _initializeFuture = null;
    clearCache();

    final bindings = _bindings;
    _bindings = null;
    _isInitialized = false;
    if (bindings != null) {
      SwissEphBindings.withNativeLock(bindings.close);
    }
  }

  /// Gets whether the service is initialized.
  bool get isInitialized => _isInitialized;
}

/// Identity of one cached planetary position.
///
/// A plain string key hid rounding decisions in `toStringAsFixed`. This key
/// keeps the instant exact to the microsecond and includes only the inputs that
/// actually change geocentric results; topocentric fields are present only
/// when the request is topocentric.
@immutable
class _PositionCacheKey {
  const _PositionCacheKey({
    required this.planetId,
    required this.instantMicroseconds,
    required this.swissFlags,
    required this.useTropical,
    required this.siderealModeConstant,
    required this.topocentric,
    required this.calculationVersion,
    this.latitude,
    this.longitude,
    this.altitude,
  });

  final int planetId;
  final int instantMicroseconds;
  final int swissFlags;
  final bool useTropical;
  final int siderealModeConstant;
  final bool topocentric;
  final int calculationVersion;
  final double? latitude;
  final double? longitude;
  final double? altitude;

  @override
  bool operator ==(Object other) {
    return other is _PositionCacheKey &&
        other.planetId == planetId &&
        other.instantMicroseconds == instantMicroseconds &&
        other.swissFlags == swissFlags &&
        other.useTropical == useTropical &&
        other.siderealModeConstant == siderealModeConstant &&
        other.topocentric == topocentric &&
        other.calculationVersion == calculationVersion &&
        other.latitude == latitude &&
        other.longitude == longitude &&
        other.altitude == altitude;
  }

  @override
  int get hashCode => Object.hash(
        planetId,
        instantMicroseconds,
        swissFlags,
        useTropical,
        siderealModeConstant,
        topocentric,
        calculationVersion,
        latitude,
        longitude,
        altitude,
      );
}
