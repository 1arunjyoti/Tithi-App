import 'dart:ffi' as ffi;
import 'dart:io';
import 'package:ffi/ffi.dart';

/// FFI bindings for Swiss Ephemeris C library.
///
/// This class provides low-level bindings to the Swiss Ephemeris shared library.
class SwissEphBindings {
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

  late final _swe_houses = _lib.lookupFunction<
      ffi.Int32 Function(
        ffi.Double,
        ffi.Double,
        ffi.Double,
        ffi.Int32,
        ffi.Pointer<ffi.Double>,
        ffi.Pointer<ffi.Double>,
      ),
      int Function(
        double,
        double,
        double,
        int,
        ffi.Pointer<ffi.Double>,
        ffi.Pointer<ffi.Double>,
      )>('swe_houses');

  SwissEphBindings() {
    _lib = _loadLibrary();
  }

  /// Loads the appropriate Swiss Ephemeris library for the platform.
  ffi.DynamicLibrary _loadLibrary() {
    // Try custom path first (from environment or development location)
    final customPath = Platform.environment['SWISSEPH_LIB_PATH'];
    if (customPath != null && customPath.isNotEmpty) {
      try {
        return ffi.DynamicLibrary.open(customPath);
      } catch (e) {
        print('Failed to load from custom path: $customPath');
      }
    }

    // Try development/local paths
    if (Platform.isMacOS) {
      final devPaths = [
        '/Users/sanjibacharya/Developer/jyotish/native/swisseph/swisseph-master/libswisseph.dylib',
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
  /// Returns a list of 6 doubles: [longitude, latitude, distance,
  /// longitudeSpeed, latitudeSpeed, distanceSpeed]
  ///
  /// Returns null if calculation fails, with error message in [errorBuffer].
  List<double>? calculateUT({
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

      return List.generate(6, (i) => resultPtr[i]);
    } finally {
      malloc.free(resultPtr);
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
  }) {
    // Allocate memory for cusps (13 elements, index 0 unused, 1-12 are house cusps)
    final cuspsPtr = malloc<ffi.Double>(13);
    // Allocate memory for ascmc (10 elements: ascendant, MC, ARMC, vertex, etc.)
    final ascmcPtr = malloc<ffi.Double>(10);

    try {
      final systemCode = houseSystem.codeUnitAt(0);

      final returnCode = _swe_houses(
        julianDay,
        latitude,
        longitude,
        systemCode,
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
}
