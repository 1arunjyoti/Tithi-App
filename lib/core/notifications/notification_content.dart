import '../../services/bengali_calendar/bengali_calendar_data.dart';

// Phase 4: pure notification content helpers extracted from
// services/notification_service.dart. No Ref, no plugin, no Hive — safe in
// the Workmanager background isolate and unit-testable.

String? secondaryCalendarLine({
  required int secondarySystem,
  required DateTime date,
  required String displayMasa,
  required String rawMasa,
  required int yearEraIndex,
  required int hinduDay,
}) {
  switch (secondarySystem) {
    case 2: // Hindu
      // Year boundary uses the raw Amanta masa (same as
      // HinduCalendarService.vikramSamvatYear); display uses the
      // month-system-converted name.
      final vsYear = vikramSamvatYear(
        gregorianYear: date.year,
        gregorianMonth: date.month,
        masa: rawMasa,
      );
      // yearEraIndex mirrors HinduYearEra: 0=vikramSamvat, 1=shakaSamvat.
      if (yearEraIndex == 0) {
        return '$displayMasa $hinduDay, Vikram $vsYear';
      }
      return '$displayMasa $hinduDay, Shaka ${vsYear - 135}';
    case 3: // Bengali
      final bengali = approxBengaliDate(date);
      return '${bengali.month} ${bengali.day}, ${bengali.year}';
    case 0: // none
    case 1: // gregorian (already shown)
    default:
      return null;
  }
}

/// Year boundary: +57 on/after Chaitra (new year), +56 before it.
/// Mirrors HinduCalendarService.vikramSamvatYear without a Ref.
int vikramSamvatYear({
  required int gregorianYear,
  required int gregorianMonth,
  required String masa,
}) {
  if (gregorianMonth < 3) return gregorianYear + 56;
  if (gregorianMonth > 4) return gregorianYear + 57;
  final base = baseMasaName(masa);
  if (base == 'Chaitra' || base == 'Vaishakha' || base == 'Jyeshtha') {
    return gregorianYear + 57;
  }
  return gregorianYear + 56;
}

String baseMasaName(String masa) {
  if (masa.startsWith('Adhika_')) return masa.substring(7);
  if (masa.startsWith('Nija_')) return masa.substring(5);
  return masa;
}

/// Solar approximation of the Bengali date (Pohela Boishakh = Apr 14).
/// Same table as the web Bengali service; avoids FFI/Ref in the
/// background isolate where notifications are built.
({int day, String month, int year}) approxBengaliDate(DateTime date) {
  // Guide Sec 3.1 spellings; shared with the web/native services.
  const months = kBengaliMonths;
  int bengaliYear = date.year - 593;
  if (date.month < 4 || (date.month == 4 && date.day < 14)) {
    bengaliYear--;
  }
  final starts = [
    DateTime(date.year, 4, 14),
    DateTime(date.year, 5, 15),
    DateTime(date.year, 6, 15),
    DateTime(date.year, 7, 16),
    DateTime(date.year, 8, 16),
    DateTime(date.year, 9, 16),
    DateTime(date.year, 10, 17),
    DateTime(date.year, 11, 16),
    DateTime(date.year, 12, 16),
    DateTime(date.year + 1, 1, 14),
    DateTime(date.year + 1, 2, 13),
    DateTime(date.year + 1, 3, 15),
  ];
  int monthIndex = 11;
  int day = date.difference(starts[11]).inDays + 1;
  for (int i = 0; i < starts.length; i++) {
    if (date.isBefore(starts[i])) {
      monthIndex = i == 0 ? 11 : i - 1;
      final prevStart = i == 0
          ? DateTime(date.year - 1, 3, 15)
          : starts[i - 1];
      day = date.difference(prevStart).inDays + 1;
      break;
    }
    if (i == starts.length - 1) {
      monthIndex = 11;
      day = date.difference(starts[11]).inDays + 1;
    }
  }
  if (day < 1) day = 1;
  if (day > 32) day = 1;
  return (day: day, month: months[monthIndex], year: bengaliYear);
}
