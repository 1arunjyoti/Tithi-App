import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tithi/models/festival.dart';
import 'package:tithi/models/panchang_data.dart';

// Regression: Durga Puja 2026 day map under both Panjika schools.
//
// Source tithi boundaries (Kolkata, 2026):
//
// Bisuddhasiddhanta            Suryasiddhanta
//  6: Oct 16 03:25              6: Oct 16 01:28
//  7: Oct 17 05:54              7: Oct 17 03:32
//  8: Oct 18 08:27              8: Oct 18 05:39
//  9: Oct 19 10:51              9: Oct 19 07:37
// 10: Oct 20 12:50             10: Oct 20 09:19
// 11: Oct 21 14:11             11: Oct 21 10:36
//
// The five Durga Puja rules are `dominant_tithi: "strict"`, so only the tithi
// actually prevailing at sunrise matches. Vriddhi stays `both`: a genuine
// two-sunrise run is kept in full.
//
// Bisuddha: Shashthi at sunrise Oct 16 AND 17; Saptami only Oct 18.
// Surya:    Shashthi only Oct 16; Saptami at sunrise Oct 17 AND 18.
//
// The dominant-tithi grace is what makes this interesting: under Bisuddha
// Saptami begins 17 min after the Oct 17 sunrise, and under Surya Siddhanta
// Ashtami begins ~2 min after the Oct 18 sunrise. Without `strict` those
// grace samples add a spurious day to each school.

typedef TithiStart = ({int index, DateTime start});

/// Fractional tithi index at [instant], given the start of each tithi.
///
/// The final boundary has no recorded end, so it borrows a 24-hour span: the
/// fraction inside that tithi only matters here for its floor.
double rawTithiAt(DateTime instant, List<TithiStart> starts) {
  for (var i = 0; i < starts.length; i++) {
    final start = starts[i];
    final end = i + 1 < starts.length
        ? starts[i + 1].start
        : start.start.add(const Duration(hours: 24));
    if (instant.isBefore(start.start) || !instant.isBefore(end)) continue;
    final span = end.difference(start.start).inSeconds;
    final elapsed = instant.difference(start.start).inSeconds;
    return start.index + elapsed / span;
  }
  throw StateError('$instant is outside the supplied tithi boundaries');
}

const kDurgaPujaIds = [
  'shashthi_durga_puja',
  'saptami_durga_puja',
  'ashtami_durga_puja',
  'navami_durga_puja',
  'dasami_durga_puja',
];

/// The five dataset entries, optionally stripped of `dominant_tithi` so a test
/// can show what the grace window would have added.
List<Festival> durgaPujaFestivals({bool strict = true}) {
  final decoded =
      jsonDecode(File('assets/festivals.json').readAsStringSync()) as List;
  final entries = decoded.cast<Map<String, dynamic>>();
  return [
    for (final id in kDurgaPujaIds)
      Festival.fromJson(() {
        final entry = entries.firstWhere((f) => f['id'] == id);
        if (!strict) {
          (entry['panchang_rules'] as Map).remove('dominant_tithi');
        }
        return entry;
      }()),
  ];
}

/// Kolkata sunrise is ~05:37 on these dates; the exact minute is immaterial
/// as long as it sits between the supplied boundaries.
const kSunriseHour = 5;
const kSunriseMinute = 37;

Map<DateTime, List<String>> dayMap({
  required List<TithiStart> starts,
  required List<Festival> festivals,
}) {
  final result = <DateTime, List<String>>{};
  for (var day = 16; day <= 21; day++) {
    final date = DateTime(2026, 10, day);
    final sunrise = DateTime(2026, 10, day, kSunriseHour, kSunriseMinute);
    final dayData = PanchangData.fromRawTithi(
      date: date,
      rawTithi: rawTithiAt(sunrise, starts),
      rawTithiDominant: rawTithiAt(
        sunrise.add(const Duration(minutes: 60)),
        starts,
      ),
      rawTithiNextSunrise: rawTithiAt(
        sunrise.add(const Duration(days: 1)),
        starts,
      ),
      masa: 'Ashwin',
      masaNextSunrise: 'Ashwin',
      allFestivals: festivals,
    );
    result[date] = dayData.festivals.map((f) => f.id).toList();
  }
  return result;
}

final bisuddhaStarts = <TithiStart>[
  (index: 6, start: DateTime(2026, 10, 16, 3, 25)),
  (index: 7, start: DateTime(2026, 10, 17, 5, 54)),
  (index: 8, start: DateTime(2026, 10, 18, 8, 27)),
  (index: 9, start: DateTime(2026, 10, 19, 10, 51)),
  (index: 10, start: DateTime(2026, 10, 20, 12, 50)),
  (index: 11, start: DateTime(2026, 10, 21, 14, 11)),
];

final suryaStarts = <TithiStart>[
  (index: 6, start: DateTime(2026, 10, 16, 1, 28)),
  (index: 7, start: DateTime(2026, 10, 17, 3, 32)),
  (index: 8, start: DateTime(2026, 10, 18, 5, 39)),
  (index: 9, start: DateTime(2026, 10, 19, 7, 37)),
  (index: 10, start: DateTime(2026, 10, 20, 9, 19)),
  (index: 11, start: DateTime(2026, 10, 21, 10, 36)),
];

void main() {
  group('Durga Puja 2026 (strict sunrise tithi)', () {
    test('Bisuddhasiddhanta: Shashthi Oct 16+17, Saptami only Oct 18', () {
      final map = dayMap(
        starts: bisuddhaStarts,
        festivals: durgaPujaFestivals(),
      );
      expect(map[DateTime(2026, 10, 16)], equals(['shashthi_durga_puja']));
      expect(map[DateTime(2026, 10, 17)], equals(['shashthi_durga_puja']));
      expect(map[DateTime(2026, 10, 18)], equals(['saptami_durga_puja']));
      expect(map[DateTime(2026, 10, 19)], equals(['ashtami_durga_puja']));
      expect(map[DateTime(2026, 10, 20)], equals(['navami_durga_puja']));
      expect(map[DateTime(2026, 10, 21)], equals(['dasami_durga_puja']));
    });

    test('Suryasiddhanta: Shashthi only Oct 16, Saptami Oct 17+18', () {
      final map = dayMap(starts: suryaStarts, festivals: durgaPujaFestivals());
      expect(map[DateTime(2026, 10, 16)], equals(['shashthi_durga_puja']));
      expect(map[DateTime(2026, 10, 17)], equals(['saptami_durga_puja']));
      expect(map[DateTime(2026, 10, 18)], equals(['saptami_durga_puja']));
      expect(map[DateTime(2026, 10, 19)], equals(['ashtami_durga_puja']));
      expect(map[DateTime(2026, 10, 20)], equals(['navami_durga_puja']));
      expect(map[DateTime(2026, 10, 21)], equals(['dasami_durga_puja']));
    });
  });

  group('Grace window would add a day without `dominant_tithi: strict`', () {
    test('Bisuddha Saptami spills onto Oct 17', () {
      final map = dayMap(
        starts: bisuddhaStarts,
        festivals: durgaPujaFestivals(strict: false),
      );
      expect(
        map[DateTime(2026, 10, 17)],
        containsAll(['shashthi_durga_puja', 'saptami_durga_puja']),
      );
    });

    test('Surya Siddhanta Ashtami spills onto Oct 18', () {
      final map = dayMap(
        starts: suryaStarts,
        festivals: durgaPujaFestivals(strict: false),
      );
      expect(
        map[DateTime(2026, 10, 18)],
        containsAll(['saptami_durga_puja', 'ashtami_durga_puja']),
      );
    });
  });
}
