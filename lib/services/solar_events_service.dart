import 'package:flutter/foundation.dart';

import '../models/panchang_profile.dart';
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

/// Strategy boundary for the solar-events seam.
///
/// Phase 1a ships [NoaaSolarEventCalculator]. Phase 1b adds a Swiss Ephemeris
/// implementation using `swe_rise_trans()` with `SE_BIT_HINDU_RISING`.
abstract interface class SolarEventCalculator {
  DateTime rise({
    required DateTime date,
    required double latitude,
    required double longitude,
  });

  DateTime set({
    required DateTime date,
    required double latitude,
    required double longitude,
  });
}

/// Behavior-preserving Phase 1a delegate over the shipped NOAA calculator.
///
/// Do not present this as the Hindu rise/set convention. It is the labelled
/// fallback until the native Swiss Ephemeris binding lands in Phase 1b.
class NoaaSolarEventCalculator implements SolarEventCalculator {
  const NoaaSolarEventCalculator();

  @override
  DateTime rise({
    required DateTime date,
    required double latitude,
    required double longitude,
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
  }) => SunriseCalculator.calculateSunsetIST(
    date: date,
    latitude: latitude,
    longitude: longitude,
  );
}

enum _SolarEventKind { sunrise, sunset }

/// One cached entry point for every production sunrise/sunset read.
///
/// Phase 1a is intentionally behavior-preserving: this service delegates to
/// the same NOAA math the app used before, and the cache key includes the
/// device offset so a timezone change cannot serve a stale instant. Phase 1b
/// replaces the delegate with the native Hindu convention, bumps
/// [kPanchangCalculationVersion], and invalidates this cache.
class SolarEventsService {
  SolarEventsService({
    SolarEventCalculator? calculator,
    this.convention = SolarEventConvention.apparentUpperLimb,
  }) : _calculator = calculator ?? const NoaaSolarEventCalculator() {
    if (convention != SolarEventConvention.apparentUpperLimb) {
      throw UnsupportedError(
        'Phase 1a implements only the '
        '${SolarEventConvention.apparentUpperLimb.name} solar convention; '
        'the ${SolarEventConvention.hindu.name} convention lands in Phase 1b.',
      );
    }
  }

  /// Convention served by this instance. Phase 1a is NOAA only.
  final SolarEventConvention convention;

  final SolarEventCalculator _calculator;

  /// FIFO cache keyed by event, civil day, place, device offset, and
  /// convention. Bounded so a long-lived process cannot grow without limit.
  final Map<String, DateTime> _cache = <String, DateTime>{};

  static const int _maxCacheEntries = 4096;

  DateTime sunrise({
    required DateTime date,
    required double latitude,
    required double longitude,
  }) => _resolve(
    _SolarEventKind.sunrise,
    date: date,
    latitude: latitude,
    longitude: longitude,
  );

  DateTime sunset({
    required DateTime date,
    required double latitude,
    required double longitude,
  }) => _resolve(
    _SolarEventKind.sunset,
    date: date,
    latitude: latitude,
    longitude: longitude,
  );

  /// Bundles the day's sunrise/sunset with the next sunrise.
  ///
  /// The input is normalized to its local civil day first, matching
  /// `resolveTithiCheckpoints`. [nextSunrise] keeps the existing
  /// `date + 1 day` arithmetic. Callers that need calendar-day arithmetic
  /// across a DST transition (for example the home-widget payload) should ask
  /// for that specific date instead.
  SolarEvents forDate({
    required DateTime date,
    required double latitude,
    required double longitude,
  }) {
    final local = date.isUtc ? date.toLocal() : date;
    final dateOnly = DateTime(local.year, local.month, local.day);
    return SolarEvents(
      date: dateOnly,
      sunrise: sunrise(
        date: dateOnly,
        latitude: latitude,
        longitude: longitude,
      ),
      sunset: sunset(date: dateOnly, latitude: latitude, longitude: longitude),
      nextSunrise: sunrise(
        date: dateOnly.add(const Duration(days: 1)),
        latitude: latitude,
        longitude: longitude,
      ),
    );
  }

  /// Intraday instant for a timing-override checkpoint.
  ///
  /// Mirrors the shipped checkpoint arithmetic exactly: madhyahna = midday,
  /// aparahna = 3/4 day, nishita = night midpoint, pradosha = sunset +
  /// night/10. The Phase 2 resolver replaces this point sample with the
  /// observance policy.
  DateTime? checkpointTimeFor({
    required DateTime date,
    required String timingOverride,
    required double latitude,
    required double longitude,
  }) {
    final dateOnly = DateTime(date.year, date.month, date.day);
    final events = forDate(
      date: dateOnly,
      latitude: latitude,
      longitude: longitude,
    );
    final dayLength = events.sunset.difference(events.sunrise);
    final nightLength = events.nextSunrise.difference(events.sunset);
    switch (timingOverride) {
      case 'madhyahna':
        return events.sunrise.add(Duration(minutes: dayLength.inMinutes ~/ 2));
      case 'aparahna':
        return events.sunrise.add(
          Duration(minutes: dayLength.inMinutes * 3 ~/ 4),
        );
      case 'nishita':
        return events.sunset.add(Duration(minutes: nightLength.inMinutes ~/ 2));
      case 'pradosha':
        return events.sunset.add(
          Duration(minutes: nightLength.inMinutes ~/ 10),
        );
      default:
        return null;
    }
  }

  /// Drops every cached event. Phase 1b calls this after a convention or
  /// calculation-version change.
  void clearCache() => _cache.clear();

  @visibleForTesting
  int get debugCacheSize => _cache.length;

  DateTime _resolve(
    _SolarEventKind kind, {
    required DateTime date,
    required double latitude,
    required double longitude,
  }) {
    final key = _cacheKey(kind, date, latitude, longitude);
    final cached = _cache[key];
    if (cached != null) return cached;

    final value = switch (kind) {
      _SolarEventKind.sunrise => _calculator.rise(
        date: date,
        latitude: latitude,
        longitude: longitude,
      ),
      _SolarEventKind.sunset => _calculator.set(
        date: date,
        latitude: latitude,
        longitude: longitude,
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
  ) {
    final local = date.isUtc ? date.toLocal() : date;
    final year = local.year.toString().padLeft(4, '0');
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    return '${kind.name}|$year-$month-$day|'
        '${local.timeZoneOffset.inMinutes}|'
        '${latitude.toStringAsFixed(6)}|${longitude.toStringAsFixed(6)}|'
        '${convention.name}';
  }
}

/// Process-wide instance used by production callers.
///
/// Tests that need isolation construct their own [SolarEventsService].
final SolarEventsService solarEventsService = SolarEventsService();
