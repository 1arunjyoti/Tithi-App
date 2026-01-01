import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jyotish/jyotish.dart';
import '../models/eclipse.dart';

/// Provider for EclipseService
final eclipseServiceProvider = Provider<EclipseService>((ref) {
  return EclipseService();
});

/// Service for calculating and predicting eclipses
class EclipseService {
  EclipseService();

  /// Get Swiss Ephemeris bindings
  SwissEphBindings get _bindings {
    // Access bindings through jyotish initialization
    return SwissEphBindings();
  }

  /// Get upcoming eclipses (both solar and lunar)
  /// Returns eclipses sorted by date
  Future<List<Eclipse>> getUpcomingEclipses({
    int count = 10,
    double latitude = 28.6139,
    double longitude = 77.2090,
  }) async {
    final eclipses = <Eclipse>[];

    // Get current Julian day
    final now = DateTime.now().toUtc();
    final startJd = _dateTimeToJulianDay(now);

    // Find upcoming lunar eclipses
    var lunarJd = startJd;
    for (int i = 0; i < count ~/ 2 + 1; i++) {
      final lunarResult = _bindings.findNextLunarEclipse(
        startJulianDay: lunarJd,
      );

      if (lunarResult != null) {
        final eclipse = _parseLunarEclipse(lunarResult, latitude, longitude);
        if (eclipse != null) {
          eclipses.add(eclipse);
        }
        // Search for next eclipse after this one
        final times = lunarResult['times'] as List<double>;
        lunarJd = times[0] + 1; // Start search 1 day after max eclipse
      } else {
        break;
      }
    }

    // Find upcoming solar eclipses
    var solarJd = startJd;
    for (int i = 0; i < count ~/ 2 + 1; i++) {
      final solarResult = _bindings.findNextSolarEclipseGlobal(
        startJulianDay: solarJd,
      );

      if (solarResult != null) {
        final eclipse = await _parseSolarEclipse(
          solarResult,
          latitude,
          longitude,
        );
        if (eclipse != null) {
          eclipses.add(eclipse);
        }
        // Search for next eclipse after this one
        final times = solarResult['times'] as List<double>;
        solarJd = times[0] + 1;
      } else {
        break;
      }
    }

    // Sort by date
    eclipses.sort((a, b) => a.maxEclipseTime.compareTo(b.maxEclipseTime));

    // Return requested count
    return eclipses.take(count).toList();
  }

  /// Get detailed visibility for an eclipse at a specific location
  Future<Eclipse> getEclipseWithVisibility({
    required Eclipse eclipse,
    required double latitude,
    required double longitude,
  }) async {
    if (eclipse.type.isLunar) {
      // Lunar eclipses are visible from anywhere the Moon is above horizon
      final jd = _dateTimeToJulianDay(eclipse.maxEclipseTime);
      final details = _bindings.getLunarEclipseDetails(
        julianDay: jd,
        latitude: latitude,
        longitude: longitude,
      );

      if (details != null) {
        final umbralMag = details['umbralMagnitude'] as double;
        return eclipse.copyWithVisibility(
          visibleAtLocation:
              umbralMag > 0 || (details['penumbralMagnitude'] as double) > 0,
          localMagnitude: umbralMag,
        );
      }
    } else {
      // Solar eclipses need location-specific calculation
      final jd = _dateTimeToJulianDay(eclipse.maxEclipseTime);
      final localResult = _bindings.findNextSolarEclipseLocal(
        startJulianDay: jd - 1,
        latitude: latitude,
        longitude: longitude,
      );

      if (localResult != null) {
        final times = localResult['times'] as List<double>;
        final maxEclipseJd = times[0];

        // Check if times match (within 1 day tolerance)
        if ((maxEclipseJd - jd).abs() < 1.0) {
          return eclipse.copyWithVisibility(
            visibleAtLocation: true,
            localMagnitude: localResult['magnitude'] as double?,
            localAltitude: localResult['altitude'] as double?,
          );
        }
      }

      return eclipse.copyWithVisibility(visibleAtLocation: false);
    }

    return eclipse;
  }

  /// Parse lunar eclipse data from raw result
  Eclipse? _parseLunarEclipse(
    Map<String, dynamic> result,
    double latitude,
    double longitude,
  ) {
    final typeFlags = result['type'] as int;
    final times = result['times'] as List<double>;

    // Determine eclipse type from flags
    EclipseType type;
    if (typeFlags & SwissEphBindings.SE_ECL_TOTAL != 0) {
      type = EclipseType.lunarTotal;
    } else if (typeFlags & SwissEphBindings.SE_ECL_PARTIAL != 0) {
      type = EclipseType.lunarPartial;
    } else if (typeFlags & SwissEphBindings.SE_ECL_PENUMBRAL != 0) {
      type = EclipseType.lunarPenumbral;
    } else {
      return null; // Unknown type
    }

    // Times array indices for lunar eclipse:
    // [0] = maximum eclipse
    // [1] = partial phase begin
    // [2] = partial phase end
    // [3] = totality begin
    // [4] = totality end
    // [5] = penumbral begin
    // [6] = penumbral end

    final maxEclipseTime = _bindings.julianDayToDateTime(times[0]);

    // Get magnitude
    final details = _bindings.getLunarEclipseDetails(
      julianDay: times[0],
      latitude: latitude,
      longitude: longitude,
    );

    return Eclipse(
      type: type,
      maxEclipseTime: maxEclipseTime,
      partialStart: times[1] > 0
          ? _bindings.julianDayToDateTime(times[1])
          : null,
      partialEnd: times[2] > 0 ? _bindings.julianDayToDateTime(times[2]) : null,
      totalStart: times[3] > 0 ? _bindings.julianDayToDateTime(times[3]) : null,
      totalEnd: times[4] > 0 ? _bindings.julianDayToDateTime(times[4]) : null,
      penumbralStart: times[5] > 0
          ? _bindings.julianDayToDateTime(times[5])
          : null,
      penumbralEnd: times[6] > 0
          ? _bindings.julianDayToDateTime(times[6])
          : null,
      magnitude: details?['umbralMagnitude'] as double?,
      visibleAtLocation: true, // Lunar eclipses visible from half the Earth
    );
  }

  /// Parse solar eclipse data from raw result
  Future<Eclipse?> _parseSolarEclipse(
    Map<String, dynamic> result,
    double latitude,
    double longitude,
  ) async {
    final typeFlags = result['type'] as int;
    final times = result['times'] as List<double>;

    // Determine eclipse type from flags
    EclipseType type;
    if (typeFlags & SwissEphBindings.SE_ECL_TOTAL != 0) {
      type = EclipseType.solarTotal;
    } else if (typeFlags & SwissEphBindings.SE_ECL_ANNULAR != 0) {
      type = EclipseType.solarAnnular;
    } else if (typeFlags & SwissEphBindings.SE_ECL_ANNULAR_TOTAL != 0) {
      type = EclipseType.solarHybrid;
    } else if (typeFlags & SwissEphBindings.SE_ECL_PARTIAL != 0) {
      type = EclipseType.solarPartial;
    } else {
      return null;
    }

    // Get eclipse center location
    final location = _bindings.getSolarEclipseLocation(julianDay: times[0]);

    final maxEclipseTime = _bindings.julianDayToDateTime(times[0]);

    // Check local visibility
    final localResult = _bindings.findNextSolarEclipseLocal(
      startJulianDay: times[0] - 0.5,
      latitude: latitude,
      longitude: longitude,
    );

    bool visibleLocally = false;
    double? localMag;
    double? localAlt;

    if (localResult != null) {
      final localTimes = localResult['times'] as List<double>;
      if ((localTimes[0] - times[0]).abs() < 0.5) {
        visibleLocally = true;
        localMag = localResult['magnitude'] as double?;
        localAlt = localResult['altitude'] as double?;
      }
    }

    return Eclipse(
      type: type,
      maxEclipseTime: maxEclipseTime,
      partialStart: times[1] > 0
          ? _bindings.julianDayToDateTime(times[1])
          : null,
      partialEnd: times[2] > 0 ? _bindings.julianDayToDateTime(times[2]) : null,
      totalStart: times[3] > 0 ? _bindings.julianDayToDateTime(times[3]) : null,
      totalEnd: times[4] > 0 ? _bindings.julianDayToDateTime(times[4]) : null,
      magnitude: null, // Global magnitude not directly available
      centerLatitude: location?['latitude'] as double?,
      centerLongitude: location?['longitude'] as double?,
      visibleAtLocation: visibleLocally,
      localMagnitude: localMag,
      localAltitude: localAlt,
    );
  }

  /// Convert DateTime to Julian Day
  double _dateTimeToJulianDay(DateTime dt) {
    final utc = dt.toUtc();
    final hour = utc.hour + utc.minute / 60.0 + utc.second / 3600.0;
    return _bindings.julianDay(
      year: utc.year,
      month: utc.month,
      day: utc.day,
      hour: hour,
    );
  }
}
