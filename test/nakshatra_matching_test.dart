import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tithi/models/festival.dart';
import 'package:tithi/models/panchang_data.dart';

Festival mulaFestival() {
  return const Festival(
    id: 'saraswati_avahan',
    name: 'Saraswati Avahan',
    category: 'major',
    nameRegional: NameRegional(nameEnglish: 'Test'),
    visuals: Visuals(),
    purpose: Purpose(description: 'Test'),
    panchangRules: PanchangRules(
      masa: 'Ashwin',
      paksha: 'Shukla',
      tithi: 7,
      conditions: 'Mula Nakshatra',
      vriddhi: 'first',
    ),
    rituals: Rituals(steps: []),
    media: Media(),
  );
}

void main() {
  group('Nakshatra names', () {
    test('27 mansions with Mula at index 18', () {
      expect(hinduNakshatras, hasLength(27));
      expect(hinduNakshatras[0], equals('Ashwini'));
      expect(hinduNakshatras[18], equals('Mula'));
      expect(hinduNakshatras[26], equals('Revati'));
    });

    test('nakshatraForLongitude maps Mula span 240-253.33', () {
      expect(nakshatraForLongitude(240.0), equals('Mula'));
      expect(nakshatraForLongitude(250.0), equals('Mula'));
      expect(nakshatraForLongitude(239.9), equals('Jyeshtha'));
      expect(nakshatraForLongitude(253.4), equals('Purva Ashadha'));
      expect(nakshatraForLongitude(360.0), equals('Ashwini'));
    });
  });

  group('Nakshatra lords', () {
    test('9-graha Vimshottari sequence repeats three times', () {
      expect(nakshatraLords, hasLength(9));
      for (var i = 0; i < 27; i++) {
        expect(
          nakshatraLordFor(i),
          equals(nakshatraLords[i % 9]),
          reason: 'index $i (${hinduNakshatras[i]})',
        );
      }
    });

    test('spot-check Ashwini, Rohini, Mula, Revati lords', () {
      expect(nakshatraLordFor(0), equals('Ketu')); // Ashwini
      expect(nakshatraLordFor(3), equals('Moon')); // Rohini
      expect(nakshatraLordFor(18), equals('Ketu')); // Mula
      expect(nakshatraLordFor(26), equals('Mercury')); // Revati
    });
  });

  group('nakshatraCondition parsing', () {
    test('Mula Nakshatra (any case) resolves to canonical Mula', () {
      expect(mulaFestival().nakshatraCondition, equals('Mula'));
      const lower = Festival(
        id: 'x',
        name: 'x',
        nameRegional: NameRegional(nameEnglish: 'x'),
        visuals: Visuals(),
        purpose: Purpose(description: 'x'),
        panchangRules: PanchangRules(
          masa: 'Ashwin',
          paksha: 'Shukla',
          tithi: 7,
          conditions: 'mula nakshatra',
        ),
        rituals: Rituals(steps: []),
        media: Media(),
      );
      expect(lower.nakshatraCondition, equals('Mula'));
    });

    test('tithi and Solar conditions yield null', () {
      Festival withConditions(String c) => Festival(
        id: 'x',
        name: 'x',
        nameRegional: const NameRegional(nameEnglish: 'x'),
        visuals: const Visuals(),
        purpose: const Purpose(description: 'x'),
        panchangRules: PanchangRules(
          masa: 'Ashwin',
          paksha: 'Shukla',
          tithi: 7,
          conditions: c,
        ),
        rituals: const Rituals(steps: []),
        media: const Media(),
      );
      expect(withConditions('Saptami').nakshatraCondition, isNull);
      expect(withConditions('Solar').nakshatraCondition, isNull);
      expect(withConditions('').nakshatraCondition, isNull);
      expect(withConditions('Foo Nakshatra').nakshatraCondition, isNull);
    });
  });

  group('matchesFestivalOnDay', () {
    test('matches masa + paksha + Mula regardless of tithi', () {
      // Shashthi day (tithi 6): matches, like Oct 16 2026.
      expect(
        matchesFestivalOnDay(
          festival: mulaFestival(),
          paksha: 'Shukla',
          tithiNumber: 6,
          masa: 'Ashwin',
          nakshatra: 'Mula',
          date: DateTime(2026, 10, 16),
        ),
        isTrue,
      );
      // Saptami day (tithi 7): also matches, like Sep 29 2025.
      expect(
        matchesFestivalOnDay(
          festival: mulaFestival(),
          paksha: 'Shukla',
          tithiNumber: 7,
          masa: 'Ashwin',
          nakshatra: 'Mula',
          date: DateTime(2025, 9, 29),
        ),
        isTrue,
      );
    });

    test('wrong nakshatra, masa, paksha, or unknown all miss', () {
      expect(
        matchesFestivalOnDay(
          festival: mulaFestival(),
          paksha: 'Shukla',
          tithiNumber: 6,
          masa: 'Ashwin',
          nakshatra: 'Rohini',
        ),
        isFalse,
      );
      expect(
        matchesFestivalOnDay(
          festival: mulaFestival(),
          paksha: 'Shukla',
          tithiNumber: 6,
          masa: 'Ashwin',
          nakshatra: null,
        ),
        isFalse,
      );
      expect(
        matchesFestivalOnDay(
          festival: mulaFestival(),
          paksha: 'Shukla',
          tithiNumber: 6,
          masa: 'Bhadrapada',
          nakshatra: 'Mula',
        ),
        isFalse,
      );
      expect(
        matchesFestivalOnDay(
          festival: mulaFestival(),
          paksha: 'Krishna',
          tithiNumber: 6,
          masa: 'Ashwin',
          nakshatra: 'Mula',
        ),
        isFalse,
      );
    });
  });

  group('PanchangData.fromRawTithi with nakshatra', () {
    PanchangData dayOn(double rawTithi, String? nakshatra) {
      return PanchangData.fromRawTithi(
        date: DateTime(2026, 10, 16),
        rawTithi: rawTithi,
        masa: 'Ashwin',
        allFestivals: [mulaFestival()],
        nakshatraAtSunrise: nakshatra,
      );
    }

    test('stored tithi ignored: matches on Shashthi and Saptami', () {
      expect(dayOn(6.5, 'Mula').festivals.map((f) => f.id), equals(['saraswati_avahan']));
      expect(dayOn(7.5, 'Mula').festivals.map((f) => f.id), equals(['saraswati_avahan']));
    });

    test('misses without Mula at sunrise', () {
      expect(dayOn(6.5, 'Rohini').festivals, isEmpty);
      expect(dayOn(6.5, null).festivals, isEmpty);
    });

    test('nakshatra preserved on the day for the detail sheet', () {
      expect(dayOn(6.5, 'Mula').nakshatra, equals('Mula'));
    });
  });

  group('Dataset', () {
    test('Saraswati Avahan is Mula-observed, first of run', () {
      final file = File('assets/festivals.json');
      final decoded = jsonDecode(file.readAsStringSync()) as List;
      final entry = decoded.cast<Map<String, dynamic>>().firstWhere(
        (f) => f['id'] == 'sharad_navratri_saraswati Avahan',
      );
      final rules = (entry['panchang_rules'] as Map).cast<String, dynamic>();
      expect(rules['conditions'], equals('Mula Nakshatra'));
      expect(rules['vriddhi'], equals('first'));
      expect(
        Festival.fromJson(entry).nakshatraCondition,
        equals('Mula'),
      );
    });

    test('Saraswati Puja is Purva-Ashadha-observed, first of run', () {
      final file = File('assets/festivals.json');
      final decoded = jsonDecode(file.readAsStringSync()) as List;
      final entry = decoded.cast<Map<String, dynamic>>().firstWhere(
        (f) => f['id'] == 'sharad_navratri_saraswati_puja',
      );
      final rules = (entry['panchang_rules'] as Map).cast<String, dynamic>();
      expect(rules['conditions'], equals('Purva Ashadha Nakshatra'));
      expect(rules['vriddhi'], equals('first'));
      expect(
        Festival.fromJson(entry).nakshatraCondition,
        equals('Purva Ashadha'),
      );
    });
  });
}
