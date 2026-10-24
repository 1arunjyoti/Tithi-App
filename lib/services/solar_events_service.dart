import 'package:flutter/foundation.dart';
import 'package:jyotish/jyotish.dart';
import 'package:timezone/timezone.dart' as tz;

import '../core/location/timezone_resolver.dart';
import '../models/panchang_profile.dart';
import 'moonrise_calculator.dart';
import 'sunrise_calculator.dart';

/// Solar events for one civil day at one place.
@immutable
class SolarEvents {
  const SolarEvents({
    required this.date,
    required this.sunrise,
    required this.sunset,
    required this.nextSunrise,
  });

  /// Normalized local calendar day these events belong to.
  final DateTime date;

  final DateTime sunrise;
  final DateTime sunset;

  /// Sunrise of the following civil day; bounds the night windows.
  final DateTime nextSunrise;

  Duration get dayLength => sunset.difference(sunrise);
  Duration get nightLength => nextSunrise.difference(sunset);

  @override
  String toString() =>
      'SolarEvents($date, sunrise: $sunrise, sunset: $sunset, '
      'nextSunrise: $nextSunrise)';
}

/// Raised when the Sun does not rise or set on the requested civil day.
///
/// Polar day/night is a real astronomical state, not an error. Callers that
/// render a day must decide how to present the missing event; the service no
/// longer invents a 06:00 or 18:00 fallback.
class SolarEventUnavailable implements Exception {
  const SolarEventUnavailable({
    required this.event,
    required this.date,
    required this.latitude,
    required this.longitude,
  });

  final String event;
  final DateTime date;
  final double latitude;
  final double longitude;

  @override
  String toString() =>
      'SolarEventUnavailable($event on $date at '
      '${latitude.toStringAsFixed(4)}, ${longitude.toStringAsFixed(4)})';
}

/// Strategy boundary for the solar-events seam.
///
/// [SwissSolarEventCalculator] is the production implementation. The NOAA
/// delegate remains the labelled fallback for platforms where the native
/// Swiss Ephemeris library is unavailable, and for parity tests.
abstract interface class SolarEventCalculator {
  /// True when this calculator uses the native Swiss Ephemeris backend.
  bool get isNative => false;

  DateTime rise({
    required DateTime date,
    required double latitude,
    required double longitude,
    double altitudeMeters = 0,
    String? timezoneId,
  });

  DateTime set({
    required DateTime date,
    required double latitude,
    required double longitude,
    double altitudeMeters = 0,
    String? timezoneId,
  });
}

/// Swiss Ephemeris implementation using `swe_rise_trans()`.
///
/// The Hindu convention is `SE_BIT_HINDU_RISING`: disc centre, no refraction,
/// geocentric, and no ecliptic latitude. That is deliberately not the same as
/// the old NOAA apparent-upper-limb calculation; fixtures move by about four
/// minutes because of the 50 arcminute difference in the horizon definition.
class SwissSolarEventCalculator implements SolarEventCalculator {
  SwissSolarEventCalculator({required this.bindings});

  final SwissEphBindings bindings;

  @override
  bool get isNative => true;

  @override
  DateTime rise({
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
    event: 'sunrise',
  );

  @override
  DateTime set({
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
    event: 'sunset',
  );

  DateTime _calculate({
    required DateTime date,
    required double latitude,
    required double longitude,
    required double altitudeMeters,
    required String? timezoneId,
    required int riseSetFlag,
    required String event,
  }) {
    final location = _locationFor(timezoneId, date);
    final wallDate = _wallDate(date, location);
    final midnight = location == null
        ? DateTime(wallDate.year, wallDate.month, wallDate.day)
        : tz.TZDateTime(location, wallDate.year, wallDate.month, wallDate.day);

    final startJulianDay = _julianDayUtc(midnight.toUtc());
    final result = bindings.riseTrans(
      startJulianDay: startJulianDay,
      planetId: SwissEphConstants.sun,
      ephemerisFlag:
          SwissEphBindings.SEFLG_SWIEPH |
          SwissEphBindings.SEFLG_NONUT |
          SwissEphBindings.SEFLG_TRUEPOS,
      riseSetFlag: riseSetFlag | SwissEphBindings.SE_BIT_HINDU_RISING,
      longitude: longitude,
      latitude: latitude,
      altitudeMeters: _normalizedAltitude(altitudeMeters),
    );

    if (result.isUnavailable) {
      throw SolarEventUnavailable(
        event: event,
        date: wallDate,
        latitude: latitude,
        longitude: longitude,
      );
    }
    if (!result.isSuccess) {
      throw StateError(
        'swe_rise_trans failed for $event: '
                'status ${result.status} ${result.error ?? ''}'
            .trim(),
      );
    }

    final utc = bindings.julianDayToUtcDateTime(result.julianDay!);
    if (location != null) return tz.TZDateTime.from(utc, location);
    return utc.toLocal();
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

/// Behavior-preserving delegate over the shipped NOAA calculator.
///
/// Do not present this as the Hindu rise/set convention. It is the labelled
/// fallback until the native Swiss Ephemeris binding is available on every
/// target, and it is the parity reference for the seam.
class NoaaSolarEventCalculator implements SolarEventCalculator {
  const NoaaSolarEventCalculator();

  @override
  bool get isNative => false;

  @override
  DateTime rise({
    required DateTime date,
    required double latitude,
    required double longitude,
    double altitudeMeters = 0,
    String? timezoneId,
  }) => SunriseCalculator.calculateSunriseIST(
    date: date,
    latitude: latitude,
    longitude: longitude,
  );

  @override
  DateTime set({
    required DateTime date,
    required double latitude,
    required double longitude,
    double altitudeMeters = 0,
    String? timezoneId,
  }) => SunriseCalculator.calculateSunsetIST(
    date: date,
    latitude: latitude,
    longitude: longitude,
  );
}

enum _SolarEventKind { sunrise, sunset }

/// One cached entry point for every production sunrise/sunset read.
///
/// The default convention is [SolarEventConvention.hindu]. Until
/// [configureSwiss] succeeds, the service keeps the labelled NOAA fallback so
/// app startup and platforms without a native library still work.
class SolarEventsService {
  SolarEventsService({
    SolarEventCalculator? calculator,
    this.convention = SolarEventConvention.hindu,
  }) : _calculator = calculator ?? const NoaaSolarEventCalculator();

  /// Convention served by this instance.
  final SolarEventConvention convention;

  SolarEventCalculator _calculator;

  /// IANA zone of the selected place, published by the location layer.
  ///
  /// Bridge until Phase 2's canonical day carries an explicit place context:
  /// detail sheets, notification scheduling, export, the Bengali calendar, and
  /// the home widget call [sunrise]/[sunset] with coordinates only. Without a
  /// default they resolve civil time in the device zone, which is wrong for a
  /// place in another zone. An explicit `timezoneId` argument always wins.
  String? _placeTimezoneId;

  /// FIFO cache keyed by event, civil day, place, offset, altitude, and
  /// convention/version. Bounded so a long-lived process cannot grow without
  /// limit.
  final Map<String, DateTime> _cache = <String, DateTime>{};

  static const int _maxCacheEntries = 4096;

  /// True once the native Swiss Ephemeris calculator has been installed.
  bool get usesNativeCalculator => _calculator.isNative;

  /// IANA zone used when a caller does not supply one; null means device zone.
  String? get placeTimezoneId => _placeTimezoneId;

  /// Publishes the selected place's zone for callers that only pass lat/lon.
  ///
  /// Legacy aliases are canonicalized (`Asia/Calcutta` -> `Asia/Kolkata`), so
  /// the cache key and the returned `TZDateTime` agree. Changing the zone
  /// clears the cache: every cached instant was keyed by the previous zone.
  void setPlaceTimezone(String? timezoneId) {
    final canonical = canonicalTimezoneId(timezoneId ?? '');
    final next = canonical.isEmpty ? null : canonical;
    if (next == _placeTimezoneId) return;
    _placeTimezoneId = next;
    clearCache();
  }

  String? _effectiveTimezoneId(String? timezoneId) {
    final raw = timezoneId?.trim();
    if (raw != null && raw.isNotEmpty) return raw;
    return _placeTimezoneId;
  }

  DateTime sunrise({
    required DateTime date,
    required double latitude,
    required double longitude,
    double altitudeMeters = 0,
    String? timezoneId,
  }) => _resolve(
    _SolarEventKind.sunrise,
    date: date,
    latitude: latitude,
    longitude: longitude,
    altitudeMeters: altitudeMeters,
    timezoneId: timezoneId,
  );

  DateTime sunset({
    required DateTime date,
    required double latitude,
    required double longitude,
    double altitudeMeters = 0,
    String? timezoneId,
  }) => _resolve(
    _SolarEventKind.sunset,
    date: date,
    latitude: latitude,
    longitude: longitude,
    altitudeMeters: altitudeMeters,
    timezoneId: timezoneId,
  );

  /// Bundles the day's sunrise/sunset with the next sunrise.
  ///
  /// The input is normalized to its local civil day first, matching
  /// `resolveTithiCheckpoints`. [nextSunrise] keeps the existing
  /// `date + 1 day` arithmetic. When a timezone id is supplied, the returned
  /// date and events carry that zone, so DST transitions are represented by
  /// the zone's offset rather than the device offset.
  SolarEvents forDate({
    required DateTime date,
    required double latitude,
    required double longitude,
    double altitudeMeters = 0,
    String? timezoneId,
  }) {
    final effectiveTimezoneId = _effectiveTimezoneId(timezoneId);
    final location = _effectiveLocation(effectiveTimezoneId, date);
    final wallDate = _wallDate(date, location);
    final dateOnly = location == null
        ? DateTime(wallDate.year, wallDate.month, wallDate.day)
        : tz.TZDateTime(location, wallDate.year, wallDate.month, wallDate.day);

    return SolarEvents(
      date: dateOnly,
      sunrise: sunrise(
        date: dateOnly,
        latitude: latitude,
        longitude: longitude,
        altitudeMeters: altitudeMeters,
        timezoneId: effectiveTimezoneId,
      ),
      sunset: sunset(
        date: dateOnly,
        latitude: latitude,
        longitude: longitude,
        altitudeMeters: altitudeMeters,
        timezoneId: effectiveTimezoneId,
      ),
      nextSunrise: sunrise(
        date: dateOnly.add(const Duration(days: 1)),
        latitude: latitude,
        longitude: longitude,
        altitudeMeters: altitudeMeters,
        timezoneId: effectiveTimezoneId,
      ),
    );
  }

  /// Intraday instant for a timing-override checkpoint.
  ///
  /// Mirrors the resolver's checkpoint arithmetic: madhyahna = midday,
  /// aparahna = 3/4 day, nishita = the opening of the Nishita window
  /// (`sunset + 7/15 night`, the eighth of the fifteen night muhurtas),
  /// pradosha = sunset + night/10, moonrise = the Moon's rise on the civil day
  /// (null when the Moon does not rise, matching the canonical day's anchor).
  ///
  /// This is the forward-scan probe, which samples one instant per checkpoint.
  /// A `nishita` observance matches the tithi at either edge of the window, so
  /// the scan also checks the closing instant; see
  /// `PanchangService.findNextFestivalOccurrence`.
  DateTime? checkpointTimeFor({
    required DateTime date,
    required String timingOverride,
    required double latitude,
    required double longitude,
    double altitudeMeters = 0,
    String? timezoneId,
  }) {
    final effectiveTimezoneId = _effectiveTimezoneId(timezoneId);
    final location = _effectiveLocation(effectiveTimezoneId, date);
    final wallDate = _wallDate(date, location);
    final dateOnly = location == null
        ? DateTime(wallDate.year, wallDate.month, wallDate.day)
        : tz.TZDateTime(location, wallDate.year, wallDate.month, wallDate.day);
    final events = forDate(
      date: dateOnly,
      latitude: latitude,
      longitude: longitude,
      altitudeMeters: altitudeMeters,
      timezoneId: effectiveTimezoneId,
    );
    final dayLength = events.sunset.difference(events.sunrise);
    final nightLength = events.nextSunrise.difference(events.sunset);
    final nightMicros = nightLength.inMicroseconds;
    switch (timingOverride) {
      case 'madhyahna':
        return events.sunrise.add(Duration(minutes: dayLength.inMinutes ~/ 2));
      case 'aparahna':
        return events.sunrise.add(
          Duration(minutes: dayLength.inMinutes * 3 ~/ 4),
        );
      case 'nishita':
        return events.sunset.add(
          Duration(microseconds: nightMicros * 7 ~/ 15),
        );
      case 'nishitaEnd':
        return events.sunset.add(
          Duration(microseconds: nightMicros * 8 ~/ 15),
        );
      case 'pradosha':
        return events.sunset.add(
          Duration(minutes: nightLength.inMinutes ~/ 10),
        );
      case 'moonrise':
        // A lunar anchor, not a solar offset: reuse the same civil-day rise the
        // canonical day records, so the forward scan and the day agree.
        return MoonriseCalculator.calculateMoonriseSet(
          date: dateOnly,
          latitude: latitude,
          longitude: longitude,
        ).moonrise;
      default:
        return null;
    }
  }

  /// Installs the native Swiss Ephemeris calculator.
  ///
  /// [PanchangService.init] calls this after the bundled ephemeris files are
  /// copied and `Jyotish().initialize()` succeeds. Failure is non-fatal: the
  /// service keeps the labelled NOAA fallback and [usesNativeCalculator] stays
  /// false.
  void configureSwiss({
    required String ephemerisPath,
    SwissEphBindings? bindings,
  }) {
    if (convention != SolarEventConvention.hindu) return;

    try {
      final native = bindings ?? SwissEphBindings();
      native.setEphemerisPath(ephemerisPath);
      _calculator = SwissSolarEventCalculator(bindings: native);
      clearCache();
    } catch (error) {
      if (kDebugMode) {
        debugPrint('SolarEventsService: native setup failed: $error');
      }
      _calculator = const NoaaSolarEventCalculator();
      clearCache();
    }
  }

  /// Drops every cached event.
  void clearCache() => _cache.clear();

  @visibleForTesting
  int get debugCacheSize => _cache.length;

  DateTime _resolve(
    _SolarEventKind kind, {
    required DateTime date,
    required double latitude,
    required double longitude,
    required double altitudeMeters,
    required String? timezoneId,
  }) {
    final effectiveTimezoneId = _effectiveTimezoneId(timezoneId);
    final key = _cacheKey(
      kind,
      date,
      latitude,
      longitude,
      altitudeMeters,
      effectiveTimezoneId,
    );
    final cached = _cache[key];
    if (cached != null) return cached;

    final value = switch (kind) {
      _SolarEventKind.sunrise => _calculator.rise(
        date: date,
        latitude: latitude,
        longitude: longitude,
        altitudeMeters: altitudeMeters,
        timezoneId: effectiveTimezoneId,
      ),
      _SolarEventKind.sunset => _calculator.set(
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

  String _cacheKey(
    _SolarEventKind kind,
    DateTime date,
    double latitude,
    double longitude,
    double altitudeMeters,
    String? timezoneId,
  ) {
    final location = _effectiveLocation(timezoneId, date);
    final wallDate = _wallDate(date, location);
    final year = wallDate.year.toString().padLeft(4, '0');
    final month = wallDate.month.toString().padLeft(2, '0');
    final day = wallDate.day.toString().padLeft(2, '0');
    final zone = location?.name ?? '';
    final offset = wallDate.timeZoneOffset.inMinutes;
    return '${kind.name}|$year-$month-$day|$offset|$zone|'
        '${latitude.toStringAsFixed(6)}|${longitude.toStringAsFixed(6)}|'
        '${altitudeMeters.toStringAsFixed(1)}|'
        '${convention.name}|$kPanchangCalculationVersion';
  }

  static tz.Location? _effectiveLocation(String? timezoneId, DateTime date) {
    return SwissSolarEventCalculator._locationFor(timezoneId, date);
  }

  static DateTime _wallDate(DateTime date, tz.Location? location) {
    return SwissSolarEventCalculator._wallDate(date, location);
  }
}

/// Process-wide instance used by production callers.
///
/// Tests that need isolation construct their own [SolarEventsService]. The
/// global instance is configured natively from `PanchangService.init()`.
final SolarEventsService solarEventsService = SolarEventsService();
