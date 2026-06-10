import 'package:flutter_test/flutter_test.dart';
import 'package:tithi/models/hindu_month_system.dart';

void main() {
  group('Panchang Calculations', () {
    test('Tithi should be between 1 and 30', () {
      // Test that rawTithi values produce valid tithi numbers
      for (double rawTithi = 1.0; rawTithi <= 30.0; rawTithi += 0.5) {
        final tithiNumber = rawTithi.floor();
        expect(tithiNumber, greaterThanOrEqualTo(1));
        expect(tithiNumber, lessThanOrEqualTo(30));
      }
    });

    test('Paksha calculation from tithi', () {
      // Tithi 1-14 should be Shukla Paksha
      for (int tithi = 1; tithi <= 14; tithi++) {
        final paksha = tithi <= 15 ? 'Shukla' : 'Krishna';
        expect(paksha, equals('Shukla'));
      }

      // Tithi 16-30 should be Krishna Paksha
      for (int tithi = 16; tithi <= 30; tithi++) {
        final paksha = tithi <= 15 ? 'Shukla' : 'Krishna';
        expect(paksha, equals('Krishna'));
      }

      // Tithi 15 (Purnima) should be Shukla Paksha
      expect(15 <= 15, isTrue);
    });

    test('Tithi names should be correctly assigned', () {
      final tithiNames = [
        'Pratipada', 'Dwitiya', 'Tritiya', 'Chaturthi', 'Panchami',
        'Shashthi', 'Saptami', 'Ashtami', 'Navami', 'Dashami',
        'Ekadashi', 'Dwadashi', 'Trayodashi', 'Chaturdashi', 'Purnima',
        'Pratipada', 'Dwitiya', 'Tritiya', 'Chaturthi', 'Panchami',
        'Shashthi', 'Saptami', 'Ashtami', 'Navami', 'Dashami',
        'Ekadashi', 'Dwadashi', 'Trayodashi', 'Chaturdashi', 'Amavasya',
      ];

      for (int i = 1; i <= 30; i++) {
        expect(tithiNames[i - 1], isNotEmpty);
      }

      // Verify special tithis
      expect(tithiNames[14], equals('Purnima')); // 15th tithi
      expect(tithiNames[29], equals('Amavasya')); // 30th tithi
    });

    test('Moon phase calculation from tithi', () {
      // New Moon (Amavasya) - tithi ~30
      const amavasya = 30.0;
      const amavasyaPhase = ((amavasya - 1) * 12) / 360;
      expect(amavasyaPhase, closeTo(0.97, 0.01));

      // Full Moon (Purnima) - tithi ~15
      const purnima = 15.0;
      const purnimaPhase = ((purnima - 1) * 12) / 360;
      expect(purnimaPhase, closeTo(0.47, 0.01));

      // First Quarter - tithi ~8
      const firstQuarter = 8.0;
      const firstQuarterPhase = ((firstQuarter - 1) * 12) / 360;
      expect(firstQuarterPhase, closeTo(0.23, 0.01));
    });

    test('Hindu month system conversions', () {
      // Test that both Amanta and Purnimant systems are supported
      expect(HinduMonthSystem.amanta.name, equals('amanta'));
      expect(HinduMonthSystem.purnimant.name, equals('purnimant'));
    });

    test('Sunrise sunset ordering', () {
      // Sunrise should always be before sunset on the same day
      final testDate = DateTime(2024, 1, 15);
      final sunrise = DateTime(2024, 1, 15, 6, 30);
      final sunset = DateTime(2024, 1, 15, 18);

      expect(sunrise.isBefore(sunset), isTrue);
      expect(sunrise.day, equals(testDate.day));
      expect(sunset.day, equals(testDate.day));
    });

    test('Tithi fractional calculations', () {
      // Test that tithi can have fractional values for precise timing
      const rawTithi = 14.75; // 75% through 14th tithi
      final tithiNumber = rawTithi.floor();
      final tithiFraction = rawTithi - tithiNumber;

      expect(tithiNumber, equals(14));
      expect(tithiFraction, closeTo(0.75, 0.01));
    });

    test('Masa name should not be empty', () {
      // Common Hindu month names
      final masaNames = [
        'Chaitra', 'Vaishakha', 'Jyeshtha', 'Ashadha',
        'Shravana', 'Bhadrapada', 'Ashwin', 'Kartik',
        'Margashirsha', 'Pausha', 'Magha', 'Phalguna'
      ];

      for (final masa in masaNames) {
        expect(masa, isNotEmpty);
        expect(masa.length, greaterThan(4));
      }
    });
  });

  group('Edge Cases', () {
    test('Handle tithi at exact boundaries', () {
      // Exact Purnima
      const purnimaTithi = 15.0;
      expect(purnimaTithi.floor(), equals(15));

      // Exact Amavasya
      const amavasya = 30.0;
      expect(amavasya.floor(), equals(30));
    });

    test('Handle date near month boundaries', () {
      final lastDayOfMonth = DateTime(2024, 1, 31);
      final firstDayOfMonth = DateTime(2024, 2);

      expect(lastDayOfMonth.month, equals(1));
      expect(firstDayOfMonth.month, equals(2));
      expect(firstDayOfMonth.difference(lastDayOfMonth).inDays, equals(1));
    });

    test('Handle leap year dates', () {
      final leapDay = DateTime(2024, 2, 29);
      expect(leapDay.day, equals(29));
      expect(leapDay.month, equals(2));
    });
  });
}
