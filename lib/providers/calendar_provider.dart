import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/hindu_month_system.dart';
import '../services/storage_service.dart';

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

    StartingDayOfWeek parseStartOfWeek() {
      final index = box.get(_startOfWeekKey, defaultValue: 0) as int;
      if (index >= 0 && index < StartingDayOfWeek.values.length) {
        return StartingDayOfWeek.values[index];
      }
      return StartingDayOfWeek.sunday;
    }

    PrimaryEventView parsePrimaryEventView() {
      final index = box.get(_primaryEventViewKey, defaultValue: 0) as int;
      if (index >= 0 && index < PrimaryEventView.values.length) {
        return PrimaryEventView.values[index];
      }
      return PrimaryEventView.tithi;
    }

    AppCalendarSystem parsePrimaryCalendarSystem() {
      final index =
          box.get(
                _primaryCalendarSystemKey,
                defaultValue: AppCalendarSystem.gregorian.index,
              )
              as int;
      if (index >= 0 && index < AppCalendarSystem.values.length) {
        return AppCalendarSystem.values[index];
      }
      return AppCalendarSystem.gregorian;
    }

    AppCalendarSystem parseSecondaryCalendarSystem() {
      final index =
          box.get(
                _secondaryCalendarSystemKey,
                defaultValue: AppCalendarSystem.none.index,
              )
              as int;
      if (index >= 0 && index < AppCalendarSystem.values.length) {
        return AppCalendarSystem.values[index];
      }
      return AppCalendarSystem.none;
    }

    HinduMonthSystem parseHinduMonthSystem() {
      final index =
          box.get(
                _hinduMonthSystemKey,
                defaultValue: HinduMonthSystem.amanta.index,
              )
              as int;
      if (index >= 0 && index < HinduMonthSystem.values.length) {
        return HinduMonthSystem.values[index];
      }
      return HinduMonthSystem.amanta;
    }

    HinduYearEra parseHinduYearEra() {
      final index =
          box.get(
                _hinduYearEraKey,
                defaultValue: HinduYearEra.vikramSamvat.index,
              )
              as int;
      if (index >= 0 && index < HinduYearEra.values.length) {
        return HinduYearEra.values[index];
      }
      return HinduYearEra.vikramSamvat;
    }

    TithiDisplayMode parseTithiDisplayMode() {
      final index = box.get(_tithiDisplayModeKey, defaultValue: 0) as int;
      if (index >= 0 && index < TithiDisplayMode.values.length) {
        return TithiDisplayMode.values[index];
      }
      return TithiDisplayMode.pakshaBased;
    }

    return CalendarPreferences(
      startOfWeek: parseStartOfWeek(),
      primaryEventView: parsePrimaryEventView(),
      primaryCalendarSystem: parsePrimaryCalendarSystem(),
      secondaryCalendarSystem: parseSecondaryCalendarSystem(),
      hinduMonthSystem: parseHinduMonthSystem(),
      hinduYearEra: parseHinduYearEra(),
      tithiDisplayMode: parseTithiDisplayMode(),
    );
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
