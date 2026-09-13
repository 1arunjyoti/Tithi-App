import 'package:flutter_test/flutter_test.dart';
import 'package:tithi/models/festival.dart';
import 'package:tithi/models/hindu_month_system.dart';
import 'package:tithi/models/panchang_data.dart';

/// Minimal Janmashtami-like festival (stored in Amanta format).
Festival _krishnaFestival() => Festival.fromJson({
  'id': 'janmashtami',
  'name': 'Krishna Janmashtami',
  'panchang_rules': {
    'masa': 'Shravana',
    'paksha': 'Krishna',
    'tithi': 8,
    'conditions': 'Ashtami',
  },
});

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
  group('Month System Festival Matching', () {
    // Regression: Krishna festivals (e.g. Janmashtami = Shravana Krishna
    // Ashtami in Amanta storage) must match in BOTH display modes. Matching
    // is always Amanta; Purnimant is display-only.
    test('Krishna festival matches in Amanta mode', () {
      final panchang = PanchangData.fromRawTithi(
        date: DateTime(2026, 9, 4),
        rawTithi: 23.5, // Krishna Ashtami
        masa: 'Shravana', // Amanta masa from calculateMasa
        allFestivals: [_krishnaFestival()],
        // monthSystem defaults to amanta; passed explicitly in the
        // Purnimant test below.
        sunrise: DateTime(2026, 9, 4, 6),
        sunset: DateTime(2026, 9, 4, 18, 30),
      );

      expect(panchang.festivals.map((f) => f.id), contains('janmashtami'));
    });

    test('Krishna festival still matches in Purnimant mode', () {
      final panchang = PanchangData.fromRawTithi(
        date: DateTime(2026, 9, 4),
        rawTithi: 23.5, // Krishna Ashtami
        masa: 'Shravana', // Amanta masa from calculateMasa
        allFestivals: [_krishnaFestival()],
        monthSystem: HinduMonthSystem.purnimant,
        sunrise: DateTime(2026, 9, 4, 6),
        sunset: DateTime(2026, 9, 4, 18, 30),
      );

      expect(panchang.festivals.map((f) => f.id), contains('janmashtami'));
    });

    test('Shukla festival matches in both modes', () {
      final shuklaFestival = Festival.fromJson({
        'id': 'diwali',
        'name': 'Diwali',
        'panchang_rules': {
          'masa': 'Kartika',
          'paksha': 'Shukla',
          'tithi': 1,
          'conditions': 'Pratipada',
        },
      });

      for (final system in HinduMonthSystem.values) {
        final panchang = PanchangData.fromRawTithi(
          date: DateTime(2024, 11),
          rawTithi: 1.5, // Shukla Pratipada
          masa: 'Kartika',
          allFestivals: [shuklaFestival],
          monthSystem: system,
          sunrise: DateTime(2024, 11, 1, 6, 30),
          sunset: DateTime(2024, 11, 1, 17, 30),
        );

        expect(panchang.festivals.map((f) => f.id), contains('diwali'));
      }
    });
  });

  group('Festival observed-tithi resolution', () {
    // The detail sheet queries Begins/Ends for the festival's OBSERVED
    // tithi (timingOverride-aware), not the day's sunrise tithi — e.g.
    // Ganesh Chaturthi (madhyahna) on a day whose sunrise is still Tritiya
    // must resolve to Chaturthi (index 4), not Tritiya (index 3).
    test('Shukla rule resolves to the same 1-15 index', () {
      final ganesh = Festival.fromJson({
        'id': 'ganesh_chaturthi',
        'name': 'Ganesh Chaturthi',
        'panchang_rules': {
          'masa': 'Bhadrapada',
          'paksha': 'Shukla',
          'tithi': 4,
          'conditions': 'Chaturthi',
          'timingOverride': 'madhyahna',
        },
      });

      expect(ganesh.resolvePaksha('Shukla'), equals('Shukla'));
      expect(ganesh.resolveTithiIndex('Shukla'), equals(4));
    });

    test('Krishna rule resolves to the 16-30 index', () {
      expect(_krishnaFestival().resolvePaksha('Krishna'), equals('Krishna'));
      expect(_krishnaFestival().resolveTithiIndex('Krishna'), equals(23));
    });

    test('Wildcard paksha follows the day paksha', () {
      final generic = Festival.fromJson({
        'id': 'ekadashi_krishna',
        'name': 'Ekadashi',
        'panchang_rules': {
          'masa': '*',
          'paksha': '*',
          'tithi': 11,
          'conditions': 'Ekadashi',
        },
      });

      expect(generic.resolvePaksha('Shukla'), equals('Shukla'));
      expect(generic.resolveTithiIndex('Shukla'), equals(11));
      expect(generic.resolvePaksha('Krishna'), equals('Krishna'));
      expect(generic.resolveTithiIndex('Krishna'), equals(26));
    });

    test('tithiNameFor labels boundary tithis', () {
      expect(PanchangData.tithiNameFor(15, 'Shukla'), contains('Purnima'));
      expect(PanchangData.tithiNameFor(15, 'Krishna'), contains('Amavasya'));
      expect(PanchangData.tithiNameFor(8, 'Shukla'), equals('Ashtami'));
      expect(PanchangData.tithiNameFor(1, 'Krishna'), equals('Pratipada'));
    });

        test('tithiNameFor uses 1-based numbers (1 = Pratipada)', () {

      // Guards against 0-based indexing slips: index i must name tithi i.
      const expected = [
        '',
        'Pratipada',
        'Dwitiya',
        'Tritiya',
        'Chaturthi',
        'Panchami',
        'Shashthi',
        'Saptami',
        'Ashtami',
        'Navami',
        'Dashami',
        'Ekadashi',
        'Dwadashi',
        'Trayodashi',
        'Chaturdashi',
      ];
      for (var i = 1; i <= 14; i++) {
        expect(PanchangData.tithiNameFor(i, 'Shukla'), equals(expected[i]));
        expect(PanchangData.tithiNameFor(i, 'Krishna'), equals(expected[i]));
      }
      // Out-of-range inputs never index the table.
      expect(PanchangData.tithiNameFor(0, 'Shukla'), equals('Unknown'));
      expect(PanchangData.tithiNameFor(16, 'Shukla'), equals('Unknown'));
    });
  });

  group('Kshaya (skipped tithi) fallback', () {
    // A tithi that begins after one sunrise and ends before the next owns
    // no sunrise. The engine credits it to the earlier day so its festivals
    // still fire (see FESTIVALS_Modification_GUIDE.md "Kshaya").
    Festival kshayaFestival(String id, String masa, String paksha, int tithi) =>
        Festival.fromJson({
          'id': id,
          'name': id,
          'panchang_rules': {
            'masa': masa,
            'paksha': paksha,
            'tithi': tithi,
            'conditions': 'Panchami',
          },
        });

    test('skipped tithi matches the earlier day', () {
      // Arrange: sunrise sees Chaturthi (index 4), next sunrise sees
      // Shashthi (index 6) — Panchami (index 5) owns no sunrise.
      final panchami = kshayaFestival(
        'test_panchami',
        'Shravana',
        'Shukla',
        5,
      );

      // Act
      final panchang = PanchangData.fromRawTithi(
        date: DateTime(2026, 8, 10),
        rawTithi: 4.2,
        rawTithiNextSunrise: 6.3,
        masa: 'Shravana',
        allFestivals: [panchami],
        sunrise: DateTime(2026, 8, 10, 6),
        sunset: DateTime(2026, 8, 10, 18, 30),
      );

      // Assert
      expect(panchang.festivals.map((f) => f.id), contains('test_panchami'));
    });

    test('non-skipped tithi still misses on a kshaya day', () {
      // Arrange: same skipped-Panchami setup, but the festival wants
      // Saptami (index 7), which no checkpoint covers.
      final saptami = kshayaFestival('test_saptami', 'Shravana', 'Shukla', 7);

      // Act
      final panchang = PanchangData.fromRawTithi(
        date: DateTime(2026, 8, 10),
        rawTithi: 4.2,
        rawTithiNextSunrise: 6.3,
        masa: 'Shravana',
        allFestivals: [saptami],
        sunrise: DateTime(2026, 8, 10, 6),
        sunset: DateTime(2026, 8, 10, 18, 30),
      );

      // Assert
      expect(panchang.festivals, isEmpty);
    });

    test('boundary skip across Amavasya uses the next lunation masa', () {
      // Arrange: sunrise sees Amavasya (index 30), next sunrise sees
      // Shukla Dwitiya (index 2) — Shukla Pratipada (index 1) is skipped
      // across the new moon, so it belongs to the next lunation's masa.
      final nextMasaPratipada = kshayaFestival(
        'test_next_pratipada',
        'Vaishakha',
        'Shukla',
        1,
      );

      // Act
      final panchang = PanchangData.fromRawTithi(
        date: DateTime(2026, 4, 27),
        rawTithi: 30.2,
        rawTithiNextSunrise: 2.3,
        masa: 'Chaitra',
        masaNextSunrise: 'Vaishakha',
        allFestivals: [nextMasaPratipada],
        sunrise: DateTime(2026, 4, 27, 6),
        sunset: DateTime(2026, 4, 27, 18, 30),
      );

      // Assert
      expect(
        panchang.festivals.map((f) => f.id),
        contains('test_next_pratipada'),
      );
    });
  });

  group('Elongation segments map to the documented tithis', () {
    // Locks the 12°-segment table: segment s covers elongation
    // [s*12, s*12+12) and must yield (paksha, number, name) below.
    // The code numbers rawTithi = elong/12 + 1 (1-based), so segment s
    // corresponds to rawTithi floor s+1 — same boundaries, offset labels.
    test('all 30 segments resolve identically', () {
      const segments = [
        ('Shukla', 1, 'Pratipada'),
        ('Shukla', 2, 'Dwitiya'),
        ('Shukla', 3, 'Tritiya'),
        ('Shukla', 4, 'Chaturthi'),
        ('Shukla', 5, 'Panchami'),
        ('Shukla', 6, 'Shashthi'),
        ('Shukla', 7, 'Saptami'),
        ('Shukla', 8, 'Ashtami'),
        ('Shukla', 9, 'Navami'),
        ('Shukla', 10, 'Dashami'),
        ('Shukla', 11, 'Ekadashi'),
        ('Shukla', 12, 'Dwadashi'),
        ('Shukla', 13, 'Trayodashi'),
        ('Shukla', 14, 'Chaturdashi'),
        ('Shukla', 15, 'Purnima'),
        ('Krishna', 1, 'Pratipada'),
        ('Krishna', 2, 'Dwitiya'),
        ('Krishna', 3, 'Tritiya'),
        ('Krishna', 4, 'Chaturthi'),
        ('Krishna', 5, 'Panchami'),
        ('Krishna', 6, 'Shashthi'),
        ('Krishna', 7, 'Saptami'),
        ('Krishna', 8, 'Ashtami'),
        ('Krishna', 9, 'Navami'),
        ('Krishna', 10, 'Dashami'),
        ('Krishna', 11, 'Ekadashi'),
        ('Krishna', 12, 'Dwadashi'),
        ('Krishna', 13, 'Trayodashi'),
        ('Krishna', 14, 'Chaturdashi'),
        ('Krishna', 15, 'Amavasya'),
      ];
      expect(segments, hasLength(30));

      for (var s = 0; s < 30; s++) {
        // Mid-segment elongation -> rawTithi -> PanchangData.
        final rawTithi = (s * 12 + 6) / 12 + 1;
        final panchang = PanchangData.fromRawTithi(
          date: DateTime(2026),
          rawTithi: rawTithi,
          allFestivals: [],
        );

        final (expectedPaksha, expectedNum, expectedName) = segments[s];
        expect(
          panchang.paksha,
          equals(expectedPaksha),
          reason: 'segment $s (elong ${s * 12}-${s * 12 + 12}°)',
        );
        expect(
          panchang.tithiNumber,
          equals(expectedNum),
          reason: 'segment $s (elong ${s * 12}-${s * 12 + 12}°)',
        );
        expect(
          panchang.tithiName,
          equals(expectedName),
          reason: 'segment $s (elong ${s * 12}-${s * 12 + 12}°)',
        );
      }
    });
  });
}
