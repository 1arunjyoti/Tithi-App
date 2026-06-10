import 'dart:math';

/// Calculates sunrise and sunset times for a given date and location.
/// Uses the NOAA Solar Calculator algorithm for accurate results.
///
/// SMELL-4: The shared solar-geometry calculation has been extracted into a
/// single private [_computeSunTime] method. Both [calculateSunriseIST] and
/// [calculateSunsetIST] are thin wrappers that delegate to it, eliminating
/// ~90 lines of duplicated code.
class SunriseCalculator {
  /// Earth's orbital eccentricity (IERS 2010 value: 0.016708634).
  /// Extracted to a named constant to avoid repeating the raw literal four
  /// times inside the equation-of-time formula (SMELL-6).
  static const double _earthOrbitEccentricity = 0.016708634;

  /// Get sunrise for the device's local timezone.
  /// Previously fixed to Indian Standard Time (IST = UTC+5:30); now uses the
  /// device's actual timezone offset so users outside India get accurate times.
  static DateTime calculateSunriseIST({
    required DateTime date,
    required double latitude,
    required double longitude,
  }) =>
      _computeSunTime(
        date: date,
        latitude: latitude,
        longitude: longitude,
        isSunrise: true,
      );

  /// Get sunset for the device's local timezone.
  /// Previously fixed to IST; now uses the device's actual UTC offset.
  static DateTime calculateSunsetIST({
    required DateTime date,
    required double latitude,
    required double longitude,
  }) =>
      _computeSunTime(
        date: date,
        latitude: latitude,
        longitude: longitude,
        isSunrise: false,
      );

  // ---------------------------------------------------------------------------
  // Shared solar-geometry engine (SMELL-4 refactor)
  // ---------------------------------------------------------------------------

  /// Computes either sunrise ([isSunrise] = true) or sunset ([isSunrise] =
  /// false) for [date] at the given [latitude]/[longitude].
  ///
  /// All intermediate values are calculated once; the only difference between
  /// sunrise and sunset is whether the hour-angle is subtracted from or added
  /// to solar noon.
  static DateTime _computeSunTime({
    required DateTime date,
    required double latitude,
    required double longitude,
    required bool isSunrise,
  }) {
    // BUG-6: convert a UTC DateTime to local first so DST is handled correctly
    // (a UTC DateTime always reports timeZoneOffset == Duration.zero).
    final localDate = date.isUtc ? date.toLocal() : date;
    final latRad = latitude * pi / 180;

    // Julian day
    final jd = _julianDay(localDate.year, localDate.month, localDate.day);

    // Julian century
    final jc = (jd - 2451545) / 36525;

    // Geometric mean longitude of sun (degrees)
    var sunMeanLong = 280.46646 + jc * (36000.76983 + 0.0003032 * jc);
    while (sunMeanLong > 360) {
      sunMeanLong -= 360;
    }
    while (sunMeanLong < 0) {
      sunMeanLong += 360;
    }

    // Geometric mean anomaly of sun (degrees)
    final sunMeanAnom = 357.52911 + jc * (35999.05029 - 0.0001537 * jc);
    final sunMeanAnomRad = sunMeanAnom * pi / 180;

    // Equation of center
    final sunEqOfCtr =
        sin(sunMeanAnomRad) * (1.914602 - jc * (0.004817 + 0.000014 * jc)) +
        sin(2 * sunMeanAnomRad) * (0.019993 - 0.000101 * jc) +
        sin(3 * sunMeanAnomRad) * 0.000289;

    // Sun true longitude
    final sunTrueLong = sunMeanLong + sunEqOfCtr;

    // Obliquity of ecliptic
    final obliqCorr =
        23.439291 - jc * (0.0130042 - jc * (0.00000016 + 0.000000504 * jc));
    final obliqCorrRad = obliqCorr * pi / 180;

    // Sun declination
    final sunDec =
        asin(sin(obliqCorrRad) * sin(sunTrueLong * pi / 180)) * 180 / pi;
    final sunDecRad = sunDec * pi / 180;

    // Equation of time (minutes) — uses named eccentricity constant (SMELL-6)
    final varY = tan(obliqCorrRad / 2) * tan(obliqCorrRad / 2);
    final sunMeanLongRad = sunMeanLong * pi / 180;
    final eqOfTime =
        4 *
        (varY * sin(2 * sunMeanLongRad) -
            2 * _earthOrbitEccentricity * sin(sunMeanAnomRad) +
            4 *
                _earthOrbitEccentricity *
                varY *
                sin(sunMeanAnomRad) *
                cos(2 * sunMeanLongRad) -
            0.5 * varY * varY * sin(4 * sunMeanLongRad) -
            1.25 *
                _earthOrbitEccentricity *
                _earthOrbitEccentricity *
                sin(2 * sunMeanAnomRad)) *
        180 /
        pi;

    // Hour angle (degrees)
    const zenith = 90.833;
    const zenithRad = zenith * pi / 180;
    final haArg =
        cos(zenithRad) / (cos(latRad) * cos(sunDecRad)) -
        tan(latRad) * tan(sunDecRad);

    if (haArg > 1 || haArg < -1) {
      // Polar day / polar night — return a sensible default hour
      return DateTime(
        localDate.year,
        localDate.month,
        localDate.day,
        isSunrise ? 6 : 18,
      );
    }

    final hourAngle = acos(haArg) * 180 / pi;

    // Solar noon (fraction of day in UTC)
    final solarNoon = (720 - 4 * longitude - eqOfTime) / 1440;

    // Sunrise subtracts the hour angle; sunset adds it
    final eventUTC = isSunrise
        ? solarNoon - hourAngle * 4 / 1440
        : solarNoon + hourAngle * 4 / 1440;

    // Convert to local time using the target date's timezone offset.
    final localOffsetHours = localDate.timeZoneOffset.inMinutes / 60.0;
    final eventLocal = eventUTC + localOffsetHours / 24;

    final eventMinutes = (eventLocal * 24 * 60).round();
    final hours = (eventMinutes ~/ 60) % 24;
    final minutes = eventMinutes % 60;

    return DateTime(localDate.year, localDate.month, localDate.day, hours, minutes);
  }

  /// Calculate Julian Day Number
  static double _julianDay(int year, int month, int day) {
    if (month <= 2) {
      year -= 1;
      month += 12;
    }
    final a = (year / 100).floor();
    final b = 2 - a + (a / 4).floor();
    return (365.25 * (year + 4716)).floor() +
        (30.6001 * (month + 1)).floor() +
        day +
        b -
        1524.5;
  }
}
