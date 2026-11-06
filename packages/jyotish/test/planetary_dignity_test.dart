import 'package:jyotish/jyotish.dart';
import 'package:test/test.dart';

void main() {
  group('Planetary dignity', () {
    test('Venus debilitation is 27 Virgo, not 15 Virgo', () {
      expect(debilitationDegreeFor(Planet.venus), 177.0);
      expect(
        dignityForLongitude(Planet.venus, 177.0),
        PlanetaryDignity.debilitated,
      );
    });

    test('Jupiter debilitation is 5 Capricorn', () {
      expect(debilitationDegreeFor(Planet.jupiter), 275.0);
      expect(
        dignityForLongitude(Planet.jupiter, 275.0),
        PlanetaryDignity.debilitated,
      );
    });

    test('moola trikona is evaluated before own sign', () {
      expect(
        dignityForLongitude(Planet.mercury, 70.0), // 10° Gemini
        PlanetaryDignity.ownSign,
      );
      // Mercury in Virgo is exalted by sign; exaltation is evaluated before
      // moola trikona, so its Virgo 16-20° range is intentionally shadowed.
      expect(
        dignityForLongitude(Planet.mercury, 168.0), // 18° Virgo
        PlanetaryDignity.exalted,
      );
      expect(
        dignityForLongitude(Planet.sun, 130.0), // 10° Leo
        PlanetaryDignity.moolaTrikona,
      );
      expect(
        dignityForLongitude(Planet.sun, 145.0), // 25° Leo
        PlanetaryDignity.ownSign,
      );
      expect(
        dignityForLongitude(Planet.venus, 190.0), // 10° Libra
        PlanetaryDignity.moolaTrikona,
      );
      expect(
        dignityForLongitude(Planet.saturn, 310.0), // 10° Aquarius
        PlanetaryDignity.moolaTrikona,
      );
    });

    test('exaltation still wins over moola trikona', () {
      // The Moon's exaltation and moola-trikona share Taurus.
      expect(
        dignityForLongitude(Planet.moon, 40.0), // 10° Taurus
        PlanetaryDignity.exalted,
      );
    });

    test('moola trikona honours its degree range', () {
      expect(
        dignityForLongitude(Planet.jupiter, 250.0), // 10° Sagittarius
        PlanetaryDignity.moolaTrikona,
      );
      expect(
        dignityForLongitude(Planet.jupiter, 251.0), // 11° Sagittarius
        PlanetaryDignity.ownSign,
      );
      expect(
        dignityForLongitude(Planet.mars, 12.0), // 12° Aries, inclusive
        PlanetaryDignity.moolaTrikona,
      );
      expect(
        dignityForLongitude(Planet.mars, 12.1),
        PlanetaryDignity.ownSign,
      );
    });

    test('normalizes wrapped and negative longitudes', () {
      expect(
        dignityForLongitude(Planet.sun, 490.0), // 130° = 10° Leo
        PlanetaryDignity.moolaTrikona,
      );
      expect(
        dignityForLongitude(Planet.sun, -230.0), // 130°
        PlanetaryDignity.moolaTrikona,
      );
    });

    test('rejects a non-finite longitude', () {
      expect(
        () => dignityForLongitude(Planet.sun, double.nan),
        throwsArgumentError,
      );
    });
  });
}
