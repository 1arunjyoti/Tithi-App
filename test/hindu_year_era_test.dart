import 'package:flutter_test/flutter_test.dart';
import 'package:tithi/models/hindu_month_system.dart';
import 'package:tithi/services/hindu_calendar_service.dart';

/// Tests the Vikram/Shaka era boundary rules against the era spec:
/// VS = Gregorian +57 on/after Chaitra Shukla Pratipada, +56 before;
/// traditional lunisolar Shaka = VS - 135 (same New Year).
void main() {
  group('Vikram Samvat year boundary', () {
    test('Spec example: June 10, 2026 (after New Year) -> VS 2083', () {
      expect(
        HinduCalendarService.vikramSamvatYear(
          gregorianYear: 2026,
          gregorianMonth: 6,
          masa: 'Jyeshtha',
        ),
        equals(2083),
      );
    });

    test('Spec example: February 1, 2026 (before New Year) -> VS 2082', () {
      expect(
        HinduCalendarService.vikramSamvatYear(
          gregorianYear: 2026,
          gregorianMonth: 2,
          masa: 'Magha',
        ),
        equals(2082),
      );
    });

    test('Jan/Feb always take the old year (+56)', () {
      expect(
        HinduCalendarService.vikramSamvatYear(
          gregorianYear: 2026,
          gregorianMonth: 1,
          masa: 'Pausha',
        ),
        equals(2082),
      );
      expect(
        HinduCalendarService.vikramSamvatYear(
          gregorianYear: 2026,
          gregorianMonth: 2,
          masa: 'Phalguna',
        ),
        equals(2082),
      );
    });

    test('May..Dec always take the new year (+57)', () {
      expect(
        HinduCalendarService.vikramSamvatYear(
          gregorianYear: 2026,
          gregorianMonth: 5,
          masa: 'Vaishakha',
        ),
        equals(2083),
      );
      expect(
        HinduCalendarService.vikramSamvatYear(
          gregorianYear: 2026,
          gregorianMonth: 12,
          masa: 'Pausha',
        ),
        equals(2083),
      );
    });

    test('Mar/Apr straddle: masa decides the year', () {
      // Still the old year (Phalguna tail end).
      expect(
        HinduCalendarService.vikramSamvatYear(
          gregorianYear: 2026,
          gregorianMonth: 3,
          masa: 'Phalguna',
        ),
        equals(2082),
      );
      // New Year reached (Amanta Chaitra starts at Shukla Pratipada).
      expect(
        HinduCalendarService.vikramSamvatYear(
          gregorianYear: 2026,
          gregorianMonth: 3,
          masa: 'Chaitra',
        ),
        equals(2083),
      );
      expect(
        HinduCalendarService.vikramSamvatYear(
          gregorianYear: 2026,
          gregorianMonth: 4,
          masa: 'Chaitra',
        ),
        equals(2083),
      );
      expect(
        HinduCalendarService.vikramSamvatYear(
          gregorianYear: 2026,
          gregorianMonth: 4,
          masa: 'Vaishakha',
        ),
        equals(2083),
      );
    });

    test('Spec conversion table (dates after New Year)', () {
      const expectations = {
        2024: 2081,
        2025: 2082,
        2026: 2083,
        2027: 2084,
        2030: 2087,
      };
      expectations.forEach((gregorian, vs) {
        expect(
          HinduCalendarService.vikramSamvatYear(
            gregorianYear: gregorian,
            gregorianMonth: 7,
            masa: 'Ashadha',
          ),
          equals(vs),
        );
      });
    });
  });

  group('Shaka Samvat derivation (VS - 135)', () {
    test('Spec examples hold the 135-year gap', () {
      // June 2026: 2083 - 1948 = 135.
      expect(2083 - 1948, equals(135));
      // February 2026: 2082 - 1947 = 135.
      expect(2082 - 1947, equals(135));
    });

    test('Shaka offsets match the spec on both sides of New Year', () {
      // After New Year: Shaka = Gregorian - 78.
      expect(2026 - 78, equals(1948));
      // Before New Year: Shaka = Gregorian - 79.
      expect(2026 - 79, equals(1947));
      // Both equal their VS counterpart minus 135.
      expect(2026 + 57 - 135, equals(2026 - 78));
      expect(2026 + 56 - 135, equals(2026 - 79));
    });

    test('fromGregorianYear helpers agree with the boundary rules', () {
      // afterNewYear defaults to true.
      expect(
        HinduYearEra.vikramSamvat.fromGregorianYear(2026),
        equals(2083),
      );
      expect(
        HinduYearEra.vikramSamvat.fromGregorianYear(2026, afterNewYear: false),
        equals(2082),
      );
      expect(
        HinduYearEra.shakaSamvat.fromGregorianYear(2026),
        equals(1948),
      );
      expect(
        HinduYearEra.shakaSamvat.fromGregorianYear(2026, afterNewYear: false),
        equals(1947),
      );
    });
  });
}
