import 'package:flutter_test/flutter_test.dart';
import 'package:tithi/features/panchang/domain/tithi_span.dart';

// Phase 5b: [resolveTithiSpan] is the shared tithi-span resolver behind the
// tithi sheet and the festival export. It replaced the 1-minute binary search
// that used to live in PanchangService, so these tests pin the index math and
// the two wrap boundaries against a linear elongation model - the kind of
// exact answer the native golden test cannot provide.

/// Mean Sun-Moon separation rate, degrees per day (360 / 29.53).
const double _rate = 12.19;

void main() {
  final origin = DateTime(2026, 10, 24);

  double elongationAt(DateTime instant) {
    final days =
        instant.difference(origin).inMicroseconds / Duration.microsecondsPerDay;
    return (0 + _rate * days) % 360;
  }

  /// Linear elongation model anchored [degrees] into tithi [tithiIndex] at
  /// [origin], so both edges sit a predictable distance from the probe.
  double Function(DateTime) elongationModel(double degrees) {
    return (instant) {
      final days =
          instant.difference(origin).inMicroseconds /
          Duration.microsecondsPerDay;
      return (degrees + _rate * days) % 360;
    };
  }

  /// First instant at or after [from] whose elongation reaches [target].
  DateTime crossingForward(
    double target, {
    DateTime? from,
    double Function(DateTime)? model,
  }) {
    final sample = model ?? elongationAt;
    final base = from ?? origin;
    final delta = (target - sample(base)) % 360;
    return base.add(
      Duration(
        microseconds: (delta / _rate * Duration.microsecondsPerDay).round(),
      ),
    );
  }

  /// Last instant at or before [from] whose elongation reaches [target].
  DateTime crossingBackward(
    double target, {
    DateTime? from,
    double Function(DateTime)? model,
  }) {
    final sample = model ?? elongationAt;
    final base = from ?? origin;
    final delta = (sample(base) - target) % 360;
    return base.subtract(
      Duration(
        microseconds: (delta / _rate * Duration.microsecondsPerDay).round(),
      ),
    );
  }

  group('tithiIndexForElongation', () {
    test('maps the 30 segments to the 1-30 index', () {
      expect(tithiIndexForElongation(0), equals(1)); // Shukla Pratipada
      expect(tithiIndexForElongation(11.99), equals(1));
      expect(tithiIndexForElongation(12), equals(2));
      expect(tithiIndexForElongation(84), equals(8)); // Shukla Ashtami
      expect(tithiIndexForElongation(96), equals(9));
      expect(tithiIndexForElongation(180), equals(16)); // Krishna Pratipada
      expect(tithiIndexForElongation(348), equals(30)); // Amavasya
      expect(tithiIndexForElongation(359.99), equals(30));
    });

    test('folds the 360 wrap and negative input to the same index', () {
      // 360 is the end of tithi 30 and the start of tithi 1: the fold must
      // never produce index 31.
      expect(tithiIndexForElongation(360), equals(1));
      expect(tithiIndexForElongation(-1), equals(30));
      expect(tithiIndexForElongation(-360), equals(1));
    });
  });

  group('resolveTithiSpan', () {
    test('resolves a mid-cycle span to the second', () async {
      // Arrange: tithi 8 (Shukla Ashtami, 84-96) with the probe 2 degrees in.
      final model = elongationModel(86);
      final expectedStart = crossingBackward(84, model: model);
      final expectedEnd = crossingForward(96, model: model);

      // Act
      final span = await resolveTithiSpan(
        date: origin,
        tithiIndex: 8,
        elongationAt: (instant) async => model(instant),
      );

      // Assert
      expect(span, isNotNull);
      expect(
        span!.start.difference(expectedStart).inSeconds.abs(),
        lessThanOrEqualTo(1),
      );
      expect(
        span.end.difference(expectedEnd).inSeconds.abs(),
        lessThanOrEqualTo(1),
      );
      expect(span.start.isBefore(origin), isTrue);
      expect(span.end.isAfter(origin), isTrue);
    });

    test('crosses the 360 -> 0 wrap on the start of tithi 1', () async {
      // Arrange: 2 degrees into Shukla Pratipada, so the start edge is the
      // previous Amavasya's 360 -> 0 wrap. The bracket runs 358 -> 2, which the
      // angle fold has to read as one upward crossing.
      final model = elongationModel(2);
      final expectedStart = crossingBackward(0, model: model);
      final expectedEnd = crossingForward(12, model: model);

      // Act
      final span = await resolveTithiSpan(
        date: origin,
        tithiIndex: 1,
        elongationAt: (instant) async => model(instant),
      );

      // Assert
      expect(span, isNotNull);
      expect(
        span!.start.difference(expectedStart).inSeconds.abs(),
        lessThanOrEqualTo(1),
      );
      expect(
        span.end.difference(expectedEnd).inSeconds.abs(),
        lessThanOrEqualTo(1),
      );
      // The start must be the first instant in tithi 1, with the previous
      // sample still in tithi 30 (the solved instant is past the crossing).
      expect(tithiIndexForElongation(model(span.start)), equals(1));
      expect(
        tithiIndexForElongation(
          model(span.start.subtract(const Duration(seconds: 2))),
        ),
        equals(30),
      );
    });

    test('crosses the 360 -> 0 wrap on the end of tithi 30', () async {
      // Arrange: 2 degrees into Krishna Amavasya (348-360). Its end is
      // elongation 360, which folds to target 0.
      final model = elongationModel(350);
      final expectedStart = crossingBackward(348, model: model);
      final expectedEnd = crossingForward(0, model: model);

      // Act
      final span = await resolveTithiSpan(
        date: origin,
        tithiIndex: 30,
        elongationAt: (instant) async => model(instant),
      );

      // Assert
      expect(span, isNotNull);
      expect(
        span!.start.difference(expectedStart).inSeconds.abs(),
        lessThanOrEqualTo(1),
      );
      expect(
        span.end.difference(expectedEnd).inSeconds.abs(),
        lessThanOrEqualTo(1),
      );
      // The end is the first instant of the next lunation's tithi 1.
      expect(tithiIndexForElongation(model(span.end)), equals(1));
    });

    test('returns null for a tithi that does not occur nearby', () async {
      // Arrange: a frozen elongation never leaves tithi 1, so tithi 5 has no
      // occurrence inside the scan window. This is the Kshaya path: the sheet
      // and the export must hide the timings rather than show a wrong span.
      // Act
      final span = await resolveTithiSpan(
        date: origin,
        tithiIndex: 5,
        elongationAt: (instant) async => 0,
      );

      // Assert
      expect(span, isNull);
    });

    test('returns null when the elongation sampler fails', () async {
      // Arrange: an unreadable ephemeris must hide the card, not guess.
      // Act
      final span = await resolveTithiSpan(
        date: origin,
        tithiIndex: 8,
        elongationAt: (instant) async => null,
      );

      // Assert
      expect(span, isNull);
    });
  });
}
