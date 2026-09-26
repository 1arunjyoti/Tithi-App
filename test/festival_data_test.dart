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

Map<String, dynamic> _rulesOf(
  List<Map<String, dynamic>> festivals,
  String id,
) {
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
      expect(
        normalizedPujaKala(loaded('maha_shivaratri')),
        equals('nishita'),
      );
      expect(normalizedPujaKala(loaded('lakshmi_puja')), equals('pradosha'));
    });

    test('every Ekadashi entry breaks in the Dwadashi window', () {
      // Arrange + Act
      const ids = [
        'varuthini_ekadashi',
        'nirjala_ekadashi',
        'devshayani_ekadashi',
        'kamika_ekadashi',
        'pavitra_ekadashi',
        'devutthani_ekadashi',
        'pausha_putrada_ekadashi',
        'ekadashi_shukla',
        'ekadashi_krishna',
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
  });
}
