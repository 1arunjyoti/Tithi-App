import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:tithi/models/festival.dart';
import 'package:tithi/models/hindu_month_system.dart';
import 'package:tithi/models/panchang_data.dart';
import 'package:tithi/services/festival_export_service.dart';

Festival _ganesh() => Festival.fromJson({
      'id': 'ganesh_chaturthi',
      'name': 'Ganesh Chaturthi',
      'category': 'major',
      'nameRegional': {'nameHindi': 'गणेश चतुर्थी'},
      'panchang_rules': {
        'masa': 'Bhadrapada',
        'paksha': 'Shukla',
        'tithi': 4,
        'conditions': 'Chaturthi',
        'timingOverride': 'madhyahna',
      },
    });

void main() {
  group('FestivalExportService.buildEntry', () {
    test('encodes identity, rule, and occurrence', () {
      final entry = FestivalExportService.buildEntry(
        festival: _ganesh(),
        date: DateTime(2026, 9, 14),
        paksha: 'Shukla',
        tithiNumber: 4,
        tithiIndex: 4,
        tithiName: 'Chaturthi',
        masa: 'Bhadrapada',
        masaDisplay: 'Bhadrapada',
        vsYear: 2083,
        shakaYear: 1948,
        tithiBegins: DateTime(2026, 9, 14, 7, 6),
        tithiEnds: DateTime(2026, 9, 15, 7, 44),
        sunrise: DateTime(2026, 9, 14, 6, 7),
        sunset: DateTime(2026, 9, 14, 18, 28),
      );

      expect(entry['id'], equals('ganesh_chaturthi'));
      expect(entry['name'], equals('Ganesh Chaturthi'));
      expect(entry['category'], equals('major'));
      expect(
        entry['rule'],
        equals({
          'masa': 'Bhadrapada',
          'paksha': 'Shukla',
          'tithi': 4,
          'conditions': 'Chaturthi',
        }),
      );

      final occurrence = entry['occurrence'] as Map<String, dynamic>;
      expect(occurrence['date'], equals('2026-09-14'));
      expect(occurrence['paksha'], equals('Shukla'));
      expect(occurrence['tithiNumber'], equals(4));
      expect(occurrence['tithiIndex'], equals(4));
      expect(occurrence['tithiName'], equals('Chaturthi'));
      expect(occurrence['masa'], equals('Bhadrapada'));
      expect(occurrence['masaDisplay'], equals('Bhadrapada'));
      expect(occurrence['vsYear'], equals(2083));
      expect(occurrence['shakaYear'], equals(1948));
      expect(
        occurrence['tithiBegins'],
        equals(DateTime(2026, 9, 14, 7, 6).toIso8601String()),
      );
      expect(
        occurrence['tithiEnds'],
        equals(DateTime(2026, 9, 15, 7, 44).toIso8601String()),
      );
    });

    test('null date encodes a null occurrence', () {
      final entry = FestivalExportService.buildEntry(festival: _ganesh());

      expect(entry['id'], equals('ganesh_chaturthi'));
      expect(entry['occurrence'], isNull);
    });

    test('March Phalguna stays in the old year (Amanta boundary)', () {
      // A March day in Phalguna Krishna (displayed as Chaitra Krishna in
      // Purnimant mode) still belongs to VS 2082: the era calc must use the
      // Amanta masa, never the display label.
      final entry = FestivalExportService.buildEntry(
        festival: _ganesh(),
        date: DateTime(2026, 3, 10),
        paksha: 'Krishna',
        tithiNumber: 11,
        tithiIndex: 26,
        tithiName: 'Ekadashi',
        masa: 'Phalguna',
        masaDisplay: 'Chaitra',
        vsYear: 2082,
        shakaYear: 1947,
      );

      final occurrence = entry['occurrence'] as Map<String, dynamic>;
      expect(occurrence['masa'], equals('Phalguna'));
      expect(occurrence['masaDisplay'], equals('Chaitra'));
      expect(occurrence['vsYear'], equals(2082));
      expect(occurrence['shakaYear'], equals(1947));
    });

    test('entry is JSON-serializable', () {
      final entry = FestivalExportService.buildEntry(
        festival: _ganesh(),
        date: DateTime(2026, 9, 14),
        paksha: 'Shukla',
        tithiNumber: 4,
        tithiIndex: 4,
        tithiName: 'Chaturthi',
        masa: 'Bhadrapada',
        masaDisplay: 'Bhadrapada',
      );

      // Must not throw; null timings stay null.
      final encoded = jsonEncode(entry);
      final decoded = jsonDecode(encoded) as Map<String, dynamic>;
      final occurrence = decoded['occurrence'] as Map<String, dynamic>;
      expect(occurrence['tithiBegins'], isNull);
      expect(occurrence['tithiEnds'], isNull);
      expect(occurrence['date'], equals('2026-09-14'));
    });
  });

  group('masaDisplay matches the UI for Krishna festivals', () {
    // Proves the export serializer resolves the same Purnimant labels the
    // UI shows, from the same Amanta inputs: Janmashtami day renders
    // Bhadrapada and Mahalaya day renders Ashwin in Purnimant mode.
    String exportLabel(double rawTithi, String amantaMasa) {
      final panchang = PanchangData.fromRawTithi(
        date: DateTime(2026, 9, 4),
        rawTithi: rawTithi,
        masa: amantaMasa,
      );
      return displayMasaName(
        panchang.masa,
        panchang.paksha,
        HinduMonthSystem.purnimant,
      );
    }

    test('Janmashtami day displays Bhadrapada in Purnimant mode', () {
      // Krishna Ashtami (index 23), Amanta Shravana.
      expect(exportLabel(23.5, 'Shravana'), equals('Bhadrapada'));
    });

    test('Mahalaya day displays Ashwin in Purnimant mode', () {
      // Amavasya (index 30), Amanta Bhadrapada.
      expect(exportLabel(30.0, 'Bhadrapada'), equals('Ashwin'));
    });

    test('Amanta mode keeps the matching-basis name', () {
      final panchang = PanchangData.fromRawTithi(
        date: DateTime(2026, 9, 4),
        rawTithi: 23.5,
        masa: 'Shravana',
      );
      expect(
        displayMasaName(
          panchang.masa,
          panchang.paksha,
          HinduMonthSystem.amanta,
        ),
        equals('Shravana'),
      );
    });
  });
}
