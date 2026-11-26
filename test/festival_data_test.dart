import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tithi/features/event_detail/domain/puja_samay.dart';
import 'package:tithi/models/festival.dart';
import 'package:tithi/models/hindu_month_system.dart';
import 'package:tithi/models/panchang_data.dart';

/// Loads the real festival dataset shipped with the app.
List<Map<String, dynamic>> _loadFestivalJson() {
  final file = File('assets/festivals.json');
  final decoded = jsonDecode(file.readAsStringSync());
  return (decoded as List).cast<Map<String, dynamic>>();
}

Map<String, dynamic> _rulesOf(List<Map<String, dynamic>> festivals, String id) {
  final entry = festivals.firstWhere(
    (f) => f['id'] == id,
    orElse: () => throw StateError('festival $id not found in dataset'),
  );
  return (entry['panchang_rules'] as Map).cast<String, dynamic>();
}

void main() {
  group('Festival dataset stores Krishna rules in Amanta months', () {
    // Festivals are matched in Amanta, so Krishna-paksha rules must carry
    // the Amanta month name (NOT the Purnimanta one). These three were once
    // stored with the North-Indian (Purnimanta) month and fired ~a month late.
    test('Kamika Ekadashi is Ashadha Krishna Ekadashi (Amanta)', () {
      final rules = _rulesOf(_loadFestivalJson(), 'kamika_ekadashi');
      expect(rules['masa'], equals('Ashadha'));
      expect(rules['paksha'], equals('Krishna'));
      expect(rules['tithi'], equals(11));
    });

    test('Varuthini Ekadashi is Chaitra Krishna Ekadashi (Amanta)', () {
      final rules = _rulesOf(_loadFestivalJson(), 'varuthini_ekadashi');
      expect(rules['masa'], equals('Chaitra'));
      expect(rules['paksha'], equals('Krishna'));
      expect(rules['tithi'], equals(11));
    });

    test('Kajari Teej is Shravana Krishna Tritiya (Amanta)', () {
      final rules = _rulesOf(_loadFestivalJson(), 'kajari_teej');
      expect(rules['masa'], equals('Shravana'));
      expect(rules['paksha'], equals('Krishna'));
      expect(rules['tithi'], equals(3));
    });

    test('Janmashtami guard: Shravana Krishna Ashtami (Amanta)', () {
      final rules = _rulesOf(_loadFestivalJson(), 'janmashtami');
      expect(rules['masa'], equals('Shravana'));
      expect(rules['paksha'], equals('Krishna'));
      expect(rules['tithi'], equals(8));
    });
  });

  group('Corrected festivals match on the right day in both systems', () {
    test('Kamika matches Ashadha Krishna Ekadashi in both modes', () {
      final festivals = _loadFestivalJson();
      final kamika = Festival.fromJson(
        festivals.firstWhere((f) => f['id'] == 'kamika_ekadashi'),
      );

      for (final system in HinduMonthSystem.values) {
        final panchang = PanchangData.fromRawTithi(
          date: DateTime(2026, 7, 10),
          rawTithi: 26.5, // Krishna Ekadashi (index 15 + 11)
          masa: 'Ashadha', // Amanta masa from calculateMasa
          allFestivals: [kamika],
          monthSystem: system,
          sunrise: DateTime(2026, 7, 10, 6),
          sunset: DateTime(2026, 7, 10, 19),
        );

        expect(
          panchang.festivals.map((f) => f.id),
          contains('kamika_ekadashi'),
          reason: 'Kamika must match in $system mode',
        );
      }
    });

    test('Kajari matches Shravana Krishna Tritiya in both modes', () {
      final festivals = _loadFestivalJson();
      final kajari = Festival.fromJson(
        festivals.firstWhere((f) => f['id'] == 'kajari_teej'),
      );

      for (final system in HinduMonthSystem.values) {
        final panchang = PanchangData.fromRawTithi(
          date: DateTime(2026, 8, 31),
          rawTithi: 18.5, // Krishna Tritiya (index 15 + 3)
          masa: 'Shravana', // Amanta masa from calculateMasa
          allFestivals: [kajari],
          monthSystem: system,
          sunrise: DateTime(2026, 8, 31, 6),
          sunset: DateTime(2026, 8, 31, 18, 45),
        );

        expect(
          panchang.festivals.map((f) => f.id),
          contains('kajari_teej'),
          reason: 'Kajari Teej must match in $system mode',
        );
      }
    });
  });

  group('Solar festivals use fixed Gregorian dates', () {
    // Pongal was once stored as a lunisolar Thai/Shukla/15 (Purnima) rule
    // whose masa never equals a computed lunisolar masa, so it never fired.
    // It is a solar harvest festival on Jan 14, same as Makar Sankranti.
    test('Pongal guard: Solar 01-14 (same day as Makar Sankranti)', () {
      // Arrange
      final rules = _rulesOf(_loadFestivalJson(), 'pongal');

      // Act + Assert
      expect(rules['conditions'], equals('Solar'));
      expect(rules['solarDate'], equals('01-14'));
      expect(rules['tithi'], equals(0));
      expect(rules['paksha'], equals('*'));
    });

    test('Pongal matches Jan 14 regardless of tithi/masa', () {
      // Arrange
      final festivals = _loadFestivalJson();
      final pongal = Festival.fromJson(
        festivals.firstWhere((f) => f['id'] == 'pongal'),
      );

      // Act
      final onDay = PanchangData.fromRawTithi(
        date: DateTime(2026, 1, 14),
        rawTithi: 5.5,
        masa: 'Pausha',
        allFestivals: [pongal],
      );
      final offDay = PanchangData.fromRawTithi(
        date: DateTime(2026, 1, 15),
        rawTithi: 15.5, // Purnima — the old dead Thai/Shukla/15 rule
        masa: 'Thai',
        allFestivals: [pongal],
      );

      // Assert
      expect(onDay.festivals.map((f) => f.id), contains('pongal'));
      expect(offDay.festivals.map((f) => f.id), isNot(contains('pongal')));
    });
  });

  group('Puja Samay dataset wiring', () {
    // The Puja Samay card and the paran line render only when the entry's
    // data carries pujaKala / paranRule. Ganesh Chaturthi once shipped the
    // snake_case twin (puja_kala) while the sheet read camelCase, so the
    // card silently hid — these guards pin the full chain (JSON spelling →
    // parser → normalizer) on the real file.
    Festival loaded(String id) {
      final entry = _loadFestivalJson().firstWhere(
        (f) => f['id'] == id,
        orElse: () => throw StateError('festival $id not found in dataset'),
      );
      return Festival.fromJson(entry);
    }

    test('Ganesh Chaturthi snake_case kala resolves (both spellings)', () {
      // Arrange + Act
      final ganesh = loaded('ganesh_chaturthi');

      // Assert
      expect(ganesh.panchangRules.pujaKala, equals('madhyahna'));
      expect(normalizedPujaKala(ganesh), equals('madhyahna'));
    });

    test('Janmashtami pairs nishita kala with after-puja paran', () {
      // Arrange + Act
      final janmashtami = loaded('janmashtami');

      // Assert
      expect(normalizedPujaKala(janmashtami), equals('nishita'));
      expect(normalizedParanRule(janmashtami), equals('after_puja_kala'));
    });

    test('Karva Chauth pairs moonrise kala with moonrise paran', () {
      // Arrange + Act
      final karva = loaded('karva_chauth');

      // Assert
      expect(normalizedPujaKala(karva), equals('moonrise'));
      expect(normalizedParanRule(karva), equals('moonrise'));
    });

    test('Shivaratri and Lakshmi Puja carry night kalas', () {
      // Arrange + Act + Assert
      expect(normalizedPujaKala(loaded('maha_shivaratri')), equals('nishita'));
      expect(normalizedPujaKala(loaded('lakshmi_puja')), equals('pradosha'));
    });

    test('every Ekadashi entry breaks in the Dwadashi window', () {
      // Arrange + Act
      const ids = [
        'kamada_ekadashi',
        'papamochani_ekadashi',
        'mohini_ekadashi',
        'varuthini_ekadashi',
        'nirjala_ekadashi',
        'apara_ekadashi',
        'devshayani_ekadashi',
        'yogini_ekadashi',
        'shravana_putrada_ekadashi',
        'kamika_ekadashi',
        'parivartini_ekadashi',
        'aja_ekadashi',
        'pashankusha_ekadashi',
        'indira_ekadashi',
        'devutthani_ekadashi',
        'rama_ekadashi',
        'mokshada_ekadashi',
        'utpanna_ekadashi',
        'pausha_putrada_ekadashi',
        'saphala_ekadashi',
        'jaya_ekadashi',
        'shattila_ekadashi',
        'amalaki_ekadashi',
        'vijaya_ekadashi',
        'padmini_ekadashi',
        'parama_ekadashi',
      ];

      // Assert
      for (final id in ids) {
        expect(
          normalizedParanRule(loaded(id)),
          equals('dwadashi_window'),
          reason: '$id must carry the Dwadashi paran rule',
        );
      }
    });

    test('Tulsi Vivah carries the Godhuli kala', () {
      // Arrange + Act
      final tulsi = loaded('tulsi_vivah');

      // Assert
      expect(normalizedPujaKala(tulsi), equals('godhuli'));
      expect(tulsi.panchangRules.timingOverride, isNull);
    });

    test(
      'Makar Sankranti and Pongal match the transit and show punya kala',
      () {
        // Arrange + Act
        final makar = loaded('makar_sankranti');
        final pongal = loaded('pongal');

        // Assert
        for (final festival in [makar, pongal]) {
          expect(
            festival.panchangRules.sankrantiRashi,
            equals('Makara'),
            reason: '${festival.id} must follow the Sun into Makara',
          );
          expect(normalizedPujaKala(festival), equals('punya_kala'));
          // The fixed date stays as the fallback when the ingress search is
          // skipped, so both surfaces agree on the shipped date.
          expect(festival.panchangRules.solarDate, equals('01-14'));
        }
      },
    );

    test('Raksha Bandhan avoids Bhadra', () {
      // Arrange + Act
      final rakhi = loaded('raksha_bandhan');

      // Assert
      expect(rakhi.panchangRules.avoidBhadra, isTrue);
      expect(normalizedPujaKala(rakhi), equals('aparahna'));
    });
  });

  group('Curated featured flag in the shipped catalog', () {
    test('flags a small curated set and nothing else', () {
      // Arrange
      final festivals = _loadFestivalJson();
      final flagged = [
        for (final entry in festivals)
          if (entry['featured'] != null)
            (id: entry['id'] as String, featured: entry['featured']),
      ];

      // Assert: only a real `true` counts, and the set stays rare. "major"
      // covers 94 of the bundled records, which is exactly why the featured card
      // cannot use the category; if this set grows past a quarter of the
      // catalog, "featured" has stopped meaning anything.
      expect(flagged, isNotEmpty);
      expect(flagged.where((f) => f.featured != true), isEmpty);
      expect(flagged.length, lessThanOrEqualTo(festivals.length ~/ 4));
    });

    test('covers the flagship observances, not just the artwork entries', () {
      // Arrange
      final featured = {
        for (final entry in _loadFestivalJson())
          if (entry['featured'] == true) entry['id'] as String,
      };

      // Assert: the set is an editorial fact, so it is neither the 7 records
      // that ship artwork nor the 96 in the major category.
      expect(featured, containsAll(['diwali', 'holi', 'dussehra']));
      // Karva Chauth is a vrat and is deliberately not in the curated set:
      // `featured` is an editorial choice, not a category or an artwork flag.
      expect(featured, isNot(contains('karva_chauth')));
      expect(featured, isNot(contains('hanuman_jayanti')));
      expect(featured.length, greaterThan(7));
    });

    test('keeps a multi-day celebration whole', () {
      // Arrange
      final featured = {
        for (final entry in _loadFestivalJson())
          if (entry['featured'] == true) entry['id'] as String,
      };

      // Assert: Durga Puja runs for days. Featuring one day and dropping the
      // rest is what "the next major from today" did, and it looked broken.
      expect(
        featured,
        containsAll([
          'shashthi_durga_puja',
          'saptami_durga_puja',
          'ashtami_durga_puja',
          'navami_durga_puja',
          'dasami_durga_puja',
        ]),
      );
    });

    test('parses into Festival.featured and defaults to false', () {
      // Arrange
      final festivals = _loadFestivalJson();

      // Act
      final diwali = Festival.fromJson(
        festivals.firstWhere((entry) => entry['id'] == 'diwali'),
      );
      final unflagged = Festival.fromJson(
        festivals.firstWhere((entry) => entry['id'] == 'hanuman_jayanti'),
      );

      // Assert
      expect(diwali.featured, isTrue);
      expect(unflagged.featured, isFalse);
    });
  });

  group('Named Ekadashis resolve individually', () {
    // Amanta month that is STORED for each of the 24 named Ekadashis. The
    // Krishna ones are the month that ends with that Amavasya, so they read
    // one month earlier than the Purnimanta name devotees know them by.
    const named = [
      ('kamada_ekadashi', 'Chaitra', 'Shukla'),
      ('papamochani_ekadashi', 'Phalguna', 'Krishna'),
      ('mohini_ekadashi', 'Vaishakha', 'Shukla'),
      ('varuthini_ekadashi', 'Chaitra', 'Krishna'),
      ('nirjala_ekadashi', 'Jyeshtha', 'Shukla'),
      ('apara_ekadashi', 'Vaishakha', 'Krishna'),
      ('devshayani_ekadashi', 'Ashadha', 'Shukla'),
      ('yogini_ekadashi', 'Jyeshtha', 'Krishna'),
      ('shravana_putrada_ekadashi', 'Shravana', 'Shukla'),
      ('kamika_ekadashi', 'Ashadha', 'Krishna'),
      ('parivartini_ekadashi', 'Bhadrapada', 'Shukla'),
      ('aja_ekadashi', 'Shravana', 'Krishna'),
      ('pashankusha_ekadashi', 'Ashwin', 'Shukla'),
      ('indira_ekadashi', 'Bhadrapada', 'Krishna'),
      ('devutthani_ekadashi', 'Kartika', 'Shukla'),
      ('rama_ekadashi', 'Ashwin', 'Krishna'),
      ('mokshada_ekadashi', 'Margashirsha', 'Shukla'),
      ('utpanna_ekadashi', 'Kartika', 'Krishna'),
      ('pausha_putrada_ekadashi', 'Pausha', 'Shukla'),
      ('saphala_ekadashi', 'Margashirsha', 'Krishna'),
      ('jaya_ekadashi', 'Magha', 'Shukla'),
      ('shattila_ekadashi', 'Pausha', 'Krishna'),
      ('amalaki_ekadashi', 'Phalguna', 'Shukla'),
      ('vijaya_ekadashi', 'Magha', 'Krishna'),
    ];

    test('all 24 names carry specific Amanta rules', () {
      final festivals = _loadFestivalJson();
      expect(named, hasLength(24));

      for (final (id, masa, paksha) in named) {
        final entry = festivals.firstWhere(
          (f) => f['id'] == id,
          orElse: () => throw StateError('$id is missing from festivals.json'),
        );
        final rules = (entry['panchang_rules'] as Map).cast<String, dynamic>();
        expect(entry['category'], equals('vrat'), reason: '$id category');
        expect(rules['masa'], equals(masa), reason: '$id masa');
        expect(rules['paksha'], equals(paksha), reason: '$id paksha');
        expect(rules['tithi'], equals(11), reason: '$id tithi');
        expect(rules['conditions'], equals('Ekadashi'), reason: '$id condition');
        // Strict sunrise matching resolves a viddha day (Dashami at sunrise)
        // to the true day; vriddhi "first" keeps a genuine two-sunrise run to
        // one observance. Together they replace the viddha rule the engine
        // cannot express on its own.
        expect(
          rules['dominant_tithi'],
          equals('strict'),
          reason: '$id dominant_tithi',
        );
        expect(rules['vriddhi'], equals('first'), reason: '$id vriddhi');
      }
    });

    test('no wildcard entry competes with a named Ekadashi', () {
      final festivals = _loadFestivalJson();
      final ids = festivals.map((f) => f['id'] as String).toSet();
      expect(ids, isNot(contains('ekadashi_shukla')));
      expect(ids, isNot(contains('ekadashi_krishna')));

      for (final entry in festivals) {
        final rules = (entry['panchang_rules'] as Map).cast<String, dynamic>();
        if (rules['conditions'] == 'Ekadashi') {
          expect(
            rules['masa'],
            isNot(equals('*')),
            reason: '${entry['id']} would match every Ekadashi',
          );
        }
      }
    });

    test('Adhika Jyeshtha supplies Padmini and Parama', () {
      final festivals = _loadFestivalJson();
      for (final (id, paksha) in [
        ('padmini_ekadashi', 'Shukla'),
        ('parama_ekadashi', 'Krishna'),
      ]) {
        final rules = _rulesOf(festivals, id);
        expect(rules['masa'], equals('Adhika_Jyeshtha'), reason: '$id masa');
        expect(rules['paksha'], equals(paksha), reason: '$id paksha');
        expect(rules['tithi'], equals(11));
        expect(
          rules['dominant_tithi'],
          equals('strict'),
          reason: 'Adhika entry $id timing',
        );
        expect(
          rules['vriddhi'],
          equals('first'),
          reason: 'Adhika entry $id vriddhi',
        );
      }
    });

    test('Kartika Shukla and Krishna resolve to different names', () {
      final namedIds = named.map((e) => e.$1).toList();
      final festivals = _loadFestivalJson()
          .where((f) => namedIds.contains(f['id']))
          .map(Festival.fromJson)
          .toList();

      for (final system in HinduMonthSystem.values) {
        final shukla = PanchangData.fromRawTithi(
          date: DateTime(2026, 11, 20),
          rawTithi: 11.5,
          masa: 'Kartika',
          allFestivals: festivals,
          monthSystem: system,
          sunrise: DateTime(2026, 11, 20, 6),
          sunset: DateTime(2026, 11, 20, 18),
        );
        final krishna = PanchangData.fromRawTithi(
          date: DateTime(2026, 12, 5),
          rawTithi: 26.5,
          masa: 'Kartika',
          allFestivals: festivals,
          monthSystem: system,
          sunrise: DateTime(2026, 12, 5, 6),
          sunset: DateTime(2026, 12, 5, 18),
        );
        final shuklaIds = shukla.festivals.map((f) => f.id).toList();
        final krishnaIds = krishna.festivals.map((f) => f.id).toList();
        expect(shuklaIds, contains('devutthani_ekadashi'), reason: '$system');
        expect(shuklaIds, isNot(contains('utpanna_ekadashi')), reason: '$system');
        expect(krishnaIds, contains('utpanna_ekadashi'), reason: '$system');
        expect(krishnaIds, isNot(contains('devutthani_ekadashi')), reason: '$system');
      }
    });

    test('every non-solar festival uses a canonical Amanta masa', () {
      // The matcher compares festival.masa to the computed month literally, so
      // a near-miss spelling such as "Kartik" silently never matches.
      const canonical = <String>{
        '*',
        'Chaitra',
        'Vaishakha',
        'Jyeshtha',
        'Adhika_Jyeshtha',
        'Ashadha',
        'Shravana',
        'Bhadrapada',
        'Ashwin',
        'Kartika',
        'Margashirsha',
        'Pausha',
        'Magha',
        'Phalguna',
      };
      for (final entry in _loadFestivalJson()) {
        final rules = (entry['panchang_rules'] as Map).cast<String, dynamic>();
        if (rules['conditions'] == 'Solar') continue;
        final masa = rules['masa'] as String?;
        expect(
          masa,
          isIn(canonical),
          reason: '${entry['id']} masa "$masa" never matches a computed month',
        );
      }
    });

    test('Rash Purnima matches Kartika Shukla 15', () {
      final festival = Festival.fromJson(
        _loadFestivalJson().firstWhere((f) => f['id'] == 'rash_purnima'),
      );
      expect(
        matchesFestivalOnDay(
          festival: festival,
          paksha: 'Shukla',
          tithiNumber: 15,
          masa: 'Kartika',
          nakshatra: null,
        ),
        isTrue,
      );
    });

    test('Rash Purnima keeps one day of an extended tithi run', () {
      // 2026: Purnima begins 23 Nov ~23:42, so the nishita window of the 23rd
      // and the sunset of the 24th both satisfy the rule. Without a vriddhi
      // preference the home card (per-day panchang) shows both days while the
      // all-festivals occurrence scan shows only the first - pin 'first' so
      // the shared applyVriddhiFilter trims the extra day everywhere.
      final entry = _loadFestivalJson().firstWhere(
        (f) => f['id'] == 'rash_purnima',
      );
      final rules = (entry['panchang_rules'] as Map).cast<String, dynamic>();
      expect(rules['vriddhi'], equals('first'));
      expect(Festival.fromJson(entry).panchangRules.vriddhi, equals('first'));
    });
  });
}
