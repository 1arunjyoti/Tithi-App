import 'package:flutter_test/flutter_test.dart';
import 'package:tithi/models/panchang_profile.dart';
import 'package:tithi/services/solar_events_service.dart';
import 'package:tithi/services/sunrise_calculator.dart';

void main() {
  group('SolarEventsService', () {
    late SolarEventsService service;

    setUp(() {
      service = SolarEventsService();
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

    test('rejects the Hindu convention until Phase 1b', () {
      expect(
        () => SolarEventsService(convention: SolarEventConvention.hindu),
        throwsA(isA<UnsupportedError>()),
      );
      expect(
        SolarEventsService().convention,
        SolarEventConvention.apparentUpperLimb,
      );
    });
  });
}

class _CountingCalculator implements SolarEventCalculator {
  int riseCalls = 0;
  int setCalls = 0;

  @override
  DateTime rise({
    required DateTime date,
    required double latitude,
    required double longitude,
  }) {
    riseCalls++;
    return DateTime(date.year, date.month, date.day, 6);
  }

  @override
  DateTime set({
    required DateTime date,
    required double latitude,
    required double longitude,
  }) {
    setCalls++;
    return DateTime(date.year, date.month, date.day, 18);
  }
}
