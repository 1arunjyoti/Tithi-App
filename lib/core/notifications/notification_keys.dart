// Phase 4: notification Hive keys + ID ranges extracted from
// services/notification_service.dart. Single source of truth so the UI
// isolate and the Workmanager background isolate can never disagree on
// keys or ID ranges (previously BUG-3 class of collision).

/// When festival reminders fire. Stored as the enum index under
/// [NotificationKeys.festivalTiming] (`festival_timing`).
/// (Moved here in Phase 6b so the scheduler can use it without importing
/// the singleton service.)
enum FestivalReminderTiming {
  /// Morning of the festival, at the notification time.
  onDay,

  /// At the notification time on the eve of the festival.
  dayBefore,

  /// Both eve and day-of reminders.
  both,
}

abstract final class NotificationKeys {
  static const String taskName = 'periodic_notification_check';

  static const String enabled = 'notifications_enabled';
  static const String hour = 'notification_hour';
  static const String minute = 'notification_minute';
  static const String shlokaEnabled = 'shloka_enabled';
  static const String festivalEnabled = 'festival_enabled';

  /// Stores [FestivalReminderTiming] as its enum index.
  static const String festivalTiming = 'festival_timing';

  static const String dailyTitle = 'daily_title';
  static const String dailyBody = 'daily_body';
  static const String dailyContentDate = 'daily_content_date';

  static const int dailyNotificationId = 1;
  static const int shlokaNotificationIdBase = 1000;
  static const int festivalNotificationIdBase = 2000;
  static const int festivalWindowDays = 8;

  // Base ID for sankalpa notifications (unique range to avoid collision).
  static const int sankalpaNotificationIdBase = 10000;

  // Hive keys for the persisted sankalpa → notification-ID mapping.
  static const String sankalpaIdCounter = '_sankalpa_nid_counter';
  static const String sankalpaIdPrefix = '_sankalpa_nid_';
}
