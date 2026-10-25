import 'package:flutter_test/flutter_test.dart';
import 'package:tithi/features/panchang/domain/tithi_transitions.dart';

// Phase 3: [bisectNakshatraEdge] is the wrapper the tithi sheet uses to show
// "Rohini until 3:42 PM". It aims half a nakshatra past the sunrise index (or
// before it for the start edge) so a step-shaped index sampler still presents
// one upward crossing to [solveAngleCrossing]. These tests pin that target
// math against a linear Moon model, which the generic solver tests cannot do.

const double _segment = 360.0 / 27.0;
const double _moonRate = 13.176; // mean Moon motion, degrees/day

void main() {
  final origin = DateTime(2026, 10, 24);
  // 2 degrees into the sunrise nakshatra, so both edges are a clean distance
  // away from the bracket ends.
  const double startLongitude = 4 * _segment + 2;

  double longitudeAt(DateTime instant) {
    final days =
        instant.difference(origin).inMicroseconds /
        Duration.microsecondsPerDay;
    return (startLongitude + _moonRate * days) % 360;
  }

  Future<int?> indexAt(DateTime instant) async =>
      (longitudeAt(instant) / _segment).floor() % 27;

  /// First instant at or after [from] whose longitude reaches [longitude].
  DateTime crossingOf(double longitude, {DateTime? from}) {
    final base = from ?? origin;
    final baseLongitude = longitudeAt(base);
    final delta = (longitude - baseLongitude) % 360;
    return base.add(
      Duration(
        microseconds: (delta / _moonRate * Duration.microsecondsPerDay).round(),
      ),
    );
  }

  group('bisectNakshatraEdge', () {
    test('finds the end edge of the sunrise nakshatra', () async {
      // Arrange: index 4 at lo, index 5 at hi. The end edge is where the
      // Moon enters the next nakshatra (longitude 5 * segment).
      final lo = origin;
      final hi = origin.add(const Duration(days: 1));
      final expected = crossingOf(5 * _segment);

      // Act
      final solved = await bisectNakshatraEdge(
        lo: lo,
        hi: hi,
        sunriseIndex: 4,
        findStart: false,
        indexAt: indexAt,
      );

      // Assert: the first instant in the next nakshatra, within a second.
      expect(solved, isNotNull);
      expect(solved!.isBefore(expected), isFalse);
      expect(solved.difference(expected).inSeconds.abs(), lessThanOrEqualTo(1));
      expect(await indexAt(solved), equals(5));
      expect(
        await indexAt(solved.subtract(const Duration(seconds: 2))),
        equals(4),
      );
    });

    test('finds the start edge of the sunrise nakshatra', () async {
      // Arrange: index 3 at lo, index 4 at hi. The start edge is where the
      // Moon enters the sunrise nakshatra (longitude 4 * segment).
      final lo = origin.subtract(const Duration(days: 1));
      final hi = origin;
      final expected = crossingOf(4 * _segment, from: lo);

      // Act
      final solved = await bisectNakshatraEdge(
        lo: lo,
        hi: hi,
        sunriseIndex: 4,
        findStart: true,
        indexAt: indexAt,
      );

      // Assert: the first instant in the sunrise nakshatra.
      expect(solved, isNotNull);
      expect(solved!.isBefore(expected), isFalse);
      expect(solved.difference(expected).inSeconds.abs(), lessThanOrEqualTo(1));
      expect(await indexAt(solved), equals(4));
      expect(
        await indexAt(solved.subtract(const Duration(seconds: 2))),
        equals(3),
      );
    });

    test('returns null when the index sampler fails', () async {
      // Arrange: an unreadable Moon position must hide the card, not guess.
      final lo = origin;
      final hi = origin.add(const Duration(days: 1));

      // Act
      final solved = await bisectNakshatraEdge(
        lo: lo,
        hi: hi,
        sunriseIndex: 4,
        findStart: false,
        indexAt: (instant) async => null,
      );

      // Assert
      expect(solved, isNull);
    });
  });
}
