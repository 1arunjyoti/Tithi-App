import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'package:tithi/models/festival.dart';
import 'package:tithi/models/hindu_month_system.dart';
import 'package:tithi/models/panchang_data.dart';

import 'fixtures/panchang_golden/golden_fixtures.dart';

void main() {
  group('Panchang golden fixture', () {
    late GoldenFixtureSet fixture;

    setUpAll(() {
      tzdata.initializeTimeZones();
      fixture = GoldenFixtureSet.load();
    });

    test('structure, references, and coverage are valid', () {
      // Act
      final errors = validateGoldenStructure(fixture);

      // Assert
      expect(errors, isEmpty, reason: errors.join('\n'));
    });

    test('profile metadata matches the locked calculation contract', () {
      final profile = fixture.panchang.profile;
      expect(profile.engineVersion, 'panchang-v2');
      expect(profile.ayanamsa, 'lahiri');
      expect(profile.monthSystem, 'amanta');
      expect(profile.sunriseConvention, 'hindu');
      expect(profile.timezone, 'Asia/Kolkata');
      expect(profile.calculationVersion, 2);
      expect(fixture.panchang.tolerance.eventSeconds, 60);
      expect(fixture.panchang.tolerance.longitudeArcseconds, 1);
    });

    test('every location uses a real IANA timezone', () {
      for (final c in fixture.panchang.cases) {
        expect(
          () => tz.getLocation(c.location.timezone),
          returnsNormally,
          reason: '${c.id}: ${c.location.timezone}',
        );
        expect(c.location.timezone, 'Asia/Kolkata');
      }
    });

    test('tithi names are canonical for their paksha and number', () {
      for (final c in fixture.panchang.cases) {
        final tithi = c.expected.tithiAtSunrise;
        expect(
          tithi.name,
          PanchangData.tithiNameFor(tithi.number, tithi.paksha),
          reason: '${c.id}: sunrise tithi',
        );
        final next = c.expected.nextTithi;
        if (next != null) {
          expect(
            next.name,
            PanchangData.tithiNameFor(next.number, next.paksha),
            reason: '${c.id}: next tithi',
          );
        }
      }
    });

    test('nakshatra, yoga, and karana names are canonical', () {
      final karanaNames = <String>{
        for (var i = 0; i < 60; i++) karanaNameForIndex(i),
      };
      for (final c in fixture.panchang.cases) {
        expect(
          hinduNakshatras,
          contains(c.expected.nakshatraAtSunrise),
          reason: '${c.id}: nakshatra',
        );
        expect(
          yogaNames,
          contains(c.expected.yogaAtSunrise),
          reason: '${c.id}: yoga',
        );
        expect(
          karanaNames,
          contains(c.expected.karanaAtSunrise),
          reason: '${c.id}: karana',
        );
      }
    });

    test('masa and the Amanta to Purnimanta conversion agree', () {
      for (final c in fixture.panchang.cases) {
        final expected = c.expected;
        expect(
          expected.masaPurnimanta,
          convertAmantaToPurnimant(
            expected.masa,
            expected.tithiAtSunrise.paksha,
          ),
          reason: '${c.id}: masaPurnimanta',
        );
        expect(
          expected.adhika,
          expected.masa.startsWith('Adhika_'),
          reason: '${c.id}: adhika flag',
        );
      }
    });

    test('every festival ID exists in assets/festivals.json', () {
      for (final f in fixture.festivals.cases) {
        for (final id in f.expectedFestivalIds) {
          expect(
            fixture.assetFestivalIds,
            contains(id),
            reason: '${f.caseId} references unknown festival "$id"',
          );
        }
      }
    });

    test('festival fixture stores IDs only, never copied rules', () {
      final raw =
          jsonDecode(
                File(
                  '$kGoldenFixtureDirectory/$kGoldenFestivalFileName',
                ).readAsStringSync(),
              )
              as Map<String, dynamic>;
      final cases = raw['cases'] as List<dynamic>;
      const allowed = {'caseId', 'expectedFestivalIds', 'notes'};
      for (final entry in cases) {
        final map = entry as Map<String, dynamic>;
        expect(
          map.keys.toSet().difference(allowed),
          isEmpty,
          reason: 'festival case ${map['caseId']} copies extra fields',
        );
      }
    });

    test('coverage matrix keeps every required category', () {
      final tags = fixture.panchang.cases.expand((c) => c.tags).toSet();
      expect(tags, containsAll(kGoldenRequiredTags));

      final cities = fixture.panchang.cases
          .map((c) => c.id.split('-').first)
          .toSet();
      expect(cities, kGoldenCities);

      final dates = fixture.panchang.cases.map((c) => c.dateString).toSet();
      expect(dates.length, inInclusiveRange(10, 20));
      expect(fixture.panchang.cases.length, inInclusiveRange(60, 120));
    });

    test('provided Kolkata anchor matches the migration brief', () {
      final anchor = fixture.caseById('kolkata-2026-01-29');
      expect(anchor, isNotNull);
      expect(anchor!.source.kind, 'provided-anchor');
      expect(anchor.expected.tithiAtSunrise.paksha, 'Shukla');
      expect(anchor.expected.tithiAtSunrise.number, 11);
      expect(anchor.expected.tithiAtSunrise.name, 'Ekadashi');
      expect(anchor.expected.masa, 'Magha');
      expect(anchor.expected.nakshatraAtSunrise, 'Rohini');
      expect(
        fixture.festivalCaseById(anchor.id)!.expectedFestivalIds,
        contains('ekadashi_shukla'),
      );
    });

    test('sunrise-boundary case flips tithi between cities', () {
      final delhi = fixture.caseById('delhi-2026-06-30')!;
      final mumbai = fixture.caseById('mumbai-2026-06-30')!;
      final kolkata = fixture.caseById('kolkata-2026-06-30')!;
      // Native Hindu sunrise moves Delhi past the transition, so it joins
      // Mumbai/Chennai in Krishna Pratipada; Kolkata/Varanasi/Guwahati keep
      // Purnima.
      expect(delhi.expected.tithiAtSunrise.name, 'Pratipada');
      expect(mumbai.expected.tithiAtSunrise.name, 'Pratipada');
      expect(kolkata.expected.tithiAtSunrise.name, 'Purnima');
      expect(delhi.tags, contains('sunrise-boundary'));
    });

    test('Vriddhi case keeps Shashthi in Kolkata on the second day', () {
      final kolkata = fixture.caseById('kolkata-2026-10-17')!;
      expect(kolkata.expected.tithiAtSunrise.name, 'Shashthi');
      expect(kolkata.expected.nextTithi?.name, 'Saptami');
      expect(
        fixture.festivalCaseById(kolkata.id)!.expectedFestivalIds,
        contains('shashthi_durga_puja'),
      );
      expect(kolkata.tags, contains('vriddhi'));
    });

    test('Bengali month transition is locked at Ashshin 30 -> Kartik 1', () {
      final before = fixture.caseById('kolkata-2026-10-17')!;
      final after = fixture.caseById('kolkata-2026-10-18')!;
      expect(before.expected.bengaliDate?.month, 'Ashshin');
      expect(before.expected.bengaliDate?.day, 30);
      expect(after.expected.bengaliDate?.month, 'Kartik');
      expect(after.expected.bengaliDate?.day, 1);
    });

    test('Janmashtami known gaps stay documented', () {
      for (final id in ['delhi-2026-09-04', 'mumbai-2026-09-04']) {
        final c = fixture.caseById(id)!;
        expect(c.tags, contains('known-gap'), reason: id);
        expect(c.source.notes, contains('Known gap'), reason: id);
        expect(
          fixture.festivalCaseById(id)!.expectedFestivalIds,
          isEmpty,
          reason: id,
        );
      }
      final kolkata = fixture.caseById('kolkata-2026-09-04')!;
      expect(kolkata.tags, isNot(contains('known-gap')));
      expect(
        fixture.festivalCaseById(kolkata.id)!.expectedFestivalIds,
        contains('janmashtami'),
      );
    });

    test('ephemeris boundary cases stay in the dataset', () {
      expect(fixture.caseById('delhi-1800-01-01'), isNotNull);
      expect(fixture.caseById('guwahati-2399-12-31'), isNotNull);
      final tags = fixture.panchang.cases.expand((c) => c.tags).toSet();
      expect(tags, contains('ephemeris-boundary'));
    });
  });
}
