import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:tithi/models/festival.dart';
import 'package:tithi/models/sankalpa.dart';
import 'package:tithi/providers/home_cards_visibility_provider.dart';
import 'package:tithi/services/storage_service.dart';

// Home cards visibility: defaults (first install shows everything) and
// Hive persistence across restarts (new container = new launch).
void main() {
  setUp(() async {
    final tempDir = await Directory.systemTemp.createTemp('tithi_cards_vis');
    Hive.init(tempDir.path);
    try {
      Hive.registerAdapter(FestivalAdapter());
      Hive.registerAdapter(NameRegionalAdapter());
      Hive.registerAdapter(VisualsAdapter());
      Hive.registerAdapter(PurposeAdapter());
      Hive.registerAdapter(PanchangRulesAdapter());
      Hive.registerAdapter(RitualsAdapter());
      Hive.registerAdapter(MediaAdapter());
      Hive.registerAdapter(SankalpaAdapter());
    } catch (_) {
      // Ignore if already registered
    }
    await StorageService().init();
  });

  tearDown(() async {
    try {
      await Hive.close().timeout(const Duration(seconds: 10));
    } catch (_) {}
  });

  ProviderContainer freshContainer() {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    return container;
  }

  test('both cards visible on first install', () {
    final container = freshContainer();
    expect(container.read(dailyWisdomVisibleProvider), isTrue);
    expect(container.read(festivalCountdownsVisibleProvider), isTrue);
  });

  test('hiding persists across restarts, showing restores', () async {
    final container = freshContainer();
    await container.read(dailyWisdomVisibleProvider.notifier).setVisible(false);
    await container
        .read(festivalCountdownsVisibleProvider.notifier)
        .setVisible(false);
    expect(container.read(dailyWisdomVisibleProvider), isFalse);
    expect(container.read(festivalCountdownsVisibleProvider), isFalse);

    // New launch reads the persisted values.
    final relaunched = freshContainer();
    expect(relaunched.read(dailyWisdomVisibleProvider), isFalse);
    expect(relaunched.read(festivalCountdownsVisibleProvider), isFalse);

    await relaunched
        .read(dailyWisdomVisibleProvider.notifier)
        .setVisible(true);
    await relaunched
        .read(festivalCountdownsVisibleProvider.notifier)
        .setVisible(true);
    expect(freshContainer().read(dailyWisdomVisibleProvider), isTrue);
    expect(freshContainer().read(festivalCountdownsVisibleProvider), isTrue);
  });
}
