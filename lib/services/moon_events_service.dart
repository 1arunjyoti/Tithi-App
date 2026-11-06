import 'package:flutter/foundation.dart';
import 'package:jyotish/jyotish.dart';
import 'package:timezone/timezone.dart' as tz;

import '../core/location/timezone_resolver.dart';
import '../models/panchang_profile.dart';
import 'moonrise_calculator.dart';

// Phase 5: the lunar counterpart of the solar-events seam.
//
// Moonrise decides real observances - Karva Chauth's puja and paran both wait
// for it - so the instant must not come from a truncated lunar series that is
// 1-3 minutes off. `swe_rise_trans()` is a single synchronous FFI call, so the
// native path costs less than the ~150-sample pure-Dart scan it replaces; the
// old approximation was never a latency requirement.
//
// The lunar convention is deliberately NOT `SE_BIT_HINDU_RISING`. That bit
// combines disc centre, no refraction, geocentric position and "ignore
// ecliptic latitude" - the last two are wrong for the Moon, whose parallax
// (~57') and 5.1-degree orbital inclination dominate its rise time. Rise/set
// here is topocentric with the true ecliptic latitude, and the limb and
// refraction policy comes from [PanchangProfile] instead of being hardcoded.

/// Strategy boundary for lunar rise/set.
///
/// Both methods return null when the event does not occur on the requested
/// civil day - about once a month for the Moon, and all day at high latitudes.
/// Callers keep their existing "prevailing event" fallbacks
/// ([findPreviousRise] / [findNextSet]) rather than hiding the event.
abstract interface class MoonEventCalculator {
  /// True when this calculator uses the native Swiss Ephemeris backend.
  bool get isNative => false;

  /// Moonrise on the civil day of [date], or null when the Moon does not rise.
  DateTime? rise({
    required DateTime date,
    required double latitude,
    required double longitude,
    double altitudeMeters = 0,
    String? timezoneId,
  });

  /// Moonset on the civil day of [date], or null when the Moon does not set.
  DateTime? set({
    required DateTime date,
    required double latitude,
    required double longitude,
    double altitudeMeters = 0,
    String? timezoneId,
  });
}

/// Swiss Ephemeris implementation using `swe_rise_trans()`.
///
/// `swe_rise_trans` always searches forward, so a body that never rises on the
/// requested day returns the *next* day's rise instead of failing. The result
/// is therefore discarded unless it lands on the same civil day; that check is
/// what preserves the "no moonrise today" contract the observances rely on.
class SwissMoonEventCalculator implements MoonEventCalculator {
  SwissMoonEventCalculator({
    required this.bindings,
    this.profile = PanchangProfile.standard,
  });

  final SwissEphBindings bindings;

  /// Supplies the lunar limb and refraction policy.
  final PanchangProfile profile;

  @override
  bool get isNative => true;

  @override
  DateTime? rise({
    required DateTime date,
    required double latitude,
    required double longitude,
    double altitudeMeters = 0,
    String? timezoneId,
  }) => _calculate(
    date: date,
    latitude: latitude,
    longitude: longitude,
    altitudeMeters: altitudeMeters,
    timezoneId: timezoneId,
    riseSetFlag: SwissEphBindings.SE_CALC_RISE,
  );

  @override
  DateTime? set({
    required DateTime date,
    required double latitude,
    required double longitude,
    double altitudeMeters = 0,
    String? timezoneId,
  }) => _calculate(
    date: date,
    latitude: latitude,
    longitude: longitude,
    altitudeMeters: altitudeMeters,
    timezoneId: timezoneId,
    riseSetFlag: SwissEphBindings.SE_CALC_SET,
  );

  /// Limb and refraction bits for [profile].
  ///
  /// `SE_BIT_GEOCTR_NO_ECL_LAT` is never set: it would drop the Moon's
  /// ecliptic latitude and its parallax, which together move a rise by up to
  /// an hour.
  int get riseSetBits {
    var bits = switch (profile.lunarLimb) {
      LunarLimb.upperLimb => 0,
      LunarLimb.center => SwissEphBindings.SE_BIT_DISC_CENTER,
      LunarLimb.lowerLimb => SwissEphBindings.SE_BIT_DISC_BOTTOM,
    };
    if (profile.lunarRefraction == LunarRefraction.none) {
      bits |= SwissEphBindings.SE_BIT_NO_REFRACTION;
    }
    return bits;
  }

  DateTime? _calculate({
    required DateTime date,
    required double latitude,
    required double longitude,
    required double altitudeMeters,
    required String? timezoneId,
    required int riseSetFlag,
  }) {
    final location = _locationFor(timezoneId, date);
    final wallDate = _wallDate(date, location);
    final midnight = location == null
        ? DateTime(wallDate.year, wallDate.month, wallDate.day)
        : tz.TZDateTime(location, wallDate.year, wallDate.month, wallDate.day);

    final result = SwissEphBindings.withNativeLock(
      () => bindings.riseTrans(
        startJulianDay: _julianDayUtc(midnight.toUtc()),
        planetId: SwissEphConstants.moon,
        // Apparent position (no SEFLG_TRUEPOS): a rise/set is a phenomenon of
        // the observed Moon, so light-time and nutation belong in the answer.
        riseSetFlag: riseSetFlag | riseSetBits,
        longitude: longitude,
        latitude: latitude,
        altitudeMeters: _normalizedAltitude(altitudeMeters),
      ),
    );

    // -2 is the legitimate "no rise/set on this day" answer, not a failure.
    if (result.isUnavailable) return null;
    if (!result.isSuccess) {
      throw StateError(
        'swe_rise_trans failed for the Moon: '
                'status ${result.status} ${result.error ?? ''}'
            .trim(),
      );
    }

    final utc = bindings.julianDayToUtcDateTime(result.julianDay!);
    final event = location == null ? utc.toLocal() : tz.TZDateTime.from(utc, location);

    // Forward search: an event on the following day is not this day's event.
    if (event.year != midnight.year ||
        event.month != midnight.month ||
        event.day != midnight.day) {
      return null;
    }
    return event;
  }

  static double _normalizedAltitude(double altitudeMeters) {
    if (!altitudeMeters.isFinite) return 0;
    return altitudeMeters.clamp(-500.0, 25000.0).toDouble();
  }

  static tz.Location? _locationFor(String? timezoneId, DateTime date) {
    final raw = timezoneId?.trim();
    if (raw != null && raw.isNotEmpty) {
      final canonical = canonicalTimezoneId(raw);
      if (canonical.isNotEmpty) {
        try {
          return tz.getLocation(canonical);
        } catch (_) {
          // Timezone data may not be initialized in a small unit test; fall
          // through to the zone carried by the date, then to device local.
        }
      }
    }
    if (date is tz.TZDateTime) return date.location;
    return null;
  }

  static DateTime _wallDate(DateTime date, tz.Location? location) {
    if (date is tz.TZDateTime) return date;
    if (location == null) return date.isUtc ? date.toLocal() : date;
    if (date.isUtc) return tz.TZDateTime.from(date, location);
    return tz.TZDateTime(
      location,
      date.year,
      date.month,
      date.day,
      date.hour,
      date.minute,
      date.second,
      date.millisecond,
      date.microsecond,
    );
  }

  static double _julianDayUtc(DateTime utc) {
    const unixEpochJulianDay = 2440587.5;
    return unixEpochJulianDay +
        utc.millisecondsSinceEpoch / Duration.millisecondsPerDay;
  }
}

/// Pure-Dart fallback over [MoonriseCalculator].
///
/// Labelled fallback for platforms without the native library and the parity
/// reference for the seam. It must not be presented as the native result: the
/// truncated lunar series is 1-3 minutes off, which is enough to move a
/// moonrise observance across a tithi boundary.
class ApproximateMoonEventCalculator implements MoonEventCalculator {
  const ApproximateMoonEventCalculator();

  @override
  bool get isNative => false;

  @override
  DateTime? rise({
    required DateTime date,
    required double latitude,
    required double longitude,
    double altitudeMeters = 0,
    String? timezoneId,
  }) => MoonriseCalculator.calculateMoonrise(
    date: date,
    latitude: latitude,
    longitude: longitude,
  );

  @override
  DateTime? set({
    required DateTime date,
    required double latitude,
    required double longitude,
    double altitudeMeters = 0,
    String? timezoneId,
  }) => MoonriseCalculator.calculateMoonset(
    date: date,
    latitude: latitude,
    longitude: longitude,
  );
}

/// The day's lunar anchors, with "does not occur" represented as null.
class MoonEvents {
  const MoonEvents({this.moonrise, this.moonset});

  final DateTime? moonrise;
  final DateTime? moonset;

  @override
  String toString() =>
      'MoonEvents(moonrise: $moonrise, moonset: $moonset)';
}

/// Resolves moonrise/moonset for a place and civil day.
///
/// Mirrors [SolarEventsService]: a strategy seam, a labelled fallback, a
/// published place zone for callers that only pass coordinates, and a bounded
/// cache. Unlike the solar service it returns null instead of throwing, because
/// a missing lunar event is a normal monthly occurrence that observances
/// already handle.
class MoonEventsService {
  MoonEventsService({
    MoonEventCalculator? calculator,
    PanchangProfile profile = PanchangProfile.standard,
  }) : _calculator = calculator ?? const ApproximateMoonEventCalculator(),
       _profile = profile;

  MoonEventCalculator _calculator;
  PanchangProfile _profile;

  /// Why the native calculator could not be installed, or null when it was.
  Object? _nativeSetupError;

  /// IANA zone of the selected place, published by the location layer.
  String? _placeTimezoneId;

  final Map<String, DateTime?> _cache = <String, DateTime?>{};

  static const int _maxCacheEntries = 4096;

  /// True once the native Swiss Ephemeris calculator has been installed.
  bool get usesNativeCalculator => _calculator.isNative;

  /// Why the native calculator could not be installed, or null when it was.
  ///
  /// Callers that must not run on the approximation read this instead of
  /// treating [usesNativeCalculator] == false as a normal state.
  Object? get nativeSetupError => _nativeSetupError;

  /// Lunar limb/refraction policy currently in force.
  PanchangProfile get profile => _profile;

  /// IANA zone used when a caller does not supply one; null means device zone.
  String? get placeTimezoneId => _placeTimezoneId;

  /// Publishes the selected place's zone for callers that only pass lat/lon.
  ///
  /// Changing the zone clears the cache: every cached instant was keyed by the
  /// previous zone, so the wall dates no longer match.
  void setPlaceTimezone(String? timezoneId) {
    final canonical = canonicalTimezoneId(timezoneId ?? '');
    final next = canonical.isEmpty ? null : canonical;
    if (next == _placeTimezoneId) return;
    _placeTimezoneId = next;
    clearCache();
  }

  /// Both lunar crossings for the civil day of [date].
  MoonEvents forDate({
    required DateTime date,
    required double latitude,
    required double longitude,
    double altitudeMeters = 0,
    String? timezoneId,
  }) => MoonEvents(
    moonrise: _resolve(
      _MoonEventKind.rise,
      date: date,
      latitude: latitude,
      longitude: longitude,
      altitudeMeters: altitudeMeters,
      timezoneId: timezoneId,
    ),
    moonset: _resolve(
      _MoonEventKind.set,
      date: date,
      latitude: latitude,
      longitude: longitude,
      altitudeMeters: altitudeMeters,
      timezoneId: timezoneId,
    ),
  );

  /// Moonrise on the civil day of [date], or null when the Moon does not rise.
  DateTime? moonrise({
    required DateTime date,
    required double latitude,
    required double longitude,
    double altitudeMeters = 0,
    String? timezoneId,
  }) => _resolve(
    _MoonEventKind.rise,
    date: date,
    latitude: latitude,
    longitude: longitude,
    altitudeMeters: altitudeMeters,
    timezoneId: timezoneId,
  );

  /// Moonset on the civil day of [date], or null when the Moon does not set.
  DateTime? moonset({
    required DateTime date,
    required double latitude,
    required double longitude,
    double altitudeMeters = 0,
    String? timezoneId,
  }) => _resolve(
    _MoonEventKind.set,
    date: date,
    latitude: latitude,
    longitude: longitude,
    altitudeMeters: altitudeMeters,
    timezoneId: timezoneId,
  );

  /// Most recent moonrise strictly before the civil day of [date].
  ///
  /// Fallback for days with no moonrise (about once a month): the Moon up
  /// today rose the previous evening. Native searches only run forward, so this
  /// walks forward from the far edge of the window and keeps the last rise that
  /// still precedes the day. Returns null when nothing is found within
  /// [kMoonFallbackSearchLimit] (polar regions).
  DateTime? findPreviousRise({
    required DateTime date,
    required double latitude,
    required double longitude,
    double altitudeMeters = 0,
    String? timezoneId,
  }) => _scanFor(
    date: date,
    latitude: latitude,
    longitude: longitude,
    altitudeMeters: altitudeMeters,
    timezoneId: timezoneId,
    rising: true,
    direction: -1,
  );

  /// Next moonset at or after the end of the civil day of [date].
  ///
  /// Mirror fallback for days with no moonset: the Moon up today sets the
  /// following morning. Returns null when nothing is found within
  /// [kMoonFallbackSearchLimit] (polar regions).
  DateTime? findNextSet({
    required DateTime date,
    required double latitude,
    required double longitude,
    double altitudeMeters = 0,
    String? timezoneId,
  }) => _scanFor(
    date: date,
    latitude: latitude,
    longitude: longitude,
    altitudeMeters: altitudeMeters,
    timezoneId: timezoneId,
    rising: false,
    direction: 1,
  );

  /// Installs the native Swiss Ephemeris calculator.
  ///
  /// [PanchangService.init] calls this once the bundled ephemeris files exist.
  /// Failure is non-fatal here so the service stays usable with its labelled
  /// approximation; the error is kept in [nativeSetupError] and
  /// `ensureNativeEngineInstalled` turns it into a startup failure on the
  /// platforms that ship the native engine.
  void configureSwiss({
    required String ephemerisPath,
    PanchangProfile profile = PanchangProfile.standard,
    SwissEphBindings? bindings,
  }) {
    try {
      final native = bindings ?? SwissEphBindings();
      SwissEphBindings.withNativeLock(
        () => native.setEphemerisPath(ephemerisPath),
      );
      _calculator = SwissMoonEventCalculator(
        bindings: native,
        profile: profile,
      );
      _profile = profile;
      _nativeSetupError = null;
      clearCache();
    } catch (error) {
      if (kDebugMode) {
        debugPrint('MoonEventsService: native setup failed: $error');
      }
      _nativeSetupError = error;
      _calculator = const ApproximateMoonEventCalculator();
      clearCache();
    }
  }

  /// Drops every cached event.
  void clearCache() => _cache.clear();

  @visibleForTesting
  int get debugCacheSize => _cache.length;

  DateTime? _resolve(
    _MoonEventKind kind, {
    required DateTime date,
    required double latitude,
    required double longitude,
    required double altitudeMeters,
    required String? timezoneId,
  }) {
    final effectiveTimezoneId = _effectiveTimezoneId(timezoneId);
    final key = [
      kind.name,
      date.year,
      date.month,
      date.day,
      latitude.toStringAsFixed(4),
      longitude.toStringAsFixed(4),
      altitudeMeters.round(),
      effectiveTimezoneId ?? 'device',
      // A limb/refraction change must not serve a value computed under the
      // previous policy.
      _profile.lunarLimb.name,
      _profile.lunarRefraction.name,
    ].join('|');

    if (_cache.containsKey(key)) return _cache[key];

    final value = switch (kind) {
      _MoonEventKind.rise => _calculator.rise(
        date: date,
        latitude: latitude,
        longitude: longitude,
        altitudeMeters: altitudeMeters,
        timezoneId: effectiveTimezoneId,
      ),
      _MoonEventKind.set => _calculator.set(
        date: date,
        latitude: latitude,
        longitude: longitude,
        altitudeMeters: altitudeMeters,
        timezoneId: effectiveTimezoneId,
      ),
    };

    if (_cache.length >= _maxCacheEntries) {
      _cache.remove(_cache.keys.first);
    }
    _cache[key] = value;
    return value;
  }

  /// Walks [kMoonFallbackSearchLimit] in [direction] for the prevailing event.
  ///
  /// The native calculator only answers "the next event after [start]", so a
  /// backward search starts at the far edge of the window and keeps the last
  /// event that still precedes the day. Both directions therefore use the same
  /// forward primitive.
  DateTime? _scanFor({
    required DateTime date,
    required double latitude,
    required double longitude,
    required double altitudeMeters,
    required String? timezoneId,
    required bool rising,
    required int direction,
  }) {
    final wallDate = date.isUtc ? date.toLocal() : date;
    final dayStart = DateTime(wallDate.year, wallDate.month, wallDate.day);

    if (direction > 0) {
      // Forward: the first event after the day ends is the prevailing one.
      var cursor = dayStart.add(const Duration(days: 1));
      final limit = cursor.add(kMoonFallbackSearchLimit);
      while (cursor.isBefore(limit)) {
        final event = _eventAt(cursor, rising, latitude, longitude,
            altitudeMeters, timezoneId);
        if (event != null) return event;
        // The native search already skipped a day with no event; step a whole
        // day so a polar window terminates.
        cursor = cursor.add(const Duration(days: 1));
      }
      return null;
    }

    // Backward: sweep from the far edge and keep the last event before the day.
    DateTime? latest;
    var cursor = dayStart.subtract(kMoonFallbackSearchLimit);
    while (cursor.isBefore(dayStart)) {
      final event = _eventAt(cursor, rising, latitude, longitude,
          altitudeMeters, timezoneId);
      if (event != null) {
        if (!event.isBefore(dayStart)) break;
        latest = event;
      }
      cursor = cursor.add(const Duration(days: 1));
    }
    return latest;
  }

  /// The calculator's event for the civil day containing [instant].
  DateTime? _eventAt(
    DateTime instant,
    bool rising,
    double latitude,
    double longitude,
    double altitudeMeters,
    String? timezoneId,
  ) => rising
      ? moonrise(
          date: instant,
          latitude: latitude,
          longitude: longitude,
          altitudeMeters: altitudeMeters,
          timezoneId: timezoneId,
        )
      : moonset(
          date: instant,
          latitude: latitude,
          longitude: longitude,
          altitudeMeters: altitudeMeters,
          timezoneId: timezoneId,
        );

  String? _effectiveTimezoneId(String? timezoneId) {
    final raw = timezoneId?.trim();
    if (raw != null && raw.isNotEmpty) return raw;
    return _placeTimezoneId;
  }
}

/// How far the prev/next fallback searches.
///
/// A lunar rise/set cycle is ~24.8 h, so the neighbouring event is always well
/// inside this window outside polar regions, where nothing is found at all.
const Duration kMoonFallbackSearchLimit = Duration(hours: 48);

enum _MoonEventKind { rise, set }

/// Process-wide lunar events, configured by `PanchangService.init`.
final MoonEventsService moonEventsService = MoonEventsService();
