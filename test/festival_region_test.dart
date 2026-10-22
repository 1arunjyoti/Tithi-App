import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tithi/models/festival.dart';
import 'package:tithi/models/festival_region.dart';

Festival regionFestival(
  String id, {
  List<String> regions = const ['all'],
  int? displayPriority,
  String category = 'major',
}) {
  return Festival(
    id: id,
    name: id,
    category: category,
    nameRegional: const NameRegional(nameEnglish: 'Test'),
    visuals: const Visuals(),
    purpose: const Purpose(description: 'Test'),
    panchangRules: const PanchangRules(
      masa: 'Ashwin',
      paksha: 'Shukla',
      tithi: 9,
      conditions: 'Navami',
    ),
    rituals: const Rituals(steps: []),
    media: const Media(),
    displayPriority: displayPriority,
    regions: regions,
  );
}

List<String> idsOf(List<Festival> festivals) =>
    festivals.map((festival) => festival.id).toList();

void main() {
  group('Festival.regions parsing', () {
    Map<String, dynamic> jsonWith(Object? regions) => {
      'id': 'test',
      'name': 'Test',
      'regions': regions,
      'panchang_rules': {
        'masa': 'Ashwin',
        'paksha': 'Shukla',
        'tithi': 9,
        'conditions': 'Navami',
      },
    };

    test('missing regions defaults to pan-India', () {
      final festival = Festival.fromJson({
        'id': 'test',
        'name': 'Test',
        'panchang_rules': {
          'masa': 'Ashwin',
          'paksha': 'Shukla',
          'tithi': 9,
          'conditions': 'Navami',
        },
      });

      expect(festival.regions, equals(['all']));
    });

    test('valid tags are kept, lowercased, de-duplicated and ordered', () {
      final festival = Festival.fromJson(jsonWith(['North', 'west', 'north']));

      expect(festival.regions, equals(['north', 'west']));
    });

    test('all collapses the list and unknown tags are dropped', () {
      expect(
        Festival.fromJson(jsonWith(['north', 'all'])).regions,
        equals(['all']),
      );
      expect(
        Festival.fromJson(jsonWith(['north', 'atlantis'])).regions,
        equals(['north']),
      );
      expect(Festival.fromJson(jsonWith(const [])).regions, equals(['all']));
      expect(Festival.fromJson(jsonWith('north')).regions, equals(['all']));
    });

    test('constructor defaults to pan-India', () {
      expect(regionFestival('test').regions, equals(['all']));
    });

    test('normalizeFestivalRegions returns an unmodifiable list', () {
      final regions = normalizeFestivalRegions(['north', 'west']);

      expect(() => regions.add('east'), throwsUnsupportedError);
    });
  });

  group('parseFestivalRegion', () {
    test('maps stored indices and falls back to All India', () {
      expect(parseFestivalRegion(0), equals(FestivalRegion.all));
      expect(parseFestivalRegion(1), equals(FestivalRegion.north));
      expect(
        parseFestivalRegion(FestivalRegion.northeast.index),
        equals(FestivalRegion.northeast),
      );
      expect(parseFestivalRegion(null), equals(FestivalRegion.all));
      expect(parseFestivalRegion(-1), equals(FestivalRegion.all));
      expect(parseFestivalRegion(99), equals(FestivalRegion.all));
      expect(parseFestivalRegion('north'), equals(FestivalRegion.all));
    });

    test('round-trips every region through its tag', () {
      for (final region in FestivalRegion.values) {
        final festival = regionFestival('test', regions: [region.tag]);
        expect(parseFestivalRegion(region.index), equals(region));
        expect(festivalRegionTier(festival, region), equals(0));
      }
    });
  });

  group('festivalRegionTier', () {
    test('selected region first, pan-India middle, others last', () {
      final north = regionFestival('north', regions: ['north']);
      final panIndia = regionFestival('all');
      final south = regionFestival('south', regions: ['south']);

      expect(festivalRegionTier(north, FestivalRegion.north), equals(0));
      expect(festivalRegionTier(panIndia, FestivalRegion.north), equals(1));
      expect(festivalRegionTier(south, FestivalRegion.north), equals(2));
    });

    test('multi-region festivals match any selected region', () {
      final shared = regionFestival('shared', regions: ['north', 'east']);

      expect(festivalRegionTier(shared, FestivalRegion.north), equals(0));
      expect(festivalRegionTier(shared, FestivalRegion.east), equals(0));
      expect(festivalRegionTier(shared, FestivalRegion.west), equals(2));
    });

    test('All India leaves every festival in one tier', () {
      final festivals = [
        regionFestival('north', regions: ['north']),
        regionFestival('all'),
        regionFestival('south', regions: ['south']),
      ];

      for (final festival in festivals) {
        expect(festivalRegionTier(festival, FestivalRegion.all), equals(0));
      }
    });
  });

  group('sortedFestivalsForRegion', () {
    test('lifts the selected region, keeps pan-India next, others last', () {
      // Arrange: input already in displayPriority order
      final festivals = [
        regionFestival('pan_india_a'),
        regionFestival('south', regions: ['south']),
        regionFestival('north', regions: ['north']),
        regionFestival('pan_india_b'),
        regionFestival('east', regions: ['east']),
      ];

      // Act
      final sorted = sortedFestivalsForRegion(festivals, FestivalRegion.north);

      // Assert
      expect(
        idsOf(sorted),
        equals(['north', 'pan_india_a', 'pan_india_b', 'south', 'east']),
      );
    });

    test('All India is a no-op and returns the same list', () {
      final festivals = [
        regionFestival('south', regions: ['south']),
        regionFestival('north', regions: ['north']),
        regionFestival('pan_india'),
      ];

      final sorted = sortedFestivalsForRegion(festivals, FestivalRegion.all);

      expect(identical(sorted, festivals), isTrue);
      expect(idsOf(sorted), equals(['south', 'north', 'pan_india']));
    });

    test('preserves displayPriority order inside each tier', () {
      // Arrange: priority 1 < 2 < 3 within the pan-India tier, while the
      // regional festival has the worst rank of all.
      final festivals = [
        regionFestival('all_1', displayPriority: 1),
        regionFestival('all_2', displayPriority: 2),
        regionFestival('north', regions: ['north'], displayPriority: 3),
        regionFestival('all_3', displayPriority: 4),
      ];

      // Act
      final sorted = sortedFestivalsForRegion(festivals, FestivalRegion.north);

      // Assert: tier wins, then the incoming (priority) order is untouched
      expect(idsOf(sorted), equals(['north', 'all_1', 'all_2', 'all_3']));
    });

    test('keeps ties deterministic and does not mutate the input', () {
      final festivals = [
        regionFestival('south', regions: ['south']),
        regionFestival('east', regions: ['east']),
        regionFestival('west', regions: ['west']),
      ];

      final first = sortedFestivalsForRegion(festivals, FestivalRegion.north);
      final second = sortedFestivalsForRegion(festivals, FestivalRegion.north);

      expect(idsOf(first), equals(['south', 'east', 'west']));
      expect(idsOf(second), equals(idsOf(first)));
      expect(idsOf(festivals), equals(['south', 'east', 'west']));
    });

    test('single-festival and empty lists are returned as-is', () {
      final single = [regionFestival('north', regions: ['north'])];
      final empty = <Festival>[];

      expect(
        identical(
          sortedFestivalsForRegion(single, FestivalRegion.south),
          single,
        ),
        isTrue,
      );
      expect(
        identical(
          sortedFestivalsForRegion(empty, FestivalRegion.south),
          empty,
        ),
        isTrue,
      );
    });

    test('region never hides festivals from other regions', () {
      final festivals = [
        regionFestival('one', regions: ['north']),
        regionFestival('two', regions: ['south']),
        regionFestival('three', regions: ['east']),
        regionFestival('four'),
      ];

      final sorted = sortedFestivalsForRegion(festivals, FestivalRegion.west);

      expect(sorted, hasLength(festivals.length));
      expect(sorted.toSet(), equals(festivals.toSet()));
    });
  });

  group('primaryFestivalForRegion', () {
    test('picks the regional festival over a ranked pan-India one', () {
      final festivals = [
        regionFestival('dussehra', displayPriority: 1),
        regionFestival('durga', regions: ['east'], displayPriority: 9),
      ];

      expect(
        primaryFestivalForRegion(festivals, FestivalRegion.east).id,
        equals('durga'),
      );
      expect(
        primaryFestivalForRegion(festivals, FestivalRegion.all).id,
        equals('dussehra'),
      );
    });

    test('falls back to the legacy pick when no festival matches', () {
      final minor = regionFestival(
        'south_minor',
        regions: ['south'],
        category: 'vrat',
      );
      final major = regionFestival('pan_india_major');

      expect(
        primaryFestivalForRegion([minor, major], FestivalRegion.north).id,
        equals('pan_india_major'),
      );
    });

    test('pan-India outranks another region even when minor', () {
      // Arrange: the only pan-India entry is a vrat, the out-of-region one
      // is a major festival. Tier must win over category, otherwise the
      // notification headline would disagree with the first list row.
      final otherRegionMajor = regionFestival(
        'south_major',
        regions: ['south'],
      );
      final panIndiaVrat = regionFestival('pan_india_vrat', category: 'vrat');
      final festivals = [otherRegionMajor, panIndiaVrat];

      // Act
      final headline = primaryFestivalForRegion(
        festivals,
        FestivalRegion.north,
      );
      final firstRow = sortedFestivalsForRegion(
        festivals,
        FestivalRegion.north,
      ).first;

      // Assert
      expect(headline.id, equals('pan_india_vrat'));
      expect(firstRow.id, equals(headline.id));
    });
  });

  group('shipped festivals.json', () {
    final decoded =
        (jsonDecode(File('assets/festivals.json').readAsStringSync()) as List)
            .cast<Map<String, dynamic>>();

    test('every entry has valid, non-empty region tags', () {
      for (final entry in decoded) {
        final id = entry['id'];
        final raw = entry['regions'];
        expect(raw, isA<List<dynamic>>(), reason: '$id is missing regions');
        final regions = (raw as List<dynamic>).cast<String>();
        expect(regions, isNotEmpty, reason: '$id has empty regions');
        for (final tag in regions) {
          expect(
            kFestivalRegionTags,
            contains(tag),
            reason: '$id has unknown region tag "$tag"',
          );
        }
        if (regions.contains('all')) {
          expect(regions, hasLength(1), reason: '$id mixes all with zones');
        }
      }
    });

    test('known regional festivals carry the expected tags', () {
      List<String> regionsOf(String id) {
        final entry = decoded.firstWhere((festival) => festival['id'] == id);
        return (entry['regions'] as List<dynamic>).cast<String>();
      }

      expect(regionsOf('onam'), equals(['south']));
      expect(regionsOf('pongal'), equals(['south']));
      expect(regionsOf('lohri'), equals(['north']));
      expect(regionsOf('shashthi_durga_puja'), equals(['east']));
      expect(regionsOf('jamai_shashti'), equals(['east']));
      expect(regionsOf('chhath_puja'), containsAll(['north', 'east']));
      expect(regionsOf('diwali'), equals(['all']));
      expect(regionsOf('dussehra'), equals(['all']));
    });

    test('catalog keeps at least one festival for the populated zones', () {
      final tagged = decoded
          .expand((entry) => (entry['regions'] as List<dynamic>).cast<String>())
          .toSet();

      // North-East is a selectable zone but currently has no exclusive
      // festivals in the catalog; selecting it promotes pan-India entries
      // over the other zones until one is tagged.
      const populatedZones = [
        'north',
        'south',
        'east',
        'west',
        'central',
      ];
      for (final tag in populatedZones) {
        expect(tagged, contains(tag), reason: 'no festival is tagged $tag');
      }
      expect(
        FestivalRegion.values.map((region) => region.tag),
        contains('northeast'),
      );
    });
  });
}
