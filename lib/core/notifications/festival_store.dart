import 'package:flutter/foundation.dart';

import '../../models/festival.dart';
import '../storage/hive_adapters.dart';
import '../../services/storage_service.dart';

// Phase 4: festival loading for notifications, extracted from
// NotificationService._loadFestivalsForNotification. Reads directly from
// Hive so it works in the Workmanager background isolate (no Riverpod).
// Returns empty on any failure so the notification falls back to tithi.
Future<List<Festival>> loadFestivalsForNotification() async {
  try {
    // Single registration site (core/storage/hive_adapters.dart) — safe
    // in both the UI and Workmanager background isolates.
    registerHiveAdapters();
    final box = await StorageService().openFestivalsBox();
    if (box.isEmpty) return const [];
    return List<Festival>.unmodifiable(box.values);
  } catch (e) {
    debugPrint('Failed to load festivals for notification: $e');
    return const [];
  }
}
