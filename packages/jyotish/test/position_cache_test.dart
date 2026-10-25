import 'package:jyotish/jyotish.dart';
import 'package:test/test.dart';

/// Cache keys are typed and include only inputs that change the result:
/// frame/ayanamsa/instant always, location and altitude only when topocentric.
void main() {
  group('Position cache identity', () {
    late EphemerisService service;

    final dateTime = DateTime.utc(2024, 1, 1, 12);
    final delhi = GeographicLocation(latitude: 28.6139, longitude: 77.2090);
    final chennai = GeographicLocation(latitude: 13.0827, longitude: 80.2707);

    setUp(() async {
      service = EphemerisService();
      await service.initialize();
    });

    tearDown(() {
      service.dispose();
    });

    test('geocentric results ignore the observer location', () async {
      final first = await service.calculatePlanetPosition(
        planet: Planet.sun,
        dateTime: dateTime,
        location: delhi,
        flags: CalculationFlags.defaultFlags(),
      );
      final second = await service.calculatePlanetPosition(
        planet: Planet.sun,
        dateTime: dateTime,
        location: chennai,
        flags: CalculationFlags.defaultFlags(),
      );

      expect(identical(first, second), isTrue);
      expect(service.positionCacheSize, 1);
    });

    test('topocentric results include altitude in the key', () async {
      final seaLevel = GeographicLocation(
        latitude: 28.6139,
        longitude: 77.2090,
        altitude: 0,
      );
      final highAltitude = GeographicLocation(
        latitude: 28.6139,
        longitude: 77.2090,
        altitude: 2000,
      );
      final flags = CalculationFlags.topocentric();

      final first = await service.calculatePlanetPosition(
        planet: Planet.moon,
        dateTime: dateTime,
        location: seaLevel,
        flags: flags,
      );
      final second = await service.calculatePlanetPosition(
        planet: Planet.moon,
        dateTime: dateTime,
        location: highAltitude,
        flags: flags,
      );

      expect(identical(first, second), isFalse);
      expect(service.positionCacheSize, 2);
    });

    test('tropical and sidereal positions never share an entry', () async {
      final sidereal = await service.calculatePlanetPosition(
        planet: Planet.sun,
        dateTime: dateTime,
        location: delhi,
        flags: CalculationFlags.defaultFlags(),
      );
      final tropical = await service.calculatePlanetPosition(
        planet: Planet.sun,
        dateTime: dateTime,
        location: delhi,
        flags: CalculationFlags.astronomical(heliocentric: false),
      );

      expect(identical(sidereal, tropical), isFalse);
      expect(service.positionCacheSize, 2);
      final separation =
          (tropical.longitude - sidereal.longitude + 540) % 360 - 180;
      expect(separation, closeTo(24.2, 2));
    });

    test('the instant is part of the key to the microsecond', () async {
      final first = await service.calculatePlanetPosition(
        planet: Planet.sun,
        dateTime: DateTime.utc(2024, 1, 1, 12, 0, 0, 0, 1),
        location: delhi,
        flags: CalculationFlags.defaultFlags(),
      );
      final second = await service.calculatePlanetPosition(
        planet: Planet.sun,
        dateTime: DateTime.utc(2024, 1, 1, 12, 0, 0, 0, 2),
        location: delhi,
        flags: CalculationFlags.defaultFlags(),
      );

      expect(identical(first, second), isFalse);
      expect(service.positionCacheSize, 2);
    });

    test('clearCache releases every entry', () {
      service.calculateSunMoon(
        dateTime: dateTime,
        location: delhi,
        flags: CalculationFlags.defaultFlags(),
      );
      expect(service.positionCacheSize, 2);

      service.clearCache();
      expect(service.positionCacheSize, 0);
    });
  });
}
