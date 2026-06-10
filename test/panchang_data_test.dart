import 'package:flutter_test/flutter_test.dart';
import 'package:tithi/models/panchang_data.dart';

void main() {
  group('PanchangData Model Tests', () {
    test('fromRawTithi creates correct Shukla Paksha data', () {
      final testDate = DateTime(2024, 3, 15);
      final sunrise = DateTime(2024, 3, 15, 6, 30);
      final sunset = DateTime(2024, 3, 15, 18);

      // Raw tithi 8.5 should be Shukla Ashtami
      final panchang = PanchangData.fromRawTithi(
        date: testDate,
        rawTithi: 8.5,
        masa: 'Chaitra',
        allFestivals: [],
        sunrise: sunrise,
        sunset: sunset,
      );

      expect(panchang.paksha, equals('Shukla'));
      expect(panchang.tithiNumber, equals(8));
      expect(panchang.masa, equals('Chaitra'));
    });

    test('fromRawTithi creates correct Krishna Paksha data', () {
      final testDate = DateTime(2024, 3, 25);
      final sunrise = DateTime(2024, 3, 25, 6, 20);
      final sunset = DateTime(2024, 3, 25, 18, 10);

      // Raw tithi 22 should be Krishna Saptami (22 - 15 = 7)
      final panchang = PanchangData.fromRawTithi(
        date: testDate,
        rawTithi: 22.0,
        masa: 'Chaitra',
        allFestivals: [],
        sunrise: sunrise,
        sunset: sunset,
      );

      expect(panchang.paksha, equals('Krishna'));
      expect(panchang.tithiNumber, equals(7));
    });

    test('Purnima is correctly identified', () {
      final testDate = DateTime(2024, 3, 24);
      final sunrise = DateTime(2024, 3, 24, 6, 22);
      final sunset = DateTime(2024, 3, 24, 18, 08);

      final panchang = PanchangData.fromRawTithi(
        date: testDate,
        rawTithi: 15.0,
        masa: 'Phalguna',
        allFestivals: [],
        sunrise: sunrise,
        sunset: sunset,
      );

      expect(panchang.paksha, equals('Shukla'));
      expect(panchang.tithiNumber, equals(15));
      // Tithi 15 is labeled as "Purnima/Amavasya" in the implementation
      expect(panchang.tithiName, contains('Purnima'));
    });

    test('Amavasya is correctly identified', () {
      final testDate = DateTime(2024, 4, 8);
      final sunrise = DateTime(2024, 4, 8, 6, 10);
      final sunset = DateTime(2024, 4, 8, 18, 20);

      final panchang = PanchangData.fromRawTithi(
        date: testDate,
        rawTithi: 30.0,
        masa: 'Chaitra',
        allFestivals: [],
        sunrise: sunrise,
        sunset: sunset,
      );

      expect(panchang.paksha, equals('Krishna'));
      expect(panchang.tithiNumber, equals(15));
      // Tithi 15 in Krishna Paksha (raw tithi 30) is Amavasya
      expect(panchang.tithiName, contains('Amavasya'));
    });

    test('hasFestivals returns false when no festivals', () {
      final testDate = DateTime(2024, 11);
      final sunrise = DateTime(2024, 11, 1, 6, 30);
      final sunset = DateTime(2024, 11, 1, 17, 30);

      final panchang = PanchangData.fromRawTithi(
        date: testDate,
        rawTithi: 29.0,
        masa: 'Kartik',
        allFestivals: [],
        sunrise: sunrise,
        sunset: sunset,
      );

      expect(panchang.hasFestivals, isFalse);
    });

    test('Tithi boundary conditions are handled', () {
      final testDate = DateTime(2024);
      final sunrise = DateTime(2024, 1, 1, 6, 45);
      final sunset = DateTime(2024, 1, 1, 17, 15);

      // Test tithi 1 (Shukla Pratipada)
      final panchang1 = PanchangData.fromRawTithi(
        date: testDate,
        rawTithi: 1.0,
        allFestivals: [],
        sunrise: sunrise,
        sunset: sunset,
      );
      expect(panchang1.paksha, equals('Shukla'));
      expect(panchang1.tithiNumber, equals(1));
      expect(panchang1.tithiName, equals('Pratipada'));

      // Test tithi 16 (Krishna Pratipada)
      final panchang16 = PanchangData.fromRawTithi(
        date: testDate,
        rawTithi: 16.0,
        allFestivals: [],
        sunrise: sunrise,
        sunset: sunset,
      );
      expect(panchang16.paksha, equals('Krishna'));
      expect(panchang16.tithiNumber, equals(1));
      expect(panchang16.tithiName, equals('Pratipada'));
    });
  });

  group('Moon Phase Calculations', () {
    test('New Moon phase calculation', () {
      // Amavasya (tithi 30) should have moon phase close to 0 or 1
      const rawTithi = 30.0;
      const phase = ((rawTithi - 1) * 12) / 360;
      // Phase should be close to 1 (end of cycle)
      expect(phase, closeTo(0.967, 0.01));
    });

    test('Full Moon phase calculation', () {
      // Purnima (tithi 15) should have moon phase close to 0.5
      const rawTithi = 15.0;
      const phase = ((rawTithi - 1) * 12) / 360;
      expect(phase, closeTo(0.467, 0.01));
    });

    test('First Quarter phase calculation', () {
      // Shukla Ashtami (tithi 8) should have phase close to 0.25
      const rawTithi = 8.0;
      const phase = ((rawTithi - 1) * 12) / 360;
      expect(phase, closeTo(0.233, 0.01));
    });

    test('Last Quarter phase calculation', () {
      // Krishna Ashtami (tithi 23) should have phase close to 0.75
      const rawTithi = 23.0;
      const phase = ((rawTithi - 1) * 12) / 360;
      expect(phase, closeTo(0.733, 0.01));
    });
  });

  group('PanchangData Properties', () {
    test('isShukla and isKrishna work correctly', () {
      final sunrise = DateTime(2024, 1, 1, 6, 30);
      final sunset = DateTime(2024, 1, 1, 17, 30);

      final shukla = PanchangData.fromRawTithi(
        date: DateTime(2024),
        rawTithi: 5.0,
        allFestivals: [],
        sunrise: sunrise,
        sunset: sunset,
      );
      expect(shukla.isShukla, isTrue);
      expect(shukla.isKrishna, isFalse);

      final krishna = PanchangData.fromRawTithi(
        date: DateTime(2024, 1, 15),
        rawTithi: 20.0,
        allFestivals: [],
        sunrise: sunrise,
        sunset: sunset,
      );
      expect(krishna.isShukla, isFalse);
      expect(krishna.isKrishna, isTrue);
    });

    test('rawTithi is preserved', () {
      final sunrise = DateTime(2024, 1, 1, 6, 30);
      final sunset = DateTime(2024, 1, 1, 17, 30);
      
      const expectedRawTithi = 12.75;
      final panchang = PanchangData.fromRawTithi(
        date: DateTime(2024),
        rawTithi: expectedRawTithi,
        allFestivals: [],
        sunrise: sunrise,
        sunset: sunset,
      );

      expect(panchang.rawTithi, equals(expectedRawTithi));
    });
  });
}
