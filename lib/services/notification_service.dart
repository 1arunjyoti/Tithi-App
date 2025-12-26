import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:hive/hive.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;

/// Notification service for scheduling daily tithi notifications
/// FOSS-compatible: Uses native Android NotificationCompat, no Google Play Services
class NotificationService {
  static const String _boxName = 'notification_settings';
  static const String _keyEnabled = 'notifications_enabled';
  static const String _keyHour = 'notification_hour';
  static const String _keyMinute = 'notification_minute';
  static const int _dailyNotificationId = 1;

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  Box? _box;
  bool _isInitialized = false;

  /// Initialize the notification service
  Future<void> init() async {
    if (_isInitialized) return;

    try {
      // Initialize timezone
      tz_data.initializeTimeZones();
      tz.setLocalLocation(tz.getLocation('Asia/Kolkata'));

      // Initialize Hive box
      _box = await Hive.openBox(_boxName);

      // Initialize notifications
      const androidSettings = AndroidInitializationSettings(
        '@mipmap/ic_launcher',
      );
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
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

      if (kDebugMode) {
        print('NotificationService initialized');
      }

      // Reschedule if enabled
      if (await isEnabled()) {
        await scheduleDailyNotification();
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

  /// Set notification time
  Future<void> setNotificationTime(int hour, int minute) async {
    _ensureInitialized();
    await _box?.put(_keyHour, hour);
    await _box?.put(_keyMinute, minute);

    // Reschedule with new time
    if (await isEnabled()) {
      await scheduleDailyNotification();
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
      styleInformation: BigTextStyleInformation(''),
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
      _dailyNotificationId,
      title ?? '🙏 Tithi Today',
      body ?? 'Open to see today\'s panchang details',
      scheduledDate,
      notificationDetails,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time, // Repeat daily
    );

    if (kDebugMode) {
      print('Scheduled daily notification for ${time.hour}:${time.minute}');
    }
  }

  /// Show immediate notification (for testing)
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

  void _ensureInitialized() {
    if (!_isInitialized) {
      throw Exception(
        'NotificationService not initialized. Call init() first.',
      );
    }
  }
}
