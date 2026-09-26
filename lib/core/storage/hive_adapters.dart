import 'package:hive/hive.dart';

import '../../models/festival.dart';
import '../../models/sankalpa.dart';

/// Single registration site for all Hive [TypeAdapter]s (Phase 1).
///
/// Replaces the duplicated blocks in `main.dart` and
/// `NotificationService._loadFestivalsForNotification` (background isolate).
/// Guarded by [Hive.isAdapterRegistered] so it is safe to call from both
/// the UI isolate and the Workmanager `callbackDispatcher`.
void registerHiveAdapters() {
  if (!Hive.isAdapterRegistered(0)) {
    Hive.registerAdapter(FestivalAdapter());
  }
  if (!Hive.isAdapterRegistered(1)) {
    Hive.registerAdapter(NameRegionalAdapter());
  }
  if (!Hive.isAdapterRegistered(2)) {
    Hive.registerAdapter(VisualsAdapter());
  }
  if (!Hive.isAdapterRegistered(3)) {
    Hive.registerAdapter(PurposeAdapter());
  }
  if (!Hive.isAdapterRegistered(4)) {
    Hive.registerAdapter(PanchangRulesAdapter());
  }
  if (!Hive.isAdapterRegistered(5)) {
    Hive.registerAdapter(RitualsAdapter());
  }
  if (!Hive.isAdapterRegistered(6)) {
    Hive.registerAdapter(MediaAdapter());
  }
  if (!Hive.isAdapterRegistered(10)) {
    Hive.registerAdapter(SankalpaAdapter());
  }
}
