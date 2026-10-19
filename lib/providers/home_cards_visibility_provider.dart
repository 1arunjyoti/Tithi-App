import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/storage_service.dart';

// Visibility of the optional home-screen cards (Daily Wisdom, Festival
// Countdowns). Same persisted-dismiss pattern as
// homeWidgetPromoDismissedProvider: Hive-backed so a hidden card stays
// hidden across restarts, defaulting to visible. Hidden cards are skipped
// entirely by the home SliverList (no sliver, no gap, no fetch); Settings
// offers both switches back.

/// Daily Wisdom card visible on home.
final dailyWisdomVisibleProvider =
    NotifierProvider<DailyWisdomVisibleNotifier, bool>(
      DailyWisdomVisibleNotifier.new,
    );

class DailyWisdomVisibleNotifier extends Notifier<bool> {
  static const _key = 'home_card_daily_wisdom_visible';

  @override
  bool build() {
    try {
      return StorageService().getSettingsBox().get(_key, defaultValue: true)
          as bool;
    } catch (_) {
      return true;
    }
  }

  Future<void> setVisible(bool visible) async {
    state = visible;
    try {
      await StorageService().getSettingsBox().put(_key, visible);
    } catch (_) {
      // State already updated for this session.
    }
  }
}

/// Festival Countdowns card visible on home.
final festivalCountdownsVisibleProvider =
    NotifierProvider<FestivalCountdownsVisibleNotifier, bool>(
      FestivalCountdownsVisibleNotifier.new,
    );

class FestivalCountdownsVisibleNotifier extends Notifier<bool> {
  static const _key = 'home_card_festival_countdowns_visible';

  @override
  bool build() {
    try {
      return StorageService().getSettingsBox().get(_key, defaultValue: true)
          as bool;
    } catch (_) {
      return true;
    }
  }

  Future<void> setVisible(bool visible) async {
    state = visible;
    try {
      await StorageService().getSettingsBox().put(_key, visible);
    } catch (_) {
      // State already updated for this session.
    }
  }
}
