import 'package:flutter_test/flutter_test.dart';
import 'package:tithi/models/panchang_school.dart';
import 'package:tithi/services/panchang/ephemeris/panchang_ephemeris.dart';
import 'package:tithi/services/panchang/ephemeris/surya_siddhanta_engine.dart';

// The Surya Siddhanta engine is pure Dart: no FFI, no ephemeris files. These
// tests lock the port against the reference algorithm
// (kiranojhanp/surya-siddanta, a public-domain transcription of Burgess 1858).

void main() {
  group('Surya Siddhanta jya table', () {
    test('anchors on the table entries', () {
      expect(SuryaSiddhantaEngine.jyaOf(0), closeTo(0, 1e-9));
      expect(SuryaSiddhantaEngine.jyaOf(30), closeTo(1719, 1e-9));
      expect(SuryaSiddhantaEngine.jyaOf(90), closeTo(3438, 1e-9));
    });

    test('is signed across the lower quadrants', () {
      expect(SuryaSiddhantaEngine.jyaOf(180), closeTo(0, 1e-9));
      expect(SuryaSiddhantaEngine.jyaOf(270), closeTo(-3438, 1e-9));
      expect(SuryaSiddhantaEngine.jyaOf(360), closeTo(0, 1e-9));
    });

    test('mirrors the upper quadrants', () {
      // sin(150) == sin(30); sin(210) == -sin(30).
      expect(
        SuryaSiddhantaEngine.jyaOf(150),
        closeTo(SuryaSiddhantaEngine.jyaOf(30), 1e-9),
      );
      expect(
        SuryaSiddhantaEngine.jyaOf(210),
        closeTo(-SuryaSiddhantaEngine.jyaOf(30), 1e-9),
      );
    });

    test('stays within one table step of a modern sine', () {
      // The 24-point table is coarse; anything worse than this means the
      // interpolation itself is broken.
      for (var degrees = 0; degrees <= 360; degrees += 5) {
        final expected = 3438.0 * _sinDegrees(degrees.toDouble());
        expect(
          SuryaSiddhantaEngine.jyaOf(degrees.toDouble()),
          closeTo(expected, 12),
          reason: 'jya($degrees)',
        );
      }
    });
  });

  group('Surya Siddhanta ahargana', () {
    test('J2000 noon is JD 2451545', () {
      expect(
        SuryaSiddhantaEngine.julianDayAt(DateTime.utc(2000, 1, 1, 12)),
        closeTo(2451545.0, 1e-9),
      );
    });

    test('the Kali epoch has zero ahargana', () {
      // JD 588465.5 is 18 Feb 3102 BCE, i.e. 4713 BCE proleptic Julian.
      // Derive the instant from the JD instead of hard-coding a calendar date.
      final epochMicros = ((kSuryaSiddhantaKaliEpochJd - 2440587.5) *
              Duration.microsecondsPerDay)
          .round();
      final epoch = DateTime.fromMicrosecondsSinceEpoch(epochMicros, isUtc: true);
      expect(SuryaSiddhantaEngine.aharganaAt(epoch), closeTo(0.0, 1e-6));
    });

    test('a local DateTime is interpreted as the instant it represents', () {
      final utc = DateTime.utc(2026, 10, 28, 0, 30);
      final local = utc.toLocal();
      expect(
        SuryaSiddhantaEngine.aharganaAt(local),
        closeTo(SuryaSiddhantaEngine.aharganaAt(utc), 1e-9),
      );
    });
  });

  group('Surya Siddhanta mean longitudes', () {
    const engine = SuryaSiddhantaEngine();

    test('start at zero at the epoch with the classical tuning', () {
      expect(engine.meanSunLongitude(0), closeTo(0, 1e-9));
      expect(engine.meanMoonLongitude(0), closeTo(0, 1e-9));
      expect(engine.meanMoonApsisLongitude(0), closeTo(0, 1e-9));
    });

    test('advance at the daily rate implied by the Mahayuga', () {
      // Sun: 4,320,000 revolutions per 1,577,917,828 days.
      const sunDaily = 360.0 * kSuryaSiddhantaSunRevolutions /
          kSuryaSiddhantaDaysPerMahayuga;
      expect(engine.meanSunLongitude(1), closeTo(sunDaily, 1e-9));

      const moonDaily = 360.0 * kSuryaSiddhantaMoonRevolutions /
          kSuryaSiddhantaDaysPerMahayuga;
      expect(engine.meanMoonLongitude(1), closeTo(moonDaily, 1e-9));
    });

    test('reproduce the text sidereal month and year', () {
      const moonDaily = 360.0 * kSuryaSiddhantaMoonRevolutions /
          kSuryaSiddhantaDaysPerMahayuga;
      expect(360.0 / moonDaily, closeTo(27.32167, 1e-5));

      const sunDaily = 360.0 * kSuryaSiddhantaSunRevolutions /
          kSuryaSiddhantaDaysPerMahayuga;
      expect(360.0 / sunDaily, closeTo(365.25876, 1e-5));
    });

    test('a tuning offset shifts the mean longitude', () {
      const tuned = SuryaSiddhantaEngine(
        tuning: SuryaSiddhantaTuning(sunEpochLongitude: 12.5),
      );
      expect(tuned.meanSunLongitude(0), closeTo(12.5, 1e-9));
    });

    test('an annual bija accumulates linearly', () {
      const tuned = SuryaSiddhantaEngine(
        tuning: SuryaSiddhantaTuning(moonBijaArcSecondsPerYear: 36),
      );
      // One solar year of 36 arc seconds is 0.01 degrees on top of the
      // classical mean motion at the same ahargana.
      expect(
        tuned.meanMoonLongitude(kSuryaSiddhantaSolarYear) -
            engine.meanMoonLongitude(kSuryaSiddhantaSolarYear),
        closeTo(0.01, 1e-9),
      );
    });
  });

  group('Surya Siddhanta true longitudes', () {
    const engine = SuryaSiddhantaEngine();

    test('apply the manda correction with the correct sign', () {
      // At kendra 90 the Sun's equation reaches its maximum, ~2.18 degrees,
      // and is subtracted (apogee to perigee).
      final ahargana = _aharganaWhereSunKendraIs90();
      final mean = engine.meanSunLongitude(ahargana);
      final trueLon = engine.trueSunLongitude(ahargana);
      final delta = _signedDelta(trueLon - mean);
      expect(delta, closeTo(-2.18, 0.05));
    });

    test('the Moon correction is larger than the Sun correction', () {
      // The Moon's epicycle is 32 degrees against the Sun's 14, so its
      // maximum equation is ~5.1 degrees against ~2.2.
      expect(
        _maxEquation(engine, isMoon: true),
        greaterThan(_maxEquation(engine, isMoon: false)),
      );
      expect(_maxEquation(engine, isMoon: true), closeTo(5.1, 0.1));
      expect(_maxEquation(engine, isMoon: false), closeTo(2.2, 0.1));
    });

    test('match the reference algorithm for 2026-10-28 06:00 IST', () {
      // Regression lock on the ported output. The Moon value moved by ~7.5
      // degrees when the manda sign was corrected (see the quadrant test
      // below); the Sun happened to sit in the first quadrant at this instant
      // and so did not change.
      final instant = DateTime.utc(2026, 10, 28, 0, 30);
      final positions = engine.longitudesAt(instant);
      expect(positions.sun, closeTo(189.5913, 1e-3));
      expect(positions.moon, closeTo(37.7101, 1e-3));
    });

    test('applies the manda as a magnitude with a quadrant sign', () {
      // The equation of centre is negative while the kendra runs from apogee
      // to perigee (0..180) and positive on the return half. Applying the
      // quadrant rule to an already-signed jya inverts the correction over
      // half the orbit - worth up to 2 * 5.1 degrees for the Moon and 2 * 2.2
      // for the Sun, which is enough to move a tithi.
      var checked = 0;
      for (var ahargana = 1872500.0; ahargana < 1872600.0; ahargana += 0.37) {
        final mean = engine.meanMoonLongitude(ahargana);
        final kendra = _norm(mean - engine.meanMoonApsisLongitude(ahargana));
        final correction = _signedDelta(
          engine.trueMoonLongitude(ahargana) - mean,
        );

        if (kendra > 5 && kendra < 175) {
          expect(correction, lessThan(0), reason: 'kendra $kendra');
          checked++;
        } else if (kendra > 185 && kendra < 355) {
          expect(correction, greaterThan(0), reason: 'kendra $kendra');
          checked++;
        }
      }
      expect(checked, greaterThan(20));
    });

    test('produce a tithi in the 1..30 range across a lunation', () {
      final start = DateTime.utc(2026, 10);
      for (var hour = 0; hour < 24 * 32; hour += 7) {
        final instant = start.add(Duration(hours: hour));
        final positions = engine.longitudesAt(instant);
        final elapsed = _norm(positions.moon - positions.sun);
        final tithi = elapsed / 12 + 1;
        expect(tithi, greaterThanOrEqualTo(1.0));
        expect(tithi, lessThan(31.0));
      }
    });
  });

  group('Ephemeris selection', () {
    test('bisuddha keeps the Drik path', () {
      final ephemeris = ephemerisFor(PanchangSchool.bisuddha);
      expect(ephemeris.school, PanchangSchool.bisuddha);
      expect(ephemeris.tag, 'drik-lahiri');
      expect(ephemeris, isA<DrikPanchangEphemeris>());
    });

    test('suryasiddhanta uses the pure-Dart engine', () {
      final ephemeris = ephemerisFor(PanchangSchool.suryasiddhanta);
      expect(ephemeris.school, PanchangSchool.suryasiddhanta);
      expect(ephemeris, isA<SuryaSiddhantaEphemeris>());
      expect(ephemeris.tag, 'ss-classical');
    });

    test('a calibrated tuning changes the provenance tag', () {
      final ephemeris = ephemerisFor(
        PanchangSchool.suryasiddhanta,
        tuning: const SuryaSiddhantaTuning(moonBijaArcSecondsPerYear: 36),
      );
      expect(ephemeris.tag, isNot('ss-classical'));
    });

    test('the Surya Siddhanta path ignores the observer position', () async {
      final ephemeris = ephemerisFor(PanchangSchool.suryasiddhanta);
      final instant = DateTime.utc(2026, 10, 28, 0, 30);
      final delhi = await ephemeris.longitudesAt(
        instant,
        latitude: 28.6139,
        longitude: 77.2090,
      );
      final sydney = await ephemeris.longitudesAt(
        instant,
        latitude: -33.8688,
        longitude: 151.2093,
      );
      expect(delhi.sun, sydney.sun);
      expect(delhi.moon, sydney.moon);
    });
  });

  group('PanchangSchool', () {
    test('parses stored names and falls back to bisuddha', () {
      expect(panchangSchoolFromName('suryasiddhanta'),
          PanchangSchool.suryasiddhanta);
      expect(panchangSchoolFromName('bisuddha'), PanchangSchool.bisuddha);
      expect(panchangSchoolFromName(null), PanchangSchool.bisuddha);
      expect(panchangSchoolFromName('nonsense'), PanchangSchool.bisuddha);
    });

    test('only bisuddha needs Swiss positions', () {
      expect(PanchangSchool.bisuddha.usesSwissPositions, isTrue);
      expect(PanchangSchool.suryasiddhanta.usesSwissPositions, isFalse);
    });
  });
}

double _norm(double degrees) {
  final value = degrees % 360;
  return value < 0 ? value + 360 : value;
}

double _signedDelta(double degrees) {
  var value = _norm(degrees);
  if (value > 180) value -= 360;
  return value;
}

double _sinDegrees(double degrees) {
  // Small self-contained sine so the test does not depend on dart:math's
  // radian API being used correctly elsewhere.
  const pi = 3.1415926535897932;
  final radians = degrees * pi / 180.0;
  var term = radians;
  var sum = radians;
  for (var i = 1; i <= 9; i++) {
    term *= -radians * radians / ((2 * i) * (2 * i + 1));
    sum += term;
  }
  return sum;
}

/// Ahargana at which the Sun's manda kendra is 90 degrees.
double _aharganaWhereSunKendraIs90() {
  const engine = SuryaSiddhantaEngine();
  // The kendra is (mean Sun - apogee), so the target is 90 degrees of kendra,
  // not 90 degrees of mean longitude.
  const target = 90.0;
  var ahargana = 1_870_000.0;
  for (var i = 0; i < 40; i++) {
    final kendra = _norm(
      engine.meanSunLongitude(ahargana) - kSuryaSiddhantaSunApogee,
    );
    final delta = _signedDelta(target - kendra);
    if (delta.abs() < 1e-9) break;
    ahargana +=
        delta /
        (360.0 * kSuryaSiddhantaSunRevolutions /
            kSuryaSiddhantaDaysPerMahayuga);
  }
  return ahargana;
}

/// Peak absolute equation of centre over one anomalistic cycle.
double _maxEquation(SuryaSiddhantaEngine engine, {required bool isMoon}) {
  var peak = 0.0;
  final ahargana = _aharganaWhereSunKendraIs90();
  for (var day = 0; day < 4000; day++) {
    final a = ahargana + day;
    final mean = isMoon
        ? engine.meanMoonLongitude(a)
        : engine.meanSunLongitude(a);
    final trueLon =
        isMoon ? engine.trueMoonLongitude(a) : engine.trueSunLongitude(a);
    final delta = _signedDelta(trueLon - mean).abs();
    if (delta > peak) peak = delta;
  }
  return peak;
}
