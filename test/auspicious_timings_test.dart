import 'package:flutter_test/flutter_test.dart';
import 'package:tithi/services/auspicious_timings.dart';

String f(DateTime t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

AuspiciousTimings oct3() => AuspiciousTimings.calculate(
  date: DateTime(2026, 10, 3),
  sunrise: DateTime(2026, 10, 3, 5, 24),
  sunset: DateTime(2026, 10, 3, 17, 36),
  nextSunrise: DateTime(2026, 10, 4, 5, 25),
);

void main() {
  group('AuspiciousTimings', () {
    test('Abhijit is the 8th of 15 day-muhurtas', () {
      // Arrange + Act
      final a = oct3();

      // Assert: D = 732 min, muhurta 48.8; 11:05:36 and 11:54:24 round
      // to the mockup's 11:06-11:54.
      expect(f(a.abhijit.start), equals('11:06'));
      expect(f(a.abhijit.end), equals('11:54'));
    });

    test('Brahma Muhurta defaults to night-based', () {
      // Arrange: N = 709 min (17:36 -> 5:25), night-muhurta ~= 47.27.
      // Act
      final a = oct3();

      // Assert: [5:24 - 94.53m, 5:24 - 47.27m] -> 3:49-4:37.
      expect(f(a.brahmaMuhurta.start), equals('03:49'));
      expect(f(a.brahmaMuhurta.end), equals('04:37'));
    });

    test('Brahma Muhurta fixed-clock option', () {
      // Arrange + Act
      final a = AuspiciousTimings.calculate(
        date: DateTime(2026, 10, 3),
        sunrise: DateTime(2026, 10, 3, 5, 24),
        sunset: DateTime(2026, 10, 3, 17, 36),
        nextSunrise: DateTime(2026, 10, 4, 5, 25),
        useFixedBrahmaMuhurta: true,
      );

      // Assert: [sunrise - 96, sunrise - 48].
      expect(f(a.brahmaMuhurta.start), equals('03:48'));
      expect(f(a.brahmaMuhurta.end), equals('04:36'));
    });

    test('Madhyahna instant and middle-fifth window', () {
      // Arrange: Delhi 6:05 sunrise, 12h22m day (spec's verified case).
      // Act
      final m = AuspiciousTimings.calculate(
        date: DateTime(2026, 1, 15),
        sunrise: DateTime(2026, 1, 15, 6, 5),
        sunset: DateTime(2026, 1, 15, 18, 27),
        nextSunrise: DateTime(2026, 1, 16, 6, 5),
      );

      // Assert: instant 12:16, window 11:02-13:30 (spec: 11:02-13:30/31).
      expect(f(m.madhyahnaInstant), equals('12:16'));
      expect(f(m.madhyahnaWindow.start), equals('11:02'));
      expect(f(m.madhyahnaWindow.end), equals('13:30'));

      // Oct 3 midpoint is the sunrise-sunset mean.
      expect(f(oct3().madhyahnaInstant), equals('11:30'));
    });

    test('Nishita is the 8th of 15 night-muhurtas', () {
      // Arrange: N = 709 -> [17:36 + 330.87m, 17:36 + 377.87m].
      // Act
      final a = oct3();

      // Assert
      expect(f(a.nishita.start), equals('23:07'));
      expect(f(a.nishita.end), equals('23:54'));
    });

    test('Godhuli starts at sunset for one day-ghati', () {
      // Arrange + Act
      final a = oct3();

      // Assert: D/30 = 24.4 min -> [17:36, 18:00:24] -> 18:00.
      expect(f(a.godhuli.start), equals('17:36'));
      expect(f(a.godhuli.end), equals('18:00'));
    });

    test('Pradosha conventions', () {
      // Arrange: N = 709 -> classical N/5 = 141.8 min.
      // Act
      final classical = oct3();
      DateTime sunset = DateTime(2026, 10, 3, 17, 36);
      AuspiciousTimings withConvention(PradoshaConvention c) =>
          AuspiciousTimings.calculate(
            date: DateTime(2026, 10, 3),
            sunrise: DateTime(2026, 10, 3, 5, 24),
            sunset: sunset,
            nextSunrise: DateTime(2026, 10, 4, 5, 25),
            pradoshaConvention: c,
          );

      // Assert: classical [17:36, 19:57:48] -> 19:58.
      expect(f(classical.pradosha.start), equals('17:36'));
      expect(f(classical.pradosha.end), equals('19:58'));
      // 96-minute variant ends 19:12; ±45 variant spans 16:51-18:21.
      expect(
        f(withConvention(PradoshaConvention.twoMuhurtas).pradosha.end),
        equals('19:12'),
      );
      final popular = withConvention(PradoshaConvention.plusMinus45).pradosha;
      expect(f(popular.start), equals('16:51'));
      expect(f(popular.end), equals('18:21'));
    });

    test('Pradosha clips at Trayodashi end', () {
      // Arrange + Act: Trayodashi ends 19:00, inside the 17:36-19:58 span.
      final clipped = AuspiciousTimings.calculate(
        date: DateTime(2026, 10, 3),
        sunrise: DateTime(2026, 10, 3, 5, 24),
        sunset: DateTime(2026, 10, 3, 17, 36),
        nextSunrise: DateTime(2026, 10, 4, 5, 25),
        tithiNumber: 13,
        tithiEnd: DateTime(2026, 10, 3, 19, 0),
      );

      // Assert
      expect(f(clipped.pradosha.start), equals('17:36'));
      expect(f(clipped.pradosha.end), equals('19:00'));
    });

    test('no clipping off Trayodashi or outside the span', () {
      // Arrange + Act
      DateTime end(int h, int m) => DateTime(2026, 10, 3, h, m);
      AuspiciousTimings calc({int? tithi, DateTime? tithiEnd}) =>
          AuspiciousTimings.calculate(
            date: DateTime(2026, 10, 3),
            sunrise: DateTime(2026, 10, 3, 5, 24),
            sunset: DateTime(2026, 10, 3, 17, 36),
            nextSunrise: DateTime(2026, 10, 4, 5, 25),
            tithiNumber: tithi,
            tithiEnd: tithiEnd,
          );

      // Assert: non-Trayodashi, tithi ending past the span, or tithi
      // ending before sunset all leave the classical end untouched.
      expect(f(calc(tithi: 12, tithiEnd: end(19, 0)).pradosha.end),
          equals('19:58'));
      expect(f(calc().pradosha.end), equals('19:58'));
      expect(f(calc(tithi: 13, tithiEnd: end(21, 0)).pradosha.end),
          equals('19:58'));
      expect(f(calc(tithi: 13, tithiEnd: end(17, 0)).pradosha.end),
          equals('19:58'));
    });

    test('Abhijit weekday rules', () {
      // Arrange: Oct 7 2026 Wednesday, Oct 3 Saturday, Oct 5 Monday.
      // Act + Assert
      expect(
        AuspiciousTimings.abhijitAvoided(DateTime(2026, 10, 7)),
        isTrue,
      );
      expect(
        AuspiciousTimings.abhijitBoosted(DateTime(2026, 10, 3)),
        isTrue,
      );
      expect(
        AuspiciousTimings.abhijitAvoided(DateTime(2026, 10, 5)),
        isFalse,
      );
      expect(
        AuspiciousTimings.abhijitBoosted(DateTime(2026, 10, 5)),
        isFalse,
      );
    });
  });
}
