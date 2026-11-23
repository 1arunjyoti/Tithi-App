import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:tithi/core/storage/hive_adapters.dart';
import 'package:tithi/models/festival.dart';
import 'package:tithi/services/festival_repository.dart';
import 'package:tithi/services/storage_service.dart';

/// A record whose frame is valid but whose payload can no longer be decoded.
///
/// That is the shape of a festivals box written by an older [Festival]
/// adapter: opening a non-lazy box decodes every record, so the failure
/// surfaces inside `openBox` — before any repository code runs. The
/// `tier` → `featured` rename (an int at field 11, then a bool) left exactly
/// this on upgraded installs and crashed startup.
class _UndecodableRecord {}

class _UndecodableAdapter extends TypeAdapter<_UndecodableRecord> {
  @override
  final int typeId = 99;

  @override
  _UndecodableRecord read(BinaryReader reader) =>
      throw const FormatException('record written by an older adapter');

  @override
  void write(BinaryWriter writer, _UndecodableRecord obj) {}
}

Festival _festival({bool? featuredFlag}) => Festival(
  id: 'flagless',
  name: 'Flagless',
  nameRegional: const NameRegional(nameEnglish: 'Flagless'),
  visuals: const Visuals(),
  purpose: const Purpose(description: 'A festival'),
  panchangRules: const PanchangRules(
    masa: '',
    paksha: 'Shukla',
    tithi: 1,
    conditions: '',
  ),
  rituals: const Rituals(steps: []),
  media: const Media(),
  featuredFlag: featuredFlag,
);

/// Writes the cache-schema marker that `openFestivalsBox` checks.
Future<void> _markSchema(int version) async {
  final settings = await Hive.openBox<dynamic>(
    StorageService.festivalSettingsBoxName,
  );
  await settings.put(StorageService.festivalsSchemaKey, version);
}

/// Writes a `festivals` box whose only record cannot be decoded.
Future<void> _writeUndecodableCache() async {
  final stale = await Hive.openBox<dynamic>('festivals');
  await stale.put('diwali', _UndecodableRecord());
  await stale.close();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('festival_cache_recovery');
    Hive.init(tempDir.path);
    registerHiveAdapters();
    if (!Hive.isAdapterRegistered(99)) {
      Hive.registerAdapter(_UndecodableAdapter());
    }
  });

  tearDown(() async {
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  test('a stale cache schema is dropped before it is decoded', () async {
    // Arrange: a record from an older model plus the marker saying so — the
    // shape of an upgrade across a Festival layout change.
    final unhandled = <Object>[];

    await runZonedGuarded(() async {
      await _writeUndecodableCache();
      await _markSchema(kFestivalCacheSchemaVersion - 1);

      // Act
      final box = await StorageService().openFestivalsBox();

      // Assert: the box was replaced instead of decoded, so not even the
      // unhandled error Hive emits for a failed open was triggered.
      expect(box.isEmpty, isTrue);
      expect(Hive.isBoxOpen('festivals'), isTrue);

      // Act: the repository rebuilds the catalog from the bundled JSON.
      await FestivalRepository().init();

      // Assert: full catalog, including the curated flag from data.
      expect(box.length, 127);
      expect(box.get('diwali')?.featured, isTrue);
    }, (error, stack) => unhandled.add(error));

    expect(unhandled, isEmpty);
  });

  test(
    'an undecodable cache with a matching schema is still recovered',
    () async {
      // Hive's `_openBox` completes an internal `_openingBoxes` completer with
      // the open error without anyone listening to it, so a failed open is also
      // reported as an unhandled async error (the app's `runZonedGuarded` logs
      // it). Mirror that here instead of letting it fail the test.
      final unhandled = <Object>[];

      await runZonedGuarded(() async {
        // Arrange: corruption the schema marker cannot predict.
        await _writeUndecodableCache();
        await _markSchema(kFestivalCacheSchemaVersion);

        // Act: startup opens the box (Hive decodes every record while opening).
        final box = await StorageService().openFestivalsBox();

        // Assert: the unreadable cache was dropped instead of failing startup,
        // and the box is still open for every `Hive.box('festivals')` call-site.
        expect(box.isEmpty, isTrue);
        expect(Hive.isBoxOpen('festivals'), isTrue);
      }, (error, stack) => unhandled.add(error));

      expect(unhandled, isNotEmpty);
    },
  );

  test('a null stored flag reads as not featured', () async {
    // Arrange: field 11 absent — a box written before the field existed, or an
    // instance kept alive across a hot reload of the model.
    final box = await Hive.openBox<Festival>('festivals');
    await box.put('flagless', _festival());
    await box.close();

    // Act
    final reopened = await Hive.openBox<Festival>('festivals');
    final festival = reopened.get('flagless');

    // Assert: the storage field stays null, the public flag is false.
    expect(festival?.featuredFlag, isNull);
    expect(festival?.featured, isFalse);
  });
}
