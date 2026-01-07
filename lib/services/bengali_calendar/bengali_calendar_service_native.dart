import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jyotish/jyotish.dart';
import '../../providers/panchang_provider.dart';

final bengaliCalendarServiceProvider = Provider<BengaliCalendarService>((ref) {
  return BengaliCalendarService(ref);
});

/// Native implementation of Bengali Calendar Service
/// Uses FFI-based Swiss Ephemeris for accurate calculations
class BengaliCalendarService {
  final Ref _ref;

  BengaliCalendarService(this._ref);

  // Public getter for use in other widgets
  List<String> get bengaliMonths => const [
    'Boishakh',
    'Jyoishtho',
    'Ashar',
    'Srabon',
    'Bhadro',
    'Ashwin',
    'Kartik',
    'Agrahayan',
    'Poush',
    'Magh',
    'Falgun',
    'Chaitra',
  ];

  /// Calculates the Bengali Date (West Bengal System) using Sun's position.
  /// Returns a record ({int day, String month, int year}).
  Future<({int day, String month, int year})> calculateDate(
    DateTime date, {
    double latitude = 22.5726, // Kolkata
    double longitude = 88.3639,
  }) async {
    // Ensure core service is initialized
    final _ = await _ref.read(panchangInitProvider.future);

    final location = GeographicLocation(
      latitude: latitude,
      longitude: longitude,
    );

    // Get Sun's current position to determine current Month
    final sunNow = await Jyotish().getPlanetPosition(
      planet: Planet.sun,
      dateTime: date,
      location: location,
    );

    // Month Index: 0=Boishakh (Aries), 1=Jyoishtho (Taurus) ...
    // Note: Jyotish returns Nirayana (Sidereal) Longitude.
    // Aries starts at 0 degrees.
    double lng = sunNow.longitude;
    final int monthIndex = (lng / 30).floor() % 12;

    // To find the day, we need to find when the Sun entered this Rasi (Sankranti).
    // WB Rule: If Sankranti occurs between Sunrise and Midnight, the NEXT day is 1st of month.

    DateTime searchDate = date;
    // Optimization: Jump back by the degrees approx
    double degInSign = lng % 30;
    searchDate = searchDate.subtract(Duration(days: degInSign.toInt()));

    // Now search accurately backwards
    // We look for the day where (longitude < boundary) becomes false (i.e., just crossed).
    // Boundary angle:
    double boundary = monthIndex * 30.0;
    // Handle wrap around (Pisces -> Aries)
    if (monthIndex == 0 && degInSign > 15) {
      // If we are in Aries (0-30), boundary is 0. But previous was 330-360.
    }

    // Iterate backwards up to 5 days to find exact crossing day (Sankranti Day)
    DateTime sankrantiDay = searchDate; // Placeholder

    // Safety break
    for (int i = 0; i < 5; i++) {
      final sunPos = await Jyotish().getPlanetPosition(
        planet: Planet.sun,
        dateTime: searchDate,
        location: location,
      );
      double sLng = sunPos.longitude;
      // Check if we went too far back (into previous sign)
      // Check difference considering 360 wrap
      double diff = sLng - boundary; // Should be >= 0 for current month
      if (diff < -300) diff += 360; // Wrap around case

      if (diff < 0) {
        // We found the day BEFORE ingress.
        // So the NEXT day was Sankranti (or ingress day).
        sankrantiDay = searchDate.add(const Duration(days: 1));
        break;
      }
      sankrantiDay = searchDate; // Candidate
      searchDate = searchDate.subtract(const Duration(days: 1));
    }

    // Calculate day of month
    // Date - SankrantiDay + 1.
    int day = date.difference(sankrantiDay).inDays + 1;

    // Safety check for day
    if (day > 32) day = 1;
    if (day < 1) day = 1;

    // Calculate Bengali Year (Bangabda)
    // Roughly: Gregorian Year - 593 (if after Pohela Boishakh)
    int startGregorianYear = date.year;

    if (date.month < 4) {
      startGregorianYear = date.year - 1;
    } else if (date.month == 4) {
      if (monthIndex == 11) {
        // Chaitra
        startGregorianYear = date.year - 1;
      }
    }

    int bengaliYear = startGregorianYear - 593;

    return (day: day, month: bengaliMonths[monthIndex], year: bengaliYear);
  }

  /// returns the Gregorian Date for the 1st of the given Bengali Month/Year
  Future<DateTime> getMonthStart(int bengaliYear, int monthIndex) async {
    // 1. Approximate Gregorian Start
    int gYear = bengaliYear + 593;
    if (monthIndex >= 9) gYear += 1;

    int gMonth = 4 + monthIndex;
    if (gMonth > 12) gMonth -= 12;

    DateTime estimate = DateTime(gYear, gMonth, 15);

    // 2. Refine
    // Search around estimate to find day where calculateDate returns {day: 1, monthIndex: monthIndex}
    // We check a window of +/- 4 days

    // Go back 5 days to be safe
    DateTime search = estimate.subtract(const Duration(days: 5));

    for (int i = 0; i < 15; i++) {
      final bDate = await calculateDate(search);
      // Map string month back to index for comparison
      final bMonthIndex = _getBengaliMonthIndex(bDate.month);

      if (bMonthIndex == monthIndex && bDate.day == 1) {
        return search;
      }
      search = search.add(const Duration(days: 1));
    }

    return estimate; // Fallback
  }

  int _getBengaliMonthIndex(String name) {
    return bengaliMonths.indexOf(name);
  }
}
