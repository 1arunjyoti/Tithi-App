import 'dart:typed_data';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:hive_flutter/hive_flutter.dart';

import '../core/storage/box_names.dart';
import '../models/festival.dart';
import '../models/sankalpa.dart';

/// Centralized Hive box orchestration for startup and reset flows.
/// SMELL-4: Const singleton – the class is stateless so every call-site can
/// share a single canonical instance without needless heap allocations.
class StorageService {
  const StorageService._();
  static const StorageService _instance = StorageService._();
  factory StorageService() => _instance;
  // Canonical names live in core/storage/box_names.dart (Phase 1).
  // Kept here as aliases so existing call-sites keep compiling.
  static const String settingsBoxName = BoxNames.settings;
  static const String locationSettingsBoxName = BoxNames.locationSettings;
  static const String notificationSettingsBoxName =
      BoxNames.notificationSettings;
  static const String ritualCompletionBoxName = BoxNames.ritualCompletion;
  static const String sankalpasBoxName = BoxNames.sankalpas;
  static const String festivalSettingsBoxName = BoxNames.festivalSettings;
  static const String festivalsBoxName = BoxNames.festivals;
  static const String panchangCacheBoxName = BoxNames.panchangCache;

  /// Key in [festivalSettingsBoxName] holding the
  /// [kFestivalCacheSchemaVersion] that wrote the cached festivals box.
  static const String festivalsSchemaKey = 'hiveSchema';

  /// Opens all known boxes used by app features.
  Future<void> init() async {
    await openSettingsBox();
    await openLocationSettingsBox();
    await openNotificationSettingsBox();
    await openRitualCompletionBox();
    await openSankalpasBox();
    await openFestivalSettingsBox();
    await openFestivalsBox();
    await openPanchangCacheBox();
  }

  Future<Box<dynamic>> openSettingsBox() async {
    if (Hive.isBoxOpen(settingsBoxName)) {
      return Hive.box(settingsBoxName);
    }
    return Hive.openBox(settingsBoxName);
  }

  Future<Box<dynamic>> openLocationSettingsBox() async {
    if (Hive.isBoxOpen(locationSettingsBoxName)) {
      return Hive.box(locationSettingsBoxName);
    }
    return Hive.openBox(locationSettingsBoxName);
  }

  Future<Box<dynamic>> openNotificationSettingsBox() async {
    if (Hive.isBoxOpen(notificationSettingsBoxName)) {
      return Hive.box(notificationSettingsBoxName);
    }
    return Hive.openBox(notificationSettingsBoxName);
  }

  Future<Box<dynamic>> openRitualCompletionBox() async {
    if (Hive.isBoxOpen(ritualCompletionBoxName)) {
      return Hive.box(ritualCompletionBoxName);
    }
    return Hive.openBox(ritualCompletionBoxName);
  }

  Future<Box<Sankalpa>> openSankalpasBox() async {
    if (Hive.isBoxOpen(sankalpasBoxName)) {
      return Hive.box<Sankalpa>(sankalpasBoxName);
    }
    return Hive.openBox<Sankalpa>(sankalpasBoxName);
  }

  Future<Box<int>> openFestivalSettingsBox() async {
    if (Hive.isBoxOpen(festivalSettingsBoxName)) {
      return Hive.box<int>(festivalSettingsBoxName);
    }
    return Hive.openBox<int>(festivalSettingsBoxName);
  }

  /// Opens the festivals box, discarding a cached catalog it cannot use.
  ///
  /// The box is a rebuildable cache of `assets/festivals.json`, so throwing it
  /// away costs one re-seed and nothing else. Two layers:
  ///
  /// 1. A stale [kFestivalCacheSchemaVersion] is detected from
  ///    [festivalsSchemaKey] *before* opening. This matters because Hive
  ///    decodes every record while opening a non-lazy box (`BoxImpl`), and a
  ///    decode failure is also surfaced as an unhandled async error (Hive's
  ///    internal `_openingBoxes` completer has no listener) even when the
  ///    throw is caught. Checking first means an ordinary model change never
  ///    attempts the decode at all. The `tier` (int) → `featured` (bool) field
  ///    11 rename left ints in the previous box and crashed startup this way.
  /// 2. A box that still fails to open (corruption, or a box from before the
  ///    marker existed) is deleted and reopened empty; `FestivalRepository`
  ///    then reseeds from the asset.
  ///
  /// Falls back to an in-memory box if the disk copy cannot be rebuilt, so the
  /// catalog still renders for the session.
  Future<Box<Festival>> openFestivalsBox() async {
    if (Hive.isBoxOpen(festivalsBoxName)) {
      return Hive.box<Festival>(festivalsBoxName);
    }
    await _discardIncompatibleFestivalsCache();
    try {
      final box = await Hive.openBox<Festival>(festivalsBoxName);
      await _rememberFestivalsSchema();
      return box;
    } catch (error) {
      debugPrint(
        'Festivals cache unreadable ($error); discarding it and rebuilding '
        'from assets/festivals.json.',
      );
    }
    await _discardFestivalsCache();
    try {
      final box = await Hive.openBox<Festival>(festivalsBoxName);
      await _rememberFestivalsSchema();
      return box;
    } catch (error) {
      // Last resort: an in-memory box keeps the "festivals box is always open"
      // invariant every `Hive.box('festivals')` call-site relies on. The
      // repository still seeds it from the bundled JSON, so the list works for
      // this session; the next launch retries the disk.
      debugPrint(
        'Festivals cache could not be rebuilt ($error); '
        'continuing with an in-memory catalog for this session.',
      );
      return Hive.openBox<Festival>(festivalsBoxName, bytes: Uint8List(0));
    }
  }

  /// Deletes the cached catalog when it was written by a different
  /// [kFestivalCacheSchemaVersion] (or by a build that predates the marker).
  Future<void> _discardIncompatibleFestivalsCache() async {
    int? stored;
    try {
      stored = (await openFestivalSettingsBox()).get(festivalsSchemaKey);
    } catch (error) {
      debugPrint('Could not read the festivals cache schema ($error).');
    }
    if (stored == kFestivalCacheSchemaVersion) return;
    debugPrint(
      'Festivals cache schema changed ($stored -> '
      '$kFestivalCacheSchemaVersion); discarding the stored catalog.',
    );
    await _discardFestivalsCache();
  }

  /// Records which layout wrote the cache, for the next launch's check.
  Future<void> _rememberFestivalsSchema() async {
    try {
      final settings = await openFestivalSettingsBox();
      await settings.put(festivalsSchemaKey, kFestivalCacheSchemaVersion);
    } catch (error) {
      debugPrint('Could not store the festivals cache schema ($error).');
    }
  }

  /// Deletes the festivals box files. Best-effort: a locked or read-only file
  /// is handled by the in-memory fallback in [openFestivalsBox].
  ///
  /// The failed open releases its file handles asynchronously (Hive closes the
  /// half-initialized box in a `catch` without awaiting it), so a delete can
  /// briefly lose the race on Windows. Retry a few times before giving up.
  Future<void> _discardFestivalsCache() async {
    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        await Hive.deleteBoxFromDisk(festivalsBoxName);
        return;
      } catch (error) {
        debugPrint('Could not delete the festivals cache ($error).');
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
    }
  }

  Future<Box<dynamic>> openPanchangCacheBox() async {
    if (Hive.isBoxOpen(panchangCacheBoxName)) {
      return Hive.box(panchangCacheBoxName);
    }
    return Hive.openBox(panchangCacheBoxName);
  }

  Box<dynamic> getSettingsBox() => Hive.box(settingsBoxName);

  Box<dynamic> getRitualCompletionBox() => Hive.box(ritualCompletionBoxName);

  Box<Sankalpa> getSankalpasBox() => Hive.box<Sankalpa>(sankalpasBoxName);

  Box<Festival> getFestivalsBox() => Hive.box<Festival>(festivalsBoxName);

  Future<void> resetAll() async {
    final settingsBox = await openSettingsBox();
    await settingsBox.clear();

    final locationBox = await openLocationSettingsBox();
    await locationBox.clear();

    final notificationBox = await openNotificationSettingsBox();
    await notificationBox.clear();

    final ritualBox = await openRitualCompletionBox();
    await ritualBox.clear();

    final sankalpaBox = await openSankalpasBox();
    await sankalpaBox.clear();

    final festivalSettingsBox = await openFestivalSettingsBox();
    await festivalSettingsBox.clear();

    final festivalBox = await openFestivalsBox();
    await festivalBox.clear();

    final panchangCacheBox = await openPanchangCacheBox();
    await panchangCacheBox.clear();
  }
}
