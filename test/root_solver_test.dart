import 'package:flutter_test/flutter_test.dart';

import 'package:tithi/features/panchang/domain/panchang_crossings.dart';
import 'package:tithi/features/panchang/domain/root_solver.dart';

/// A sampler driven by an explicit value at [origin] plus [degreesPerDay].
Future<double?> Function(DateTime) _linearSampler({
  required DateTime origin,
  required double startDegrees,
  required double degreesPerDay,
}) {
  return (instant) async {
    final days =
        instant.difference(origin).inMicroseconds /
        Duration.microsecondsPerDay;
    return (startDegrees + degreesPerDay * days) % 360;
  };
}

DateTime _plusSeconds(DateTime base, double seconds) {
  return base.add(Duration(microseconds: (seconds * 1e6).round()));
}

void main() {
  group('signedAngleDelta', () {
    test('folds a difference into (-180, 180]', () {
      expect(signedAngleDelta(359, 0), closeTo(-1, 1e-9));
      expect(signedAngleDelta(1, 0), closeTo(1, 1e-9));
      expect(signedAngleDelta(190, 0), closeTo(-170, 1e-9));
      expect(signedAngleDelta(0, 350), closeTo(10, 1e-9));
    });

    test('treats the antipode as positive 180', () {
      expect(signedAngleDelta(180, 0), equals(180));
      expect(signedAngleDelta(0, 180), equals(180));
    });
  });

  group('solveRoot', () {
    test('finds a linear crossing to the requested tolerance', () async {
      // Arrange: residual is 0 exactly 5h after the origin.
      final origin = DateTime(2026, 10, 24);
      final crossing = origin.add(const Duration(hours: 5));

      // Act
      final solved = await solveRoot(
        before: origin,
        after: origin.add(const Duration(days: 1)),
        residualAt: (instant) async =>
            instant.difference(crossing).inMicroseconds.toDouble(),
      );

      // Assert: the first instant past the root, within a second of it.
      expect(solved, isNotNull);
      expect(solved!.isBefore(crossing), isFalse);
      expect(solved.difference(crossing), lessThanOrEqualTo(
        const Duration(seconds: 1),
      ));
    });

    test('rejects a bracket that does not straddle the root', () async {
      // Arrange: residual stays negative across the whole bracket.
      final origin = DateTime(2026, 10, 24);

      // Act
      final solved = await solveRoot(
        before: origin,
        after: origin.add(const Duration(hours: 2)),
        residualAt: (instant) async => -1,
      );

      // Assert: null instead of a plausible-looking wrong instant.
      expect(solved, isNull);
    });

    test('rejects a bracket already past the root', () async {
      final origin = DateTime(2026, 10, 24);

      final solved = await solveRoot(
        before: origin,
        after: origin.add(const Duration(hours: 2)),
        residualAt: (instant) async => 1,
      );

      expect(solved, isNull);
    });

    test('aborts when a sample fails', () async {
      final origin = DateTime(2026, 10, 24);

      final solved = await solveRoot(
        before: origin,
        after: origin.add(const Duration(hours: 2)),
        residualAt: (instant) async => null,
      );

      expect(solved, isNull);
    });

    test('rejects an empty or reversed bracket', () async {
      final origin = DateTime(2026, 10, 24);

      expect(
        await solveRoot(
          before: origin,
          after: origin,
          residualAt: (instant) async => 0,
        ),
        isNull,
      );
      expect(
        await solveRoot(
          before: origin,
          after: origin.subtract(const Duration(hours: 1)),
          residualAt: (instant) async => 0,
        ),
        isNull,
      );
    });

    test('does not solve a descending crossing', () async {
      // Arrange: residual goes +1 -> -1 across the bracket. The contract is
      // upward-only, so this must return null rather than a root.
      final origin = DateTime(2026, 10, 24);
      final pivot = origin.add(const Duration(hours: 1));

      // Act
      final solved = await solveRoot(
        before: origin,
        after: origin.add(const Duration(hours: 2)),
        residualAt: (instant) async =>
            instant.isBefore(pivot) ? 1.0 : -1.0,
      );

      // Assert
      expect(solved, isNull);
    });
  });

  group('solveAngleCrossing', () {
    test('crosses the 360 -> 0 wrap', () async {
      // Arrange: elapsed angle starts at 350 degrees and runs 12/day, so the
      // wrap (new moon) is 10 degrees - ten hours - into the bracket.
      final origin = DateTime(2026, 10, 24);
      const rate = 12.0;
      final crossing = _plusSeconds(origin, 10 / rate * 86400);

      // Act
      final solved = await solveAngleCrossing(
        before: origin,
        after: origin.add(const Duration(days: 4)),
        valueAt: _linearSampler(
          origin: origin,
          startDegrees: 350,
          degreesPerDay: rate,
        ),
        target: 0,
      );

      // Assert
      expect(solved, isNotNull);
      expect(solved!.isBefore(crossing), isFalse);
      expect(
        solved.difference(crossing),
        lessThanOrEqualTo(const Duration(seconds: 1)),
      );
    });

    test('finds a mid-cycle target', () async {
      // Arrange: 13 degrees/day from 100 degrees, target 180 (~6.15 days).
      final origin = DateTime(2026, 10, 24);
      final crossing = _plusSeconds(origin, 80 / 13 * 86400);

      // Act
      final solved = await solveAngleCrossing(
        before: origin,
        after: origin.add(const Duration(days: 10)),
        valueAt: _linearSampler(
          origin: origin,
          startDegrees: 100,
          degreesPerDay: 13,
        ),
        target: 180,
      );

      // Assert
      expect(solved, isNotNull);
      expect(solved!.isBefore(crossing), isFalse);
      expect(
        solved.difference(crossing),
        lessThanOrEqualTo(const Duration(seconds: 1)),
      );
    });
  });

  group('findNewMoonInstant', () {
    test('refines an estimate that is hours off', () async {
      // Arrange: a real lunation's elapsed rate, with the estimate 10h late.
      final trueNewMoon = DateTime(2026, 10, 10, 4, 30);
      final estimate = trueNewMoon.add(const Duration(hours: 10));
      final sampler = _linearSampler(
        origin: trueNewMoon,
        startDegrees: 0,
        degreesPerDay: 12.19,
      );

      // Act
      final solved = await findNewMoonInstant(
        estimate: estimate,
        elapsedDegreesAt: sampler,
      );

      // Assert: seconds, not the ~3h the old two-round approximation allowed.
      expect(solved, isNotNull);
      expect(
        solved!.difference(trueNewMoon).inSeconds.abs(),
        lessThanOrEqualTo(1),
      );
    });

    test('returns null when the window holds no wrap', () async {
      // Arrange: flat value, so no crossing anywhere in the window.
      final estimate = DateTime(2026, 10, 10, 12);

      // Act
      final solved = await findNewMoonInstant(
        estimate: estimate,
        elapsedDegreesAt: (instant) async => 120,
      );

      // Assert
      expect(solved, isNull);
    });
  });

  group('resolveNewMoonInstant', () {
    test('widens the window when the estimate is days off', () async {
      // Arrange: the true new moon is 5 days before the estimate, so the
      // default ±3 day window starts after it and holds no wrap. The ±7 day
      // retry must still find the exact instant instead of a noon estimate.
      final trueNewMoon = DateTime(2026, 10, 10, 4, 30);
      final estimate = trueNewMoon.add(const Duration(days: 5));
      final sampler = _linearSampler(
        origin: trueNewMoon,
        startDegrees: 0,
        degreesPerDay: 12.19,
      );

      // Act
      final solved = await resolveNewMoonInstant(
        estimate: estimate,
        elapsedDegreesAt: sampler,
      );

      // Assert
      expect(solved, isNotNull);
      expect(
        solved!.difference(trueNewMoon).inSeconds.abs(),
        lessThanOrEqualTo(1),
      );
    });

    test('returns null when every window fails', () async {
      // Arrange: flat value, so widening cannot manufacture a crossing. The
      // service turns this into a loud failure rather than a noon guess.
      final estimate = DateTime(2026, 10, 10, 12);

      // Act
      final solved = await resolveNewMoonInstant(
        estimate: estimate,
        elapsedDegreesAt: (instant) async => 120,
      );

      // Assert
      expect(solved, isNull);
    });
  });

  group('findSankrantiInstant', () {
    test('resolves a solar ingress to the second', () async {
      // Arrange: mean Sun rate, ingress into the next sign at 240 degrees.
      final origin = DateTime(2026, 11, 16);
      const rate = 0.9856;
      final trueIngress = _plusSeconds(origin, 30 / rate * 86400);
      final estimate = trueIngress.add(const Duration(hours: 2));

      // Act
      final solved = await findSankrantiInstant(
        estimate: estimate,
        sunLongitudeAt: _linearSampler(
          origin: origin,
          startDegrees: 210,
          degreesPerDay: rate,
        ),
        boundaryDegrees: 240,
      );

      // Assert
      expect(solved, isNotNull);
      expect(solved!.isBefore(trueIngress), isFalse);
      expect(
        solved.difference(trueIngress),
        lessThanOrEqualTo(const Duration(seconds: 1)),
      );
    });
  });
}
