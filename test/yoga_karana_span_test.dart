import 'package:flutter_test/flutter_test.dart';
import 'package:tithi/features/panchang/domain/yoga_karana_span.dart';

// Phase 3 follow-up: the tithi detail sheet shows "yoga until 3:42 PM" and
// "karana until 3:28 PM". The provider used to bisect the step-shaped index to
// a minute; the span ends now go through the shared crossing solver on the
// continuous value (Sun+Moon sum for yoga, elongation for karana), so they are
// second-precise and testable without FFI.

void main() {
  final sunrise = DateTime(2026, 10, 24, 6);
  const sunRate = 1.0;
  const moonRate = 13.2;

  Future<({double sun, double moon})?> Function(DateTime) sampler({
    required double sunAtSunrise,
    required double moonAtSunrise,
  }) {
    return (instant) async {
      final days =
          instant.difference(sunrise).inMicroseconds /
          Duration.microsecondsPerDay;
      return (
        sun: (sunAtSunrise + sunRate * days) % 360,
        moon: (moonAtSunrise + moonRate * days) % 360,
      );
    };
  }

  DateTime crossingAfter(double start, double target, double rate) {
    final delta = (target - start) % 360;
    return sunrise.add(
      Duration(
        microseconds: (delta / rate * Duration.microsecondsPerDay).round(),
      ),
    );
  }

  group('resolveYogaKaranaSpan', () {
    test('resolves both span ends to the second', () async {
      // Arrange: Sun 0 deg, Moon 100 deg at sunrise. Yoga index 7 ends when
      // the sum reaches 8 segments; karana index 16 ends at elongation 102.
      final longitudesAt = sampler(sunAtSunrise: 0, moonAtSunrise: 100);
      final expectedYogaEnd = crossingAfter(100, 8 * (360 / 27), 14.2);
      final expectedKaranaEnd = crossingAfter(100, 17 * 6, 12.2);

      // Act
      final span = await resolveYogaKaranaSpan(
        sunrise: sunrise,
        longitudesAt: longitudesAt,
      );

      // Assert
      expect(span, isNotNull);
      expect(span!.yogaIndex, equals(7));
      expect(span.karanaIndex, equals(16));
      expect(
        span.yogaEnd.difference(expectedYogaEnd).inSeconds.abs(),
        lessThanOrEqualTo(1),
      );
      expect(
        span.karanaEnd.difference(expectedKaranaEnd).inSeconds.abs(),
        lessThanOrEqualTo(1),
      );
    });

    test('crosses the 360 wrap for the last yoga and karana', () async {
      // Arrange: sum 350 (yoga 26, the last) and elongation 355 (karana 59,
      // the last). Both ends are the wrap to 0, which the angle fold handles.
      final longitudesAt = sampler(sunAtSunrise: 357.5, moonAtSunrise: 352.5);
      final expectedYogaEnd = crossingAfter(710, 360, 14.2);
      final expectedKaranaEnd = crossingAfter(-5, 360, 12.2);

      // Act
      final span = await resolveYogaKaranaSpan(
        sunrise: sunrise,
        longitudesAt: longitudesAt,
      );

      // Assert
      expect(span, isNotNull);
      expect(span!.yogaIndex, equals(26));
      expect(span.karanaIndex, equals(59));
      expect(
        span.yogaEnd.difference(expectedYogaEnd).inSeconds.abs(),
        lessThanOrEqualTo(1),
      );
      expect(
        span.karanaEnd.difference(expectedKaranaEnd).inSeconds.abs(),
        lessThanOrEqualTo(1),
      );
    });

    test('returns null when the sunrise sample fails', () async {
      // Act
      final span = await resolveYogaKaranaSpan(
        sunrise: sunrise,
        longitudesAt: (instant) async => null,
      );

      // Assert
      expect(span, isNull);
    });

    test('returns null when no boundary is reached', () async {
      // Arrange: a flat value never crosses a segment boundary, so both
      // searches must give up instead of returning the 48-hour cap.
      final span = await resolveYogaKaranaSpan(
        sunrise: sunrise,
        longitudesAt: (instant) async => (sun: 0.0, moon: 0.0),
      );

      // Assert
      expect(span, isNull);
    });
  });
}
