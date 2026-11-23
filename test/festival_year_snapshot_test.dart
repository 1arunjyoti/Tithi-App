import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:tithi/features/countdown/data/festival_year_snapshot.dart';
import 'package:tithi/features/countdown/domain/target_resolution.dart';
import 'package:tithi/models/festival.dart';
import 'package:tithi/services/storage_service.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('tithi_year_snapshot');
    Hive.init(tempDir.path);
    await StorageService().openFestivalOccurrencesBox();
  });

  tearDown(() async {
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  Festival festival(String id) => Festival(
    id: id,
    name: id.toUpperCase(),
    category: 'major',
    nameRegional: const NameRegional(nameEnglish: 'Test'),
    visuals: const Visuals(),
    purpose: const Purpose(description: 'A test festival description'),
    panchangRules: const PanchangRules(
      masa: '',
      paksha: 'Shukla',
      tithi: 4,
      conditions: '',
    ),
    rituals: const Rituals(steps: []),
    media: const Media(),
  );

  Future<List<DatedFestival>?> read({
    required List<Festival> festivals,
    int? catalogVersion,
    double? latitude,
    double? longitude,
  }) {
    return readFestivalYearSnapshot(
      yearStart: DateTime(2026),
      festivals: festivals,
      latitude: latitude ?? 28.6139,
      longitude: longitude ?? 77.2090,
      catalogVersion: catalogVersion ?? 7,
    );
  }

  Future<void> write(
    List<DatedFestival> items, {
    int? catalogVersion,
    double? latitude,
    double? longitude,
  }) {
    return writeFestivalYearSnapshot(
      yearStart: DateTime(2026),
      items: items,
      latitude: latitude ?? 28.6139,
      longitude: longitude ?? 77.2090,
      catalogVersion: catalogVersion ?? 7,
    );
  }

  test('round-trips dated and undated rows in chronological order', () async {
    final alpha = festival('alpha');
    final beta = festival('beta');
    final gamma = festival('gamma');
    final items = <DatedFestival>[
      (festival: beta, date: DateTime(2026, 3, 3)),
      (festival: alpha, date: DateTime(2026)),
      (festival: gamma, date: null),
    ];

    await write(items);
    final restored = await read(festivals: [alpha, beta, gamma]);

    expect(restored, isNotNull);
    expect(restored!.map((row) => row.festival.id).toList(), [
      'alpha',
      'beta',
      'gamma',
    ]);
    expect(restored[0].date, DateTime(2026));
    expect(restored[1].date, DateTime(2026, 3, 3));
    expect(restored[2].date, isNull);
  });

  test('GPS jitter inside the cache grid still hits', () async {
    await write([(festival: festival('alpha'), date: DateTime(2026))]);

    final restored = await read(
      festivals: [festival('alpha')],
      latitude: 28.6141,
      longitude: 77.2094,
    );

    expect(restored, isNotNull);
    expect(restored, hasLength(1));
  });

  test('a moved place misses', () async {
    await write([(festival: festival('alpha'), date: DateTime(2026))]);

    final restored = await read(
      festivals: [festival('alpha')],
      latitude: 28.6300,
      longitude: 77.2090,
    );

    expect(restored, isNull);
  });

  test('a catalog change misses', () async {
    await write([(festival: festival('alpha'), date: DateTime(2026))]);

    final restored = await read(
      festivals: [festival('alpha')],
      catalogVersion: 8,
    );

    expect(restored, isNull);
  });

  test('rows for a catalog that no longer has the ids miss', () async {
    await write([(festival: festival('alpha'), date: DateTime(2026))]);

    final restored = await read(festivals: [festival('beta')]);

    expect(restored, isNull);
  });

  test('a second year does not drop the first year\'s snapshot', () async {
    final alpha = festival('alpha');
    final box = await StorageService().openFestivalOccurrencesBox();

    await write([(festival: alpha, date: DateTime(2026))]);
    await writeFestivalYearSnapshot(
      yearStart: DateTime(2027),
      items: [(festival: alpha, date: DateTime(2027, 2, 2))],
      latitude: 28.6139,
      longitude: 77.2090,
      catalogVersion: 7,
    );

    expect(
      box.keys.whereType<String>().where((k) => k.startsWith('year1_')),
      hasLength(2),
    );
  });

  test('the box is bounded: only the most recent years survive', () async {
    final alpha = festival('alpha');
    final box = await StorageService().openFestivalOccurrencesBox();

    // Write 11 distinct years: past ones, the current one and future ones.
    for (var y = 2020; y <= 2030; y++) {
      await writeFestivalYearSnapshot(
        yearStart: DateTime(y),
        items: [(festival: alpha, date: DateTime(y))],
        latitude: 28.6139,
        longitude: 77.2090,
        catalogVersion: 7,
      );
    }

    final remaining = box.keys
        .whereType<String>()
        .where((k) => k.startsWith('year1_'))
        .map(_snapshotYearOf)
        .toList();
    expect(remaining, hasLength(8));
    // The most recent years are the ones kept.
    for (var y = 2023; y <= 2030; y++) {
      expect(remaining, contains(y));
    }
    expect(remaining, isNot(contains(2020)));
    expect(remaining, isNot(contains(2022)));
  });

  test('a just-written far-past year survives the pruning pass', () async {
    final alpha = festival('alpha');
    final box = await StorageService().openFestivalOccurrencesBox();

    for (var y = 2026; y <= 2033; y++) {
      await writeFestivalYearSnapshot(
        yearStart: DateTime(y),
        items: [(festival: alpha, date: DateTime(y))],
        latitude: 28.6139,
        longitude: 77.2090,
        catalogVersion: 7,
      );
    }
    // Now browse far back: the write must not be instantly pruned, or the
    // next visit to that year would re-scan.
    await writeFestivalYearSnapshot(
      yearStart: DateTime(2019),
      items: [(festival: alpha, date: DateTime(2019))],
      latitude: 28.6139,
      longitude: 77.2090,
      catalogVersion: 7,
    );

    expect(
      box.keys.whereType<String>().where((k) => k.startsWith('year1_2019')),
      hasLength(1),
    );
  });

  test(
    'writing a new snapshot drops the stale-location record beyond the cap',
    () async {
      final alpha = festival('alpha');
      final box = await StorageService().openFestivalOccurrencesBox();

      // Eight 2026 records at distinct locations: the old "one record" rule
      // would drop these on every write; the cap keeps them until more years
      // push them out.
      for (var i = 0; i < 8; i++) {
        await write([
          (festival: alpha, date: DateTime(2026)),
        ], latitude: 28.61 + i);
      }
      expect(
        box.keys.whereType<String>().where((k) => k.startsWith('year1_')),
        hasLength(8),
      );

      // A different-location record pushes the box past the cap; the oldest
      // years (all equal here, so effectively arbitrary) are evicted.
      await write([(festival: alpha, date: DateTime(2026))], latitude: 28.70);
      expect(
        box.keys.whereType<String>().where((k) => k.startsWith('year1_')),
        hasLength(8),
      );
    },
  );
}

int _snapshotYearOf(String key) =>
    int.parse(RegExp(r'^year1_(\d{4})_').firstMatch(key)!.group(1)!);
