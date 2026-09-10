import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:workmanager/workmanager.dart';
import '../utils/date_utils.dart';
import 'shloka_service.dart';
import '../models/festival.dart';
import '../models/sankalpa.dart';
import '../models/hindu_month_system.dart';
import '../models/panchang_data.dart';
import 'panchang_service.dart';
import 'storage_service.dart';
import 'sunrise_calculator.dart';
import 'bengali_calendar/bengali_calendar_data.dart';

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

      return Future.value(true);
    } catch (e) {
      // SMELL-07: always surface background task failures, not just in debug.
      debugPrint('WorkManager task failed: $e');
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: e,
          context: ErrorDescription('WorkManager callbackDispatcher'),
        ),
      );
      return Future.value(false);
    }
  });
}

/// When festival reminders fire. Stored as the enum index under
/// [NotificationService._keyFestivalTiming] (`festival_timing`).
enum FestivalReminderTiming {
  /// Morning of the festival, at the notification time.
  onDay,

  /// At the notification time on the eve of the festival.
  dayBefore,

  /// Both eve and day-of reminders.
  both,
}

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

  static const String _taskName = 'periodic_notification_check';

  /// Initialize WorkManager
  Future<void> initWorkManager() async {
    // Only initialize on Android/iOS (skip web/desktop if targeted)
    if (kIsWeb) return;

    // We only need workmanager on Android/iOS
    // desktop doesn't support workmanager nicely yet or needs different setup
    // But since this app seems mobile focused:

    try {
      await Workmanager().initialize(callbackDispatcher);

      await Workmanager().registerPeriodicTask(
        "periodic_check_id",
        _taskName,
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

  static const String _keyEnabled = 'notifications_enabled';
  static const String _keyHour = 'notification_hour';
  static const String _keyMinute = 'notification_minute';
  static const String _keyShlokaEnabled = 'shloka_enabled';
  static const String _keyFestivalEnabled = 'festival_enabled';
  static const String _keyFestivalTiming = 'festival_timing';
  static const String _keyDailyTitle = 'daily_title';
  static const String _keyDailyBody = 'daily_body';
  static const String _keyDailyContentDate = 'daily_content_date';
  static const int _dailyNotificationId = 1;
  static const int _shlokaNotificationIdBase = 1000;
  static const int _festivalNotificationIdBase = 2000;
  static const int _festivalWindowDays = 8;

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  Box? _box;
  bool _isInitialized = false;

  // Base ID for sankalpa notifications (unique range to avoid collision)
  static const int _sankalpaNotificationIdBase = 10000;
  // Hive keys for the persisted sankalpa → notification-ID mapping.
  static const String _keySankalpaIdCounter = '_sankalpa_nid_counter';
  static const String _keySankalpaIdPrefix = '_sankalpa_nid_';

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
          _box?.get(_keyEnabled, defaultValue: false) ?? false;
      final shlokasEnabled =
          _box?.get(_keyShlokaEnabled, defaultValue: false) ?? false;
      final festivalsEnabled =
          _box?.get(_keyFestivalEnabled, defaultValue: false) ?? false;

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
    return _box?.get(_keyEnabled, defaultValue: false) ?? false;
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
        _box?.get(_keyEnabled, defaultValue: false) as bool? ?? false;
    await _box?.put(_keyEnabled, enabled);

    try {
      if (enabled) {
        // Fail fast with a clear message when the OS blocks notifications
        // (e.g. revoked after granting): zonedSchedule would otherwise
        // "succeed" silently while nothing is ever shown.
        await _assertSystemNotificationsAllowed();
        await scheduleDailyNotification();
        // Re-assert shloka schedules (independent flag; harmless if fresh).
        final shlokaEnabled =
            _box?.get(_keyShlokaEnabled, defaultValue: false) ?? false;
        if (shlokaEnabled) {
          await _scheduleUpcomingShlokas();
        }
      } else {
        // Cancel only the daily schedule. Shloka, sankalpa, and festival
        // reminders have their own lifecycle and must survive toggling
        // daily notifications (use cancelAllNotifications() only for full
        // reset flows).
        await _notifications.cancel(_dailyNotificationId);
      }
    } catch (e) {
      // Roll back so the toggle can reflect the real state on retry.
      try {
        await _box?.put(_keyEnabled, previous);
      } catch (rollbackError) {
        debugPrint('Failed to roll back notification flag: $rollbackError');
      }
      debugPrint('Failed to ${enabled ? 'enable' : 'disable'} notifications: $e');
      rethrow;
    }
  }

  /// Get notification time (default 8:00 AM)
  Future<({int hour, int minute})> getNotificationTime() async {
    _ensureInitialized();
    final hour = (_box?.get(_keyHour, defaultValue: 8) as int?) ?? 8;
    final minute = (_box?.get(_keyMinute, defaultValue: 0) as int?) ?? 0;
    return (hour: hour, minute: minute);
  }

  // SMELL-02: cache the enabled flag to avoid two awaited Hive reads.
  ///
  /// The persisted time is rolled back if rescheduling fails, so the shown
  /// time never disagrees with the active schedule.
  Future<void> setNotificationTime(int hour, int minute) async {
    _ensureInitialized();
    final prevHour = (_box?.get(_keyHour, defaultValue: 8) as int?) ?? 8;
    final prevMinute = (_box?.get(_keyMinute, defaultValue: 0) as int?) ?? 0;
    await _box?.put(_keyHour, hour);
    await _box?.put(_keyMinute, minute);

    try {
      // Read flags directly from the box — same synchronous Hive get as isEnabled()
      final enabled = _box?.get(_keyEnabled, defaultValue: false) ?? false;
      if (enabled) {
        await scheduleDailyNotification();
      }
      final shlokaEnabled =
          _box?.get(_keyShlokaEnabled, defaultValue: false) ?? false;
      if (shlokaEnabled) {
        await _scheduleUpcomingShlokas();
      }
      final festivalsEnabled =
          _box?.get(_keyFestivalEnabled, defaultValue: false) ?? false;
      if (festivalsEnabled) {
        await _scheduleUpcomingFestivals();
      }
    } catch (e) {
      try {
        await _box?.put(_keyHour, prevHour);
        await _box?.put(_keyMinute, prevMinute);
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
    return _box?.get(_keyShlokaEnabled, defaultValue: false) ?? false;
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
        _box?.get(_keyShlokaEnabled, defaultValue: false) as bool? ?? false;
    await _box?.put(_keyShlokaEnabled, enabled);

    try {
      if (enabled) {
        await _assertSystemNotificationsAllowed();
        await _scheduleUpcomingShlokas();
      } else {
        await cancelShlokaNotifications();
      }
    } catch (e) {
      try {
        await _box?.put(_keyShlokaEnabled, previous);
      } catch (rollbackError) {
        debugPrint('Failed to roll back shloka flag: $rollbackError');
      }
      debugPrint('Failed to set shloka notifications to $enabled: $e');
      rethrow;
    }
  }

  /// Cancel all Shloka notifications
  Future<void> cancelShlokaNotifications() async {
    // Cancel IDs 1000 to 1006 (7 days)
    for (int i = 0; i < 7; i++) {
      await _notifications.cancel(_shlokaNotificationIdBase + i);
    }
  }

  /// Schedule upcoming Shloka notifications for the next 7 days
  Future<void> _scheduleUpcomingShlokas() async {
    _ensureInitialized();
    // SMELL-2: read the flag directly from the box instead of an async
    // isShlokaEnabled() call. Independent of the daily master switch.
    final shlokaEnabled =
        _box?.get(_keyShlokaEnabled, defaultValue: false) ?? false;
    if (!shlokaEnabled) return;

    await cancelShlokaNotifications();

    // ShlokaService is a singleton, no need to cache it
    final shlokaService = ShlokaService();
    await shlokaService.init();

    final time = await getNotificationTime();
    final now = tz.TZDateTime.now(tz.local);

    final shlokas = shlokaService.getShlokasForNextNDays(7);

    for (int i = 0; i < shlokas.length; i++) {
      var scheduledDate = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day,
        time.hour,
        time.minute,
      ).add(Duration(days: i));

      // If the calculated time for "today" (i=0) has passed,
      // we might still want to show it if we just enabled it?
      // Or strictly follow "future only".
      // Daily notification logic moves it to tomorrow if passed.
      // For shlokas, if today passed, we just skip scheduling "today's" notification
      // because the user will see it in the app anyway.

      if (scheduledDate.isBefore(now)) {
        // If it's today and passed, skip scheduling for today
        continue;
      }

      const androidDetails = AndroidNotificationDetails(
        'tithi_shloka',
        'Daily Shloka',
        channelDescription: 'Spiritual verses and quotes',
        icon: '@mipmap/launcher_icon',
        largeIcon: DrawableResourceAndroidBitmap('@mipmap/launcher_icon'),
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _notifications.zonedSchedule(
        _shlokaNotificationIdBase + i,
        'Daily Wisdom',
        '"${shlokas[i].text}"\n\n${shlokas[i].translation}',
        scheduledDate,
        notificationDetails,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    }

    if (kDebugMode) {
      print('Scheduled upcoming Shloka notifications');
    }
  }

  /// Check if festival reminders are enabled.
  Future<bool> isFestivalEnabled() async {
    _ensureInitialized();
    return _box?.get(_keyFestivalEnabled, defaultValue: false) ?? false;
  }

  /// Get festival reminder timing as a [FestivalReminderTiming] index
  /// (0 = on the day, 1 = one day before, 2 = both). Defaults to on-day.
  Future<int> getFestivalTiming() async {
    _ensureInitialized();
    final timing =
        (_box?.get(_keyFestivalTiming, defaultValue: 0) as int?) ?? 0;
    if (timing < 0 || timing > FestivalReminderTiming.values.length - 1) {
      return 0;
    }
    return timing;
  }

  /// Enable or disable festival reminders.
  ///
  /// Independent of the daily master switch so users can opt into
  /// festival-only notifications. Like [setShlokaEnabled], the persisted
  /// flag is rolled back if scheduling fails.
  Future<void> setFestivalEnabled(bool enabled) async {
    _ensureInitialized();
    final previous =
        _box?.get(_keyFestivalEnabled, defaultValue: false) as bool? ?? false;
    await _box?.put(_keyFestivalEnabled, enabled);

    try {
      if (enabled) {
        await _assertSystemNotificationsAllowed();
        await _scheduleUpcomingFestivals();
      } else {
        await cancelFestivalNotifications();
      }
    } catch (e) {
      try {
        await _box?.put(_keyFestivalEnabled, previous);
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
        (_box?.get(_keyFestivalTiming, defaultValue: 0) as int?) ?? 0;
    await _box?.put(_keyFestivalTiming, timing);

    try {
      final enabled =
          _box?.get(_keyFestivalEnabled, defaultValue: false) ?? false;
      if (enabled) {
        await _scheduleUpcomingFestivals();
      }
    } catch (e) {
      try {
        await _box?.put(_keyFestivalTiming, previous);
      } catch (rollbackError) {
        debugPrint('Failed to roll back festival timing: $rollbackError');
      }
      debugPrint('Failed to set festival timing to $timing: $e');
      rethrow;
    }
  }

  /// Cancel all festival reminder notifications.
  Future<void> cancelFestivalNotifications() async {
    // IDs [_festivalNotificationIdBase, +_festivalWindowDays * 2):
    // two slots (on-day, day-before) per scanned day.
    for (int i = 0; i < _festivalWindowDays * 2; i++) {
      await _notifications.cancel(_festivalNotificationIdBase + i);
    }
  }

  /// Schedule reminders for festivals in the next [_festivalWindowDays] days
  /// (major preferred when several fall on one day).
  /// Day-before reminders fire at the notification time on the eve of
  /// the festival; on-day reminders fire at the notification time on the day.
  /// Past times are skipped; the 6-hourly WorkManager task re-runs this via
  /// [init], so festivals entering the window are never missed.
  Future<void> _scheduleUpcomingFestivals() async {
    _ensureInitialized();
    final enabled =
        _box?.get(_keyFestivalEnabled, defaultValue: false) ?? false;
    if (!enabled) return;

    await cancelFestivalNotifications();

    final timing = await getFestivalTiming();
    final wantOnDay = timing != FestivalReminderTiming.dayBefore.index;
    final wantDayBefore = timing != FestivalReminderTiming.onDay.index;

    final storageService = StorageService();
    final locationBox = await storageService.openLocationSettingsBox();
    final latitude =
        (locationBox.get('cached_lat', defaultValue: 28.6139) as num)
            .toDouble();
    final longitude =
        (locationBox.get('cached_lng', defaultValue: 77.2090) as num)
            .toDouble();

    final settingsBox = await storageService.openSettingsBox();
    final monthSystem = _readMonthSystem(settingsBox);
    final secondarySystem =
        (settingsBox.get('secondary_calendar_system', defaultValue: 2)
                as int?) ??
            2;
    final yearEraIndex =
        (settingsBox.get('hindu_year_era', defaultValue: 1) as int?) ?? 1;
    final tithiMode =
        (settingsBox.get('tithi_display_mode', defaultValue: 1) as int?) ?? 1;

    final service = PanchangService();
    await service.init();
    final festivals = await _loadFestivalsForNotification();
    if (festivals.isEmpty) return;

    final time = await getNotificationTime();
    final now = tz.TZDateTime.now(tz.local);
    final today = DateTime(now.year, now.month, now.day);

    const androidDetails = AndroidNotificationDetails(
      'tithi_festival',
      'Festival Reminders',
      channelDescription: 'Reminders for upcoming festivals',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/launcher_icon',
      largeIcon: DrawableResourceAndroidBitmap('@mipmap/launcher_icon'),
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    for (int i = 0; i < _festivalWindowDays; i++) {
      final date = today.add(Duration(days: i));
      final sunrise = SunriseCalculator.calculateSunriseIST(
        date: date,
        latitude: latitude,
        longitude: longitude,
      );
      final panchang = await _computePanchangForDate(
        date: date,
        service: service,
        latitude: latitude,
        longitude: longitude,
        festivals: festivals,
        monthSystem: monthSystem,
        sunriseTime: sunrise,
      );
      if (!panchang.hasFestivals) continue;
      // Major festivals first so the title names the most significant one.
      final festival = panchang.majorFestivals.isNotEmpty
          ? panchang.majorFestivals.first
          : panchang.festivals.first;

      final displayMasa = displayMasaName(
        panchang.masa,
        panchang.paksha,
        monthSystem,
      ).replaceAll('_', ' ');
      final hinduDay =
          tithiMode == 0 ? panchang.tithiNumber : panchang.tithiIndex;
      final tithiIdentity =
          '${panchang.paksha} ${panchang.tithiName} – $displayMasa';
      final gregorianLine = DateFormat('EEEE, d MMMM yyyy').format(date);
      final secondaryLine = _secondaryCalendarLine(
        secondarySystem: secondarySystem,
        date: date,
        displayMasa: displayMasa,
        rawMasa: panchang.masa,
        yearEraIndex: yearEraIndex,
        hinduDay: hinduDay,
      );
      final dateLines = secondaryLine == null
          ? gregorianLine
          : '$gregorianLine\n$secondaryLine';

      if (wantOnDay) {
        final onDay = tz.TZDateTime(
          tz.local,
          date.year,
          date.month,
          date.day,
          time.hour,
          time.minute,
        );
        if (!onDay.isBefore(now)) {
          await _notifications.zonedSchedule(
            _festivalNotificationIdBase + i * 2,
            festival.name,
            'Today • $tithiIdentity\n$dateLines',
            onDay,
            notificationDetails,
            androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          );
        }
      }
      if (wantDayBefore) {
        final eve = tz.TZDateTime(
          tz.local,
          date.year,
          date.month,
          date.day,
          time.hour,
          time.minute,
        ).subtract(const Duration(days: 1));
        if (!eve.isBefore(now)) {
          await _notifications.zonedSchedule(
            _festivalNotificationIdBase + i * 2 + 1,
            festival.name,
            'Tomorrow • $tithiIdentity\n$dateLines',
            eve,
            notificationDetails,
            androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          );
        }
      }
    }

    if (kDebugMode) {
      print('Scheduled upcoming festival notifications');
    }
  }

  /// Read the Hindu month system from a settings box (safe default).
  HinduMonthSystem _readMonthSystem(Box<dynamic> settingsBox) {
    final index =
        (settingsBox.get(
                  'hindu_month_system',
                  defaultValue: HinduMonthSystem.amanta.index,
                )
                as int?) ??
            HinduMonthSystem.amanta.index;
    if (index >= 0 && index < HinduMonthSystem.values.length) {
      return HinduMonthSystem.values[index];
    }
    return HinduMonthSystem.amanta;
  }

  /// Request notification permission.
  ///
  /// Returns true when notifications may be scheduled. Never throws: plugin
  /// errors (e.g. MissingPluginException on platforms without a registered
  /// implementation) fail closed with a log so the settings toggle can show
  /// the "permission denied" message instead of snapping back silently.
  Future<bool> requestPermission() async {
    try {
      final android = _notifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (android != null) {
        final granted = await android.requestNotificationsPermission();
        return granted ?? false;
      }

      final ios = _notifications
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      if (ios != null) {
        final granted = await ios.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
        return granted ?? false;
      }

      final macos = _notifications
          .resolvePlatformSpecificImplementation<
            MacOSFlutterLocalNotificationsPlugin
          >();
      if (macos != null) {
        final granted = await macos.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
        return granted ?? false;
      }

      // No runtime permission model (e.g. Windows/Linux/web).
      return true;
    } catch (e) {
      debugPrint('Notification permission request failed: $e');
      return false;
    }
  }

  /// Throws a descriptive [StateError] when the OS currently blocks this
  /// app's notifications (e.g. the user revoked permission in system
  /// settings after granting it). Scheduling APIs "succeed" silently in
  /// that state, so enable paths must check first instead of leaving the
  /// toggle ON while nothing can ever fire.
  ///
  /// Fail-open when the check itself is unavailable (unknown platform or
  /// plugin error): the schedule attempt will surface real failures.
  Future<void> _assertSystemNotificationsAllowed() async {
    try {
      final android = _notifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (android != null) {
        final enabled = await android.areNotificationsEnabled();
        if (enabled == false) {
          throw StateError(
            'Notifications are disabled for Tithi in system settings',
          );
        }
        return;
      }

      final ios = _notifications
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      if (ios != null) {
        final status = await ios.checkPermissions();
        if (status != null && !status.isEnabled) {
          throw StateError(
            'Notifications are disabled for Tithi in system settings',
          );
        }
        return;
      }

      final macos = _notifications
          .resolvePlatformSpecificImplementation<
            MacOSFlutterLocalNotificationsPlugin
          >();
      if (macos != null) {
        final status = await macos.checkPermissions();
        if (status != null && !status.isEnabled) {
          throw StateError(
            'Notifications are disabled for Tithi in system settings',
          );
        }
        return;
      }
      // No OS-level gate to check (Windows/Linux/web).
    } on StateError {
      rethrow;
    } catch (e) {
      debugPrint('System notification check unavailable, proceeding: $e');
    }
  }

  /// Schedule daily notification
  Future<void> scheduleDailyNotification({String? title, String? body}) async {
    _ensureInitialized();

    // Cancel existing notification first
    await _notifications.cancel(_dailyNotificationId);

    final time = await getNotificationTime();

    // Calculate next notification time
    final now = tz.TZDateTime.now(tz.local);
    var scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      time.hour,
      time.minute,
    );

    // If time has passed today, schedule for tomorrow
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    const androidDetails = AndroidNotificationDetails(
      'tithi_daily',
      'Daily Tithi',
      channelDescription: 'Daily tithi and panchang notifications',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/launcher_icon',
      largeIcon: DrawableResourceAndroidBitmap('@mipmap/launcher_icon'),
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    final content = await _getDailyNotificationContent();
    final resolvedTitle = title ?? content.title;
    final resolvedBody = body ?? content.body;

    await _notifications.zonedSchedule(
      _dailyNotificationId,
      resolvedTitle,
      resolvedBody,
      scheduledDate,
      notificationDetails,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time, // Repeat daily
    );

    if (kDebugMode) {
      print('Scheduled daily notification for ${time.hour}:${time.minute}');
    }
  }

  Future<void> _refreshDailyNotificationContent() async {
    final generated = await _buildDailyNotificationContent();
    await _box?.put(_keyDailyTitle, generated.title);
    await _box?.put(_keyDailyBody, generated.body);
    await _box?.put(_keyDailyContentDate, _dateKey(DateTime.now()));
  }

  Future<({String title, String body})> _getDailyNotificationContent() async {
    final todayKey = _dateKey(DateTime.now());
    final cachedDate = _box?.get(_keyDailyContentDate) as String?;
    final cachedTitle = _box?.get(_keyDailyTitle) as String?;
    final cachedBody = _box?.get(_keyDailyBody) as String?;

    if (cachedDate == todayKey && cachedTitle != null && cachedBody != null) {
      return (title: cachedTitle, body: cachedBody);
    }

    await _refreshDailyNotificationContent();
    return (
      title: (_box?.get(_keyDailyTitle) as String?) ?? '🙏 Tithi Today',
      body:
          (_box?.get(_keyDailyBody) as String?) ??
          'Open to see today\'s panchang details',
    );
  }

  /// Full panchang for [date] with the same intraday checkpoints the app UI
  /// uses, so festival matching (timingOverride, Kshaya) agrees with what
  /// the user sees. Shared by the daily content and the festival scanner.
  Future<PanchangData> _computePanchangForDate({
    required DateTime date,
    required PanchangService service,
    required double latitude,
    required double longitude,
    required List<Festival> festivals,
    required HinduMonthSystem monthSystem,
    required DateTime sunriseTime,
  }) async {
    final sunsetTime = SunriseCalculator.calculateSunsetIST(
      date: date,
      latitude: latitude,
      longitude: longitude,
    );
    final nextSunriseTime = SunriseCalculator.calculateSunriseIST(
      date: date.add(const Duration(days: 1)),
      latitude: latitude,
      longitude: longitude,
    );

    final rawTithi = await service.calculateTithi(
      sunriseTime,
      latitude: latitude,
      longitude: longitude,
    );
    final masa = await service.calculateMasa(
      sunriseTime,
      rawTithi,
      latitude: latitude,
      longitude: longitude,
    );
    // Intraday checkpoints so timingOverride festivals (madhyahna,
    // aparahna, nishita) and Kshaya tithis match the app UI.
    final rawTithiMadhyahna = await service.calculateTithi(
      sunriseTime.add(
        Duration(minutes: sunsetTime.difference(sunriseTime).inMinutes ~/ 2),
      ),
      latitude: latitude,
      longitude: longitude,
    );
    final rawTithiAparahna = await service.calculateTithi(
      sunriseTime.add(
        Duration(
          minutes: sunsetTime.difference(sunriseTime).inMinutes * 3 ~/ 4,
        ),
      ),
      latitude: latitude,
      longitude: longitude,
    );
    final rawTithiNishita = await service.calculateTithi(
      sunsetTime.add(
        Duration(
          minutes: nextSunriseTime.difference(sunsetTime).inMinutes ~/ 2,
        ),
      ),
      latitude: latitude,
      longitude: longitude,
    );
    final rawTithiNextSunrise = await service.calculateTithi(
      nextSunriseTime,
      latitude: latitude,
      longitude: longitude,
    );
    final masaNextSunrise = await service.calculateMasa(
      nextSunriseTime,
      rawTithiNextSunrise,
      latitude: latitude,
      longitude: longitude,
    );

    return PanchangData.fromRawTithi(
      date: date,
      rawTithi: rawTithi,
      masa: masa,
      allFestivals: festivals,
      monthSystem: monthSystem,
      sunrise: sunriseTime,
      sunset: sunsetTime,
      rawTithiMadhyahna: rawTithiMadhyahna,
      rawTithiAparahna: rawTithiAparahna,
      rawTithiNishita: rawTithiNishita,
      rawTithiNextSunrise: rawTithiNextSunrise,
      masaNextSunrise: masaNextSunrise,
    );
  }

  Future<({String title, String body})> _buildDailyNotificationContent() async {
    try {
      final storageService = StorageService();
      final locationBox = await storageService.openLocationSettingsBox();
      final latitude =
          (locationBox.get('cached_lat', defaultValue: 28.6139) as num)
              .toDouble();
      final longitude =
          (locationBox.get('cached_lng', defaultValue: 77.2090) as num)
              .toDouble();

      final settingsBox = await storageService.openSettingsBox();
      final monthSystemIndex =
          (settingsBox.get(
                'hindu_month_system',
                defaultValue: HinduMonthSystem.amanta.index,
              )
              as int);
      final monthSystem =
          (monthSystemIndex >= 0 &&
              monthSystemIndex < HinduMonthSystem.values.length)
          ? HinduMonthSystem.values[monthSystemIndex]
          : HinduMonthSystem.amanta;

      final service = PanchangService();
      await service.init();

      final today = DateTime.now();
      final date = DateTime(today.year, today.month, today.day);

      final sunriseTime = SunriseCalculator.calculateSunriseIST(
        date: date,
        latitude: latitude,
        longitude: longitude,
      );

      final panchang = await _computePanchangForDate(
        date: date,
        service: service,
        latitude: latitude,
        longitude: longitude,
        festivals: await _loadFestivalsForNotification(),
        monthSystem: monthSystem,
        sunriseTime: sunriseTime,
      );
      // Display the masa in the user's selected month system (Purnimant
      // Krishna days carry the next month's name; Shukla is identical).
      final displayMasa = displayMasaName(
        panchang.masa,
        panchang.paksha,
        monthSystem,
      ).replaceAll('_', ' ');

      // Secondary calendar line, respecting the user's
      // secondary_calendar_system setting (default Hindu).
      // Indices mirror AppCalendarSystem: 0=none, 1=gregorian, 2=hindu,
      // 3=bengali. Raw ints (not the enum) keep this background-isolate
      // safe with no Riverpod dependency.
      final secondarySystem =
          (settingsBox.get('secondary_calendar_system', defaultValue: 2)
                  as int?) ??
              2;
      final yearEraIndex =
          (settingsBox.get('hindu_year_era', defaultValue: 1) as int?) ?? 1;
      // TithiDisplayMode: 0=pakshaBased (1-15), 1=continuous30 (1-30).
      final tithiMode =
          (settingsBox.get('tithi_display_mode', defaultValue: 1) as int?) ??
              1;
      final hinduDay =
          tithiMode == 0 ? panchang.tithiNumber : panchang.tithiIndex;

      final gregorianLine =
          DateFormat('EEEE, d MMMM yyyy').format(date);
      final secondaryLine = _secondaryCalendarLine(
        secondarySystem: secondarySystem,
        date: date,
        displayMasa: displayMasa,
        rawMasa: panchang.masa,
        yearEraIndex: yearEraIndex,
        hinduDay: hinduDay,
      );

      // First line is the festival name when one falls today (major
      // preferred, else first), matching the home screen. Otherwise the
      // tithi identity.
      final tithiIdentity =
          '${panchang.paksha} ${panchang.tithiName} – $displayMasa';
      if (panchang.hasFestivals) {
        final festival = panchang.majorFestivals.isNotEmpty
            ? panchang.majorFestivals.first
            : panchang.festivals.first;
        final dateLines = secondaryLine == null
            ? gregorianLine
            : '$gregorianLine\n$secondaryLine';
        return (
          title: festival.name,
          body: '$tithiIdentity\n$dateLines',
        );
      }

      return (
        title: tithiIdentity,
        body: secondaryLine == null
            ? gregorianLine
            : '$gregorianLine\n$secondaryLine',
      );
    } catch (e, stack) {
      // BUG-MEDIUM-7: Surface the error instead of swallowing it silently.
      debugPrint('Failed to build notification content: $e\n$stack');
      return (
        title: '🙏 Tithi Today',
        body: 'Open to see today\'s panchang details',
      );
    }
  }

  /// Festivals for notification matching, loaded directly from Hive so this
  /// works in the WorkManager background isolate (no Riverpod).
  /// Returns empty on any failure so the notification falls back to tithi.
  Future<List<Festival>> _loadFestivalsForNotification() async {
    try {
      // TypeAdapters are registered in main(); the background isolate needs
      // its own registration before opening the typed box.
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
      final box = await StorageService().openFestivalsBox();
      if (box.isEmpty) return const [];
      return List<Festival>.unmodifiable(box.values);
    } catch (e) {
      debugPrint('Failed to load festivals for notification: $e');
      return const [];
    }
  }

  /// Secondary-calendar detail line for the daily notification body.
  ///
  /// Returns null when there is nothing distinct to add (none/gregorian,
  /// since Gregorian is already the first body line). Hindu secondary is a
  /// full date (`Masa day, year`, e.g. `Shravana 22, 1948`); Bengali adds
  /// the full Bengali date via a background-safe solar approximation.
  String? _secondaryCalendarLine({
    required int secondarySystem,
    required DateTime date,
    required String displayMasa,
    required String rawMasa,
    required int yearEraIndex,
    required int hinduDay,
  }) {
    switch (secondarySystem) {
      case 2: // Hindu
        // Year boundary uses the raw Amanta masa (same as
        // HinduCalendarService.vikramSamvatYear); display uses the
        // month-system-converted name.
        final vsYear = _vikramSamvatYear(
          gregorianYear: date.year,
          gregorianMonth: date.month,
          masa: rawMasa,
        );
        // yearEraIndex mirrors HinduYearEra: 0=vikramSamvat, 1=shakaSamvat.
        if (yearEraIndex == 0) {
          return '$displayMasa $hinduDay, Vikram $vsYear';
        }
        return '$displayMasa $hinduDay, Shaka ${vsYear - 135}';
      case 3: // Bengali
        final bengali = _approxBengaliDate(date);
        return '${bengali.month} ${bengali.day}, ${bengali.year}';
      case 0: // none
      case 1: // gregorian (already shown)
      default:
        return null;
    }
  }

  /// Year boundary: +57 on/after Chaitra (new year), +56 before it.
  /// Mirrors HinduCalendarService.vikramSamvatYear without a Ref.
  int _vikramSamvatYear({
    required int gregorianYear,
    required int gregorianMonth,
    required String masa,
  }) {
    if (gregorianMonth < 3) return gregorianYear + 56;
    if (gregorianMonth > 4) return gregorianYear + 57;
    final base = _baseMasaName(masa);
    if (base == 'Chaitra' || base == 'Vaishakha' || base == 'Jyeshtha') {
      return gregorianYear + 57;
    }
    return gregorianYear + 56;
  }

  String _baseMasaName(String masa) {
    if (masa.startsWith('Adhika_')) return masa.substring(7);
    if (masa.startsWith('Nija_')) return masa.substring(5);
    return masa;
  }

  /// Solar approximation of the Bengali date (Pohela Boishakh = Apr 14).
  /// Same table as the web Bengali service; avoids FFI/Ref in the
  /// background isolate where notifications are built.
  ({int day, String month, int year}) _approxBengaliDate(DateTime date) {
    // Guide Sec 3.1 spellings; shared with the web/native services.
    const months = kBengaliMonths;
    int bengaliYear = date.year - 593;
    if (date.month < 4 || (date.month == 4 && date.day < 14)) {
      bengaliYear--;
    }
    final starts = [
      DateTime(date.year, 4, 14),
      DateTime(date.year, 5, 15),
      DateTime(date.year, 6, 15),
      DateTime(date.year, 7, 16),
      DateTime(date.year, 8, 16),
      DateTime(date.year, 9, 16),
      DateTime(date.year, 10, 17),
      DateTime(date.year, 11, 16),
      DateTime(date.year, 12, 16),
      DateTime(date.year + 1, 1, 14),
      DateTime(date.year + 1, 2, 13),
      DateTime(date.year + 1, 3, 15),
    ];
    int monthIndex = 11;
    int day = date.difference(starts[11]).inDays + 1;
    for (int i = 0; i < starts.length; i++) {
      if (date.isBefore(starts[i])) {
        monthIndex = i == 0 ? 11 : i - 1;
        final prevStart = i == 0
            ? DateTime(date.year - 1, 3, 15)
            : starts[i - 1];
        day = date.difference(prevStart).inDays + 1;
        break;
      }
      if (i == starts.length - 1) {
        monthIndex = 11;
        day = date.difference(starts[11]).inDays + 1;
      }
    }
    if (day < 1) day = 1;
    if (day > 32) day = 1;
    return (day: day, month: months[monthIndex], year: bengaliYear);
  }

  // SMELL-01: delegate to shared panchangDateKey utility
  String _dateKey(DateTime date) => panchangDateKey(date);

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

  Future<void> showTestNotification({
    required String title,
    required String body,
  }) async {
    _ensureInitialized();

    const androidDetails = AndroidNotificationDetails(
      'tithi_daily',
      'Daily Tithi',
      channelDescription: 'Daily tithi and panchang notifications',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/launcher_icon',
      largeIcon: DrawableResourceAndroidBitmap('@mipmap/launcher_icon'),
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(0, title, body, notificationDetails);

    if (kDebugMode) {
      print('Showed test notification: $title');
    }
  }

  /// Cancel all notifications
  Future<void> cancelAllNotifications() async {
    await _notifications.cancelAll();
    if (kDebugMode) {
      print('Cancelled all notifications');
    }
  }

  /// Returns a stable, collision-free notification ID for the given sankalpa.
  /// IDs are persisted in the notification Hive box so they survive restarts.
  int _getOrCreateSankalpaNotificationId(String sankalpaId) {
    final mapKey = '$_keySankalpaIdPrefix$sankalpaId';
    final existing = _box?.get(mapKey) as int?;
    if (existing != null) return existing;

    // Allocate next sequential ID.
    final counter =
        (_box?.get(_keySankalpaIdCounter, defaultValue: 0) as int?) ?? 0;
    final newId = _sankalpaNotificationIdBase + counter;
    _box?.put(_keySankalpaIdCounter, counter + 1);
    _box?.put(mapKey, newId);
    return newId;
  }

  /// Schedule a specific sankalpa reminder
  Future<void> scheduleSankalpaReminder(Sankalpa sankalpa) async {
    _ensureInitialized();
    if (sankalpa.isCompleted) return;

    // Use a persisted counter to guarantee unique IDs (replaces hashCode % 10000
    // which had collision risk after ~125 sankalpas).
    final notificationId = _getOrCreateSankalpaNotificationId(sankalpa.id);

    final now = tz.TZDateTime.now(tz.local);
    var scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      sankalpa.reminderHour,
      sankalpa.reminderMinute,
    );

    // If time passed, start tomorrow
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    // Check if end date passed (if we used strict date checking)
    // For now, assume if not completed, keep reminding until duration ends + user marks complete
    // Actually, if we have duration, we should check if today + days remaining is valid.

    // Sankalpa model logic: it has endDate.
    if (scheduledDate.isAfter(
      tz.TZDateTime.from(
        sankalpa.endDate,
        tz.local,
      ).add(const Duration(days: 1)),
    )) {
      // Allow one day grace or stop exactly? Let's stop if past end date.
      return;
    }

    const androidDetails = AndroidNotificationDetails(
      'tithi_sankalpa',
      'Sankalpa Reminders',
      channelDescription: 'Daily reminders for your intentions',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/launcher_icon',
      largeIcon: DrawableResourceAndroidBitmap('@mipmap/launcher_icon'),
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.zonedSchedule(
      notificationId,
      'Sankalpa Reminder',
      sankalpa.title,
      scheduledDate,
      notificationDetails,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time, // Repeat daily
      payload: 'sankalpa:${sankalpa.id}',
    );

    if (kDebugMode) {
      print(
        'Scheduled sankalpa: ${sankalpa.title} at ${sankalpa.reminderHour}:${sankalpa.reminderMinute}',
      );
    }
  }

  /// Cancel a sankalpa reminder
  Future<void> cancelSankalpaReminder(String id) async {
    final notificationId = _getOrCreateSankalpaNotificationId(id);
    await _notifications.cancel(notificationId);
    if (kDebugMode) {
      print('Cancelled sankalpa notification: $id (ID: $notificationId)');
    }
  }

  /// Cancel all sankalpa reminders (cleanup)
  Future<void> cancelAllSankalpaReminders(List<String> sankalpaIds) async {
    for (final id in sankalpaIds) {
      await cancelSankalpaReminder(id);
    }
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
