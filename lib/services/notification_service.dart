import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:workmanager/workmanager.dart';
import '../utils/date_utils.dart';
import 'shloka_service.dart';
import '../models/sankalpa.dart';
import '../models/hindu_month_system.dart';
import '../models/panchang_data.dart';
import 'panchang_service.dart';
import 'storage_service.dart';
import 'sunrise_calculator.dart';

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
  static const String _keyDailyTitle = 'daily_title';
  static const String _keyDailyBody = 'daily_body';
  static const String _keyDailyContentDate = 'daily_content_date';
  static const int _dailyNotificationId = 1;
  static const int _shlokaNotificationIdBase = 1000;

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
      tz.setLocalLocation(tz.getLocation(deviceTimeZone));

      // Initialize Hive box
      _box = await StorageService().openNotificationSettingsBox();

      // Initialize notifications
      const androidSettings = AndroidInitializationSettings(
        '@mipmap/ic_launcher',
      );
      const iosSettings = DarwinInitializationSettings();

      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      await _notifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
      );

      _isInitialized = true;

      // Precompute/cache daily notification content so background scheduling
      // can function even without full app/provider context.
      await _refreshDailyNotificationContent();

      // SMELL-2: read flags directly from the box (synchronous Hive get) instead
      // of calling await isEnabled() / await isShlokaEnabled(), which wrap the
      // same synchronous read in an unnecessary Future.
      final notificationsEnabled =
          _box?.get(_keyEnabled, defaultValue: false) ?? false;
      final shlokasEnabled =
          _box?.get(_keyShlokaEnabled, defaultValue: false) ?? false;

      if (kDebugMode) {
        if (notificationsEnabled) {
          print(
            'NotificationService ready - notifications ON${shlokasEnabled ? ', shloka ON' : ''}',
          );
        } else {
          print(
            'NotificationService ready - notifications OFF (nothing scheduled)',
          );
        }
      }

      // Only schedule if enabled
      if (notificationsEnabled) {
        await scheduleDailyNotification();
        if (shlokasEnabled) {
          await _scheduleUpcomingShlokas();
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

  /// Enable or disable notifications
  Future<void> setEnabled(bool enabled) async {
    _ensureInitialized();
    await _box?.put(_keyEnabled, enabled);

    if (enabled) {
      await scheduleDailyNotification();
    } else {
      await cancelAllNotifications();
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
  Future<void> setNotificationTime(int hour, int minute) async {
    _ensureInitialized();
    await _box?.put(_keyHour, hour);
    await _box?.put(_keyMinute, minute);

    // Read flags directly from the box — same synchronous Hive get as isEnabled()
    final enabled = _box?.get(_keyEnabled, defaultValue: false) ?? false;
    if (enabled) {
      await scheduleDailyNotification();
      final shlokaEnabled =
          _box?.get(_keyShlokaEnabled, defaultValue: false) ?? false;
      if (shlokaEnabled) {
        await _scheduleUpcomingShlokas();
      }
    }
  }

  /// Check if Shloka notifications are enabled
  Future<bool> isShlokaEnabled() async {
    _ensureInitialized();
    return _box?.get(_keyShlokaEnabled, defaultValue: false) ?? false;
  }

  /// Enable or disable Shloka notifications
  Future<void> setShlokaEnabled(bool enabled) async {
    _ensureInitialized();
    await _box?.put(_keyShlokaEnabled, enabled);

    // SMELL-2: read main-enabled flag directly from the box.
    final mainEnabled = _box?.get(_keyEnabled, defaultValue: false) ?? false;
    if (enabled && mainEnabled) {
      // Only schedule if main notifications are also enabled
      await _scheduleUpcomingShlokas();
    } else if (!enabled) {
      await cancelShlokaNotifications();
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
    // SMELL-2: read flags directly from the box instead of async isEnabled() calls.
    final enabled = _box?.get(_keyEnabled, defaultValue: false) ?? false;
    final shlokaEnabled =
        _box?.get(_keyShlokaEnabled, defaultValue: false) ?? false;
    if (!enabled || !shlokaEnabled) return;

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
        icon: '@mipmap/ic_launcher',
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

  /// Request notification permission (Android 13+)
  Future<bool> requestPermission() async {
    final android = _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    if (android != null) {
      final granted = await android.requestNotificationsPermission();
      return granted ?? false;
    }

    return true;
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
      icon: '@mipmap/ic_launcher',
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

      final panchang = PanchangData.fromRawTithi(
        date: date,
        rawTithi: rawTithi,
        masa: masa,
        monthSystem: monthSystem,
        sunrise: sunriseTime,
        sunset: SunriseCalculator.calculateSunsetIST(
          date: date,
          latitude: latitude,
          longitude: longitude,
        ),
      );

      return (
        title: '🙏 ${panchang.tithiName}',
        body: '${panchang.paksha} • ${panchang.tithiNumber} (${panchang.masa})',
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

  // SMELL-01: delegate to shared panchangDateKey utility
  String _dateKey(DateTime date) => panchangDateKey(date);

  /// BUG-07: Returns the device's IANA timezone name using flutter_timezone.
  /// Falls back to 'Asia/Kolkata' (app's primary audience) if unavailable.
  Future<String> _getDeviceTimezone() async {
    try {
      final timezoneInfo = await FlutterTimezone.getLocalTimezone();
      return timezoneInfo;
    } catch (e) {
      debugPrint(
        'flutter_timezone unavailable, defaulting to Asia/Kolkata: $e',
      );
      return 'Asia/Kolkata';
    }
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
      icon: '@mipmap/ic_launcher',
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
      icon: '@mipmap/ic_launcher',
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
