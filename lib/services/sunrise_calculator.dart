import 'dart:math';

/// Calculates sunrise time for a given date and location.
/// Uses NOAA Solar Calculator algorithm for accurate results.
class SunriseCalculator {
  /// Calculate sunrise time for a given date and geographic coordinates.
  ///
  /// Returns DateTime of sunrise in local time.
  /// Based on NOAA Solar Calculator algorithm.
  static DateTime calculateSunrise({
    required DateTime date,
    required double latitude,
    required double longitude,
    double zenith = 90.833, // Official sunrise (accounting for refraction)
  }) {
    // Convert latitude to radians
    final latRad = latitude * pi / 180;

    // Day of year
    final n1 = (275 * date.month / 9).floor();
    final n2 = ((date.month + 9) / 12).floor();
    final n3 =
        (1 + ((date.year - 4 * (date.year / 4).floor() + 2) / 3).floor());
    final dayOfYear = n1 - (n2 * n3) + date.day - 30;

    // Approximate time of sunrise
    final lngHour = longitude / 15;
    final tRise = dayOfYear + ((6 - lngHour) / 24);

    // Sun's mean anomaly
    final mRise = (0.9856 * tRise) - 3.289;
    final mRiseRad = mRise * pi / 180;

    // Sun's true longitude
    var lRise =
        mRise + (1.916 * sin(mRiseRad)) + (0.020 * sin(2 * mRiseRad)) + 282.634;
    // Normalize to 0-360
    while (lRise < 0) {
      lRise += 360;
    }
    while (lRise >= 360) {
      lRise -= 360;
    }
    final lRiseRad = lRise * pi / 180;

    // Right ascension
    var raRise = atan(0.91764 * tan(lRiseRad)) * 180 / pi;
    // Normalize to same quadrant as L
    final lQuadrant = (lRise / 90).floor() * 90;
    final raQuadrant = (raRise / 90).floor() * 90;
    raRise = raRise + (lQuadrant - raQuadrant);
    // Convert to hours
    raRise = raRise / 15;

    // Sun's declination
    final sinDec = 0.39782 * sin(lRiseRad);
    final cosDec = cos(asin(sinDec));

    // Hour angle for sunrise
    final zenithRad = zenith * pi / 180;
    final cosHRise =
        (cos(zenithRad) - (sinDec * sin(latRad))) / (cosDec * cos(latRad));

    // Check if sun never rises or sets at this location on this date
    if (cosHRise > 1) {
      // Sun never rises (polar night) - return early morning
      return DateTime(date.year, date.month, date.day, 6, 0);
    }
    if (cosHRise < -1) {
      // Sun never sets (midnight sun) - return early morning
      return DateTime(date.year, date.month, date.day, 6, 0);
    }

    // Hour angle for sunrise
    var hRise = (acos(cosHRise) * 180 / pi); // In degrees
    hRise = 360 - hRise; // Sunrise is before solar noon
    hRise = hRise / 15; // Convert to hours

    // Local mean time of sunrise
    final tLocalRise = hRise + raRise - (0.06571 * tRise) - 6.622;

    // Adjust to UTC
    var utRise = tLocalRise - lngHour;
    // Normalize to 0-24
    while (utRise < 0) {
      utRise += 24;
    }
    while (utRise >= 24) {
      utRise -= 24;
    }

    // Convert to local time (assuming IST = UTC+5:30 for India)
    // For accurate conversion, we should use the actual timezone offset
    // For now, calculate based on longitude (approximate local solar time)
    final localOffset = longitude / 15; // Hours offset from UTC
    var localRise = utRise + localOffset;
    while (localRise < 0) {
      localRise += 24;
    }
    while (localRise >= 24) {
      localRise -= 24;
    }

    // Convert decimal hours to hours and minutes
    final hours = localRise.floor();
    final minutes = ((localRise - hours) * 60).round();

    return DateTime(date.year, date.month, date.day, hours, minutes);
  }

  /// Calculate sunset time for a given date and geographic coordinates.
  static DateTime calculateSunset({
    required DateTime date,
    required double latitude,
    required double longitude,
    double zenith = 90.833,
  }) {
    // Convert latitude to radians
    final latRad = latitude * pi / 180;

    // Day of year
    final n1 = (275 * date.month / 9).floor();
    final n2 = ((date.month + 9) / 12).floor();
    final n3 =
        (1 + ((date.year - 4 * (date.year / 4).floor() + 2) / 3).floor());
    final dayOfYear = n1 - (n2 * n3) + date.day - 30;

    // Approximate time of sunset
    final lngHour = longitude / 15;
    final tSet = dayOfYear + ((18 - lngHour) / 24);

    // Sun's mean anomaly
    final mSet = (0.9856 * tSet) - 3.289;
    final mSetRad = mSet * pi / 180;

    // Sun's true longitude
    var lSet =
        mSet + (1.916 * sin(mSetRad)) + (0.020 * sin(2 * mSetRad)) + 282.634;
    // Normalize to 0-360
    while (lSet < 0) {
      lSet += 360;
    }
    while (lSet >= 360) {
      lSet -= 360;
    }
    final lSetRad = lSet * pi / 180;

    // Right ascension
    var raSet = atan(0.91764 * tan(lSetRad)) * 180 / pi;
    // Normalize to same quadrant as L
    final lQuadrant = (lSet / 90).floor() * 90;
    final raQuadrant = (raSet / 90).floor() * 90;
    raSet = raSet + (lQuadrant - raQuadrant);
    // Convert to hours
    raSet = raSet / 15;

    // Sun's declination
    final sinDec = 0.39782 * sin(lSetRad);
    final cosDec = cos(asin(sinDec));

    // Hour angle for sunset
    final zenithRad = zenith * pi / 180;
    final cosHSet =
        (cos(zenithRad) - (sinDec * sin(latRad))) / (cosDec * cos(latRad));

    if (cosHSet > 1) {
      return DateTime(
        date.year,
        date.month,
        date.day,
        18,
        0,
      ); // Sun never rises
    }
    if (cosHSet < -1) {
      return DateTime(date.year, date.month, date.day, 18, 0); // Sun never sets
    }

    // Hour angle for sunset
    var hSet = (acos(cosHSet) * 180 / pi); // In degrees
    hSet = hSet / 15; // Convert to hours

    // Local mean time of sunset
    final tLocalSet = hSet + raSet - (0.06571 * tSet) - 6.622;

    // Adjust to UTC
    var utSet = tLocalSet - lngHour;
    // Normalize to 0-24
    while (utSet < 0) {
      utSet += 24;
    }
    while (utSet >= 24) {
      utSet -= 24;
    }

    // Convert to local time
    final localOffset = longitude / 15;
    var localSet = utSet + localOffset;
    while (localSet < 0) {
      localSet += 24;
    }
    while (localSet >= 24) {
      localSet -= 24;
    }

    final hours = localSet.floor();
    final minutes = ((localSet - hours) * 60).round();

    return DateTime(date.year, date.month, date.day, hours, minutes);
  }

  /// Get sunrise for Indian Standard Time (IST)
  /// Uses fixed offset of UTC+5:30
  static DateTime calculateSunriseIST({
    required DateTime date,
    required double latitude,
    required double longitude,
  }) {
    // Calculate sunrise using the local mean time method
    final latRad = latitude * pi / 180;

    // Julian day
    final jd = _julianDay(date.year, date.month, date.day);

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

    // Equation of time (minutes)
    final varY = tan(obliqCorrRad / 2) * tan(obliqCorrRad / 2);
    final sunMeanLongRad = sunMeanLong * pi / 180;
    final eqOfTime =
        4 *
        (varY * sin(2 * sunMeanLongRad) -
            2 * 0.016708634 * sin(sunMeanAnomRad) +
            4 *
                0.016708634 *
                varY *
                sin(sunMeanAnomRad) *
                cos(2 * sunMeanLongRad) -
            0.5 * varY * varY * sin(4 * sunMeanLongRad) -
            1.25 * 0.016708634 * 0.016708634 * sin(2 * sunMeanAnomRad)) *
        180 /
        pi;

    // Hour angle at sunrise (degrees)
    const zenith = 90.833;
    final zenithRad = zenith * pi / 180;
    final haArg =
        cos(zenithRad) / (cos(latRad) * cos(sunDecRad)) -
        tan(latRad) * tan(sunDecRad);

    if (haArg > 1 || haArg < -1) {
      // Polar day/night - return 6 AM
      return DateTime(date.year, date.month, date.day, 6, 0);
    }

    final haSunrise = acos(haArg) * 180 / pi;

    // Solar noon (LST)
    final solarNoon = (720 - 4 * longitude - eqOfTime) / 1440;

    // Sunrise time (fraction of day in UTC)
    final sunriseUTC = solarNoon - haSunrise * 4 / 1440;

    // Convert to IST (UTC + 5:30)
    final sunriseIST = sunriseUTC + 5.5 / 24;

    // Convert to hours and minutes
    final sunriseMinutes = (sunriseIST * 24 * 60).round();
    final hours = (sunriseMinutes ~/ 60) % 24;
    final minutes = sunriseMinutes % 60;

    return DateTime(date.year, date.month, date.day, hours, minutes);
  }

  /// Get sunset for Indian Standard Time (IST)
  static DateTime calculateSunsetIST({
    required DateTime date,
    required double latitude,
    required double longitude,
  }) {
    final latRad = latitude * pi / 180;
    final jd = _julianDay(date.year, date.month, date.day);
    final jc = (jd - 2451545) / 36525;

    // Geometric mean longitude
    var sunMeanLong = 280.46646 + jc * (36000.76983 + 0.0003032 * jc);
    while (sunMeanLong > 360) {
      sunMeanLong -= 360;
    }
    while (sunMeanLong < 0) {
      sunMeanLong += 360;
    }

    // Mean anomaly
    final sunMeanAnom = 357.52911 + jc * (35999.05029 - 0.0001537 * jc);
    final sunMeanAnomRad = sunMeanAnom * pi / 180;

    // Equation of center
    final sunEqOfCtr =
        sin(sunMeanAnomRad) * (1.914602 - jc * (0.004817 + 0.000014 * jc)) +
        sin(2 * sunMeanAnomRad) * (0.019993 - 0.000101 * jc) +
        sin(3 * sunMeanAnomRad) * 0.000289;

    final sunTrueLong = sunMeanLong + sunEqOfCtr;

    // Obliquity
    final obliqCorr =
        23.439291 - jc * (0.0130042 - jc * (0.00000016 + 0.000000504 * jc));
    final obliqCorrRad = obliqCorr * pi / 180;

    // Declination
    final sunDec =
        asin(sin(obliqCorrRad) * sin(sunTrueLong * pi / 180)) * 180 / pi;
    final sunDecRad = sunDec * pi / 180;

    // Equation of time
    final varY = tan(obliqCorrRad / 2) * tan(obliqCorrRad / 2);
    final sunMeanLongRad = sunMeanLong * pi / 180;
    final eqOfTime =
        4 *
        (varY * sin(2 * sunMeanLongRad) -
            2 * 0.016708634 * sin(sunMeanAnomRad) +
            4 *
                0.016708634 *
                varY *
                sin(sunMeanAnomRad) *
                cos(2 * sunMeanLongRad) -
            0.5 * varY * varY * sin(4 * sunMeanLongRad) -
            1.25 * 0.016708634 * 0.016708634 * sin(2 * sunMeanAnomRad)) *
        180 /
        pi;

    // Hour angle
    const zenith = 90.833;
    final zenithRad = zenith * pi / 180;
    final haArg =
        cos(zenithRad) / (cos(latRad) * cos(sunDecRad)) -
        tan(latRad) * tan(sunDecRad);

    if (haArg > 1 || haArg < -1) {
      return DateTime(
        date.year,
        date.month,
        date.day,
        18,
        0,
      ); // Polar day/night
    }

    final haSunset = acos(haArg) * 180 / pi;

    // Solar noon
    final solarNoon = (720 - 4 * longitude - eqOfTime) / 1440;

    // Sunset time (Add hour angle instead of subtract)
    final sunsetUTC = solarNoon + haSunset * 4 / 1440;

    final sunsetIST = sunsetUTC + 5.5 / 24;

    final sunsetMinutes = (sunsetIST * 24 * 60).round();
    final hours = (sunsetMinutes ~/ 60) % 24;
    final minutes = sunsetMinutes % 60;

    return DateTime(date.year, date.month, date.day, hours, minutes);
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
