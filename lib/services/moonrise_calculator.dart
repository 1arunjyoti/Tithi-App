import 'dart:math';

/// Calculates moonrise and moonset times for a given date and location.
///
/// Pure-Dart low-precision lunar theory (a truncated ELP-style series with
/// the half-dozen largest periodic terms, ~0.3° in ecliptic longitude).
/// That is ~1-3 minutes of rise/set error — ample for informational chips —
/// and keeps the tithi sheet synchronous with zero FFI cost on both native
/// and web (the Swiss Ephemeris path would need ~150 async calls per open).
///
/// Convention mirrors [SunriseCalculator]: the events attributed to [date]
/// are the crossings that fall inside that civil day (local
/// midnight-to-midnight). Roughly once a month there is no moonrise (or no
/// moonset) on a civil day — callers then get null and should fall back to
/// [findPreviousMoonrise] / [findNextMoonset] (the prevailing event, shown
/// with its date) rather than hiding the chip.
///
/// Rise/set threshold is the Moon's upper limb (+0.125°): ~16′ semi-diameter
/// + 34′ refraction − ~57′ mean parallax, per USNO.
class MoonriseCalculator {
  /// Altitude of the Moon's upper limb at rise/set, in degrees.
  static const double _riseSetAltitude = 0.125;

  /// Sampling step for bracketing crossings (10 min: the Moon's altitude
  /// swings ~2.5° per step near the horizon, so no crossing is skipped).
  static const Duration _sampleStep = Duration(minutes: 10);

  /// Get moonrise for the device's local timezone (null when the Moon does
  /// not rise on this civil day).
  static DateTime? calculateMoonrise({
    required DateTime date,
    required double latitude,
    required double longitude,
  }) => calculateMoonriseSet(
    date: date,
    latitude: latitude,
    longitude: longitude,
  ).moonrise;

  /// Get moonset for the device's local timezone (null when the Moon does
  /// not set on this civil day).
  static DateTime? calculateMoonset({
    required DateTime date,
    required double latitude,
    required double longitude,
  }) => calculateMoonriseSet(
    date: date,
    latitude: latitude,
    longitude: longitude,
  ).moonset;

  /// Both crossings in a single sampling pass. Either (rarely both) may be
  /// null on days with no rise/set.
  static ({DateTime? moonrise, DateTime? moonset}) calculateMoonriseSet({
    required DateTime date,
    required double latitude,
    required double longitude,
  }) {
    // BUG-6 (sunrise parity): a UTC DateTime reports a zero offset, so
    // convert to local first — the civil day being sampled is a local day.
    final localDate = date.isUtc ? date.toLocal() : date;
    final dayStart = DateTime(localDate.year, localDate.month, localDate.day);

    DateTime? moonrise;
    DateTime? moonset;

    DateTime prevTime = dayStart;
    double prevAlt =
        moonAltitude(prevTime, latitude, longitude) - _riseSetAltitude;
    final steps =
        const Duration(days: 1).inMinutes ~/ _sampleStep.inMinutes;
    for (var i = 1; i <= steps; i++) {
      final time = dayStart.add(Duration(minutes: i * _sampleStep.inMinutes));
      final alt = moonAltitude(time, latitude, longitude) - _riseSetAltitude;
      if (moonrise == null && prevAlt <= 0 && alt > 0) {
        moonrise = _refineCrossing(prevTime, time, latitude, longitude);
      } else if (moonset == null && prevAlt >= 0 && alt < 0) {
        moonset = _refineCrossing(prevTime, time, latitude, longitude);
      }
      if (moonrise != null && moonset != null) break;
      prevTime = time;
      prevAlt = alt;
    }
    return (moonrise: moonrise, moonset: moonset);
  }

  /// Most recent moonrise strictly before the civil day [date].
  ///
  /// Fallback for days with no moonrise (about once a month): the moon
  /// currently up rose the previous evening, so the sheet shows that rise
  /// — with its date — instead of hiding the chip. Returns null when no
  /// rise is found within [_fallbackSearchLimit] (polar regions).
  static DateTime? findPreviousMoonrise({
    required DateTime date,
    required double latitude,
    required double longitude,
  }) {
    final localDate = date.isUtc ? date.toLocal() : date;
    final dayStart = DateTime(localDate.year, localDate.month, localDate.day);
    return _scanFor(
      from: dayStart,
      direction: -1,
      rising: true,
      latitude: latitude,
      longitude: longitude,
    );
  }

  /// Next moonset at or after the end of the civil day [date].
  ///
  /// Mirror fallback for days with no moonset: the moon up today sets
  /// tomorrow morning, so the sheet shows that set — with its date —
  /// instead of hiding the chip. Returns null when no set is found within
  /// [_fallbackSearchLimit] (polar regions).
  static DateTime? findNextMoonset({
    required DateTime date,
    required double latitude,
    required double longitude,
  }) {
    final localDate = date.isUtc ? date.toLocal() : date;
    final dayStart = DateTime(localDate.year, localDate.month, localDate.day);
    return _scanFor(
      from: dayStart.add(const Duration(days: 1)),
      direction: 1,
      rising: false,
      latitude: latitude,
      longitude: longitude,
    );
  }

  /// How far the prev/next fallback searches (a rise/set cycle is ~24.8h,
  /// so the neighbouring event is always well inside this window outside
  /// polar regions).
  static const Duration _fallbackSearchLimit = Duration(hours: 48);

  /// Scans from [from] in [direction] (+1 forward, -1 backward) for the
  /// first rise ([rising]) or set crossing, up to [_fallbackSearchLimit].
  /// Returns the first crossing encountered in scan order — i.e. the
  /// nearest event in that direction — refined to ~1 minute, or null.
  static DateTime? _scanFor({
    required DateTime from,
    required int direction,
    required bool rising,
    required double latitude,
    required double longitude,
  }) {
    DateTime prevTime = from;
    double prevAlt =
        moonAltitude(prevTime, latitude, longitude) - _riseSetAltitude;
    final steps =
        _fallbackSearchLimit.inMinutes ~/ _sampleStep.inMinutes;
    for (var i = 1; i <= steps; i++) {
      final time = from.add(
        Duration(minutes: direction * i * _sampleStep.inMinutes),
      );
      final alt = moonAltitude(time, latitude, longitude) - _riseSetAltitude;
      // Chronological order (scan order is reversed when going backward).
      final DateTime earlier = direction > 0 ? prevTime : time;
      final DateTime later = direction > 0 ? time : prevTime;
      final double altEarlier = direction > 0 ? prevAlt : alt;
      final double altLater = direction > 0 ? alt : prevAlt;
      final crossed = rising
          ? (altEarlier <= 0 && altLater > 0)
          : (altEarlier >= 0 && altLater < 0);
      if (crossed) {
        return _refineCrossing(earlier, later, latitude, longitude);
      }
      prevTime = time;
      prevAlt = alt;
    }
    return null;
  }

  /// Bisects a bracketed crossing to ~1-minute precision. [lo]/[hi] straddle
  /// [_riseSetAltitude]; returns the [hi] side (first minute past the event).
  static DateTime _refineCrossing(
    DateTime lo,
    DateTime hi,
    double latitude,
    double longitude,
  ) {
    final loAbove =
        moonAltitude(lo, latitude, longitude) >= _riseSetAltitude;
    var guard = 0;
    while (hi.difference(lo).inMinutes > 1 && guard++ < 20) {
      final mid = lo.add(Duration(minutes: hi.difference(lo).inMinutes ~/ 2));
      final midAbove =
          moonAltitude(mid, latitude, longitude) >= _riseSetAltitude;
      if (midAbove == loAbove) {
        lo = mid;
      } else {
        hi = mid;
      }
    }
    return hi;
  }

  /// Apparent altitude of the Moon's center for [instant], in degrees.
  ///
  /// Public for unit tests (pins the lunar theory against reference values).
  static double moonAltitude(
    DateTime instant,
    double latitude,
    double longitude,
  ) {
    final jd = _julianDay(instant.toUtc());
    final d = jd - 2451545.0;

    double norm360(double x) {
      x %= 360;
      if (x < 0) x += 360;
      return x;
    }

    double rad(double deg) => deg * pi / 180;
    double deg(double r) => r * 180 / pi;

    // Fundamental arguments (degrees).
    final mSun = norm360(357.529 + 0.98560028 * d);
    final lMoon = norm360(218.316 + 13.176396 * d);
    final mMoon = norm360(134.963 + 13.064993 * d);
    final elong = norm360(297.850 + 12.190749 * d);
    final argLat = norm360(93.272 + 13.229350 * d);

    // Ecliptic longitude: mean + the largest periodic perturbations.
    final lon = norm360(
      lMoon +
          6.289 * sin(rad(mMoon)) +
          1.274 * sin(rad(2 * elong - mMoon)) +
          0.658 * sin(rad(2 * elong)) +
          0.214 * sin(rad(2 * mMoon)) -
          0.186 * sin(rad(mSun)) -
          0.114 * sin(rad(2 * argLat - 2 * elong)),
    );
    // Ecliptic latitude.
    final moonLat =
        5.128 * sin(rad(argLat)) +
        0.281 * sin(rad(mMoon + argLat)) +
        0.277 * sin(rad(mMoon - argLat)) +
        0.173 * sin(rad(2 * elong - argLat));

    // Ecliptic → equatorial (mean obliquity).
    final eps = 23.4393 - 3.563e-7 * d;
    final lonR = rad(lon);
    final latR = rad(moonLat);
    final epsR = rad(eps);
    final x = cos(lonR) * cos(latR);
    final y = sin(lonR) * cos(latR) * cos(epsR) - sin(latR) * sin(epsR);
    final z = sin(lonR) * cos(latR) * sin(epsR) + sin(latR) * cos(epsR);
    final ra = norm360(deg(atan2(y, x)));
    final dec = deg(asin(z.clamp(-1.0, 1.0)));

    // Local hour angle from GMST (Meeus low-precision).
    final t = d / 36525.0;
    final gmst = norm360(
      280.46061837 +
          360.98564736629 * d +
          0.000387933 * t * t -
          t * t * t / 38710000.0,
    );
    var hourAngle = norm360(gmst + longitude - ra);
    if (hourAngle > 180) hourAngle -= 360;

    final latR2 = rad(latitude);
    final decR = rad(dec);
    final sinAlt =
        sin(latR2) * sin(decR) +
        cos(latR2) * cos(decR) * cos(rad(hourAngle));
    return deg(asin(sinAlt.clamp(-1.0, 1.0)));
  }

  /// Julian Day Number for a UTC instant (fractional day included).
  static double _julianDay(DateTime utc) {
    var year = utc.year;
    var month = utc.month;
    final day =
        utc.day +
        (utc.hour + utc.minute / 60 + utc.second / 3600) / 24;
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
