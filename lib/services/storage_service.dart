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

  Future<Box<Festival>> openFestivalsBox() async {
    if (Hive.isBoxOpen(festivalsBoxName)) {
      return Hive.box<Festival>(festivalsBoxName);
    }
    return Hive.openBox<Festival>(festivalsBoxName);
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
