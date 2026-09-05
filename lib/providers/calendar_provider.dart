import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import '../models/hindu_month_system.dart';
import '../services/storage_service.dart';

/// Notifier that tracks "today's" date and is refreshed at midnight so that
/// consumers (e.g. [todayPanchangProvider]) automatically reflect the new day.
class TodayDateNotifier extends Notifier<DateTime> {
  @override
  DateTime build() => DateTime.now();

  /// Update the tracked date (called by the midnight timer in [main.dart]).
  void setToday(DateTime date) => state = date;
}

final todayDateProvider =
    NotifierProvider<TodayDateNotifier, DateTime>(TodayDateNotifier.new);

/// Provider for currently selected date in calendar
class SelectedDateNotifier extends Notifier<DateTime> {
  @override
  DateTime build() {
    return DateTime.now();
  }

  void setDate(DateTime date) {
    state = date;
  }

  void jumpToToday() {
    state = DateTime.now();
  }
}

final selectedDateProvider = NotifierProvider<SelectedDateNotifier, DateTime>(
  SelectedDateNotifier.new,
);

/// Provider for the focused month in calendar view
class FocusedMonthNotifier extends Notifier<DateTime> {
  @override
  DateTime build() {
    return DateTime.now();
  }

  void setFocusedMonth(DateTime month) {
    state = month;
  }
}

final focusedMonthProvider = NotifierProvider<FocusedMonthNotifier, DateTime>(
  FocusedMonthNotifier.new,
);

/// Month driving heavy calendar data (panchang FFI, cell labels).
/// Updated immediately on chevron taps, but debounced ~1 animation frame
/// after TableCalendar swipes so ~250 FFI calls don't run concurrently
/// with the page animation — the exact stutter when the next month
/// crosses mid-screen and the header flips.
class HeavyMonthNotifier extends Notifier<DateTime> {
  Timer? _timer;

  @override
  DateTime build() {
    // Owned here (not as a widget global) so the timer is cancelled when
    // the provider is disposed — no leaked Timer holding a stale ref.
    ref.onDispose(() => _timer?.cancel());
    return DateTime.now();
  }

  void settle(DateTime month) {
    _timer?.cancel();
    state = month;
  }

  /// Debounced settle for TableCalendar swipes: the 220ms window lets the
  /// 250ms page animation finish before ~250 FFI calls start. A newer
  /// swipe cancels the pending one, so skipped months are never computed.
  void scheduleDebounced(DateTime month) {
    _timer?.cancel();
    final target = DateTime(month.year, month.month);
    _timer = Timer(const Duration(milliseconds: 220), () {
      final current = ref.read(focusedMonthProvider);
      if (current.year != target.year || current.month != target.month) {
        return;
      }
      state = target;
    });
  }
}

final heavyFocusedMonthProvider =
    NotifierProvider<HeavyMonthNotifier, DateTime>(
      HeavyMonthNotifier.new,
    );

/// Discrete month jump (chevron, year picker, search, today button).
/// No page animation to protect, so both light (header/position) and
/// heavy (FFI data) months move together. Swipes must NOT use this —
/// they set [focusedMonthProvider] instantly and settle heavy after
/// the animation via the debounced helper in calendar_widget.dart.
void setCalendarMonth(WidgetRef ref, DateTime month) {
  ref.read(focusedMonthProvider.notifier).setFocusedMonth(month);
  ref.read(heavyFocusedMonthProvider.notifier).settle(
        DateTime(month.year, month.month),
      );
}

/// Provider for calendar format (month/week/2 weeks)
enum CalendarViewFormat { month, twoWeeks, week }

class CalendarFormatNotifier extends Notifier<CalendarViewFormat> {
  @override
  CalendarViewFormat build() {
    return CalendarViewFormat.month;
  }

  void setFormat(CalendarViewFormat format) {
    state = format;
  }
}

final calendarFormatProvider =
    NotifierProvider<CalendarFormatNotifier, CalendarViewFormat>(
      CalendarFormatNotifier.new,
    );

// --- Preference Enums ---

enum StartingDayOfWeek { sunday, monday }

enum PrimaryEventView { tithi, festival, moonPhase }

class CalendarPreferences {
  final StartingDayOfWeek startOfWeek;
  final PrimaryEventView primaryEventView;
  final AppCalendarSystem primaryCalendarSystem;
  final AppCalendarSystem secondaryCalendarSystem;
  final HinduMonthSystem hinduMonthSystem;
  final HinduYearEra hinduYearEra;
  final TithiDisplayMode tithiDisplayMode;

  const CalendarPreferences({
    required this.startOfWeek,
    required this.primaryEventView,
    required this.primaryCalendarSystem,
    required this.secondaryCalendarSystem,
    required this.hinduMonthSystem,
    required this.hinduYearEra,
    required this.tithiDisplayMode,
  });

  CalendarPreferences copyWith({
    StartingDayOfWeek? startOfWeek,
    PrimaryEventView? primaryEventView,
    AppCalendarSystem? primaryCalendarSystem,
    AppCalendarSystem? secondaryCalendarSystem,
    HinduMonthSystem? hinduMonthSystem,
    HinduYearEra? hinduYearEra,
    TithiDisplayMode? tithiDisplayMode,
  }) {
    return CalendarPreferences(
      startOfWeek: startOfWeek ?? this.startOfWeek,
      primaryEventView: primaryEventView ?? this.primaryEventView,
      primaryCalendarSystem:
          primaryCalendarSystem ?? this.primaryCalendarSystem,
      secondaryCalendarSystem:
          secondaryCalendarSystem ?? this.secondaryCalendarSystem,
      hinduMonthSystem: hinduMonthSystem ?? this.hinduMonthSystem,
      hinduYearEra: hinduYearEra ?? this.hinduYearEra,
      tithiDisplayMode: tithiDisplayMode ?? this.tithiDisplayMode,
    );
  }
}

class CalendarPreferencesNotifier extends Notifier<CalendarPreferences> {
  static const _startOfWeekKey = 'start_of_week';
  static const _primaryEventViewKey = 'primary_event_view';
  static const _primaryCalendarSystemKey = 'primary_calendar_system';
  static const _secondaryCalendarSystemKey = 'secondary_calendar_system';
  static const _hinduMonthSystemKey = 'hindu_month_system';
  static const _hinduYearEraKey = 'hindu_year_era';
  static const _tithiDisplayModeKey = 'tithi_display_mode';

  @override
  CalendarPreferences build() {
    final box = StorageService().getSettingsBox();
    // SMELL-8: replaced 7 identical local parse functions with a single
    // generic helper. Each call is now one line instead of four.
    return CalendarPreferences(
      startOfWeek: _parseEnum(box, _startOfWeekKey, StartingDayOfWeek.values, StartingDayOfWeek.sunday),
      primaryEventView: _parseEnum(box, _primaryEventViewKey, PrimaryEventView.values, PrimaryEventView.tithi),
      primaryCalendarSystem: _parseEnum(box, _primaryCalendarSystemKey, AppCalendarSystem.values, AppCalendarSystem.gregorian),
      secondaryCalendarSystem: _parseEnum(box, _secondaryCalendarSystemKey, AppCalendarSystem.values, AppCalendarSystem.hindu),
      hinduMonthSystem: _parseEnum(box, _hinduMonthSystemKey, HinduMonthSystem.values, HinduMonthSystem.amanta),
      hinduYearEra: _parseEnum(box, _hinduYearEraKey, HinduYearEra.values, HinduYearEra.shakaSamvat),
      tithiDisplayMode: _parseEnum(box, _tithiDisplayModeKey, TithiDisplayMode.values, TithiDisplayMode.continuous30),
    );
  }

  /// Generic enum parser from a Hive [Box] entry (SMELL-8).
  ///
  /// Reads the integer index stored under [key] and maps it to the
  /// corresponding element of [values].  Returns [defaultValue] when the
  /// key is absent or its index is out of range.
  static T _parseEnum<T extends Enum>(
    Box<dynamic> box,
    String key,
    List<T> values,
    T defaultValue,
  ) {
    final index = box.get(key, defaultValue: defaultValue.index) as int;
    if (index >= 0 && index < values.length) {
      return values[index];
    }
    return defaultValue;
  }

  Future<void> setStartOfWeek(StartingDayOfWeek day) async {
    await StorageService().getSettingsBox().put(_startOfWeekKey, day.index);
    state = state.copyWith(startOfWeek: day);
  }

  Future<void> setPrimaryView(PrimaryEventView view) async {
    await StorageService().getSettingsBox().put(_primaryEventViewKey, view.index);
    state = state.copyWith(primaryEventView: view);
  }

  Future<void> setPrimaryCalendarSystem(AppCalendarSystem system) async {
    await StorageService()
        .getSettingsBox()
        .put(_primaryCalendarSystemKey, system.index);
    state = state.copyWith(primaryCalendarSystem: system);
  }

  Future<void> setSecondaryCalendarSystem(AppCalendarSystem system) async {
    await StorageService()
        .getSettingsBox()
        .put(_secondaryCalendarSystemKey, system.index);
    state = state.copyWith(secondaryCalendarSystem: system);
  }

  Future<void> setHinduMonthSystem(HinduMonthSystem system) async {
    await StorageService().getSettingsBox().put(_hinduMonthSystemKey, system.index);
    state = state.copyWith(hinduMonthSystem: system);
  }

  Future<void> setHinduYearEra(HinduYearEra era) async {
    await StorageService().getSettingsBox().put(_hinduYearEraKey, era.index);
    state = state.copyWith(hinduYearEra: era);
  }

  Future<void> setTithiDisplayMode(TithiDisplayMode mode) async {
    await StorageService().getSettingsBox().put(_tithiDisplayModeKey, mode.index);
    state = state.copyWith(tithiDisplayMode: mode);
  }
}

final calendarPreferencesProvider =
    NotifierProvider<CalendarPreferencesNotifier, CalendarPreferences>(
      CalendarPreferencesNotifier.new,
    );

final startOfWeekProvider = Provider<StartingDayOfWeek>((ref) {
  return ref.watch(calendarPreferencesProvider).startOfWeek;
});

final primaryEventViewProvider = Provider<PrimaryEventView>((ref) {
  return ref.watch(calendarPreferencesProvider).primaryEventView;
});

enum AppCalendarSystem { none, gregorian, hindu, bengali }

extension AppCalendarSystemExt on AppCalendarSystem {
  String get label {
    switch (this) {
      case AppCalendarSystem.none:
        return 'None';
      case AppCalendarSystem.gregorian:
        return 'Gregorian';
      case AppCalendarSystem.hindu:
        return 'Hindu';
      case AppCalendarSystem.bengali:
        return 'Bengali';
    }
  }
}

final primaryCalendarSystemProvider = Provider<AppCalendarSystem>((ref) {
  return ref.watch(calendarPreferencesProvider).primaryCalendarSystem;
});

final secondaryCalendarSystemProvider = Provider<AppCalendarSystem>((ref) {
  return ref.watch(calendarPreferencesProvider).secondaryCalendarSystem;
});

// --- Hindu Month System (Amanta/Purnimant) ---

final hinduMonthSystemProvider = Provider<HinduMonthSystem>((ref) {
  return ref.watch(calendarPreferencesProvider).hinduMonthSystem;
});

// --- Hindu Year Era (Vikram/Shaka Samvat) ---

final hinduYearEraProvider = Provider<HinduYearEra>((ref) {
  return ref.watch(calendarPreferencesProvider).hinduYearEra;
});

// --- Tithi Display Mode (Paksha-based vs Continuous) ---

enum TithiDisplayMode { pakshaBased, continuous30 }

final tithiDisplayModeProvider = Provider<TithiDisplayMode>((ref) {
  return ref.watch(calendarPreferencesProvider).tithiDisplayMode;
});
