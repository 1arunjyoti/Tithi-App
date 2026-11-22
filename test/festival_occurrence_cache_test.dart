import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:tithi/features/panchang/data/panchang_cache.dart';
import 'package:tithi/features/panchang/domain/occurrence_cache.dart';
import 'package:tithi/models/festival.dart';
import 'package:tithi/models/hindu_month_system.dart';
import 'package:tithi/services/panchang_service.dart';

// The All Festivals list is a stored answer: the yearly snapshot plus this
// per-festival occurrence cache. Bumping the scan alone is not enough — an
// upgraded install would keep serving the answer the buggy scan cached
// (Shattila Ekadashi resolved to Jan 2027 for a Jan 1 2026 query, so the
// Jan 14 2026 occurrence never appeared). This pins the generation bump.
class _FakePanchangService extends PanchangService {
  _FakePanchangService(this.result);

  final DateTime? result;

  @override
  Future<DateTime?> findNextFestivalOccurrence(
    Festival festival, {
    DateTime? startDate,
    double latitude = 0,
    double longitude = 0,
  }) async => result;
}

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('tithi_occ_cache');
    Hive.init(tempDir.path);
  });

  tearDown(() async {
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  test('a pre-fix occ8 answer cannot outlive the scan fix', () async {
    const latitude = 28.6139;
    const longitude = 77.2090;
    const festival = Festival(
      id: 'shattila_ekadashi',
      name: 'Shattila Ekadashi',
      category: 'vrat',
      nameRegional: NameRegional(nameEnglish: 'Shattila Ekadashi'),
      visuals: Visuals(),
      purpose: Purpose(description: 'A test festival description'),
      panchangRules: PanchangRules(
        masa: 'Pausha',
        paksha: 'Krishna',
        tithi: 11,
        conditions: '',
      ),
      rituals: Rituals(steps: []),
      media: Media(),
    );

    // Prepare first so the location signature is stored; otherwise the cached
    // lookup would clear the box (and our stale key) for the wrong reason.
    final box = await preparePanchangCacheBox(latitude, longitude);
    final signature = locationSignature(latitude, longitude);

    // What the old scanner stored: the *next* Pausha Krishna 11, a year later.
    await box.put(
      'occ8_${festival.id}_2026-1_0_$signature',
      DateTime(2027, 1, 3).millisecondsSinceEpoch,
    );

    final result = await findNextFestivalOccurrenceCached(
      service: _FakePanchangService(DateTime(2026, 1, 14)),
      festival: festival,
      startDate: DateTime(2026),
      latitude: latitude,
      longitude: longitude,
      monthSystem: HinduMonthSystem.amanta,
    );

    expect(
      result,
      DateTime(2026, 1, 14),
      reason: 'the stale 2027 answer must not win over the fixed scan',
    );
    expect(
      box.keys.whereType<String>().where((k) => k.startsWith('occ8_')),
      isEmpty,
      reason: 'pre-fix generations are purged on first box access',
    );
    expect(
      box.keys.whereType<String>().where((k) => k.startsWith('occ9_')),
      hasLength(1),
      reason: 'the fresh answer is stored under the new generation',
    );
  });
}
