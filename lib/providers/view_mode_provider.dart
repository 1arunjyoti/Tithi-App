import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/storage_service.dart';

/// View mode for the home screen
enum HomeViewMode { calendar, schedule }

/// Notifier for Home View Mode preference with Hive persistence
class HomeViewModeNotifier extends Notifier<HomeViewMode> {
  static const _key = 'home_view_mode';

  @override
  HomeViewMode build() {
    final box = StorageService().getSettingsBox();
    final index = box.get(_key, defaultValue: 0) as int;
    if (index >= 0 && index < HomeViewMode.values.length) {
      return HomeViewMode.values[index];
    }
    return HomeViewMode.calendar;
  }

  Future<void> setViewMode(HomeViewMode mode) async {
    final box = StorageService().getSettingsBox();
    await box.put(_key, mode.index);
    state = mode;
  }

  /// Toggle between calendar and schedule view
  Future<void> toggle() async {
    final newMode = state == HomeViewMode.calendar
        ? HomeViewMode.schedule
        : HomeViewMode.calendar;
    await setViewMode(newMode);
  }
}

final homeViewModeProvider =
    NotifierProvider<HomeViewModeNotifier, HomeViewMode>(
      () => HomeViewModeNotifier(),
    );
