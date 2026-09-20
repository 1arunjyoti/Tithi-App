import 'package:flutter_test/flutter_test.dart';
import 'package:tithi/services/moonrise_calculator.dart';

void main() {
  const lat = 28.6139;
  const lon = 77.2090;

  DateTime at(DateTime? t) => t!;

  group('MoonriseCalculator', () {
    test('matches timeanddate.com reference for Delhi Oct 2026 (±5 min)', () {
      // Reference: timeanddate.com moon calendar for New Delhi, Oct 2026.
      // Truncated lunar theory targets ±2 min; the assertion allows ±5.
      final reference = <int, ({int riseH, int riseM, int? setH, int? setM})>{
        24: (riseH: 16, riseM: 22, setH: 4, setM: 19),
        25: (riseH: 16, riseM: 56, setH: 5, setM: 21),
        26: (riseH: 17, riseM: 34, setH: 6, setM: 26),
        27: (riseH: 18, riseM: 19, setH: 7, setM: 35),
        28: (riseH: 19, riseM: 11, setH: 8, setM: 46),
      };
      for (final entry in reference.entries) {
        // Arrange
        final date = DateTime(2026, 10, entry.key);

        // Act
        final result = MoonriseCalculator.calculateMoonriseSet(
          date: date,
          latitude: lat,
          longitude: lon,
        );

        // Assert
        final ref = entry.value;
        final rise = at(result.moonrise);
        expect(
          (rise.hour * 60 + rise.minute - (ref.riseH * 60 + ref.riseM)).abs(),
          lessThanOrEqualTo(5),
          reason: 'Oct ${entry.key} moonrise',
        );
        final set = at(result.moonset);
        expect(
          (set.hour * 60 + set.minute - (ref.setH! * 60 + ref.setM!)).abs(),
          lessThanOrEqualTo(5),
          reason: 'Oct ${entry.key} moonset',
        );
      }
    });

    test('moonrise shifts later day-to-day (waxing week)', () {
      // Arrange
      int? previousMinutes;

      for (var day = 24; day <= 28; day++) {
        // Act
        final rise = MoonriseCalculator.calculateMoonrise(
          date: DateTime(2026, 10, day),
          latitude: lat,
          longitude: lon,
        )!;

        // Assert: each day's clock time is 20-90 min later than the previous.
        final minutes = rise.hour * 60 + rise.minute;
        if (previousMinutes != null) {
          final shift = minutes - previousMinutes;
          expect(shift, inInclusiveRange(20, 90), reason: 'Oct $day shift');
        }
        previousMinutes = minutes;
      }
    });

    test('returns null (not a wrong time) on no-rise / no-set days', () {
      // Arrange: Sep 5 2026 has no moonrise in Delhi, Sep 20 no moonset
      // (verified against timeanddate.com: the Moon skips one event as its
      // ~24.8h cycle slips past civil midnight).

      // Act
      final noRise = MoonriseCalculator.calculateMoonriseSet(
        date: DateTime(2026, 9, 5),
        latitude: lat,
        longitude: lon,
      );
      final noSet = MoonriseCalculator.calculateMoonriseSet(
        date: DateTime(2026, 9, 20),
        latitude: lat,
        longitude: lon,
      );

      // Assert
      expect(noRise.moonrise, isNull);
      expect(noRise.moonset, isNotNull);
      expect(noSet.moonset, isNull);
      expect(noSet.moonrise, isNotNull);
    });

    test('findPreviousMoonrise returns the prevailing rise', () {
      // Arrange: Oct 4 2026 has no moonrise; the moon up that day rose
      // Oct 3 at 23:27 (timeanddate.com, New Delhi).

      // Act
      final prev = MoonriseCalculator.findPreviousMoonrise(
        date: DateTime(2026, 10, 4),
        latitude: lat,
        longitude: lon,
      )!;

      // Assert
      expect(prev.day, equals(3));
      expect(
        (prev.hour * 60 + prev.minute - (23 * 60 + 27)).abs(),
        lessThanOrEqualTo(5),
      );
    });

    test('findNextMoonset returns the prevailing set', () {
      // Arrange: Sep 20 2026 has no moonset; the moon up that day sets
      // the next morning.

      // Act
      final next = MoonriseCalculator.findNextMoonset(
        date: DateTime(2026, 9, 20),
        latitude: lat,
        longitude: lon,
      )!;

      // Assert: next-day set, after the day's own moonrise (14:30).
      expect(next.day, equals(21));
      final rise = MoonriseCalculator.calculateMoonrise(
        date: DateTime(2026, 9, 20),
        latitude: lat,
        longitude: lon,
      )!;
      expect(next.isAfter(rise), isTrue);
    });

    test('handles UTC input dates like local ones', () {
      // Arrange
      final local = DateTime(2026, 10, 26);
      final utc = DateTime.utc(2026, 10, 26);

      // Act
      final fromLocal = MoonriseCalculator.calculateMoonriseSet(
        date: local,
        latitude: lat,
        longitude: lon,
      );
      final fromUtc = MoonriseCalculator.calculateMoonriseSet(
        date: utc,
        latitude: lat,
        longitude: lon,
      );

      // Assert: same civil-day attribution within a minute.
      expect(
        fromUtc.moonrise!.difference(fromLocal.moonrise!).inMinutes.abs(),
        lessThanOrEqualTo(1),
      );
      expect(
        fromUtc.moonset!.difference(fromLocal.moonset!).inMinutes.abs(),
        lessThanOrEqualTo(1),
      );
    });
  });
}
