import 'package:flutter_test/flutter_test.dart';
import 'package:tithi/services/inauspicious_timings.dart';

String f(DateTime t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

void main() {
  group('InauspiciousTimings', () {
    test('Saturday mockup values incl. half-up rounding', () {
      // Arrange: Oct 3 2026 is a Saturday; sunrise 5:24, sunset 17:36
      // (day = 732 min, segment = 91.5 min).
      // Act
      final r = InauspiciousTimings.calculate(
        date: DateTime(2026, 10, 3),
        sunrise: DateTime(2026, 10, 3, 5, 24),
        sunset: DateTime(2026, 10, 3, 17, 36),
      );

      // Assert: segments + minute-rounded ranges match the mockup.
      expect(r.gulikaSegment, equals(1));
      expect(f(r.gulika.start), equals('05:24'));
      expect(f(r.gulika.end), equals('06:56')); // 6:55:30 rounds up
      expect(r.rahuSegment, equals(3));
      expect(f(r.rahu.start), equals('08:27'));
      expect(f(r.rahu.end), equals('09:59')); // 9:58:30 rounds up
      expect(r.yamagandaSegment, equals(6));
      expect(f(r.yamaganda.start), equals('13:02')); // 13:01:30 rounds up
      expect(f(r.yamaganda.end), equals('14:33'));
      expect(r.boundaries, hasLength(9));
      expect(f(r.boundaries.first), equals('05:24'));
      expect(f(r.boundaries.last), equals('17:36'));
    });

    test('weekday tables assign distinct segments', () {
      // Arrange: nominal 6:00-18:00 day (90-min segments).
      // Act + Assert: spot-check each weekday, then distinctness.
      final expected = <int, ({int rahu, int yamaganda, int gulika})>{
        DateTime.monday: (rahu: 2, yamaganda: 4, gulika: 6),
        DateTime.tuesday: (rahu: 7, yamaganda: 3, gulika: 5),
        DateTime.wednesday: (rahu: 5, yamaganda: 2, gulika: 4),
        DateTime.thursday: (rahu: 6, yamaganda: 1, gulika: 3),
        DateTime.friday: (rahu: 4, yamaganda: 7, gulika: 2),
        DateTime.saturday: (rahu: 3, yamaganda: 6, gulika: 1),
        DateTime.sunday: (rahu: 8, yamaganda: 5, gulika: 7),
      };
      for (final entry in expected.entries) {
        // Oct 5 2026 is a Monday; add (weekday - 1) days to reach it.
        final date = DateTime(2026, 10, 5 + (entry.key - 1));
        expect(date.weekday, equals(entry.key));
        final r = InauspiciousTimings.calculate(
          date: date,
          sunrise: DateTime(date.year, date.month, date.day, 6, 27),
          sunset: DateTime(date.year, date.month, date.day, 17, 43),
        );
        expect(r.rahuSegment, equals(entry.value.rahu));
        expect(r.yamagandaSegment, equals(entry.value.yamaganda));
        expect(r.gulikaSegment, equals(entry.value.gulika));
        expect(
          {r.rahuSegment, r.yamagandaSegment, r.gulikaSegment},
          hasLength(3),
        );
      }
    });

    test('nominal day divides 6:00-18:00', () {
      // Arrange + Act
      final r = InauspiciousTimings.calculate(
        date: DateTime(2026, 10, 4), // Sunday: Rahu 8th
        sunrise: DateTime(2026, 10, 4, 6, 27),
        sunset: DateTime(2026, 10, 4, 17, 43),
        useNominalDay: true,
      );

      // Assert
      expect(f(r.sunrise), equals('06:00'));
      expect(f(r.sunset), equals('18:00'));
      expect(r.rahuSegment, equals(8));
      expect(f(r.rahu.start), equals('16:30'));
      expect(f(r.rahu.end), equals('18:00'));
    });

    test('Monday Gulika is 6th (Maandi/Drik, not minority 7th)', () {
      // Arrange: Oct 5 2026 is a Monday; nominal day = 90-min segments.
      // Act
      final r = InauspiciousTimings.calculate(
        date: DateTime(2026, 10, 5),
        sunrise: DateTime(2026, 10, 5, 6, 27),
        sunset: DateTime(2026, 10, 5, 17, 43),
        useNominalDay: true,
      );

      // Assert: 6th segment = 13:30-15:00 nominal, matching DrikPanchang's
      // ~13:00-14:31 with actual Delhi times (not the old 7th = 15:00+).
      expect(r.gulikaSegment, equals(6));
      expect(f(r.gulika.start), equals('13:30'));
      expect(f(r.gulika.end), equals('15:00'));
    });

    test('Thursday/Friday Gulika are 3rd/2nd (Maandi, not 2nd/6th)', () {
      // Arrange: Oct 8 2026 is a Thursday, Oct 9 a Friday; nominal day =
      // 90-min segments, so 3rd = 9:00-10:30 and 2nd = 7:30-9:00.
      // Act
      final thu = InauspiciousTimings.calculate(
        date: DateTime(2026, 10, 8),
        sunrise: DateTime(2026, 10, 8, 6, 27),
        sunset: DateTime(2026, 10, 8, 17, 43),
        useNominalDay: true,
      );
      final fri = InauspiciousTimings.calculate(
        date: DateTime(2026, 10, 9),
        sunrise: DateTime(2026, 10, 9, 6, 27),
        sunset: DateTime(2026, 10, 9, 17, 43),
        useNominalDay: true,
      );

      // Assert
      expect(DateTime(2026, 10, 8).weekday, equals(DateTime.thursday));
      expect(DateTime(2026, 10, 9).weekday, equals(DateTime.friday));
      expect(thu.gulikaSegment, equals(3));
      expect(f(thu.gulika.start), equals('09:00'));
      expect(f(thu.gulika.end), equals('10:30'));
      expect(fri.gulikaSegment, equals(2));
      expect(f(fri.gulika.start), equals('07:30'));
      expect(f(fri.gulika.end), equals('09:00'));
    });

    test('rangeOf resolves segment spans', () {
      // Arrange
      final r = InauspiciousTimings.calculate(
        date: DateTime(2026, 10, 3),
        sunrise: DateTime(2026, 10, 3, 5, 24),
        sunset: DateTime(2026, 10, 3, 17, 36),
      );

      // Act + Assert
      expect(f(r.rangeOf(1).start), equals('05:24'));
      expect(f(r.rangeOf(1).end), equals('06:56'));
      expect(f(r.rangeOf(8).end), equals('17:36'));
    });
  });
}
