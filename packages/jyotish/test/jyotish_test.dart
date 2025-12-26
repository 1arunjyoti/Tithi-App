import 'package:test/test.dart';
import 'package:jyotish/jyotish.dart';

/// Unit tests for Jyotish library models and calculations.
/// These tests verify mathematical calculations without requiring Swiss Ephemeris.
void main() {
  group('GeographicLocation', () {
    test('creates location with valid coordinates', () {
      final location = GeographicLocation(
        latitude: 27.7172,
        longitude: 85.3240,
        altitude: 1400,
      );

      expect(location.latitude, 27.7172);
      expect(location.longitude, 85.3240);
      expect(location.altitude, 1400);
    });

    test('throws error for invalid coordinates', () {
      expect(() => GeographicLocation(latitude: 91, longitude: 0),
          throwsArgumentError);
      expect(() => GeographicLocation(latitude: 0, longitude: 181),
          throwsArgumentError);
    });

    test('converts DMS to decimal correctly', () {
      final location = GeographicLocation.fromDMS(
        latDegrees: 27,
        latMinutes: 43,
        latSeconds: 1.92,
        isNorth: true,
        lonDegrees: 85,
        lonMinutes: 19,
        lonSeconds: 26.4,
        isEast: true,
      );

      expect(location.latitude, closeTo(27.7172, 0.0001));
      expect(location.longitude, closeTo(85.3240, 0.0001));
    });
  });

  group('Planet', () {
    test('has correct Swiss Ephemeris IDs', () {
      expect(Planet.sun.swissEphId, 0);
      expect(Planet.moon.swissEphId, 1);
      expect(Planet.mercury.swissEphId, 2);
      expect(Planet.jupiter.swissEphId, 5);
    });

    test('planet lists are correct', () {
      expect(Planet.majorPlanets.length, 10);
      expect(Planet.traditionalPlanets.length, 7);
      expect(Planet.traditionalPlanets.contains(Planet.uranus), false);
    });

    test('fromSwissEphId works correctly', () {
      expect(Planet.fromSwissEphId(0), Planet.sun);
      expect(Planet.fromSwissEphId(999), null);
    });
  });

  group('PlanetPosition Calculations', () {
    test('calculates zodiac signs correctly', () {
      final testCases = [
        (0.0, 'Aries', 0),
        (45.0, 'Taurus', 15.0),
        (90.0, 'Cancer', 0.0),
        (180.0, 'Libra', 0.0),
        (270.0, 'Capricorn', 0.0),
        (359.9, 'Pisces', 29.9),
      ];

      for (final (longitude, expectedSign, expectedPos) in testCases) {
        final position = PlanetPosition(
          planet: Planet.sun,
          dateTime: DateTime.now(),
          longitude: longitude,
          latitude: 0,
          distance: 1.0,
          longitudeSpeed: 1.0,
          latitudeSpeed: 0,
          distanceSpeed: 0,
        );

        expect(position.zodiacSign, expectedSign);
        expect(position.positionInSign, closeTo(expectedPos, 0.1));
      }
    });

    test('detects retrograde motion', () {
      final retrograde = PlanetPosition(
        planet: Planet.mercury,
        dateTime: DateTime.now(),
        longitude: 100,
        latitude: 0,
        distance: 1.0,
        longitudeSpeed: -0.5,
        latitudeSpeed: 0,
        distanceSpeed: 0,
      );

      expect(retrograde.isRetrograde, true);
    });

    test('calculates nakshatras correctly', () {
      final nakshatraWidth = 360.0 / 27;

      for (var i = 0; i < 27; i++) {
        final longitude = (i * nakshatraWidth) + (nakshatraWidth / 2);
        final position = PlanetPosition(
          planet: Planet.moon,
          dateTime: DateTime.now(),
          longitude: longitude,
          latitude: 0,
          distance: 1.0,
          longitudeSpeed: 13.0,
          latitudeSpeed: 0,
          distanceSpeed: 0,
        );

        expect(position.nakshatraIndex, i);
      }
    });

    test('calculates nakshatra padas correctly', () {
      final position = PlanetPosition(
        planet: Planet.moon,
        dateTime: DateTime.now(),
        longitude: 5.0,
        latitude: 0,
        distance: 1.0,
        longitudeSpeed: 13.0,
        latitudeSpeed: 0,
        distanceSpeed: 0,
      );

      expect(position.nakshatraPada, greaterThanOrEqualTo(1));
      expect(position.nakshatraPada, lessThanOrEqualTo(4));
    });
  });

  group('Swiss Ephemeris Integration', () {
    late Jyotish jyotish;

    setUpAll(() async {
      jyotish = Jyotish();
      try {
        await jyotish.initialize();
      } catch (e) {
        print('⚠️  Swiss Ephemeris not found. See SETUP.md for installation.');
        rethrow;
      }
    });

    tearDownAll(() {
      jyotish.dispose();
    });

    test('calculates planetary positions', () async {
      final dateTime = DateTime.utc(2024, 1, 1, 12, 0);
      final location = GeographicLocation(latitude: 0.0, longitude: 0.0);

      final position = await jyotish.getPlanetPosition(
        planet: Planet.sun,
        dateTime: dateTime,
        location: location,
      );

      expect(position.longitude, greaterThanOrEqualTo(0.0));
      expect(position.longitude, lessThan(360.0));
      expect(position.distance, greaterThan(0.0));
    });

    test('calculates sidereal positions', () async {
      final dateTime = DateTime.utc(1994, 7, 28, 5, 5);
      final location = GeographicLocation(
        latitude: 27.7172,
        longitude: 85.3240,
      );

      final flags = CalculationFlags(
        siderealMode: SiderealMode.lahiri,
        calculateSpeed: true,
      );

      final position = await jyotish.getPlanetPosition(
        planet: Planet.sun,
        dateTime: dateTime,
        location: location,
        flags: flags,
      );

      // July 28, 1994: Sun should be in Cancer (sidereal)
      expect(position.zodiacSign, 'Cancer');
      expect(position.positionInSign, greaterThan(10.0));
      expect(position.positionInSign, lessThan(12.0));
    });
  });
}
