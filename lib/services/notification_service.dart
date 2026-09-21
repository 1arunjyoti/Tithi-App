import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:timezone/timezone.dart' as tz;
import '../core/notifications/background_entrypoint.dart'
    show initNotificationWork;
import '../core/notifications/notification_keys.dart';
import '../core/notifications/scheduler.dart';
import '../models/sankalpa.dart';
import 'storage_service.dart';

// Phase 4: background entrypoint lives in
// core/notifications/background_entrypoint.dart.

// Phase 6b: FestivalReminderTiming lives in
// core/notifications/notification_keys.dart (re-exported below for
// backward compatibility with existing imports).
export '../core/notifications/notification_keys.dart'
    show FestivalReminderTiming;

/// Notification service for scheduling daily tithi notifications
/// FOSS-compatible: Uses native Android NotificationCompat, no Google Play Services
///
/// BUG-3 fix: singleton so the background isolate (callbackDispatcher),
/// main.dart, and the Riverpod provider all share the same Hive box
/// and notification-ID counter — prevents ID collisions.
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  // Phase 4: worker wiring lives in
  // core/notifications/background_entrypoint.dart as [initNotificationWork];
  // keys/IDs live in core/notifications/notification_keys.dart.

  /// Initialize WorkManager (delegates to core/notifications).
  Future<void> initWorkManager() => initNotificationWork();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  Box? _box;
  bool _isInitialized = false;

  // Phase 6b: scheduling engine lives in core/notifications/scheduler.dart
  // as [NotificationScheduler], driven by this explicit seam (plugin + box).
  // Delegates below preserve the public API and the lifecycle guards.
  NotificationScheduler get _scheduler =>
      NotificationScheduler(plugin: _notifications, box: _box);

  Future<({int hour, int minute})> getNotificationTime() {
    _ensureInitialized();
    return _scheduler.getNotificationTime();
  }

  Future<int> getFestivalTiming() {
    _ensureInitialized();
    return _scheduler.getFestivalTiming();
  }

  Future<void> _scheduleUpcomingShlokas() {
    _ensureInitialized();
    return _scheduler.scheduleUpcomingShlokas();
  }

  Future<void> _scheduleUpcomingFestivals() {
    _ensureInitialized();
    return _scheduler.scheduleUpcomingFestivals();
  }

  Future<void> cancelShlokaNotifications() =>
      _scheduler.cancelShlokaNotifications();

  Future<void> cancelFestivalNotifications() =>
      _scheduler.cancelFestivalNotifications();

  Future<void> cancelAllNotifications() =>
      _scheduler.cancelAllNotifications();

  Future<bool> requestPermission() => _scheduler.requestPermission();

  Future<void> _assertSystemNotificationsAllowed() =>
      _scheduler.assertSystemNotificationsAllowed();

  Future<void> scheduleDailyNotification({String? title, String? body}) {
    _ensureInitialized();
    return _scheduler.scheduleDailyNotification(title: title, body: body);
  }

  Future<void> showTestNotification({
    required String title,
    required String body,
  }) {
    _ensureInitialized();
    return _scheduler.showTestNotification(title: title, body: body);
  }

  Future<void> scheduleSankalpaReminder(Sankalpa sankalpa) {
    _ensureInitialized();
    return _scheduler.scheduleSankalpaReminder(sankalpa);
  }

  Future<void> cancelSankalpaReminder(String id) =>
      _scheduler.cancelSankalpaReminder(id);

  Future<void> cancelAllSankalpaReminders(List<String> sankalpaIds) =>
      _scheduler.cancelAllSankalpaReminders(sankalpaIds);

  /// Initialize the notification service
  Future<void> init() async {
    if (_isInitialized) return;

    try {
      // BUG-12: tz_data.initializeTimeZones() is already called in main() before
      // this method is reached in the normal app flow.  Calling it again here
      // wastes ~2 MB of timezone-table work.  The call is kept in
      // callbackDispatcher (background isolate) where main() has NOT run.
      // tz_data.initializeTimeZones(); ← removed

      // BUG-07: Use flutter_timezone for reliable IANA timezone identification
      // instead of the manual UTC-offset table which breaks under DST.
      final deviceTimeZone = await _getDeviceTimezone();
      try {
        tz.setLocalLocation(tz.getLocation(deviceTimeZone));
      } catch (e) {
        // Some devices/ROMs report non-IANA names (e.g. abbreviations or
        // UTC offsets) which make tz.getLocation throw. Fall back to
        // Asia/Kolkata (app's primary audience) instead of bricking init —
        // a throwing init leaves the service uninitialized forever and makes
        // the settings toggle snap back to OFF on every attempt.
        debugPrint(
          'Unknown timezone "$deviceTimeZone", falling back to Asia/Kolkata: $e',
        );
        tz.setLocalLocation(tz.getLocation('Asia/Kolkata'));
      }

      // Initialize Hive box
      _box = await StorageService().openNotificationSettingsBox();

      // Initialize notifications
      const androidSettings = AndroidInitializationSettings(
        '@mipmap/launcher_icon',
      );
      // Don't auto-prompt on iOS at init: permission is requested explicitly
      // when the user flips the toggle (requestPermission), so merely opening
      // Settings must not pop a system dialog.
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );

      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      await _notifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
      );

      _isInitialized = true;

      // NOTE: no eager _refreshDailyNotificationContent() here. Content is
      // refreshed lazily by scheduleDailyNotification() via
      // _getDailyNotificationContent(), so init stays cheap (no ephemeris
      // copy, no Jyotish native init, no tithi calc — PanchangService is not
      // a singleton) when notifications are disabled.

      // SMELL-2: read flags directly from the box (synchronous Hive get) instead
      // of calling await isEnabled() / await isShlokaEnabled(), which wrap the
      // same synchronous read in an unnecessary Future.
      final notificationsEnabled =
          _box?.get(NotificationKeys.enabled, defaultValue: false) ?? false;
      final shlokasEnabled =
          _box?.get(NotificationKeys.shlokaEnabled, defaultValue: false) ?? false;
      final festivalsEnabled =
          _box?.get(NotificationKeys.festivalEnabled, defaultValue: false) ?? false;

      if (kDebugMode) {
        if (notificationsEnabled || festivalsEnabled) {
          print(
            'NotificationService ready - notifications ON'
            '${shlokasEnabled ? ', shloka ON' : ''}'
            '${festivalsEnabled ? ', festival ON' : ''}',
          );
        } else {
          print(
            'NotificationService ready - notifications OFF (nothing scheduled)',
          );
        }
      }

      // Only schedule if enabled. Scheduling failures must not fail init:
      // a throwing init leaves _isInitialized false, so every later
      // setEnabled/isEnabled throws ("not initialized") and the settings
      // toggle snaps back to OFF permanently. Log and continue instead —
      // the toggle and the periodic WorkManager task will retry scheduling.
      if (notificationsEnabled) {
        try {
          await scheduleDailyNotification();
        } catch (e) {
          debugPrint('Failed to reschedule notifications during init: $e');
        }
      }
      // Shloka reminders are independent of the daily master switch.
      if (shlokasEnabled) {
        try {
          await _scheduleUpcomingShlokas();
        } catch (e) {
          debugPrint('Failed to reschedule shlokas during init: $e');
        }
      }
      // Festival reminders are independent of the daily master switch so
      // users can opt into festival-only notifications.
      if (festivalsEnabled) {
        try {
          await _scheduleUpcomingFestivals();
        } catch (e) {
          debugPrint('Failed to reschedule festivals during init: $e');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error initializing NotificationService: $e');
      }
      rethrow;
    }
  }

  /// Handle notification tap
  void _onNotificationTapped(NotificationResponse response) {
    if (kDebugMode) {
      print('Notification tapped: ${response.payload}');
    }
    // App will open automatically when notification is tapped
  }

  /// Check if notifications are enabled
  Future<bool> isEnabled() async {
    _ensureInitialized();
    return _box?.get(NotificationKeys.enabled, defaultValue: false) ?? false;
  }

  /// Enable or disable notifications.
  ///
  /// The persisted flag is rolled back if (re)scheduling fails, so storage
  /// never claims notifications are ON while nothing is scheduled. Callers
  /// (e.g. the settings toggle) should catch the rethrown error to show
  /// feedback and revert any optimistic UI update.
  Future<void> setEnabled(bool enabled) async {
    _ensureInitialized();
    final previous =
        _box?.get(NotificationKeys.enabled, defaultValue: false) as bool? ?? false;
    await _box?.put(NotificationKeys.enabled, enabled);

    try {
      if (enabled) {
        // Fail fast with a clear message when the OS blocks notifications
        // (e.g. revoked after granting): zonedSchedule would otherwise
        // "succeed" silently while nothing is ever shown.
        await _assertSystemNotificationsAllowed();
        await scheduleDailyNotification();
        // Re-assert shloka schedules (independent flag; harmless if fresh).
        final shlokaEnabled =
            _box?.get(NotificationKeys.shlokaEnabled, defaultValue: false) ?? false;
        if (shlokaEnabled) {
          await _scheduleUpcomingShlokas();
        }
      } else {
        // Cancel only the daily schedule. Shloka, sankalpa, and festival
        // reminders have their own lifecycle and must survive toggling
        // daily notifications (use cancelAllNotifications() only for full
        // reset flows).
        await _notifications.cancel(NotificationKeys.dailyNotificationId);
      }
    } catch (e) {
      // Roll back so the toggle can reflect the real state on retry.
      try {
        await _box?.put(NotificationKeys.enabled, previous);
      } catch (rollbackError) {
        debugPrint('Failed to roll back notification flag: $rollbackError');
      }
      debugPrint('Failed to ${enabled ? 'enable' : 'disable'} notifications: $e');
      rethrow;
    }
  }


  // SMELL-02: cache the enabled flag to avoid two awaited Hive reads.
  ///
  /// The persisted time is rolled back if rescheduling fails, so the shown
  /// time never disagrees with the active schedule.
  Future<void> setNotificationTime(int hour, int minute) async {
    _ensureInitialized();
    final prevHour = (_box?.get(NotificationKeys.hour, defaultValue: 8) as int?) ?? 8;
    final prevMinute = (_box?.get(NotificationKeys.minute, defaultValue: 0) as int?) ?? 0;
    await _box?.put(NotificationKeys.hour, hour);
    await _box?.put(NotificationKeys.minute, minute);

    try {
      // Read flags directly from the box — same synchronous Hive get as isEnabled()
      final enabled = _box?.get(NotificationKeys.enabled, defaultValue: false) ?? false;
      if (enabled) {
        await scheduleDailyNotification();
      }
      final shlokaEnabled =
          _box?.get(NotificationKeys.shlokaEnabled, defaultValue: false) ?? false;
      if (shlokaEnabled) {
        await _scheduleUpcomingShlokas();
      }
      final festivalsEnabled =
          _box?.get(NotificationKeys.festivalEnabled, defaultValue: false) ?? false;
      if (festivalsEnabled) {
        await _scheduleUpcomingFestivals();
      }
    } catch (e) {
      try {
        await _box?.put(NotificationKeys.hour, prevHour);
        await _box?.put(NotificationKeys.minute, prevMinute);
      } catch (rollbackError) {
        debugPrint('Failed to roll back notification time: $rollbackError');
      }
      debugPrint('Failed to set notification time: $e');
      rethrow;
    }
  }

  /// Check if Shloka notifications are enabled
  Future<bool> isShlokaEnabled() async {
    _ensureInitialized();
    return _box?.get(NotificationKeys.shlokaEnabled, defaultValue: false) ?? false;
  }

  /// Enable or disable Shloka notifications.
  ///
  /// Independent of the daily master switch (like festival reminders), so
  /// users can opt into shloka-only notifications. Like [setEnabled], the
  /// persisted flag is rolled back if scheduling fails so callers can
  /// revert optimistic UI updates on error.
  Future<void> setShlokaEnabled(bool enabled) async {
    _ensureInitialized();
    final previous =
        _box?.get(NotificationKeys.shlokaEnabled, defaultValue: false) as bool? ?? false;
    await _box?.put(NotificationKeys.shlokaEnabled, enabled);

    try {
      if (enabled) {
        await _assertSystemNotificationsAllowed();
        await _scheduleUpcomingShlokas();
      } else {
        await cancelShlokaNotifications();
      }
    } catch (e) {
      try {
        await _box?.put(NotificationKeys.shlokaEnabled, previous);
      } catch (rollbackError) {
        debugPrint('Failed to roll back shloka flag: $rollbackError');
      }
      debugPrint('Failed to set shloka notifications to $enabled: $e');
      rethrow;
    }
  }



  /// Check if festival reminders are enabled.
  Future<bool> isFestivalEnabled() async {
    _ensureInitialized();
    return _box?.get(NotificationKeys.festivalEnabled, defaultValue: false) ?? false;
  }


  /// Enable or disable festival reminders.
  ///
  /// Independent of the daily master switch so users can opt into
  /// festival-only notifications. Like [setShlokaEnabled], the persisted
  /// flag is rolled back if scheduling fails.
  Future<void> setFestivalEnabled(bool enabled) async {
    _ensureInitialized();
    final previous =
        _box?.get(NotificationKeys.festivalEnabled, defaultValue: false) as bool? ?? false;
    await _box?.put(NotificationKeys.festivalEnabled, enabled);

    try {
      if (enabled) {
        await _assertSystemNotificationsAllowed();
        await _scheduleUpcomingFestivals();
      } else {
        await cancelFestivalNotifications();
      }
    } catch (e) {
      try {
        await _box?.put(NotificationKeys.festivalEnabled, previous);
      } catch (rollbackError) {
        debugPrint('Failed to roll back festival flag: $rollbackError');
      }
      debugPrint('Failed to set festival notifications to $enabled: $e');
      rethrow;
    }
  }

  /// Set when festival reminders fire (0 = on the day, 1 = one day before,
  /// 2 = both). Out-of-range values throw [ArgumentError] without touching
  /// storage. Reschedules when reminders are enabled; rolls back on failure.
  Future<void> setFestivalTiming(int timing) async {
    _ensureInitialized();
    if (timing < 0 || timing > FestivalReminderTiming.values.length - 1) {
      throw ArgumentError.value(timing, 'timing', 'Must be 0, 1, or 2');
    }
    final previous =
        (_box?.get(NotificationKeys.festivalTiming, defaultValue: 0) as int?) ?? 0;
    await _box?.put(NotificationKeys.festivalTiming, timing);

    try {
      final enabled =
          _box?.get(NotificationKeys.festivalEnabled, defaultValue: false) ?? false;
      if (enabled) {
        await _scheduleUpcomingFestivals();
      }
    } catch (e) {
      try {
        await _box?.put(NotificationKeys.festivalTiming, previous);
      } catch (rollbackError) {
        debugPrint('Failed to roll back festival timing: $rollbackError');
      }
      debugPrint('Failed to set festival timing to $timing: $e');
      rethrow;
    }
  }














  /// BUG-07: Returns the device's IANA timezone name using flutter_timezone.
  /// Falls back to 'Asia/Kolkata' (app's primary audience) if unavailable.
  Future<String> _getDeviceTimezone() async {
    try {
      final timezoneInfo = await FlutterTimezone.getLocalTimezone();
      if (timezoneInfo.isNotEmpty) return timezoneInfo;
      debugPrint('flutter_timezone returned empty name, using Asia/Kolkata');
    } catch (e) {
      debugPrint(
        'flutter_timezone unavailable, defaulting to Asia/Kolkata: $e',
      );
    }
    return 'Asia/Kolkata';
  }







  void _ensureInitialized() {
    if (!_isInitialized) {
      throw Exception(
        'NotificationService not initialized. Call init() first.',
      );
    }
  }

  /// Dispose of resources (call when app closes)
  Future<void> dispose() async {
    if (_box != null && _box!.isOpen) {
      await _box!.close();
    }
    _isInitialized = false;
  }
}
