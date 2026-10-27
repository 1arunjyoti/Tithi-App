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

  group('Nishita window matching', () {
    // Nishita Kaal is a muhurta-long window (`sunset + 7/15 night` to
    // `+ 8/15 night`), so a `nishita` rule matches the tithi at either edge.
    // The old point sample at the night midpoint is gone: it lost Delhi
    // 2026-09-04, where Ashtami ends 00:14 but the window opens at 23:57.
    Festival janmashtami() => Festival.fromJson({
      'id': 'janmashtami',
      'name': 'Krishna Janmashtami',
      'panchang_rules': {
        'masa': 'Shravana',
        'paksha': 'Krishna',
        'tithi': 8,
        'conditions': 'Ashtami',
        'timingOverride': 'nishita',
      },
    });

    PanchangData at({
      required double sunrise,
      double? nishita,
      double? nishitaEnd,
    }) => PanchangData.fromRawTithi(
      date: DateTime(2026, 9, 4),
      rawTithi: sunrise,
      masa: 'Shravana',
      allFestivals: [janmashtami()],
      rawTithiNishita: nishita,
      rawTithiNishitaEnd: nishitaEnd,
    );

    test('matches when Ashtami prevails at the window opening', () {
      // Delhi: sunrise Saptami, opening Ashtami, close Navami.
      final panchang = at(sunrise: 22.6, nishita: 23.987, nishitaEnd: 24.022);

      expect(panchang.festivals.map((f) => f.id), equals(['janmashtami']));
    });

    test('matches when Ashtami only arrives before the window closes', () {
      // Ashtami begins just inside the window: absent at the opening,
      // prevailing at the close. Losing this day would be the mirror defect.
      final panchang = at(sunrise: 22.6, nishita: 22.98, nishitaEnd: 23.02);

      expect(panchang.festivals.map((f) => f.id), equals(['janmashtami']));
    });

    test('does not match when neither window edge holds Ashtami', () {
      // Mumbai 2026-09-04: Ashtami ends 00:14:06, the window opens 00:14:11.
      final panchang = at(sunrise: 22.6, nishita: 24.0001, nishitaEnd: 24.0359);

      expect(panchang.festivals, isEmpty);
    });

    test('falls back to the sunrise tithi without a window', () {
      // Polar day: no sunset, so no window. The rule then reads the sunrise
      // tithi rather than inventing a checkpoint.
      final panchang = at(sunrise: 23.5);

      expect(panchang.festivals.map((f) => f.id), equals(['janmashtami']));
    });
  });

  group('Default sunrise checkpoint', () {
    // A rule without a timingOverride is decided at sunrise. The other
    // checkpoint samples must not leak into the match: only rawTithi (the
    // sunrise sample) counts.
    Festival ramNavami({String? timingOverride}) => Festival.fromJson({
      'id': 'ram_navami',
      'name': 'Ram Navami',
      'panchang_rules': {
        'masa': 'Chaitra',
        'paksha': 'Shukla',
        'tithi': 9,
        'conditions': 'Navami',
        'timingOverride': ?timingOverride,
      },
    });

    PanchangData at(
      Festival festival, {
      required double sunrise,
      double? madhyahna,
    }) => PanchangData.fromRawTithi(
      date: DateTime(2026, 3, 26),
      rawTithi: sunrise,
      masa: 'Chaitra',
      allFestivals: [festival],
      rawTithiMadhyahna: madhyahna,
      // No rawTithiDominant: the 60-minute grace window must not mask a
      // failure of the sunrise default.
    );

    test('matches the sunrise tithi when no override is set', () {
      // Sunrise is Navami, midday is already Dashami.
      final panchang = at(ramNavami(), sunrise: 9.2, madhyahna: 10.4);

      expect(panchang.festivals.map((f) => f.id), equals(['ram_navami']));
    });

    test('does not match a tithi that only prevails at another checkpoint', () {
      // Sunrise is Ashtami; Navami arrives only by midday.
      final panchang = at(ramNavami(), sunrise: 8.2, madhyahna: 9.4);

      expect(panchang.festivals, isEmpty);
    });

    test('an unknown override still falls back to sunrise', () {
      // A misspelled checkpoint must not silently match at a later sample.
      final panchang = at(
        ramNavami(timingOverride: 'not_a_checkpoint'),
        sunrise: 8.2,
        madhyahna: 9.4,
      );

      expect(panchang.festivals, isEmpty);
    });
  });

  group('Extended checkpoint matching', () {
    // Every value in timingOverrideCheckpoints must read its own sample in
    // fromRawTithi. If a value is added to the set but the switch is not
    // extended, the rule silently falls back to sunrise and the dominant
    // grace is already suppressed for it - a silent date regression.
    const checkpoints = [
      'brahma_muhurta_start',
      'arunodaya_start',
      'arunodaya',
      'purvahna',
      'sayahna_start',
      'sayahna_center',
      'sayahna_end',
      'madhyahna',
      'aparahna',
      'nishita',
      'pradosh',
      'pradosha',
      'moonrise',
      'chandrodaya',
    ];

    Festival navami(String timingOverride) => Festival.fromJson({
      'id': 'navami_observance',
      'name': 'Navami Observance',
      'panchang_rules': {
        'masa': 'Chaitra',
        'paksha': 'Shukla',
        'tithi': 9,
        'conditions': 'Navami',
        'timingOverride': timingOverride,
      },
    });

    // Sunrise is Ashtami (8.2); only the selected checkpoint is Navami.
    PanchangData atCheckpoint(String timingOverride) {
      double? brahmaMuhurtaStart;
      double? arunodaya;
      double? purvahna;
      double? sayahnaStart;
      double? sayahnaCenter;
      double? sayahnaEnd;
      double? madhyahna;
      double? aparahna;
      double? nishita;
      double? pradosha;
      double? moonrise;
      const navamiSample = 9.2;
      switch (timingOverride) {
        case 'brahma_muhurta_start':
          brahmaMuhurtaStart = navamiSample;
        case 'arunodaya_start' || 'arunodaya':
          arunodaya = navamiSample;
        case 'purvahna':
          purvahna = navamiSample;
        case 'sayahna_start':
          sayahnaStart = navamiSample;
        case 'sayahna_center':
          sayahnaCenter = navamiSample;
        case 'sayahna_end':
          sayahnaEnd = navamiSample;
        case 'madhyahna':
          madhyahna = navamiSample;
        case 'aparahna':
          aparahna = navamiSample;
        case 'nishita':
          nishita = navamiSample;
        case 'pradosh' || 'pradosha':
          pradosha = navamiSample;
        case 'moonrise' || 'chandrodaya':
          moonrise = navamiSample;
      }
      return PanchangData.fromRawTithi(
        date: DateTime(2026, 3, 26),
        rawTithi: 8.2,
        masa: 'Chaitra',
        allFestivals: [navami(timingOverride)],
        rawTithiBrahmaMuhurtaStart: brahmaMuhurtaStart,
        rawTithiArunodaya: arunodaya,
        rawTithiPurvahna: purvahna,
        rawTithiSayahnaStart: sayahnaStart,
        rawTithiSayahnaCenter: sayahnaCenter,
        rawTithiSayahnaEnd: sayahnaEnd,
        rawTithiMadhyahna: madhyahna,
        rawTithiAparahna: aparahna,
        rawTithiNishita: nishita,
        rawTithiPradosha: pradosha,
        rawTithiMoonrise: moonrise,
      );
    }

    test('every accepted override reads its own sample', () {
      for (final checkpoint in checkpoints) {
        expect(
          atCheckpoint(checkpoint).festivals.map((f) => f.id),
          equals(['navami_observance']),
          reason: checkpoint,
        );
      }
    });
  });

  group('Pradosh checkpoint matching', () {
    test('matches the tithi sampled at the Pradosh checkpoint', () {
      final festival = Festival.fromJson({
        'id': 'pradosh_vrata',
        'name': 'Pradosh Vrata',
        'panchang_rules': {
          'masa': 'Ashwin',
          'paksha': 'Krishna',
          'tithi': 13,
          'conditions': 'Trayodashi',
          'timingOverride': 'pradosh',
        },
      });

      final panchang = PanchangData.fromRawTithi(
        date: DateTime(2026, 10),
        rawTithi: 12.5,
        masa: 'Ashwin',
        allFestivals: [festival],
        rawTithiPradosha: 28.1,
      );

      expect(
        panchang.festivals.map((festival) => festival.id),
        equals(['pradosh_vrata']),
      );
    });
  });

  group('Moonrise checkpoint matching', () {
    // A `moonrise` rule is tested against the tithi at the Moon's rise, not at
    // sunrise. Karva Chauth is the shipped example of a moonrise observance
    // (its `pujaKala`/`paranRule`), so the checkpoint must be real rather than
    // a documented value that silently degrades to sunrise matching.
    Festival karvaChauth() => Festival.fromJson({
      'id': 'karva_chauth',
      'name': 'Karva Chauth',
      'panchang_rules': {
        'masa': 'Ashwin',
        'paksha': 'Krishna',
        'tithi': 4,
        'conditions': 'Chaturthi',
        'timingOverride': 'moonrise',
        'pujaKala': 'moonrise',
        'paranRule': 'moonrise',
      },
    });

    PanchangData at({required double sunrise, double? moonrise}) =>
        PanchangData.fromRawTithi(
          date: DateTime(2026, 10, 29),
          rawTithi: sunrise,
          masa: 'Ashwin',
          allFestivals: [karvaChauth()],
          rawTithiMoonrise: moonrise,
        );

    test('matches on the tithi prevailing at moonrise', () {
      // Sunrise is still Tritiya; Chaturthi has begun by moonrise.
      final panchang = at(sunrise: 18.6, moonrise: 19.2);

      expect(panchang.festivals.map((f) => f.id), equals(['karva_chauth']));
    });

    test('does not match when the tithi has already left by moonrise', () {
      // Sunrise is Chaturthi, but Panchami begins before the Moon rises.
      final panchang = at(sunrise: 19.2, moonrise: 20.4);

      expect(panchang.festivals, isEmpty);
    });

    test('falls back to the sunrise tithi on a day with no moonrise', () {
      // The Moon does not rise on roughly one civil day a month. The rule then
      // reads the day's own tithi instead of inventing a checkpoint.
      final panchang = at(sunrise: 19.2);

      expect(panchang.festivals.map((f) => f.id), equals(['karva_chauth']));
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

  group('Sankranti solar matching', () {
    Festival transitFestival({String? rashi = 'Makara', String? solarDate}) {
      return Festival.fromJson({
        'id': 'makar_sankranti',
        'name': 'Makar Sankranti',
        'panchang_rules': {
          'masa': 'Pausha',
          'paksha': '*',
          'tithi': 0,
          'conditions': 'Solar',
          'sankranti': ?rashi,
          'solarDate': ?solarDate,
        },
      });
    }

    PanchangData day({
      required DateTime date,
      required List<Festival> festivals,
      String? sankrantiRashi,
      DateTime? sankrantiInstant,
      bool sankrantiComputed = false,
    }) {
      return PanchangData.fromRawTithi(
        date: date,
        rawTithi: 10.2,
        masa: 'Pausha',
        allFestivals: festivals,
        sunrise: DateTime(date.year, date.month, date.day, 6, 30),
        sunset: DateTime(date.year, date.month, date.day, 18),
        sankrantiRashi: sankrantiRashi,
        sankrantiInstant: sankrantiInstant,
        sankrantiComputed: sankrantiComputed,
      );
    }

    test('matches the ingress day when the rashi agrees', () {
      // Arrange
      final festival = transitFestival();

      // Act: Sun enters Makara at 09:00 on Jan 14.
      final panchang = day(
        date: DateTime(2027, 1, 14),
        festivals: [festival],
        sankrantiRashi: 'Makara',
        sankrantiInstant: DateTime(2027, 1, 14, 9),
        sankrantiComputed: true,
      );

      // Assert
      expect(panchang.festivals.map((f) => f.id), contains('makar_sankranti'));
      expect(panchang.sankranti?.rashi, equals('Makara'));
      expect(panchang.sankranti?.instant, equals(DateTime(2027, 1, 14, 9)));
      expect(panchang.sankranti?.shifted, isFalse);
    });

    test('a different ingress rashi does not match', () {
      // Arrange
      final festival = transitFestival();

      // Act
      final panchang = day(
        date: DateTime(2027, 1, 14),
        festivals: [festival],
        sankrantiRashi: 'Kumbha',
        sankrantiInstant: DateTime(2027, 1, 14, 9),
        sankrantiComputed: true,
      );

      // Assert
      expect(panchang.festivals, isEmpty);
    });

    test('a computed day with no ingress does not fall back to solarDate', () {
      // Arrange: the old fixed date must not resurrect the festival once the
      // transit search ran, or both days would match.
      final festival = transitFestival(solarDate: '01-14');

      // Act
      final panchang = day(
        date: DateTime(2027, 1, 14),
        festivals: [festival],
        sankrantiComputed: true,
      );

      // Assert
      expect(panchang.festivals, isEmpty);
      expect(panchang.sankranti, isNull);
    });

    test('an uncomputed day falls back to the fixed solar date', () {
      // Arrange: paths without the ingress search (unit tests, old caches)
      // still match the shipped Gregorian date.
      final festival = transitFestival(solarDate: '01-14');

      // Act
      final onDate = day(date: DateTime(2027, 1, 14), festivals: [festival]);
      final offDate = day(date: DateTime(2027, 1, 15), festivals: [festival]);

      // Assert
      expect(onDate.festivals.map((f) => f.id), contains('makar_sankranti'));
      expect(offDate.festivals, isEmpty);
    });

    test('fixed-date solar festivals keep matching when ingress ran', () {
      // Arrange: a plain solar observance with no sankranti rashi.
      final festival = transitFestival(rashi: null, solarDate: '01-14');

      // Act
      final panchang = day(
        date: DateTime(2027, 1, 14),
        festivals: [festival],
        sankrantiRashi: 'Makara',
        sankrantiInstant: DateTime(2027, 1, 14, 9),
        sankrantiComputed: true,
      );

      // Assert
      expect(panchang.festivals.map((f) => f.id), contains('makar_sankranti'));
    });

    test('rashi names accept Sanskrit and English spellings', () {
      // Arrange + Act + Assert
      expect(normalizeRashiName('Makara'), equals('Makara'));
      expect(normalizeRashiName('capricorn'), equals('Makara'));
      expect(normalizeRashiName(' Capricorn '), equals('Makara'));
      expect(normalizeRashiName('bogus'), isNull);
      expect(rashiIndexForName('Makara'), equals(9));
      expect(rashiIndexForName('Capricorn'), equals(9));
      expect(rashiIndexForLongitude(270), equals(9));
      expect(rashiIndexForLongitude(269.9), equals(8));
      expect(rashiIndexForLongitude(-90), equals(9));
    });

    test('the ingress search is gated to the fixed-date estimate', () {
      // Arrange
      final transit = transitFestival(solarDate: '01-14');

      // Act + Assert: the gate keeps a 420-day scan cheap.
      expect(needsSankrantiSearchOn([transit], DateTime(2027, 1, 14)), isTrue);
      expect(needsSankrantiSearchOn([transit], DateTime(2027, 1, 16)), isTrue);
      expect(needsSankrantiSearchOn([transit], DateTime(2027, 1, 17)), isFalse);
      expect(needsSankrantiSearchOn([transit], DateTime(2027, 7, 15)), isFalse);
      // A non-transit festival never needs the search.
      expect(
        needsSankrantiSearchOn([transitFestival(rashi: null)], DateTime(2027)),
        isFalse,
      );
      // Without a fixed-date estimate there is nothing to gate on.
      expect(needsSankrantiSearchOn([transitFestival()], DateTime(2027)), isTrue);
    });

    test('copyWith keeps the day\'s Sankranti and Bhadra data', () {
      // Arrange: the single-day provider reuses the month entry through
      // copyWith, and the Vriddhi filter rebuilds days the same way. Dropping
      // these fields hid the punya kala card and left Bhadra untrimmed.
      final panchang = day(
        date: DateTime(2027, 1, 14),
        festivals: [transitFestival()],
        sankrantiRashi: 'Makara',
        sankrantiInstant: DateTime(2027, 1, 14, 9),
        sankrantiComputed: true,
      ).copyWith(
        tithiTransitionTime: DateTime(2027, 1, 14, 11),
        transitionTithiIndex: 11,
        bhadraWindows: [
          (
            start: DateTime(2027, 1, 14, 13),
            end: DateTime(2027, 1, 14, 14),
          ),
        ],
      );

      // Act: a later copy that only changes the label (the live hero path).
      final relabeled = panchang.copyWith(tithiNumber: 11, paksha: 'Shukla');

      // Assert
      expect(relabeled.sankranti?.instant, equals(DateTime(2027, 1, 14, 9)));
      expect(relabeled.sankranti?.rashi, equals('Makara'));
      expect(relabeled.sankrantiComputed, isTrue);
      expect(relabeled.bhadraWindows, hasLength(1));
      expect(relabeled.festivals.map((f) => f.id), contains('makar_sankranti'));
    });

    test('solarDateInYear rejects malformed and impossible dates', () {
      // Arrange + Act + Assert
      expect(solarDateInYear('01-14', 2027), equals(DateTime(2027, 1, 14)));
      expect(solarDateInYear('02-29', 2028), equals(DateTime(2028, 2, 29)));
      expect(solarDateInYear('02-29', 2027), isNull);
      expect(solarDateInYear('02-30', 2027), isNull);
      expect(solarDateInYear('1-14', 2027), equals(DateTime(2027, 1, 14)));
      expect(solarDateInYear('bogus', 2027), isNull);
      expect(solarDateInYear(null, 2027), isNull);
    });
  });
}
