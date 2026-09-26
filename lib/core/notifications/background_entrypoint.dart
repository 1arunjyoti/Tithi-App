import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:workmanager/workmanager.dart';

import '../../services/notification_service.dart';
import 'notification_keys.dart';

// Phase 4: Workmanager background entrypoint + setup, extracted from
// services/notification_service.dart (callbackDispatcher +
// NotificationService.initWorkManager). Lives in core so the background
// isolate's dependencies (Hive, timezones, service init) are explicit and
// the singleton no longer owns process-level worker wiring.

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      if (kDebugMode) {
        print('WorkManager executing task: $task');
      }

      // Initialize dependencies in background isolate
      await Hive.initFlutter();

      // Initialize timezone data
      tz_data.initializeTimeZones();

      // Initialize NotificationService
      // This will check settings and reschedule notifications if enabled
      final service = NotificationService();
      await service.init();

      return true;
    } catch (e) {
      // SMELL-07: always surface background task failures, not just in debug.
      debugPrint('WorkManager task failed: $e');
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: e,
          context: ErrorDescription('WorkManager callbackDispatcher'),
        ),
      );
      return false;
    }
  });
}

/// Registers the periodic background notification check.
/// Only meaningful on Android/iOS; no-op on web.
Future<void> initNotificationWork() async {
  // Only initialize on Android/iOS (skip web/desktop if targeted)
  if (kIsWeb) return;

  try {
    await Workmanager().initialize(callbackDispatcher);

    await Workmanager().registerPeriodicTask(
      'periodic_check_id',
      NotificationKeys.taskName,
      frequency: const Duration(hours: 6),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.update,
    );

    if (kDebugMode) {
      print('WorkManager initialized and periodic task scheduled');
    }
  } catch (e) {
    if (kDebugMode) {
      print('Failed to init WorkManager: $e');
    }
  }
}
