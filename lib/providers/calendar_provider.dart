import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:hive/hive.dart';
import '../models/hindu_month_system.dart';

/// Provider for currently selected date in calendar
final selectedDateProvider = StateProvider<DateTime>((ref) {
  return DateTime.now();
});

/// Provider for the focused month in calendar view
final focusedMonthProvider = StateProvider<DateTime>((ref) {
  return DateTime.now();
});

/// Provider for calendar format (month/week/2 weeks)
enum CalendarViewFormat { month, twoWeeks, week }

final calendarFormatProvider = StateProvider<CalendarViewFormat>((ref) {
  return CalendarViewFormat.month;
});

// --- Preference Enums ---

enum StartingDayOfWeek { sunday, monday }

enum PrimaryEventView { tithi, festival, moonPhase }

// --- Persistence Notifiers ---

/// Notifier for Start of Week preference
class StartOfWeekNotifier extends Notifier<StartingDayOfWeek> {
  static const _boxName = 'settings';
  static const _key = 'start_of_week';

  @override
  StartingDayOfWeek build() {
    final box = Hive.box(_boxName);
    final index = box.get(_key, defaultValue: 0) as int;
    return StartingDayOfWeek.values[index];
  }

  Future<void> setStartOfWeek(StartingDayOfWeek day) async {
    final box = Hive.box(_boxName);
    await box.put(_key, day.index);
    state = day;
  }
}

final startOfWeekProvider =
    NotifierProvider<StartOfWeekNotifier, StartingDayOfWeek>(
      () => StartOfWeekNotifier(),
    );

/// Notifier for Primary Home Screen View preference
class PrimaryEventViewNotifier extends Notifier<PrimaryEventView> {
  static const _boxName = 'settings';
  static const _key = 'primary_event_view';

  @override
  PrimaryEventView build() {
    final box = Hive.box(_boxName);
    final index = box.get(_key, defaultValue: 0) as int;
    return PrimaryEventView.values[index];
  }

  Future<void> setPrimaryView(PrimaryEventView view) async {
    final box = Hive.box(_boxName);
    await box.put(_key, view.index);
    state = view;
  }
}

final primaryEventViewProvider =
    NotifierProvider<PrimaryEventViewNotifier, PrimaryEventView>(
      () => PrimaryEventViewNotifier(),
    );

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

/// Notifier for Primary Calendar System preference
class PrimaryCalendarSystemNotifier extends Notifier<AppCalendarSystem> {
  static const _boxName = 'settings';
  static const _key = 'primary_calendar_system';

  @override
  AppCalendarSystem build() {
    final box = Hive.box(_boxName);
    final index =
        box.get(_key, defaultValue: AppCalendarSystem.gregorian.index) as int;
    // Ensure index is valid
    if (index >= 0 && index < AppCalendarSystem.values.length) {
      return AppCalendarSystem.values[index];
    }
    return AppCalendarSystem.gregorian;
  }

  Future<void> setSystem(AppCalendarSystem system) async {
    final box = Hive.box(_boxName);
    await box.put(_key, system.index);
    state = system;
  }
}

final primaryCalendarSystemProvider =
    NotifierProvider<PrimaryCalendarSystemNotifier, AppCalendarSystem>(
      () => PrimaryCalendarSystemNotifier(),
    );

/// Notifier for Secondary Calendar System preference
class SecondaryCalendarSystemNotifier extends Notifier<AppCalendarSystem> {
  static const _boxName = 'settings';
  static const _key = 'secondary_calendar_system';

  @override
  AppCalendarSystem build() {
    final box = Hive.box(_boxName);
    final index =
        box.get(_key, defaultValue: AppCalendarSystem.none.index) as int;
    // Ensure index is valid
    if (index >= 0 && index < AppCalendarSystem.values.length) {
      return AppCalendarSystem.values[index];
    }
    return AppCalendarSystem.none;
  }

  Future<void> setSystem(AppCalendarSystem system) async {
    final box = Hive.box(_boxName);
    await box.put(_key, system.index);
    state = system;
  }
}

final secondaryCalendarSystemProvider =
    NotifierProvider<SecondaryCalendarSystemNotifier, AppCalendarSystem>(
      () => SecondaryCalendarSystemNotifier(),
    );

// --- Hindu Month System (Amanta/Purnimant) ---

/// Notifier for Hindu Month System preference (Amanta vs Purnimant)
class HinduMonthSystemNotifier extends Notifier<HinduMonthSystem> {
  static const _boxName = 'settings';
  static const _key = 'hindu_month_system';

  @override
  HinduMonthSystem build() {
    final box = Hive.box(_boxName);
    final index =
        box.get(_key, defaultValue: HinduMonthSystem.amanta.index) as int;
    // Ensure index is valid
    if (index >= 0 && index < HinduMonthSystem.values.length) {
      return HinduMonthSystem.values[index];
    }
    return HinduMonthSystem.amanta; // Default to Amanta
  }

  Future<void> setSystem(HinduMonthSystem system) async {
    final box = Hive.box(_boxName);
    await box.put(_key, system.index);
    state = system;
  }
}

final hinduMonthSystemProvider =
    NotifierProvider<HinduMonthSystemNotifier, HinduMonthSystem>(
      () => HinduMonthSystemNotifier(),
    );

// --- Hindu Year Era (Vikram/Shaka Samvat) ---

/// Notifier for Hindu Year Era preference (Vikram Samvat vs Shaka Samvat)
class HinduYearEraNotifier extends Notifier<HinduYearEra> {
  static const _boxName = 'settings';
  static const _key = 'hindu_year_era';

  @override
  HinduYearEra build() {
    final box = Hive.box(_boxName);
    final index =
        box.get(_key, defaultValue: HinduYearEra.vikramSamvat.index) as int;
    // Ensure index is valid
    if (index >= 0 && index < HinduYearEra.values.length) {
      return HinduYearEra.values[index];
    }
    return HinduYearEra.vikramSamvat; // Default to Vikram Samvat
  }

  Future<void> setEra(HinduYearEra era) async {
    final box = Hive.box(_boxName);
    await box.put(_key, era.index);
    state = era;
  }
}

final hinduYearEraProvider =
    NotifierProvider<HinduYearEraNotifier, HinduYearEra>(
      () => HinduYearEraNotifier(),
    );
