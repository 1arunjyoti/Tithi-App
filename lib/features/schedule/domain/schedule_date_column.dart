import '../../../models/hindu_month_system.dart';
import '../../../models/panchang_data.dart';
import '../../../providers/calendar_provider.dart' as cp;
import '../providers/schedule_providers.dart';

// Primary/secondary calendar resolution for the schedule row's date column,
// extracted from the former widgets/schedule_view_widget.dart monolith.
//
// Pure: settings + date data in, display strings out. The widget only renders
// the result, so every system combination is testable without a widget tree
// (see test/schedule_view_test.dart).

/// What one schedule row's left date column shows.
class ScheduleDateColumnView {
  const ScheduleDateColumnView({
    required this.month,
    required this.day,
    this.secondary,
  });

  /// Resolves the primary month stem / day and the secondary-calendar chip for
  /// [panchang] under the user's calendar-system selection.
  ///
  /// [gregorianMonth] and [gregorianDay] are pre-formatted by the caller (it
  /// already owns the locale-cached formatters), so this stays formatter-free.
  factory ScheduleDateColumnView.resolve({
    required cp.AppCalendarSystem primarySystem,
    required cp.AppCalendarSystem secondarySystem,
    required HinduMonthSystem monthSystem,
    required cp.TithiDisplayMode tithiMode,
    required PanchangData panchang,
    required String gregorianMonth,
    required String gregorianDay,
    ({int day, String month, int year})? bengaliDate,
    HinduDateData? hinduDate,
  }) {
    late String primaryMonth;
    late String primaryDay;
    String? secondaryText;

    if (primarySystem == cp.AppCalendarSystem.bengali) {
      // Bengali as primary: show Bengali month and day
      if (bengaliDate != null) {
        primaryMonth = bengaliDate.month
            .substring(0, bengaliDate.month.length.clamp(0, 4))
            .toUpperCase();
        primaryDay = '${bengaliDate.day}';
      } else {
        // Fallback to Gregorian if Bengali calculation not ready
        primaryMonth = gregorianMonth;
        primaryDay = gregorianDay;
      }

      // Show secondary based on selection
      if (secondarySystem == cp.AppCalendarSystem.gregorian) {
        secondaryText = '$gregorianMonth $gregorianDay';
      } else if (secondarySystem == cp.AppCalendarSystem.hindu &&
          hinduDate != null) {
        secondaryText = '${hinduDate.paksha[0]}${hinduDate.day}';
      }
    } else if (primarySystem == cp.AppCalendarSystem.hindu) {
      // Hindu as primary: show masa and tithi with proper settings
      if (hinduDate != null) {
        primaryMonth = hinduDate.month
            .split(' ')
            .last
            .substring(0, hinduDate.month.split(' ').last.length.clamp(0, 4))
            .toUpperCase();
        primaryDay = '${hinduDate.day}';
      } else {
        // Fallback to panchang data (Amanta) with display settings applied.
        final fallbackMasa = displayMasaName(
          panchang.masa,
          panchang.paksha,
          monthSystem,
        );
        primaryMonth = panchang.masa.isNotEmpty
            ? fallbackMasa
                  .replaceAll('_', ' ')
                  .split(' ')
                  .last
                  .substring(0, fallbackMasa.split('_').last.length.clamp(0, 4))
                  .toUpperCase()
            : gregorianMonth;
        primaryDay =
            '${tithiMode == cp.TithiDisplayMode.continuous30 ? panchang.tithiIndex : panchang.tithiNumber}';
      }

      // Show secondary based on selection
      if (secondarySystem == cp.AppCalendarSystem.gregorian) {
        secondaryText = '$gregorianMonth $gregorianDay';
      } else if (secondarySystem == cp.AppCalendarSystem.bengali &&
          bengaliDate != null) {
        secondaryText =
            '${bengaliDate.month.substring(0, 3)} ${bengaliDate.day}';
      }
    } else {
      // Gregorian as primary
      primaryMonth = gregorianMonth;
      primaryDay = gregorianDay;

      // Show secondary based on selection
      if (secondarySystem == cp.AppCalendarSystem.hindu && hinduDate != null) {
        // Show paksha initial + tithi number with month abbr
        final pakshaInitial = hinduDate.paksha == 'Shukla' ? 'श' : 'क';
        secondaryText =
            '${hinduDate.month.substring(0, 3)} $pakshaInitial${hinduDate.day}';
      } else if (secondarySystem == cp.AppCalendarSystem.bengali &&
          bengaliDate != null) {
        // Show Bengali date as secondary
        secondaryText =
            '${bengaliDate.month.substring(0, 3)} ${bengaliDate.day}';
      }
    }

    return ScheduleDateColumnView(
      month: primaryMonth,
      day: primaryDay,
      secondary: secondaryText,
    );
  }

  /// Primary month stem, already uppercased (e.g. `KART`, `MAY`).
  final String month;

  /// Primary day numeral, already stringified.
  final String day;

  /// Secondary-calendar chip text; null when the column stays narrow.
  final String? secondary;

  bool get hasSecondary => secondary != null;
}
