import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tithi/models/festival.dart';
import 'package:tithi/models/panchang_data.dart';
import 'package:tithi/services/festival_matching_pipeline.dart';

Festival graceFestival(
  String id, {
  required int tithi,
  String paksha = 'Shukla',
  String masa = 'Ashwin',
  String conditions = 'Saptami',
  String? timingOverride,
  String vriddhi = 'both',
  String dominantTithi = 'grace',
}) {
  return Festival(
    id: id,
    name: id,
    category: 'major',
    nameRegional: const NameRegional(nameEnglish: 'Test'),
    visuals: const Visuals(),
    purpose: const Purpose(description: 'Test'),
    panchangRules: PanchangRules(
      masa: masa,
      paksha: paksha,
      tithi: tithi,
      conditions: conditions,
      timingOverride: timingOverride,
      vriddhi: vriddhi,
      dominantTithi: dominantTithi,
    ),
    rituals: const Rituals(steps: []),
    media: const Media(),
  );
}

PanchangData graceDay(
  DateTime date,
  double rawTithi,
  double? dominant,
  List<Festival> festivals, {
  String masa = 'Ashwin',
  String masaNext = '',
  double? pradosha,
}) {
  return PanchangData.fromRawTithi(
    date: date,
    rawTithi: rawTithi,
    masa: masa,
    allFestivals: festivals,
    masaNextSunrise: masaNext,
    rawTithiDominant: dominant,
    rawTithiPradosha: pradosha,
  );
}

void main() {
  final saptami = graceFestival('saptami', tithi: 7);

  group('Dominant-tithi grace', () {
    test('tithi beginning just after sunrise matches (Oct 17 2026)', () {
      // Shashthi at sunrise (6.95), Saptami ~20 min later (7.02).
      final day = graceDay(DateTime(2026, 10, 17), 6.95, 7.02, [saptami]);
      expect(day.festivals.map((f) => f.id), equals(['saptami']));
    });

    test('additive: sunrise matches kept when dominant moves on', () {
      final day = graceDay(DateTime(2026, 10, 18), 7.5, 8.1, [saptami]);
      expect(day.festivals.map((f) => f.id), equals(['saptami']));
    });

    test('no match when dominant stays on the old tithi', () {
      final day = graceDay(DateTime(2026, 10, 16), 6.5, 6.9, [saptami]);
      expect(day.festivals, isEmpty);
    });

    test('no dominant checkpoint means strict sunrise matching', () {
      final day = graceDay(DateTime(2026, 10, 17), 6.95, null, [saptami]);
      expect(day.festivals, isEmpty);
    });

    test('dominantTithi strict ignores the grace window', () {
      final strict = graceFestival(
        'saptami_strict',
        tithi: 7,
        dominantTithi: 'strict',
      );
      // Same samples as the grace case above: Shashthi at sunrise, Saptami
      // 20 min later. Strict keeps only the sunrise tithi.
      final day = graceDay(DateTime(2026, 10, 17), 6.95, 7.02, [strict]);
      expect(day.festivals, isEmpty);
    });

    test('timingOverride festivals are exempt from grace', () {
      final dussehra = graceFestival(
        'dussehra',
        tithi: 10,
        conditions: 'Dashami',
        timingOverride: 'aparahna',
      );
      // Dashami dominant, but no aparahna checkpoint provided.
      final day = graceDay(DateTime(2026, 10, 20), 9.9, 10.05, [dussehra]);
      expect(day.festivals, isEmpty);
    });

    test('pradosha override matches on the dusk checkpoint', () {
      final pradosh = graceFestival(
        'pradosh',
        tithi: 13,
        conditions: 'Trayodashi',
        timingOverride: 'pradosha',
      );
      // Dwadashi at sunrise, Trayodashi prevailing at pradosha.
      final day = graceDay(
        DateTime(2026, 10, 27),
        12.5,
        null,
        [pradosh],
        pradosha: 13.2,
      );
      expect(day.festivals.map((f) => f.id), equals(['pradosh']));
    });

    test('pradosha override falls back to sunrise without the checkpoint', () {
      final pradosh = graceFestival(
        'pradosh',
        tithi: 13,
        conditions: 'Trayodashi',
        timingOverride: 'pradosha',
      );
      // No pradosha sample (older cache): sunrise Dwadashi, no match.
      final day = graceDay(DateTime(2026, 10, 27), 12.5, null, [pradosh]);
      expect(day.festivals, isEmpty);
    });

    test('pradosha festivals are exempt from grace', () {
      final pradosh = graceFestival(
        'pradosh',
        tithi: 13,
        conditions: 'Trayodashi',
        timingOverride: 'pradosha',
      );
      // Trayodashi dominant, but Dwadashi still prevailing at pradosha.
      final day = graceDay(
        DateTime(2026, 10, 27),
        12.9,
        13.05,
        [pradosh],
        pradosha: 12.7,
      );
      expect(day.festivals, isEmpty);
    });

    test('new-moon wrap inside grace uses the next lunation masa', () {
      final pratipada = graceFestival(
        'pratipada',
        tithi: 1,
        masa: 'Kartika',
        conditions: 'Pratipada',
      );
      final day = graceDay(
        DateTime(2026, 11, 20),
        30.5,
        1.05,
        [pratipada],
        masaNext: 'Kartika',
      );
      expect(day.festivals.map((f) => f.id), equals(['pratipada']));
    });

    test('wrap without next-masa falls back to day masa (no match)', () {
      final pratipada = graceFestival(
        'pratipada',
        tithi: 1,
        masa: 'Kartika',
        conditions: 'Pratipada',
      );
      final day = graceDay(
        DateTime(2026, 11, 20),
        30.5,
        1.05,
        [pratipada],
      );
      expect(day.festivals, isEmpty);
    });
  });

  group('Oct 2026 acceptance: strict Durga Saptami + vriddhi day map', () {
    // Shashthi owns sunrise Oct 16+17 (Bisuddha). Saptami begins ~20 min
    // after the Oct 17 sunrise, but its dataset rule is strict, so it only
    // matches sunrise Oct 18. Navratri's sequence side still advances
    // (vriddhi first), which is why Kalaratri keeps Oct 17.
    final katyayani = graceFestival(
      'katyayani',
      tithi: 6,
      conditions: 'Shashthi',
      vriddhi: 'first',
    );
    final pujaShashthi = graceFestival(
      'puja_shashthi',
      tithi: 6,
      conditions: 'Shashthi',
    );
    final kalaratri = graceFestival(
      'kalaratri',
      tithi: 7,
      vriddhi: 'first',
    );
    final pujaSaptami = graceFestival(
      'puja_saptami',
      tithi: 7,
      dominantTithi: 'strict',
    );
    final all = [katyayani, pujaShashthi, kalaratri, pujaSaptami];

    Map<DateTime, PanchangData> buildMap() {
      return {
        DateTime(2026, 10, 16): graceDay(
          DateTime(2026, 10, 16),
          6.2,
          6.4,
          all,
        ),
        DateTime(2026, 10, 17): graceDay(
          DateTime(2026, 10, 17),
          6.95,
          7.02,
          all,
        ),
        DateTime(2026, 10, 18): graceDay(
          DateTime(2026, 10, 18),
          7.5,
          7.7,
          all,
        ),
      };
    }

    test('pre-filter: strict Saptami stays off the 17th', () {
      final days = buildMap();
      expect(
        days[DateTime(2026, 10, 17)]!.festivals.map((f) => f.id),
        equals(['katyayani', 'puja_shashthi', 'kalaratri']),
      );
    });

    test('post-filter: 16 Katyayani+PujaShashthi, 17 PujaShashthi+Kalaratri, 18 PujaSaptami', () {
      final filtered = applyVriddhiFilter(buildMap());
      expect(
        filtered[DateTime(2026, 10, 16)]!.festivals.map((f) => f.id),
        equals(['katyayani', 'puja_shashthi']),
      );
      expect(
        filtered[DateTime(2026, 10, 17)]!.festivals.map((f) => f.id),
        equals(['puja_shashthi', 'kalaratri']),
      );
      expect(
        filtered[DateTime(2026, 10, 18)]!.festivals.map((f) => f.id),
        equals(['puja_saptami']),
      );
    });
  });

  group('Dataset', () {
    test('Puja Saptami is strict at sunrise, not vriddhi-trimmed', () {
      final file = File('assets/festivals.json');
      final decoded = jsonDecode(file.readAsStringSync()) as List;
      final entry = decoded.cast<Map<String, dynamic>>().firstWhere(
        (f) => f['id'] == 'saptami_durga_puja',
      );
      final rules = (entry['panchang_rules'] as Map).cast<String, dynamic>();
      expect(rules['dominant_tithi'], equals('strict'));
      // Vriddhi stays at the default `both`: Surya Siddhanta Saptami is a
      // genuine two-sunrise run (Oct 17+18) and must not be trimmed.
      expect(rules.containsKey('vriddhi'), isFalse);

      final festival = Festival.fromJson(entry);
      expect(festival.panchangRules.usesDominantGrace, isFalse);
      // Bisuddha Oct 17: Saptami begins 17 min after sunrise. The grace
      // window would add it; strict leaves the day to Shashthi.
      final day = graceDay(DateTime(2026, 10, 17), 6.95, 7.02, [festival]);
      expect(day.festivals, isEmpty);
    });
  });
}
