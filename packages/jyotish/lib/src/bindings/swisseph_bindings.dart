// ignore_for_file: non_constant_identifier_names, constant_identifier_names

import 'dart:ffi' as ffi;
import 'dart:io';
import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';

/// Result of a Swiss Ephemeris rise/set search.
@immutable
class RiseTransResult {
  const RiseTransResult({
    required this.status,
    this.julianDay,
    this.error,
  });

  /// Raw `swe_rise_trans` return code.
  ///
  /// `0` means success, `-1` is an error, and `-2` means the body does not
  /// rise or set on the requested day (for example, a polar day or night).
  final int status;

  /// Event time as a UT Julian day, present when [status] is `0`.
  final double? julianDay;

  /// Native error text, empty when the native call succeeded.
  final String? error;

  bool get isSuccess => status == 0 && julianDay != null;

  /// True when the body is circumpolar for the requested day.
  bool get isUnavailable => status == -2;
}

/// Result of a `swe_calc_ut()` call.
///
/// [returnedFlags] is the flag set Swiss Ephemeris reports for the calculation
/// that actually ran. It can contain a different backend from the requested
/// flags when a `.se1` file is missing and the library falls back to Moshier.
@immutable
class SwissCalculationResult {
  const SwissCalculationResult({
    required this.values,
    required this.returnedFlags,
    this.warning,
  });

  /// Six double results: longitude, latitude, distance and their speeds.
  final List<double> values;

  /// Flags returned by `swe_calc_ut()`.
  final int returnedFlags;

  /// Native warning text, present even on success when the library fell back.
  final String? warning;
}

/// Raw file-range data from `swe_get_current_file_data()`.
@immutable
class SwissEphemerisFileData {
  const SwissEphemerisFileData({
    required this.ifno,
    required this.path,
    required this.startJulianDay,
    required this.endJulianDay,
    required this.denum,
  });

  /// 0 = planets, 1 = Moon, 2 = main asteroids.
  final int ifno;

  /// Loaded file path.
  final String path;

  /// First Julian day covered by the file.
  final double startJulianDay;

  /// Last Julian day covered by the file.
  final double endJulianDay;

  /// File denumeration reported by Swiss Ephemeris.
  final int denum;
}

/// FFI bindings for Swiss Ephemeris C library.
///
/// This class provides low-level bindings to the Swiss Ephemeris shared library.
class SwissEphBindings {
  SwissEphBindings() {
    _lib = _loadLibrary();
  }
  late final ffi.DynamicLibrary _lib;

  // Function signatures
  late final _swe_set_ephe_path = _lib.lookupFunction<
      ffi.Void Function(ffi.Pointer<ffi.Char>),
      void Function(ffi.Pointer<ffi.Char>)>('swe_set_ephe_path');

  late final _swe_calc_ut = _lib.lookupFunction<
      ffi.Int32 Function(
        ffi.Double,
        ffi.Int32,
        ffi.Int32,
        ffi.Pointer<ffi.Double>,
        ffi.Pointer<ffi.Char>,
      ),
      int Function(
        double,
        int,
        int,
        ffi.Pointer<ffi.Double>,
        ffi.Pointer<ffi.Char>,
      )>('swe_calc_ut');

  late final _swe_set_sid_mode = _lib.lookupFunction<
      ffi.Void Function(ffi.Int32, ffi.Double, ffi.Double),
      void Function(int, double, double)>('swe_set_sid_mode');

  late final _swe_set_topo = _lib.lookupFunction<
      ffi.Void Function(ffi.Double, ffi.Double, ffi.Double),
      void Function(double, double, double)>('swe_set_topo');

  late final _swe_close =
      _lib.lookupFunction<ffi.Void Function(), void Function()>('swe_close');

  late final _swe_julday = _lib.lookupFunction<
      ffi.Double Function(
        ffi.Int32,
        ffi.Int32,
        ffi.Int32,
        ffi.Double,
        ffi.Int32,
      ),
      double Function(
        int,
        int,
        int,
        double,
        int,
      )>('swe_julday');

  late final _swe_version = _lib.lookupFunction<
      ffi.Pointer<ffi.Char> Function(ffi.Pointer<ffi.Char>),
      ffi.Pointer<ffi.Char> Function(ffi.Pointer<ffi.Char>)>('swe_version');

  late final _swe_get_ayanamsa_ut = _lib.lookupFunction<
      ffi.Double Function(ffi.Double),
      double Function(double)>('swe_get_ayanamsa_ut');

  late final _swe_get_current_file_data = _lib.lookupFunction<
      ffi.Pointer<ffi.Char> Function(
        ffi.Int32,
        ffi.Pointer<ffi.Double>,
        ffi.Pointer<ffi.Double>,
        ffi.Pointer<ffi.Int32>,
      ),
      ffi.Pointer<ffi.Char> Function(
        int,
        ffi.Pointer<ffi.Double>,
        ffi.Pointer<ffi.Double>,
        ffi.Pointer<ffi.Int32>,
      )>('swe_get_current_file_data');

  late final _swe_houses_ex = _lib.lookupFunction<
      ffi.Int32 Function(
        ffi.Double,
        ffi.Int32,
        ffi.Double,
        ffi.Double,
        ffi.Int32,
        ffi.Pointer<ffi.Double>,
        ffi.Pointer<ffi.Double>,
      ),
      int Function(
        double,
        int,
        double,
        double,
        int,
        ffi.Pointer<ffi.Double>,
        ffi.Pointer<ffi.Double>,
      )>('swe_houses_ex');

  late final _swe_rise_trans = _lib.lookupFunction<
      ffi.Int32 Function(
        ffi.Double, // tjd_ut
        ffi.Int32, // ipl
        ffi.Pointer<ffi.Char>, // starname
        ffi.Int32, // epheflag
        ffi.Int32, // rsmi
        ffi.Pointer<ffi.Double>, // geopos [lon, lat, altitude]
        ffi.Double, // atpress
        ffi.Double, // attemp
        ffi.Pointer<ffi.Double>, // tret
        ffi.Pointer<ffi.Char>, // serr
      ),
      int Function(
        double,
        int,
        ffi.Pointer<ffi.Char>,
        int,
        int,
        ffi.Pointer<ffi.Double>,
        double,
        double,
        ffi.Pointer<ffi.Double>,
        ffi.Pointer<ffi.Char>,
      )>('swe_rise_trans');

  // ============== Rise/set constants ==============

  /// Search for a rise event in [riseTrans].
  static const int SE_CALC_RISE = 1;

  /// Search for a set event in [riseTrans].
  static const int SE_CALC_SET = 2;

  /// Use the centre of the body's disc instead of its upper limb.
  static const int SE_BIT_DISC_CENTER = 256;

  /// Use the lower limb of the body's disc.
  static const int SE_BIT_DISC_BOTTOM = 2048;

  /// Omit atmospheric refraction.
  static const int SE_BIT_NO_REFRACTION = 512;

  /// Use a geocentric position and ignore ecliptic latitude.
  static const int SE_BIT_GEOCTR_NO_ECL_LAT = 128;

  /// Swiss Ephemeris' Hindu rising/setting convention:
  /// disc centre, no refraction, geocentric, ecliptic latitude ignored.
  static const int SE_BIT_HINDU_RISING =
      SE_BIT_DISC_CENTER | SE_BIT_NO_REFRACTION | SE_BIT_GEOCTR_NO_ECL_LAT;

  /// JPL ephemeris backend.
  static const int SEFLG_JPLEPH = 1;

  /// Swiss Ephemeris backend.
  static const int SEFLG_SWIEPH = 2;

  /// Moshier analytical ephemeris backend.
  static const int SEFLG_MOSEPH = 4;

  /// Mask selecting one of the supported ephemeris backends.
  static const int SEFLG_EPHMASK = SEFLG_JPLEPH | SEFLG_SWIEPH | SEFLG_MOSEPH;

  /// Disable nutation.
  static const int SEFLG_NONUT = 64;

  /// Return sidereal positions.
  static const int SEFLG_SIDEREAL = 64 * 1024;

  /// Return true/geometric positions rather than apparent positions.
  static const int SEFLG_TRUEPOS = 16;

  // ============== Eclipse Functions ==============

  /// swe_lun_eclipse_when - Find next lunar eclipse
  /// Returns flags indicating eclipse type
  late final _swe_lun_eclipse_when = _lib.lookupFunction<
      ffi.Int32 Function(
        ffi.Double, // tjd_start - starting Julian day
        ffi.Int32, // ifl - ephemeris flag (usually 0 for default)
        ffi.Int32, // ifltype - eclipse type filter (0 = any)
        ffi.Pointer<ffi.Double>, // tret - array[10] for return times
        ffi.Int32, // backward - 0 = forward search, 1 = backward
        ffi.Pointer<ffi.Char>, // serr - error string buffer
      ),
      int Function(
        double,
        int,
        int,
        ffi.Pointer<ffi.Double>,
        int,
        ffi.Pointer<ffi.Char>,
      )>('swe_lun_eclipse_when');

  /// swe_lun_eclipse_how - Get details of lunar eclipse at given time
  late final _swe_lun_eclipse_how = _lib.lookupFunction<
      ffi.Int32 Function(
        ffi.Double, // tjd_ut - Julian day
        ffi.Int32, // ifl - ephemeris flag
        ffi.Pointer<
            ffi.Double>, // geopos - observer's geo position [lon, lat, alt]
        ffi.Pointer<ffi.Double>, // attr - array[20] for eclipse attributes
        ffi.Pointer<ffi.Char>, // serr - error string buffer
      ),
      int Function(
        double,
        int,
        ffi.Pointer<ffi.Double>,
        ffi.Pointer<ffi.Double>,
        ffi.Pointer<ffi.Char>,
      )>('swe_lun_eclipse_how');

  /// swe_sol_eclipse_when_glob - Find next global solar eclipse
  late final _swe_sol_eclipse_when_glob = _lib.lookupFunction<
      ffi.Int32 Function(
        ffi.Double, // tjd_start
        ffi.Int32, // ifl
        ffi.Int32, // ifltype - eclipse type filter
        ffi.Pointer<ffi.Double>, // tret - array[10] for return times
        ffi.Int32, // backward
        ffi.Pointer<ffi.Char>, // serr
      ),
      int Function(
        double,
        int,
        int,
        ffi.Pointer<ffi.Double>,
        int,
        ffi.Pointer<ffi.Char>,
      )>('swe_sol_eclipse_when_glob');

  /// swe_sol_eclipse_when_loc - Find next solar eclipse visible at location
  late final _swe_sol_eclipse_when_loc = _lib.lookupFunction<
      ffi.Int32 Function(
        ffi.Double, // tjd_start
        ffi.Int32, // ifl
        ffi.Pointer<ffi.Double>, // geopos - [lon, lat, alt]
        ffi.Pointer<ffi.Double>, // tret - array[10]
        ffi.Pointer<ffi.Double>, // attr - array[20]
        ffi.Int32, // backward
        ffi.Pointer<ffi.Char>, // serr
      ),
      int Function(
        double,
        int,
        ffi.Pointer<ffi.Double>,
        ffi.Pointer<ffi.Double>,
        ffi.Pointer<ffi.Double>,
        int,
        ffi.Pointer<ffi.Char>,
      )>('swe_sol_eclipse_when_loc');

  /// swe_sol_eclipse_where - Geographic position of solar eclipse
  late final _swe_sol_eclipse_where = _lib.lookupFunction<
      ffi.Int32 Function(
        ffi.Double, // tjd_ut
        ffi.Int32, // ifl
        ffi.Pointer<
            ffi.Double>, // geopos - returns [lon, lat] of eclipse center
        ffi.Pointer<ffi.Double>, // attr - array[20]
        ffi.Pointer<ffi.Char>, // serr
      ),
      int Function(
        double,
        int,
        ffi.Pointer<ffi.Double>,
        ffi.Pointer<ffi.Double>,
        ffi.Pointer<ffi.Char>,
      )>('swe_sol_eclipse_where');

  /// swe_revjul - Convert Julian day to calendar date
  late final _swe_revjul = _lib.lookupFunction<
      ffi.Void Function(
        ffi.Double, // tjd - Julian day
        ffi.Int32, // gregflag - calendar type (1 = Gregorian)
        ffi.Pointer<ffi.Int32>, // year
        ffi.Pointer<ffi.Int32>, // month
        ffi.Pointer<ffi.Int32>, // day
        ffi.Pointer<ffi.Double>, // hour
      ),
      void Function(
        double,
        int,
        ffi.Pointer<ffi.Int32>,
        ffi.Pointer<ffi.Int32>,
        ffi.Pointer<ffi.Int32>,
        ffi.Pointer<ffi.Double>,
      )>('swe_revjul');

  /// Loads the appropriate Swiss Ephemeris library for the platform.
  ///
  /// Android resolves `libswisseph.so` from the APK. Every other platform
  /// builds no native engine in this package, so the supported route there is
  /// [SWISSEPH_LIB_PATH] (tests and desktop hosts); without it, the platform's
  /// default loader path is tried and the caller keeps its labelled
  /// approximation.
  ffi.DynamicLibrary _loadLibrary() {
    // Try custom path first (from environment or development location)
    final customPath = Platform.environment['SWISSEPH_LIB_PATH'];
    if (customPath != null && customPath.isNotEmpty) {
      try {
        return ffi.DynamicLibrary.open(customPath);
      } catch (e) {
        if (kDebugMode) {
          print('Failed to load from custom path: $customPath');
        }
      }
    }

    // Try development/local paths
    if (Platform.isMacOS) {
      final devPaths = [
        '/usr/local/lib/libswisseph.dylib',
        'libswisseph.dylib',
      ];

      for (final path in devPaths) {
        try {
          return ffi.DynamicLibrary.open(path);
        } catch (e) {
          // Try next path
          continue;
        }
      }
    }

    // Fall back to standard loading
    if (Platform.isAndroid) {
      return ffi.DynamicLibrary.open('libswisseph.so');
    } else if (Platform.isIOS || Platform.isMacOS) {
      return ffi.DynamicLibrary.open('libswisseph.dylib');
    } else if (Platform.isLinux) {
      return ffi.DynamicLibrary.open('libswisseph.so');
    } else if (Platform.isWindows) {
      return ffi.DynamicLibrary.open('swisseph.dll');
    } else {
      throw UnsupportedError('Unsupported platform');
    }
  }

  /// Sets the path to Swiss Ephemeris data files.
  void setEphemerisPath(String path) {
    final pathPtr = path.toNativeUtf8();
    try {
      _swe_set_ephe_path(pathPtr.cast());
    } finally {
      malloc.free(pathPtr);
    }
  }

  /// Calculates planet position using Universal Time.
  ///
  /// Returns the six doubles (longitude, latitude, distance, longitudeSpeed,
  /// latitudeSpeed, distanceSpeed) together with the backend flags and native
  /// warning text. Returns null if the calculation fails, leaving the message
  /// in [errorBuffer].
  SwissCalculationResult? calculateUT({
    required double julianDay,
    required int planetId,
    required int flags,
    required ffi.Pointer<ffi.Char> errorBuffer,
  }) {
    final resultPtr = malloc<ffi.Double>(6);
    try {
      final returnCode = _swe_calc_ut(
        julianDay,
        planetId,
        flags,
        resultPtr,
        errorBuffer,
      );

      if (returnCode < 0) {
        return null;
      }

      final warning = errorBuffer.cast<Utf8>().toDartString().trim();
      return SwissCalculationResult(
        values: List.generate(6, (i) => resultPtr[i]),
        returnedFlags: returnCode,
        warning: warning.isEmpty ? null : warning,
      );
    } finally {
      malloc.free(resultPtr);
    }
  }

  /// Reports the file and date range Swiss Ephemeris actually loaded.
  ///
  /// [ifno] is 0 for planets, 1 for the Moon and 2 for main asteroids. The
  /// struct is populated only after a `swe_calc_ut()` probe has opened the
  /// corresponding file; call this after at least one calculation.
  ///
  /// Returns null when no file is loaded for [ifno] (for example when the
  /// library is using Moshier).
  SwissEphemerisFileData? getCurrentFileData({required int ifno}) {
    if (ifno < 0 || ifno > 2) {
      throw ArgumentError.value(ifno, 'ifno', 'Expected 0, 1 or 2');
    }

    final startPtr = malloc<ffi.Double>();
    final endPtr = malloc<ffi.Double>();
    final denumPtr = malloc<ffi.Int32>();

    try {
      final pathPtr = _swe_get_current_file_data(
        ifno,
        startPtr,
        endPtr,
        denumPtr,
      );

      if (pathPtr == ffi.nullptr) {
        return null;
      }

      final path = pathPtr.cast<Utf8>().toDartString();
      if (path.isEmpty) {
        return null;
      }

      return SwissEphemerisFileData(
        ifno: ifno,
        path: path,
        startJulianDay: startPtr.value,
        endJulianDay: endPtr.value,
        denum: denumPtr.value,
      );
    } finally {
      malloc.free(startPtr);
      malloc.free(endPtr);
      malloc.free(denumPtr);
    }
  }

  /// Sets sidereal mode.
  void setSiderealMode(int mode, double t0, double ayanT0) {
    _swe_set_sid_mode(mode, t0, ayanT0);
  }

  /// Sets topocentric position.
  void setTopocentric(double longitude, double latitude, double altitude) {
    _swe_set_topo(longitude, latitude, altitude);
  }

  /// Closes Swiss Ephemeris and frees resources.
  void close() {
    _swe_close();
  }

  /// Converts Gregorian date to Julian day number.
  double julianDay({
    required int year,
    required int month,
    required int day,
    required double hour,
    bool isGregorian = true,
  }) {
    final calendarType = isGregorian ? 1 : 0; // SE_GREG_CAL = 1, SE_JUL_CAL = 0
    return _swe_julday(year, month, day, hour, calendarType);
  }

  /// Gets Swiss Ephemeris version string.
  String getVersion() {
    // Swiss Ephemeris version string is at most 256 characters
    final versionBuffer = malloc<ffi.Char>(256);
    try {
      final resultPtr = _swe_version(versionBuffer);
      return resultPtr.cast<Utf8>().toDartString();
    } finally {
      malloc.free(versionBuffer);
    }
  }

  /// Gets ayanamsa (sidereal offset) for a given Julian day.
  double getAyanamsaUT(double julianDay) {
    return _swe_get_ayanamsa_ut(julianDay);
  }

  /// Calculates house cusps and ascendant/midheaven.
  ///
  /// Returns a map with:
  /// - 'cusps': List of 12 house cusps (0-11)
  /// - 'ascmc': List with ascendant, MC, ARMC, vertex, etc.
  ///
  /// [flags] is passed to `swe_houses_ex`; use [SEFLG_SIDEREAL] after
  /// `swe_set_sid_mode` for sidereal cusps. `0` returns tropical cusps and is
  /// equivalent to the old `swe_houses` call.
  ///
  /// House system codes:
  /// - 'P' = Placidus
  /// - 'K' = Koch
  /// - 'O' = Porphyrius
  /// - 'R' = Regiomontanus
  /// - 'C' = Campanus
  /// - 'A' or 'E' = Equal (cusp 1 is Ascendant)
  /// - 'W' = Whole sign
  Map<String, List<double>>? calculateHouses({
    required double julianDay,
    required double latitude,
    required double longitude,
    String houseSystem = 'P', // Placidus by default
    int flags = 0,
  }) {
    if (houseSystem.length != 1) {
      throw ArgumentError.value(
        houseSystem,
        'houseSystem',
        'Expected a single Swiss Ephemeris house-system code',
      );
    }

    // Allocate memory for cusps (13 elements, index 0 unused, 1-12 are house cusps)
    final cuspsPtr = malloc<ffi.Double>(13);
    // Allocate memory for ascmc (10 elements: ascendant, MC, ARMC, vertex, etc.)
    final ascmcPtr = malloc<ffi.Double>(10);

    try {
      final returnCode = _swe_houses_ex(
        julianDay,
        flags,
        latitude,
        longitude,
        houseSystem.toUpperCase().codeUnitAt(0),
        cuspsPtr,
        ascmcPtr,
      );

      if (returnCode < 0) {
        return null;
      }

      // Extract cusps (indices 1-12, skip index 0)
      final cusps = List.generate(12, (i) => cuspsPtr[i + 1]);

      // Extract ascmc values
      // [0] = Ascendant, [1] = MC, [2] = ARMC, [3] = Vertex,
      // [4] = Equatorial ascendant, [5] = Co-ascendant (Koch), etc.
      final ascmc = List.generate(10, (i) => ascmcPtr[i]);

      return {
        'cusps': cusps,
        'ascmc': ascmc,
      };
    } finally {
      malloc.free(cuspsPtr);
      malloc.free(ascmcPtr);
    }
  }

  // ============== Eclipse Wrapper Methods ==============

  /// Eclipse type flags (return values from eclipse functions)
  static const int SE_ECL_CENTRAL = 1;
  static const int SE_ECL_NONCENTRAL = 2;
  static const int SE_ECL_TOTAL = 4;
  static const int SE_ECL_ANNULAR = 8;
  static const int SE_ECL_PARTIAL = 16;
  static const int SE_ECL_ANNULAR_TOTAL = 32;
  static const int SE_ECL_PENUMBRAL = 64;
  static const int SE_ECL_ALLTYPES_SOLAR = SE_ECL_CENTRAL |
      SE_ECL_NONCENTRAL |
      SE_ECL_TOTAL |
      SE_ECL_ANNULAR |
      SE_ECL_PARTIAL |
      SE_ECL_ANNULAR_TOTAL;
  static const int SE_ECL_ALLTYPES_LUNAR =
      SE_ECL_TOTAL | SE_ECL_PARTIAL | SE_ECL_PENUMBRAL;

  /// Find the next lunar eclipse after the given Julian day.
  ///
  /// Returns a map with:
  /// - 'type': Eclipse type flags (int)
  /// - 'times': Array of times [max eclipse, partial begin, partial end,
  ///   total begin, total end, penumbral begin, penumbral end, ...]
  ///
  /// Returns null on error.
  Map<String, dynamic>? findNextLunarEclipse({
    required double startJulianDay,
    int eclipseTypeFilter = 0, // 0 = any type
    bool backward = false,
  }) {
    final tretPtr = malloc<ffi.Double>(10);
    final errorBuffer = malloc<ffi.Char>(256);

    try {
      final eclipseType = _swe_lun_eclipse_when(
        startJulianDay,
        0, // ifl - use default ephemeris
        eclipseTypeFilter,
        tretPtr,
        backward ? 1 : 0,
        errorBuffer,
      );

      if (eclipseType < 0) {
        if (kDebugMode) {
          print(
              'Lunar eclipse error: ${errorBuffer.cast<Utf8>().toDartString()}');
        }
        return null;
      }

      return {
        'type': eclipseType,
        'times': List.generate(10, (i) => tretPtr[i]),
      };
    } finally {
      malloc.free(tretPtr);
      malloc.free(errorBuffer);
    }
  }

  /// Get details of a lunar eclipse at the given time for a specific location.
  ///
  /// Returns eclipse attributes including magnitude, phase durations, etc.
  Map<String, dynamic>? getLunarEclipseDetails({
    required double julianDay,
    required double longitude,
    required double latitude,
    double altitude = 0,
  }) {
    final geoposPtr = malloc<ffi.Double>(3);
    final attrPtr = malloc<ffi.Double>(20);
    final errorBuffer = malloc<ffi.Char>(256);

    try {
      geoposPtr[0] = longitude;
      geoposPtr[1] = latitude;
      geoposPtr[2] = altitude;

      final eclipseType = _swe_lun_eclipse_how(
        julianDay,
        0, // ifl
        geoposPtr,
        attrPtr,
        errorBuffer,
      );

      if (eclipseType < 0) {
        return null;
      }

      return {
        'type': eclipseType,
        'umbralMagnitude': attrPtr[0],
        'penumbralMagnitude': attrPtr[1],
        'attributes': List.generate(20, (i) => attrPtr[i]),
      };
    } finally {
      malloc.free(geoposPtr);
      malloc.free(attrPtr);
      malloc.free(errorBuffer);
    }
  }

  /// Find the next global solar eclipse after the given Julian day.
  Map<String, dynamic>? findNextSolarEclipseGlobal({
    required double startJulianDay,
    int eclipseTypeFilter = 0,
    bool backward = false,
  }) {
    final tretPtr = malloc<ffi.Double>(10);
    final errorBuffer = malloc<ffi.Char>(256);

    try {
      final eclipseType = _swe_sol_eclipse_when_glob(
        startJulianDay,
        0,
        eclipseTypeFilter,
        tretPtr,
        backward ? 1 : 0,
        errorBuffer,
      );

      if (eclipseType < 0) {
        return null;
      }

      return {
        'type': eclipseType,
        'times': List.generate(10, (i) => tretPtr[i]),
      };
    } finally {
      malloc.free(tretPtr);
      malloc.free(errorBuffer);
    }
  }

  /// Find the next solar eclipse visible at a specific location.
  Map<String, dynamic>? findNextSolarEclipseLocal({
    required double startJulianDay,
    required double longitude,
    required double latitude,
    double altitude = 0,
    bool backward = false,
  }) {
    final geoposPtr = malloc<ffi.Double>(3);
    final tretPtr = malloc<ffi.Double>(10);
    final attrPtr = malloc<ffi.Double>(20);
    final errorBuffer = malloc<ffi.Char>(256);

    try {
      geoposPtr[0] = longitude;
      geoposPtr[1] = latitude;
      geoposPtr[2] = altitude;

      final eclipseType = _swe_sol_eclipse_when_loc(
        startJulianDay,
        0,
        geoposPtr,
        tretPtr,
        attrPtr,
        backward ? 1 : 0,
        errorBuffer,
      );

      if (eclipseType < 0) {
        return null;
      }

      return {
        'type': eclipseType,
        'times': List.generate(10, (i) => tretPtr[i]),
        'solarDiameterCoverage': attrPtr[0],
        'magnitude': attrPtr[1],
        'azimuth': attrPtr[4],
        'altitude': attrPtr[5],
        'attributes': List.generate(20, (i) => attrPtr[i]),
      };
    } finally {
      malloc.free(geoposPtr);
      malloc.free(tretPtr);
      malloc.free(attrPtr);
      malloc.free(errorBuffer);
    }
  }

  /// Get the geographic location of a solar eclipse's maximum point.
  Map<String, dynamic>? getSolarEclipseLocation({
    required double julianDay,
  }) {
    final geoposPtr = malloc<ffi.Double>(3);
    final attrPtr = malloc<ffi.Double>(20);
    final errorBuffer = malloc<ffi.Char>(256);

    try {
      final eclipseType = _swe_sol_eclipse_where(
        julianDay,
        0,
        geoposPtr,
        attrPtr,
        errorBuffer,
      );

      if (eclipseType < 0) {
        return null;
      }

      return {
        'type': eclipseType,
        'longitude': geoposPtr[0],
        'latitude': geoposPtr[1],
        'attributes': List.generate(20, (i) => attrPtr[i]),
      };
    } finally {
      malloc.free(geoposPtr);
      malloc.free(attrPtr);
      malloc.free(errorBuffer);
    }
  }

  /// Find the next rise or set of a body.
  ///
  /// [startJulianDay] is a UT Julian day. For the Hindu convention pass
  /// [SE_BIT_HINDU_RISING] in [riseSetFlag] together with [SE_CALC_RISE] or
  /// [SE_CALC_SET]. The native function filters the ephemeris flags to its
  /// supported subset, so callers only need to select a backend.
  RiseTransResult riseTrans({
    required double startJulianDay,
    required int planetId,
    required int riseSetFlag,
    required double longitude,
    required double latitude,
    double altitudeMeters = 0,
    int ephemerisFlag = SEFLG_SWIEPH,
  }) {
    final geoposPtr = calloc<ffi.Double>(3);
    final tretPtr = calloc<ffi.Double>(1);
    final errorBuffer = calloc<ffi.Char>(256);

    try {
      geoposPtr[0] = longitude;
      geoposPtr[1] = latitude;
      geoposPtr[2] = altitudeMeters;

      final status = _swe_rise_trans(
        startJulianDay,
        planetId,
        ffi.nullptr,
        ephemerisFlag,
        riseSetFlag,
        geoposPtr,
        0,
        0,
        tretPtr,
        errorBuffer,
      );

      return RiseTransResult(
        status: status,
        julianDay: status == 0 ? tretPtr[0] : null,
        error: errorBuffer.cast<Utf8>().toDartString(),
      );
    } finally {
      calloc.free(geoposPtr);
      calloc.free(tretPtr);
      calloc.free(errorBuffer);
    }
  }

  /// Convert Julian day to calendar date.
  /// Returns map with 'year', 'month', 'day', 'hour'.
  Map<String, dynamic> julianDayToDate(double julianDay) {
    final yearPtr = malloc<ffi.Int32>();
    final monthPtr = malloc<ffi.Int32>();
    final dayPtr = malloc<ffi.Int32>();
    final hourPtr = malloc<ffi.Double>();

    try {
      _swe_revjul(
        julianDay,
        1, // Gregorian calendar
        yearPtr,
        monthPtr,
        dayPtr,
        hourPtr,
      );

      return {
        'year': yearPtr.value,
        'month': monthPtr.value,
        'day': dayPtr.value,
        'hour': hourPtr.value,
      };
    } finally {
      malloc.free(yearPtr);
      malloc.free(monthPtr);
      malloc.free(dayPtr);
      malloc.free(hourPtr);
    }
  }

  /// Helper to convert Julian day to DateTime.
  DateTime julianDayToDateTime(double julianDay) {
    final dateMap = julianDayToDate(julianDay);
    final hour = dateMap['hour'] as double;
    final hours = hour.floor();
    final minutes = ((hour - hours) * 60).floor();
    final seconds = (((hour - hours) * 60 - minutes) * 60).floor();

    return DateTime.utc(
      dateMap['year'] as int,
      dateMap['month'] as int,
      dateMap['day'] as int,
      hours,
      minutes,
      seconds,
    );
  }

  /// Convert a UT Julian day to a UTC [DateTime] without dropping the
  /// sub-second part.
  ///
  /// [julianDayToDateTime] floors to whole seconds, which is fine for display
  /// but loses precision when a value is fed back into another calculation.
  DateTime julianDayToUtcDateTime(double julianDay) {
    const unixEpochJulianDay = 2440587.5;
    final milliseconds =
        ((julianDay - unixEpochJulianDay) * Duration.millisecondsPerDay)
            .round();
    return DateTime.fromMillisecondsSinceEpoch(milliseconds, isUtc: true);
  }
}
