import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:tithi/core/storage/hive_adapters.dart';
import 'package:tithi/models/festival.dart';
import 'package:tithi/providers/festival_provider.dart';
import 'package:tithi/providers/location_provider.dart';
import 'package:tithi/services/storage_service.dart';

/// First-launch regression proof: on a fresh install the Hive festivals box
/// is open but EMPTY, and the home screen already reads [festivalProvider].
///
/// Two guarantees:
/// 1. Seeding waits for the location permission decision
///    ([locationPermissionGateProvider]): no background festival work
///    contends with the permission flow, and the month batch later
///    computes once with the final coordinates.
/// 2. Once seeding completes, the provider flips to the full list live —
///    no restart, no manual invalidate (the old provider memoized the
///    transient [] forever, leaving home empty until relaunch).
void main() {
  test('festival seeding waits for location, then populates live', () async {
    TestWidgetsFlutterBinding.ensureInitialized();

    // Arrange: fresh-install state — boxes open, festivals box empty,
    // permission dialog not yet resolved (gate closed).
    final tempDir = await Directory.systemTemp.createTemp(
      'festival_first_launch_test',
    );
    Hive.init(tempDir.path);
    registerHiveAdapters();
    await StorageService().init();
    expect(Hive.box<Festival>('festivals').isEmpty, isTrue);

    final container = ProviderContainer();
    addTearDown(() async {
      container.dispose();
      await Hive.close();
    });

    // Act: home reads while the permission flow is still up.
    expect(container.read(festivalProvider), isEmpty);

    // Assert: seeding holds until the user decides — the box stays empty
    // well past the time an ungated seed would have started writing.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    expect(Hive.box<Festival>('festivals').isEmpty, isTrue);

    // Act: user resolves the permission dialog (grant → device coords,
    // deny/skip → default); seeding starts and completes in background.
    container.read(locationPermissionGateProvider).complete();
    await container.read(festivalInitProvider.future);

    // Assert: full list live with no restart and no manual invalidate.
    final festivals = container.read(festivalProvider);
    expect(festivals, isNotEmpty);
    expect(
      container.read(majorFestivalsProvider),
      isNotEmpty,
      reason: 'derived providers rebuild off the same fix',
    );
  });
}
