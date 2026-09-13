import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tithi/models/festival.dart';
import 'package:tithi/models/panchang_data.dart';
import 'package:tithi/services/festival_matching_pipeline.dart';

Festival testFestival(String id, {String vriddhi = 'both'}) {
  return Festival(
    id: id,
    name: id,
    category: 'major',
    nameRegional: const NameRegional(nameEnglish: 'Test'),
    visuals: const Visuals(),
    purpose: const Purpose(description: 'Test'),
    panchangRules: PanchangRules(
      masa: 'Ashwin',
      paksha: 'Shukla',
      tithi: 6,
      conditions: 'Shashthi',
      vriddhi: vriddhi,
    ),
    rituals: const Rituals(steps: []),
    media: const Media(),
  );
}

PanchangData testDay(DateTime date, List<Festival> festivals) {
  return PanchangData(
    date: date,
    rawTithi: 6.5,
    tithiNumber: 6,
    tithiName: 'Shashthi',
    paksha: 'Shukla',
    masa: 'Ashwin',
    festivals: festivals,
  );
}

void main() {
  group('Vriddhi preference normalization', () {
    test('missing vriddhi defaults to both', () {
      final rules = PanchangRules.fromJson({
        'masa': 'Ashwin',
        'paksha': 'Shukla',
        'tithi': 6,
        'conditions': 'Shashthi',
      });
      expect(rules.vriddhi, equals('both'));
      expect(normalizeVriddhiPreference(rules.vriddhi), equals('both'));
    });

    test('explicit first/second preserved, unknown falls back to both', () {
      expect(normalizeVriddhiPreference('first'), equals('first'));
      expect(normalizeVriddhiPreference('second'), equals('second'));
      expect(normalizeVriddhiPreference(' FIRST '), equals('first'));
      expect(normalizeVriddhiPreference('whenever'), equals('both'));
      expect(normalizeVriddhiPreference(null), equals('both'));
    });
  });

  group('applyVriddhiFilter', () {
    final navratri = testFestival('navratri_shashthi', vriddhi: 'first');
    final puja = testFestival('puja_shashthi'); // both (default)

    test('first keeps day 1, both keeps both days', () {
      final d1 = DateTime(2026, 10, 16);
      final d2 = DateTime(2026, 10, 17);
      final result = applyVriddhiFilter({
        d1: testDay(d1, [navratri, puja]),
        d2: testDay(d2, [navratri, puja]),
      });
      expect(
        result[d1]!.festivals.map((f) => f.id),
        containsAll(['navratri_shashthi', 'puja_shashthi']),
      );
      expect(
        result[d2]!.festivals.map((f) => f.id),
        equals(['puja_shashthi']),
      );
    });

    test('second keeps last day of the run', () {
      final last = testFestival('visarjan', vriddhi: 'second');
      final d1 = DateTime(2026, 10, 20);
      final d2 = DateTime(2026, 10, 21);
      final result = applyVriddhiFilter({
        d1: testDay(d1, [last]),
        d2: testDay(d2, [last]),
      });
      expect(result[d1]!.festivals, isEmpty);
      expect(result[d2]!.festivals.map((f) => f.id), equals(['visarjan']));
    });

    test('non-consecutive matches are separate runs (no trim)', () {
      final d1 = DateTime(2026, 10, 16);
      final d3 = DateTime(2026, 10, 18);
      final result = applyVriddhiFilter({
        d1: testDay(d1, [navratri]),
        d3: testDay(d3, [navratri]),
      });
      expect(result[d1]!.festivals.map((f) => f.id), equals(['navratri_shashthi']));
      expect(result[d3]!.festivals.map((f) => f.id), equals(['navratri_shashthi']));
    });

    test('single-day match untouched', () {
      final d1 = DateTime(2026, 10, 16);
      final result = applyVriddhiFilter({d1: testDay(d1, [navratri])});
      expect(result[d1]!.festivals.map((f) => f.id), equals(['navratri_shashthi']));
    });
  });

  group('resolveVriddhiCandidate', () {
    // Run: Oct 16 + 17 both match.
    Future<bool> inRun(DateTime day) async {
      final d = DateTime(day.year, day.month, day.day);
      return d == DateTime(2026, 10, 16) || d == DateTime(2026, 10, 17);
    }

    test('first resolves to run start', () async {
      final r = await resolveVriddhiCandidate(
        festival: testFestival('n', vriddhi: 'first'),
        candidate: DateTime(2026, 10, 17),
        baseDate: DateTime(2026, 10, 17),
        matchesDay: inRun,
      );
      // Run start (Oct 16) is before base: occurrence passed, resume past run.
      expect(r.occurrence, isNull);
      expect(r.resumeFrom, equals(DateTime(2026, 10, 18)));
    });

    test('first found at run start returns it', () async {
      final r = await resolveVriddhiCandidate(
        festival: testFestival('n', vriddhi: 'first'),
        candidate: DateTime(2026, 10, 16),
        baseDate: DateTime(2026, 10, 2),
        matchesDay: inRun,
      );
      expect(r.occurrence, equals(DateTime(2026, 10, 16)));
    });

    test('second resolves to run end', () async {
      final r = await resolveVriddhiCandidate(
        festival: testFestival('n', vriddhi: 'second'),
        candidate: DateTime(2026, 10, 16),
        baseDate: DateTime(2026, 10, 2),
        matchesDay: inRun,
      );
      expect(r.occurrence, equals(DateTime(2026, 10, 17)));
    });

    test('both returns candidate unchanged', () async {
      final r = await resolveVriddhiCandidate(
        festival: testFestival('n'),
        candidate: DateTime(2026, 10, 17),
        baseDate: DateTime(2026, 10, 17),
        matchesDay: inRun,
      );
      expect(r.occurrence, equals(DateTime(2026, 10, 17)));
    });
  });

  group('Dataset Vriddhi annotations', () {
    Map<String, dynamic> rulesOf(String id) {
      final file = File('assets/festivals.json');
      final decoded = jsonDecode(file.readAsStringSync()) as List;
      final entry = decoded.cast<Map<String, dynamic>>().firstWhere(
        (f) => f['id'] == id,
        orElse: () => throw StateError('festival $id not found'),
      );
      return (entry['panchang_rules'] as Map).cast<String, dynamic>();
    }

    test('Navratri sequence days take first', () {
      for (final id in [
        'sharad_navratri_katyayani_puja',
        'sharad_navratri_saraswati Avahan',
        'sharad_navratri_kalaratri_puja',
        'sharad_navratri_saraswati_puja',
      ]) {
        expect(rulesOf(id)['vriddhi'], equals('first'), reason: id);
      }
    });

    test('Durga Puja Shashthi spans both, Saptami resolves to last', () {
      for (final id in [
        'shashthi_durga_puja',
        'ashtami_durga_puja',
        'navami_durga_puja',
      ]) {
        final rules = rulesOf(id);
        expect(rules['vriddhi'] ?? 'both', equals('both'), reason: id);
      }
      // Bisuddha one-day Saptami: with the dominant-tithi grace, Saptami
      // matches 17+18 Oct 2026, so `second` keeps the 18th (see
      // dominant_grace_test.dart for the full day map).
      expect(rulesOf('saptami_durga_puja')['vriddhi'], equals('second'));
    });
  });
}
