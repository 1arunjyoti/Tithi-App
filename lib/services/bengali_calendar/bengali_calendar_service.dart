import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/panchang_provider.dart';
import 'bengali_calendar_data.dart';

final bengaliCalendarServiceProvider = Provider<BengaliCalendarService>((ref) {
  return BengaliCalendarService(ref);
});

/// Web implementation of Bengali Calendar Service
/// Uses simplified calculations since FFI-based Swiss Ephemeris is not available on web
class BengaliCalendarService {
  final Ref _ref;

  BengaliCalendarService(this._ref);

  /// Bengali solar month names, Boishakh-first (guide Sec 3.1).
  List<String> get bengaliMonths => kBengaliMonths;

  /// Bengali-script month names (বৈশাখ .. চৈত্র).
  List<String> get bengaliMonthsBn => kBengaliMonthsBn;

  /// Sanskrit names of the solar months (Vaishakha .. Chaitra).
  List<String> get bengaliSanskritNames => kBengaliSanskritNames;

  /// Sankranti starting each month (Mesha .. Meena, Appendix A).
  List<String> get bengaliSankrantiNames => kBengaliSankrantiNames;

  /// The six ritu (Grishsho .. Bosonto, guide Sec 6).
  List<String> get bengaliSeasons => kBengaliSeasons;

  /// Season for a 0-based month index.
  String seasonForMonthIndex(int monthIndex) =>
      bengaliSeasonForMonthIndex(monthIndex);

  /// Season for a month name (alias-aware).
  String seasonForMonthName(String month) {
    final i = bengaliMonthIndexOf(month);
    return i < 0 ? '' : bengaliSeasonForMonthIndex(i);
  }

  /// Sunday-first transliterated weekday names (guide Sec 7).
  List<String> get bengaliWeekdays => kBengaliWeekdays;

  /// Sunday-first Bengali-script weekday names.
  List<String> get bengaliWeekdaysBn => kBengaliWeekdaysBn;

  /// Calculates the Bengali Date using simplified approximation for web.
  /// Returns a record ({int day, String month, int year}).
  Future<({int day, String month, int year})> calculateDate(
    DateTime date, {
    double latitude = 22.5726, // Kolkata
    double longitude = 88.3639,
  }) async {
    // Ensure panchang is initialized
    await _ref.read(panchangInitProvider.future);

    // Simplified Bengali calendar calculation for web
    // Bengali calendar year starts on April 14/15 (Pohela Boishakh)

    // Approximate Bengali year
    int bengaliYear = date.year - 593;
    if (date.month < 4 || (date.month == 4 && date.day < 14)) {
      bengaliYear--;
    }

    // Calculate approximate month and day based on solar calendar
    // Each month is approximately 30-31 days
    final monthStartDates = _getMonthStartDates(date.year);

    int monthIndex = 0;
    int day = 1;

    for (int i = 0; i < monthStartDates.length; i++) {
      if (date.isBefore(monthStartDates[i])) {
        monthIndex = i == 0 ? 11 : i - 1;
        final prevStart = i == 0
            ? _getMonthStartDates(date.year - 1)[11]
            : monthStartDates[i - 1];
        day = date.difference(prevStart).inDays + 1;
        break;
      }
      if (i == monthStartDates.length - 1) {
        monthIndex = 11;
        day = date.difference(monthStartDates[11]).inDays + 1;
      }
    }

    // Ensure day is within bounds
    if (day < 1) day = 1;
    if (day > 32) day = 1;

    return (day: day, month: bengaliMonths[monthIndex], year: bengaliYear);
  }

  /// Returns approximate Gregorian start dates for Bengali months.
  /// Fixed-date fallback only (no FFI on web): the native service computes
  /// these astronomically via the Bengal sankranti rule.
  List<DateTime> _getMonthStartDates(int gregorianYear) {
    return [
      DateTime(gregorianYear, 4, 14), // Boishakh
      DateTime(gregorianYear, 5, 15), // Joishtho
      DateTime(gregorianYear, 6, 15), // Asharh
      DateTime(gregorianYear, 7, 16), // Shrabon
      DateTime(gregorianYear, 8, 16), // Bhadro
      DateTime(gregorianYear, 9, 16), // Ashshin
      DateTime(gregorianYear, 10, 17), // Kartik
      DateTime(gregorianYear, 11, 16), // Ogrohayon
      DateTime(gregorianYear, 12, 16), // Poush
      DateTime(gregorianYear + 1, 1, 14), // Magh
      DateTime(gregorianYear + 1, 2, 13), // Falgun
      DateTime(gregorianYear + 1, 3, 15), // Choitro
    ];
  }

  /// Returns the Gregorian Date for the 1st of the given Bengali Month/Year
  Future<DateTime> getMonthStart(int bengaliYear, int monthIndex) async {
    // Approximate Gregorian Start
    int gYear = bengaliYear + 593;
    if (monthIndex >= 9) {
      gYear++; // Magh, Falgun, Choitro are in next Gregorian year
    }

    final monthStarts = _getMonthStartDates(gYear);

    // Adjust for months that wrap to next year
    if (monthIndex < 9) {
      return monthStarts[monthIndex];
    } else {
      // For Magh, Falgun, Choitro - they're in the previous year's list
      return _getMonthStartDates(gYear - 1)[monthIndex];
    }
  }
}
