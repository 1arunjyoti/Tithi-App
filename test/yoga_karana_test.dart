import 'package:flutter_test/flutter_test.dart';
import 'package:tithi/models/festival.dart';

void main() {
  group('Yoga index', () {
    test('27 segments of 13deg20m over the Sun+Moon sum', () {
      // Arrange + Act + Assert
      expect(yogaIndexFor(0, 0), equals(0)); // Vishkambha
      expect(yogaNames[yogaIndexFor(0, 0)], equals('Vishkambha'));
      expect(yogaIndexFor(0, 13.4), equals(1)); // Priti
      expect(yogaIndexFor(180, 180), equals(0)); // 360 wraps to 0
      expect(yogaNames[26], equals('Vaidhriti'));
    });

    test('sum normalizes past 360 and below 0', () {
      // Arrange: 350 + 20 = 370 -> 10 deg
      // Act + Assert
      expect(yogaIndexFor(350, 20), equals(0));
      // Arrange: -10 + 5 = -5 -> 355 deg -> last segment
      // Act + Assert
      expect(yogaIndexFor(-10, 5), equals(26));
    });

    test('spot-check Sukarma and Dhriti order', () {
      expect(yogaNames[6], equals('Sukarma'));
      expect(yogaNames[7], equals('Dhriti'));
      expect(yogaNames[(6 + 1) % 27], equals('Dhriti'));
      expect(yogaNames[(26 + 1) % 27], equals('Vishkambha'));
    });
  });

  group('Karana mapping', () {
    test('spec sanity: index 15 Bava, 16 Balava', () {
      // Arrange: elongation 93deg -> floor(93/6) = 15 (Shukla Ashtami
      // 2nd half); 99deg -> 16 (Navami 1st half).
      // Act + Assert
      expect(karanaIndexFor(0, 93), equals(15));
      expect(karanaNameForIndex(15), equals('Bava'));
      expect(karanaIndexFor(0, 99), equals(16));
      expect(karanaNameForIndex(16), equals('Balava'));
    });

    test('fixed karanas at the cycle edges', () {
      // Arrange + Act + Assert
      expect(karanaNameForIndex(0), equals('Kimstughna'));
      expect(karanaNameForIndex(57), equals('Shakuni'));
      expect(karanaNameForIndex(58), equals('Chatushpada'));
      expect(karanaNameForIndex(59), equals('Naga'));
      expect(karanaIndexFor(0, 0), equals(0));
      expect(karanaIndexFor(0, 345), equals(57));
      expect(karanaIndexFor(0, 351), equals(58));
      expect(karanaIndexFor(0, 357), equals(59));
      expect(karanaIndexFor(0, 359.9), equals(59));
    });

    test('movable set runs 8 full 7-cycles over slots 1-56', () {
      // Arrange + Act + Assert
      expect(movableKaranas, hasLength(7));
      for (var i = 1; i <= 56; i++) {
        expect(
          karanaNameForIndex(i),
          equals(movableKaranas[(i - 1) % 7]),
          reason: 'slot $i',
        );
      }
      // The 8th cycle ends on Vishti, handing over to fixed Shakuni.
      expect(karanaNameForIndex(56), equals('Vishti'));
    });

    test('follower wraps 59 -> Kimstughna via modulo', () {
      // Arrange + Act + Assert: callers pass (index + 1); the mapping
      // itself normalizes, so the Amavasya -> Pratipada wrap is safe.
      expect(karanaNameForIndex(59 + 1), equals('Kimstughna'));
    });

    test('elongation normalizes negative and 360 inputs', () {
      // Arrange + Act + Assert
      expect(karanaIndexFor(10, 5), equals(59)); // -5 -> 355 deg
      expect(karanaIndexFor(0, 360), equals(0));
    });
  });
}
