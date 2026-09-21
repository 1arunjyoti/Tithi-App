/// Canonical Hive box names (Phase 1 core extraction).
///
/// Single source of truth for box names. [StorageService] re-exports these
/// via its existing `*BoxName` constants so call-sites keep working while
/// new code imports from here (`core/storage` owns persistence identity).
abstract final class BoxNames {
  static const String settings = 'settings';
  static const String locationSettings = 'location_settings';
  static const String notificationSettings = 'notification_settings';
  static const String ritualCompletion = 'ritual_completion';
  static const String sankalpas = 'sankalpas';
  static const String festivalSettings = 'festival_settings';
  static const String festivals = 'festivals';
  static const String panchangCache = 'panchang_cache';
}
