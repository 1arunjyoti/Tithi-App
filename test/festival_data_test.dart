import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
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
}
