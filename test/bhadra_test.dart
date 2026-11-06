import 'package:flutter_test/flutter_test.dart';
import 'package:tithi/features/panchang/domain/bhadra.dart';
import 'package:tithi/models/festival.dart';

void main() {
  group('isVishtiKarana', () {
    test('every seventh movable karana is Vishti', () {
      // Arrange + Act + Assert: indices 1-56 cycle the seven movable
      // karanas, so Vishti is 7, 14, ... 56.
      for (var index = 1; index <= 56; index++) {
        expect(
          isVishtiKarana(index),
          equals(index % 7 == 0),
          reason: 'karana $index (${karanaNameForIndex(index)})',
        );
      }
    });

    test('the fixed karanas are never Vishti', () {
      // Arrange + Act + Assert
      expect(isVishtiKarana(0), isFalse); // Kimstughna
      expect(isVishtiKarana(57), isFalse); // Shakuni
      expect(isVishtiKarana(58), isFalse); // Chatushpada
      expect(isVishtiKarana(59), isFalse); // Naga
    });

    test('names agree with the karana table', () {
      // Arrange + Act + Assert: the predicate must not drift from
      // karanaNameForIndex, the app's single source of karana names.
      expect(karanaNameForIndex(7), equals('Vishti'));
      expect(karanaNameForIndex(56), equals('Vishti'));
      expect(karanaNameForIndex(6), equals('Vanija'));
      expect(isVishtiKarana(7), isTrue);
      expect(isVishtiKarana(56), isTrue);
    });
  });

  group('bhadraFreeWindow', () {
    final start = DateTime(2026, 8, 22, 13);
    final end = DateTime(2026, 8, 22, 16);

    ({DateTime start, DateTime end})? free(
      List<({DateTime start, DateTime end})> windows,
    ) {
      return bhadraFreeWindow(start: start, end: end, windows: windows);
    }

    test('no windows returns the whole span', () {
      // Arrange + Act
      final result = free(const []);

      // Assert
      expect(result?.start, equals(start));
      expect(result?.end, equals(end));
    });

    test('a window in the middle returns the longer side', () {
      // Arrange: Bhadra [13:30, 14:00] leaves 30 min before and 2 h after.
      final result = free([
        (
          start: DateTime(2026, 8, 22, 13, 30),
          end: DateTime(2026, 8, 22, 14),
        ),
      ]);

      // Assert
      expect(result?.start, equals(DateTime(2026, 8, 22, 14)));
      expect(result?.end, equals(end));
    });

    test('a window at the start returns the tail', () {
      // Arrange
      final result = free([
        (
          start: DateTime(2026, 8, 22, 13),
          end: DateTime(2026, 8, 22, 14),
        ),
      ]);

      // Assert
      expect(result?.start, equals(DateTime(2026, 8, 22, 14)));
      expect(result?.end, equals(end));
    });

    test('windows outside the span are ignored', () {
      // Arrange
      final result = free([
        (
          start: DateTime(2026, 8, 22, 9),
          end: DateTime(2026, 8, 22, 10),
        ),
        (
          start: DateTime(2026, 8, 22, 17),
          end: DateTime(2026, 8, 22, 18),
        ),
      ]);

      // Assert
      expect(result?.start, equals(start));
      expect(result?.end, equals(end));
    });

    test('full coverage returns null', () {
      // Arrange + Act
      final result = free([
        (
          start: DateTime(2026, 8, 22, 12),
          end: DateTime(2026, 8, 22, 17),
        ),
      ]);

      // Assert
      expect(result, isNull);
    });

    test('overlapping windows are merged before measuring', () {
      // Arrange: [13:00,13:40] + [13:20,14:00] cover [13:00,14:00].
      final result = free([
        (
          start: DateTime(2026, 8, 22, 13, 20),
          end: DateTime(2026, 8, 22, 14),
        ),
        (
          start: DateTime(2026, 8, 22, 13),
          end: DateTime(2026, 8, 22, 13, 40),
        ),
      ]);

      // Assert
      expect(result?.start, equals(DateTime(2026, 8, 22, 14)));
      expect(result?.end, equals(end));
    });

    test('an empty or inverted span returns null', () {
      // Arrange + Act + Assert
      expect(
        bhadraFreeWindow(start: end, end: start, windows: const []),
        isNull,
      );
      expect(bhadraFreeWindow(start: end, end: end, windows: const []), isNull);
    });
  });
}
