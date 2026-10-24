import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:tithi/models/panchang_profile.dart';
import 'package:tithi/services/solar_events_service.dart';
import 'package:tithi/services/sunrise_calculator.dart';

void main() {
  final libPath = Platform.environment['SWISSEPH_LIB_PATH'];
  final libraryAvailable =
      libPath != null && libPath.isNotEmpty && File(libPath).existsSync();
  final ephemerisPath = '${Directory.current.path}/assets/ephe';
  final nativeSkip = !libraryAvailable
      ? 'Set SWISSEPH_LIB_PATH to a Swiss Ephemeris shared library.'
      : !Directory(ephemerisPath).existsSync()
      ? 'Bundled Swiss Ephemeris data files are missing.'
      : null;

  setUpAll(tz_data.initializeTimeZones);

  group('SolarEventsService', () {
    late SolarEventsService service;

    setUp(() {
      service = SolarEventsService(
        convention: SolarEventConvention.apparentUpperLimb,
      );
    });

    test('delegates to the NOAA calculator for representative cases', () {
      final cases = <({String name, DateTime date, double lat, double lon})>[
        (name: 'Delhi', date: DateTime(2026, 9, 4), lat: 28.6139, lon: 77.2090),
        (
          name: 'Kolkata',
          date: DateTime(2026, 10, 17),
          lat: 22.5726,
          lon: 88.3639,
        ),
        (
          name: 'Mumbai',
          date: DateTime(2026, 6, 30),
          lat: 19.0760,
          lon: 72.8777,
        ),
        (
          name: 'Tromso summer',
          date: DateTime(2026, 6, 21),
          lat: 69.6492,
          lon: 18.9553,
        ),
        (
          name: 'Tromso winter',
          date: DateTime(2026, 12, 21),
          lat: 69.6492,
          lon: 18.9553,
        ),
        (
          name: 'Ephemeris start',
          date: DateTime(1800),
          lat: 28.6139,
          lon: 77.2090,
        ),
      ];

      for (final c in cases) {
        expect(
          service.sunrise(date: c.date, latitude: c.lat, longitude: c.lon),
          SunriseCalculator.calculateSunriseIST(
            date: c.date,
            latitude: c.lat,
            longitude: c.lon,
          ),
          reason: '${c.name} sunrise',
        );
        expect(
          service.sunset(date: c.date, latitude: c.lat, longitude: c.lon),
          SunriseCalculator.calculateSunsetIST(
            date: c.date,
            latitude: c.lat,
            longitude: c.lon,
          ),
          reason: '${c.name} sunset',
        );
      }
    });

    test('forDate bundles the same instants as resolveTithiCheckpoints', () {
      final date = DateTime(2026, 9, 4);
      const lat = 28.6139;
      const lon = 77.2090;

      final events = service.forDate(
        date: DateTime(2026, 9, 4, 18, 30),
        latitude: lat,
        longitude: lon,
      );

      expect(events.date, date);
      expect(
        events.sunrise,
        SunriseCalculator.calculateSunriseIST(
          date: date,
          latitude: lat,
          longitude: lon,
        ),
      );
      expect(
        events.sunset,
        SunriseCalculator.calculateSunsetIST(
          date: date,
          latitude: lat,
          longitude: lon,
        ),
      );
      expect(
        events.nextSunrise,
        SunriseCalculator.calculateSunriseIST(
          date: date.add(const Duration(days: 1)),
          latitude: lat,
          longitude: lon,
        ),
      );
      expect(events.dayLength, events.sunset.difference(events.sunrise));
      expect(events.nightLength, events.nextSunrise.difference(events.sunset));
    });

    test('caches repeated reads per event, date, and place', () {
      final calculator = _CountingCalculator();
      final cached = SolarEventsService(calculator: calculator);
      final date = DateTime(2026, 9, 4);
      const lat = 28.6139;
      const lon = 77.2090;

      cached.sunrise(date: date, latitude: lat, longitude: lon);
      cached.sunrise(date: date, latitude: lat, longitude: lon);
      cached.sunrise(date: DateTime(2026, 9, 4), latitude: lat, longitude: lon);
      expect(calculator.riseCalls, 1);

      cached.sunrise(
        date: date.add(const Duration(days: 1)),
        latitude: lat,
        longitude: lon,
      );
      expect(calculator.riseCalls, 2);

      cached.sunset(date: date, latitude: lat, longitude: lon);
      cached.sunset(date: date, latitude: lat, longitude: lon);
      expect(calculator.setCalls, 1);
      expect(cached.debugCacheSize, 3);

      cached.clearCache();
      expect(cached.debugCacheSize, 0);
      cached.sunrise(date: date, latitude: lat, longitude: lon);
      expect(calculator.riseCalls, 3);
    });

    test('checkpointTimeFor preserves the shipped arithmetic', () {
      final date = DateTime(2026, 9, 4);
      const lat = 28.6139;
      const lon = 77.2090;

      final sunrise = SunriseCalculator.calculateSunriseIST(
        date: date,
        latitude: lat,
        longitude: lon,
      );
      final sunset = SunriseCalculator.calculateSunsetIST(
        date: date,
        latitude: lat,
        longitude: lon,
      );
      final nextSunrise = SunriseCalculator.calculateSunriseIST(
        date: date.add(const Duration(days: 1)),
        latitude: lat,
        longitude: lon,
      );
      final dayLength = sunset.difference(sunrise);
      final nightLength = nextSunrise.difference(sunset);

      final expected = <String, DateTime>{
        'madhyahna': sunrise.add(Duration(minutes: dayLength.inMinutes ~/ 2)),
        'aparahna': sunrise.add(
          Duration(minutes: dayLength.inMinutes * 3 ~/ 4),
        ),
        'nishita': sunset.add(Duration(minutes: nightLength.inMinutes ~/ 2)),
        'pradosha': sunset.add(Duration(minutes: nightLength.inMinutes ~/ 10)),
      };

      for (final entry in expected.entries) {
        expect(
          service.checkpointTimeFor(
            date: DateTime(2026, 9, 4, 18, 30),
            timingOverride: entry.key,
            latitude: lat,
            longitude: lon,
          ),
          entry.value,
          reason: entry.key,
        );
      }
      expect(
        service.checkpointTimeFor(
          date: date,
          timingOverride: 'unknown',
          latitude: lat,
          longitude: lon,
        ),
        isNull,
      );
    });

    test(
      'defaults to the Hindu convention with the labelled NOAA fallback',
      () {
        final fallback = SolarEventsService();
        expect(fallback.convention, SolarEventConvention.hindu);
        expect(fallback.usesNativeCalculator, isFalse);
      },
    );

    group('place timezone default', () {
      late _RecordingCalculator calculator;
      late SolarEventsService service;

      setUp(() {
        calculator = _RecordingCalculator();
        service = SolarEventsService(calculator: calculator);
      });

      tearDown(() => service.setPlaceTimezone(null));

      test('fills in the place zone when the caller omits one', () {
        const lat = 28.6139;
        const lon = 77.2090;
        final date = DateTime(2026, 9, 4);

        service.sunrise(date: date, latitude: lat, longitude: lon);
        expect(calculator.timezones.last, isNull);

        service.setPlaceTimezone('Asia/Calcutta');
        expect(service.placeTimezoneId, 'Asia/Kolkata');

        service.sunrise(date: date, latitude: lat, longitude: lon);
        expect(calculator.timezones.last, 'Asia/Kolkata');

        service.setPlaceTimezone(null);
        service.sunrise(date: date, latitude: lat, longitude: lon);
        expect(calculator.timezones.last, isNull);
      });

      test('an explicit timezoneId wins over the place default', () {
        service.setPlaceTimezone('Asia/Kolkata');

        service.sunrise(
          date: DateTime(2026, 9, 4),
          latitude: 28.6139,
          longitude: 77.2090,
          timezoneId: 'Europe/Oslo',
        );

        expect(calculator.timezones.last, 'Europe/Oslo');
      });

      test('forDate and checkpointTimeFor use the place default', () {
        service.setPlaceTimezone('Asia/Kolkata');
        const lat = 28.6139;
        const lon = 77.2090;

        service.forDate(
          date: DateTime(2026, 9, 4, 18, 30),
          latitude: lat,
          longitude: lon,
        );
        expect(calculator.timezones.last, 'Asia/Kolkata');

        service.checkpointTimeFor(
          date: DateTime(2026, 9, 4),
          timingOverride: 'nishita',
          latitude: lat,
          longitude: lon,
        );
        expect(calculator.timezones.last, 'Asia/Kolkata');
      });

      test('changing the place zone drops cached events', () {
        const lat = 28.6139;
        const lon = 77.2090;
        final date = DateTime(2026, 9, 4);

        service.sunrise(date: date, latitude: lat, longitude: lon);
        expect(service.debugCacheSize, 1);

        service.setPlaceTimezone('Asia/Kolkata');
        expect(service.debugCacheSize, 0);
      });
    });

    test('native Swiss calculator uses the Hindu convention and rejects polar '
        'no-rise explicitly', () {
      final native = SolarEventsService();
      native.configureSwiss(ephemerisPath: ephemerisPath);
      expect(native.usesNativeCalculator, isTrue);

      final sunrise = native.sunrise(
        date: DateTime(2026, 1, 6),
        latitude: 28.6139,
        longitude: 77.2090,
        altitudeMeters: 216,
        timezoneId: 'Asia/Kolkata',
      );
      expect(sunrise.year, 2026);
      expect(sunrise.month, 1);
      expect(sunrise.day, 6);
      expect(sunrise.hour, 7);
      expect(sunrise.minute, inInclusiveRange(18, 20));
      expect(sunrise.timeZoneOffset, const Duration(hours: 5, minutes: 30));

      final sunset = native.sunset(
        date: DateTime(2026, 1, 6),
        latitude: 28.6139,
        longitude: 77.2090,
        altitudeMeters: 216,
        timezoneId: 'Asia/Kolkata',
      );
      expect(sunset.hour, 17);
      expect(sunset.minute, inInclusiveRange(33, 36));

      final events = native.forDate(
        date: DateTime(2026, 1, 6),
        latitude: 28.6139,
        longitude: 77.2090,
        altitudeMeters: 216,
        timezoneId: 'Asia/Kolkata',
      );
      expect(
        events.sunrise.timeZoneOffset,
        const Duration(hours: 5, minutes: 30),
      );

      expect(
        () => native.sunrise(
          date: DateTime(2026, 6, 21),
          latitude: 69.6492,
          longitude: 18.9553,
          timezoneId: 'Europe/Oslo',
        ),
        throwsA(isA<SolarEventUnavailable>()),
      );
    }, skip: nativeSkip);
  });
}

class _CountingCalculator implements SolarEventCalculator {
  int riseCalls = 0;
  int setCalls = 0;

  @override
  bool get isNative => false;

  @override
  DateTime rise({
    required DateTime date,
    required double latitude,
    required double longitude,
    double altitudeMeters = 0,
    String? timezoneId,
  }) {
    riseCalls++;
    return DateTime(date.year, date.month, date.day, 6);
  }

  @override
  DateTime set({
    required DateTime date,
    required double latitude,
    required double longitude,
    double altitudeMeters = 0,
    String? timezoneId,
  }) {
    setCalls++;
    return DateTime(date.year, date.month, date.day, 18);
  }
}

/// Records the timezone each call received, so the place default can be
/// asserted without the native library.
class _RecordingCalculator implements SolarEventCalculator {
  final List<String?> timezones = <String?>[];

  @override
  bool get isNative => false;

  @override
  DateTime rise({
    required DateTime date,
    required double latitude,
    required double longitude,
    double altitudeMeters = 0,
    String? timezoneId,
  }) {
    timezones.add(timezoneId);
    return DateTime(date.year, date.month, date.day, 6);
  }

  @override
  DateTime set({
    required DateTime date,
    required double latitude,
    required double longitude,
    double altitudeMeters = 0,
    String? timezoneId,
  }) {
    timezones.add(timezoneId);
    return DateTime(date.year, date.month, date.day, 18);
  }
}
