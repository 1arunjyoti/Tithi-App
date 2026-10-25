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
      expect(profile.engineVersion, 'panchang-v3');
      expect(profile.ayanamsa, 'lahiri');
      expect(profile.monthSystem, 'amanta');
      expect(profile.sunriseConvention, 'hindu');
      expect(profile.timezone, 'Asia/Kolkata');
      expect(profile.calculationVersion, 3);
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
        final nakshatraIndex = hinduNakshatras.indexOf(
          c.expected.nakshatraAtSunrise,
        );
        expect(
          hinduNakshatras,
          contains(c.expected.nakshatraAtSunrise),
          reason: '${c.id}: nakshatra',
        );
        // The end edge belongs to the next nakshatra, so the pair must be
        // adjacent in the canonical 27-fold order (Revati -> Ashwini wraps).
        expect(
          c.expected.nextNakshatra,
          hinduNakshatras[(nakshatraIndex + 1) % hinduNakshatras.length],
          reason: '${c.id}: nextNakshatra must follow nakshatraAtSunrise',
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

    test('nakshatra span and next sankranti agree with the sunrise state', () {
      for (final c in fixture.panchang.cases) {
        final e = c.expected;
        expect(
          e.nakshatraStartsAt.instant.isAfter(e.sunrise.instant),
          isFalse,
          reason: '${c.id}: the sunrise nakshatra starts at or before sunrise',
        );
        expect(
          e.nakshatraEndsAt.instant.isAfter(e.sunrise.instant),
          isTrue,
          reason: '${c.id}: the sunrise nakshatra ends after sunrise',
        );
        // A nakshatra lasts 19-26 h; the band absorbs the Moon's perigee
        // (13.2 deg/day) to apogee (17.8 deg/day) spread.
        expect(
          e.nakshatraEndsAt.instant
              .difference(e.nakshatraStartsAt.instant)
              .inMinutes,
          inInclusiveRange(18 * 60, 30 * 60),
          reason: '${c.id}: nakshatra span',
        );
        expect(
          e.nextSankranti.at.instant.isAfter(e.sunrise.instant),
          isTrue,
          reason: '${c.id}: the next sankranti is strictly after sunrise',
        );
        // The locked ingress must be the sign after the locked sunrise Sun,
        // which also proves the rashi name came from the canonical list.
        final rashiIndex = sunRashiIndex(e.sunLongitude);
        expect(
          e.nextSankranti.rashi,
          rashiNames[(rashiIndex + 1) % rashiNames.length],
          reason:
              '${c.id}: ingress must be the sign after '
              '${rashiNames[rashiIndex]}',
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

    test('Janmashtami window cases stay documented', () {
      // panchang-v3 samples the Nishita window (`sunset + 7/15 night` to
      // `+ 8/15 night`) instead of the night midpoint, so Delhi resolves the
      // observance again: Ashtami prevails at the 23:57 opening even though
      // the old 00:20 midpoint sample was Navami.
      final delhi = fixture.caseById('delhi-2026-09-04')!;
      expect(delhi.tags, isNot(contains('known-gap')));
      expect(
        fixture.festivalCaseById(delhi.id)!.expectedFestivalIds,
        contains('janmashtami'),
      );

      // Mumbai stays a documented knife edge: Ashtami ends ~6 s before the
      // window opens, so neither edge holds it. Recorded as engine
      // characterization, not an asserted observance date.
      final mumbai = fixture.caseById('mumbai-2026-09-04')!;
      expect(mumbai.tags, contains('known-gap'));
      expect(mumbai.source.notes, contains('00:14:06'));
      expect(
        fixture.festivalCaseById(mumbai.id)!.expectedFestivalIds,
        isEmpty,
      );

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
