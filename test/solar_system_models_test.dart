import 'package:flutter_test/flutter_test.dart';
import 'package:jyotish/jyotish.dart';
import 'package:tithi/features/solar_system/data/solar_cache.dart';
import 'package:tithi/features/solar_system/data/solar_models.dart';

void main() {
  group('heliocentric projection', () {
    test('maps mean orbital distances to their configured orbit radii', () {
      expect(heliocentricDisplayRadius(0.387), closeTo(0.12, 1e-12));
      expect(heliocentricDisplayRadius(1.0), closeTo(0.28, 1e-12));
      expect(heliocentricDisplayRadius(5.203), closeTo(0.55, 1e-12));
    });

    test('preserves longitude and projects latitude onto the chart plane', () {
      final point = projectHeliocentric(
        longitude: 90,
        latitude: 0,
        distanceAU: 1.0,
      );

      expect(point.x, closeTo(0, 1e-12));
      expect(point.y, closeTo(0.28, 1e-12));
      expect(point.radius, closeTo(0.28, 1e-12));
    });

    test('clamps invalid and out-of-range distances safely', () {
      expect(heliocentricDisplayRadius(double.nan), 0);
      expect(heliocentricDisplayRadius(-1), 0);
      expect(heliocentricDisplayRadius(0.1), 0.1);
      expect(heliocentricDisplayRadius(100), 0.92);
    });
  });

  test('cache keys retain hour precision and view/location identity', () {
    final first = DateTime(2026, 11, 6, 10, 5);
    final sameHour = DateTime(2026, 11, 6, 10, 55);
    final nextHour = DateTime(2026, 11, 6, 11);

    expect(
      solarCacheKey(first, SolarSystemViewMode.heliocentric, 22.57, 88.36),
      solarCacheKey(sameHour, SolarSystemViewMode.heliocentric, 22.57, 88.36),
    );
    expect(
      solarCacheKey(first, SolarSystemViewMode.heliocentric, 22.57, 88.36),
      isNot(
        solarCacheKey(nextHour, SolarSystemViewMode.heliocentric, 22.57, 88.36),
      ),
    );
    expect(
      solarCacheKey(first, SolarSystemViewMode.heliocentric, 22.57, 88.36),
      isNot(solarCacheKey(first, SolarSystemViewMode.geocentric, 22.57, 88.36)),
    );
  });

  test('solar system data can retrieve a planet by identity', () {
    final data = SolarSystemData(
      dateTime: DateTime.now(),
      viewMode: SolarSystemViewMode.heliocentric,
      planets: const [
        PlanetVisualData(
          planet: Planet.earth,
          longitude: 0,
          latitude: 0,
          isRetrograde: false,
          zodiacSign: 'Aries',
          degree: 0,
          visualX: 0.28,
          visualY: 0,
          orbitRadius: 0.28,
        ),
      ],
    );

    expect(data.getPlanet(Planet.earth), isNotNull);
    expect(data.getPlanet(Planet.mars), isNull);
  });
}
