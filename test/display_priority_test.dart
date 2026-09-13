import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tithi/models/festival.dart';
import 'package:tithi/models/panchang_data.dart';

Festival priorityFestival(
  String id, {
  int? displayPriority,
  String category = 'major',
  int tithi = 9,
}) {
  return Festival(
    id: id,
    name: id,
    category: category,
    nameRegional: const NameRegional(nameEnglish: 'Test'),
    visuals: const Visuals(),
    purpose: const Purpose(description: 'Test'),
    panchangRules: PanchangRules(
      masa: 'Ashwin',
      paksha: 'Shukla',
      tithi: tithi,
      conditions: 'Navami',
    ),
    rituals: const Rituals(steps: []),
    media: const Media(),
    displayPriority: displayPriority,
  );
}

void main() {
  group('displayPriority', () {
    test('fromJson parses missing as null and int as-is', () {
      // Arrange + Act
      final missing = Festival.fromJson({
        'id': 'a',
        'name': 'A',
        'panchang_rules': {
          'masa': 'Ashwin',
          'paksha': 'Shukla',
          'tithi': 9,
          'conditions': 'Navami',
        },
      });
      final ranked = Festival.fromJson({
        'id': 'b',
        'name': 'B',
        'displayPriority': 2,
        'panchang_rules': {
          'masa': 'Ashwin',
          'paksha': 'Shukla',
          'tithi': 9,
          'conditions': 'Navami',
        },
      });

      // Assert
      expect(missing.displayPriority, isNull);
      expect(ranked.displayPriority, equals(2));
    });

    test('all-null list keeps current order (missing == current behaviour)', () {
      // Arrange: Hive A-Z order that caused the Siddhidatri report
      final festivals = [
        priorityFestival('dussehra'),
        priorityFestival('navami_durga_puja'),
        priorityFestival('sharad_navratri_siddhidatri_puja'),
      ];

      // Act
      sortFestivalsByDisplayPriority(festivals);

      // Assert: untouched
      expect(
        festivals.map((f) => f.id).toList(),
        equals([
          'dussehra',
          'navami_durga_puja',
          'sharad_navratri_siddhidatri_puja',
        ]),
      );
    });

    test('ranked festivals sort before unranked, lower first', () {
      // Arrange: worst-case input order (Hive A-Z)
      final festivals = [
        priorityFestival('dussehra', displayPriority: 3),
        priorityFestival('navami_durga_puja', displayPriority: 2),
        priorityFestival('sharad_navratri_siddhidatri_puja',
            displayPriority: 1),
      ];

      // Act
      sortFestivalsByDisplayPriority(festivals);

      // Assert
      expect(
        festivals.map((f) => f.id).toList(),
        equals([
          'sharad_navratri_siddhidatri_puja',
          'navami_durga_puja',
          'dussehra',
        ]),
      );
    });

    test('unranked Dussehra falls after ranked festivals', () {
      // Arrange: Dussehra has no displayPriority, others ranked
      final festivals = [
        priorityFestival('dussehra'),
        priorityFestival('navami_durga_puja', displayPriority: 2),
        priorityFestival('sharad_navratri_siddhidatri_puja',
            displayPriority: 1),
      ];

      // Act
      sortFestivalsByDisplayPriority(festivals);

      // Assert: ranked first in rank order, unranked last
      expect(
        festivals.map((f) => f.id).toList(),
        equals([
          'sharad_navratri_siddhidatri_puja',
          'navami_durga_puja',
          'dussehra',
        ]),
      );
      expect(primaryFestival(festivals).id,
          equals('sharad_navratri_siddhidatri_puja'));
    });

    test('single ranked festival still sorts first', () {
      // Arrange: only one carries a rank
      final festivals = [
        priorityFestival('dussehra'),
        priorityFestival('navami_durga_puja'),
        priorityFestival('sharad_navratri_siddhidatri_puja',
            displayPriority: 1),
      ];

      // Act
      sortFestivalsByDisplayPriority(festivals);

      // Assert
      expect(festivals.first.id,
          equals('sharad_navratri_siddhidatri_puja'));
    });

    test('fromRawTithi orders same-day matches by displayPriority', () {
      // Arrange: all three match Ashwin Shukla Navami (rawTithi 9.x),
      // passed in Hive A-Z order
      final date = DateTime(2026, 10, 20);
      final all = [
        priorityFestival('dussehra', displayPriority: 3),
        priorityFestival('navami_durga_puja', displayPriority: 2),
        priorityFestival('sharad_navratri_siddhidatri_puja',
            displayPriority: 1),
      ];

      // Act
      final panchang = PanchangData.fromRawTithi(
        date: date,
        rawTithi: 9.2,
        masa: 'Ashwin',
        allFestivals: all,
      );

      // Assert
      expect(
        panchang.festivals.map((f) => f.id).toList(),
        equals([
          'sharad_navratri_siddhidatri_puja',
          'navami_durga_puja',
          'dussehra',
        ]),
      );
    });

    test('primaryFestival falls back to major-first when unranked', () {
      // Arrange
      final minor = priorityFestival('minor', category: 'vrat');
      final major = priorityFestival('major');

      // Act + Assert: legacy behaviour preserved
      expect(primaryFestival([minor, major]).id, equals('major'));
      expect(
        primaryFestival([
          priorityFestival('b', displayPriority: 2),
          priorityFestival('a', displayPriority: 1),
        ]).id,
        equals('a'),
      );
    });

    test('shipped dataset ranks Maha Navami before Siddhidatri, Dussehra',
        () {
      // Arrange
      final file = File('assets/festivals.json');
      final decoded =
          (jsonDecode(file.readAsStringSync()) as List).cast<Map<String, dynamic>>();
      int? priorityOf(String id) {
        final entry = decoded.firstWhere((f) => f['id'] == id);
        final raw = entry['displayPriority'];
        return raw is num ? raw.toInt() : null;
      }

      // Act
      final siddhi = priorityOf('sharad_navratri_siddhidatri_puja');
      final navami = priorityOf('navami_durga_puja');
      final dussehra = priorityOf('dussehra');

      // Assert — matches assets/festivals.json: navami=1, siddhi=2, dussehra=3
      expect(siddhi, isNotNull);
      expect(navami, isNotNull);
      expect(dussehra, isNotNull);
      expect(navami, equals(1));
      expect(siddhi, equals(2));
      expect(dussehra, equals(3));
      expect(navami! < siddhi!, isTrue);
      expect(siddhi < dussehra!, isTrue);
    });
  });
}
