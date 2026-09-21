import 'package:flutter_test/flutter_test.dart';
import 'package:tithi/features/calendar/domain/month_navigation.dart';

void main() {
  group('adaptiveSwipeDirection', () {
    test('fast fling navigates regardless of distance', () {
      // Arrange: release speeds past the fling threshold.

      // Act + Assert: left fling advances, right fling retreats.
      expect(
        adaptiveSwipeDirection(velocity: -500, distance: 0),
        equals(1),
      );
      expect(
        adaptiveSwipeDirection(velocity: 500, distance: 0),
        equals(-1),
      );
    });

    test('slow drag past the slop navigates without fling speed', () {
      // Arrange: the release velocity of a deliberate slow drag.

      // Act + Assert: left drag advances, right drag retreats.
      expect(
        adaptiveSwipeDirection(velocity: -50, distance: -120),
        equals(1),
      );
      expect(
        adaptiveSwipeDirection(velocity: 50, distance: 120),
        equals(-1),
      );
    });

    test('short slow drags stay (no accidental turns)', () {
      // Arrange: taps, jitters, and sub-slop drags.

      // Act + Assert
      expect(adaptiveSwipeDirection(velocity: 0, distance: 0), equals(0));
      expect(
        adaptiveSwipeDirection(velocity: 100, distance: 40),
        equals(0),
      );
      expect(
        adaptiveSwipeDirection(velocity: -100, distance: -40),
        equals(0),
      );
    });

    test('boundary values need to exceed, not meet, thresholds', () {
      // Arrange: exactly at threshold in both axes.

      // Act + Assert
      expect(
        adaptiveSwipeDirection(
          velocity: -adaptiveSwipeVelocityThreshold,
          distance: -adaptiveSwipeDistanceThreshold,
        ),
        equals(0),
      );
    });
  });
}
