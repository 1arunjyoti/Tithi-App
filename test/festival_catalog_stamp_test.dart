import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:tithi/core/perf/startup_timeline.dart';
import 'package:tithi/core/storage/hive_adapters.dart';
import 'package:tithi/services/festival_repository.dart';
import 'package:tithi/services/storage_service.dart';

/// Hashing the bundled 230 KB catalog on every launch is wasted work: the
/// asset only changes when the APK does. These tests pin the cache that lets a
/// relaunch of the same build skip it, and the cases that must NOT trust it.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  void build(String version, String buildNumber) {
    PackageInfo.setMockInitialValues(
      appName: 'Tithi',
      packageName: 'app.tithi.pro',
      version: version,
      buildNumber: buildNumber,
      buildSignature: '',
    );
  }

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('festival_catalog_stamp');
    Hive.init(tempDir.path);
    registerHiveAdapters();
    build('0.9.1', '30');
    // The suite silences launch marks; this file reads them on purpose.
    StartupTimeline.enabled = true;
  });

  tearDown(() async {
    StartupTimeline.enabled = false;
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  /// Runs [FestivalRepository.init] with a clean timeline so the marks only
  /// describe that launch. `festival-asset` is emitted exactly when the asset
  /// is read, which is the whole point.
  Future<Map<String, int>> launch() async {
    StartupTimeline.reset();
    await FestivalRepository().init();
    return StartupTimeline.marks;
  }

  test('a relaunch of the same build skips the asset', () async {
    // Arrange: first launch seeds the box and fingerprints the catalog.
    final first = await launch();
    expect(first.containsKey('festival-asset'), isTrue);

    // Act: same build, same box, next launch.
    final second = await launch();

    // Assert: the 230 KB asset was not read, but init still completed.
    expect(second.containsKey('festival-asset'), isFalse);
    expect(second.containsKey('festival-init'), isTrue);
  });

  test('a new build re-fingerprints the catalog', () async {
    // Arrange
    await launch();

    // Act: the JSON can change in any release, so a new build re-reads it.
    build('0.9.2', '31');
    final next = await launch();

    // Assert
    expect(next.containsKey('festival-asset'), isTrue);
  });

  test('a cleared box always re-seeds from the asset', () async {
    // Arrange: the stamp is valid, but the rows it describes are gone.
    await launch();
    final box = await StorageService().openFestivalsBox();
    await box.clear();

    // Act
    final next = await launch();

    // Assert: the asset is read again and the box is repopulated.
    expect(next.containsKey('festival-asset'), isTrue);
    expect(box.length, 127);
  });
}
