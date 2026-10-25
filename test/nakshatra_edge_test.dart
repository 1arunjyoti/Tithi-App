import 'package:flutter_test/flutter_test.dart';
import 'package:tithi/features/panchang/domain/nakshatra_span.dart';

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

  group('resolveNakshatraSpan', () {
    /// Instant the Moon last entered [longitude], walking back from [origin].
    DateTime crossingBefore(double longitude) {
      final baseLongitude = longitudeAt(origin);
      final delta = (baseLongitude - longitude) % 360;
      return origin.subtract(
        Duration(
          microseconds: (delta / _moonRate * Duration.microsecondsPerDay)
              .round(),
        ),
      );
    }

    test('resolves the sunrise span and both edges', () async {
      // Arrange: index 4 at sunrise, 2 degrees in, so both edges are a clean
      // distance from the bracket ends.
      final expectedStart = crossingBefore(4 * _segment);
      final expectedEnd = crossingOf(5 * _segment);

      // Act
      final span = await resolveNakshatraSpan(
        sunrise: origin,
        indexAt: indexAt,
      );

      // Assert
      expect(span, isNotNull);
      expect(span!.index, equals(4));
      expect(span.nakshatra, equals('Mrigashira'));
      expect(
        span.start.difference(expectedStart).inSeconds.abs(),
        lessThanOrEqualTo(1),
      );
      expect(
        span.end.difference(expectedEnd).inSeconds.abs(),
        lessThanOrEqualTo(1),
      );
      expect(span.start.isBefore(origin), isTrue);
      expect(span.end.isAfter(origin), isTrue);
    });

    test('crosses the Revati to Ashwini wrap', () async {
      // Arrange: the last nakshatra. Its end edge is the 360 -> 0 wrap, which
      // the angle fold has to handle in both directions.
      const double start = 26 * _segment + 2;
      double longitudeAtRevati(DateTime instant) {
        final days =
            instant.difference(origin).inMicroseconds /
            Duration.microsecondsPerDay;
        return (start + _moonRate * days) % 360;
      }

      Future<int?> indexAtRevati(DateTime instant) async =>
          (longitudeAtRevati(instant) / _segment).floor() % 27;

      // Act
      final span = await resolveNakshatraSpan(
        sunrise: origin,
        indexAt: indexAtRevati,
      );

      // Assert
      expect(span, isNotNull);
      expect(span!.index, equals(26));
      expect(span.nakshatra, equals('Revati'));
      expect(
        await indexAtRevati(span.end),
        equals(0),
        reason: 'the end edge is the first instant in Ashwini',
      );
      expect(
        await indexAtRevati(span.start.subtract(const Duration(seconds: 2))),
        equals(25),
        reason: 'the start edge is the first instant in Revati',
      );
    });

    test('returns null when the sunrise sample fails', () async {
      // Act
      final span = await resolveNakshatraSpan(
        sunrise: origin,
        indexAt: (instant) async => null,
      );

      // Assert
      expect(span, isNull);
    });

    test('returns null when no edge is reached', () async {
      // Arrange: a frozen index never leaves the sunrise nakshatra, so both
      // brackets must give up instead of returning the 48-hour cap.
      final span = await resolveNakshatraSpan(
        sunrise: origin,
        indexAt: (instant) async => 4,
      );

      // Assert
      expect(span, isNull);
    });
  });
}
