import 'package:flutter/foundation.dart';
import '../../models/festival.dart';
import '../../models/hindu_month_system.dart';

/// Web implementation of PanchangService
/// Uses simplified calculations since FFI-based Swiss Ephemeris is not available on web
class PanchangService {
  PanchangService();

  bool _isInitialized = false;

  bool get isInitialized => _isInitialized;

  bool get hasFullSupport => false; // Web doesn't have full FFI support

  Future<void> init() async {
    if (_isInitialized) return;

    if (kDebugMode) {
      print(
        'PanchangService: Web platform detected, using simplified calculations',
      );
    }
    _isInitialized = true;
  }

  /// Simplified Tithi calculation using basic astronomical formulas
  /// This is less accurate than the Swiss Ephemeris but works on web
  Future<double> calculateTithi(
    DateTime date, {
    double latitude = 28.6139,
    double longitude = 77.2090,
  }) async {
    if (!_isInitialized) {
      throw Exception("PanchangService not initialized.");
    }

    // Use simplified lunar phase calculation
    // This is an approximation based on the synodic month
    return _calculateApproximateTithi(date);
  }

  /// Approximate tithi calculation using known new moon reference
  double _calculateApproximateTithi(DateTime date) {
    // Reference new moon: January 6, 2000, 18:14 UTC (known astronomical new moon)
    final referenceNewMoon = DateTime.utc(2000, 1, 6, 18, 14);

    // Synodic month (average time between new moons) = 29.530588853 days
    const synodicMonth = 29.530588853;

    // Calculate days since reference new moon
    final daysSinceReference =
        date.toUtc().difference(referenceNewMoon).inMinutes / (24 * 60);

    // Calculate current phase (0 to 1, where 0 = new moon)
    final phase = (daysSinceReference % synodicMonth) / synodicMonth;

    // Convert to tithi (1-30, where 1 = first day after new moon)
    // Each tithi is 12 degrees of lunar elongation, or 1/30th of the cycle
    final tithi = (phase * 30) + 1;

    return tithi > 30 ? tithi - 30 : tithi;
  }

  Future<String> calculateMasa(
    DateTime date,
    double rawTithi, {
    double latitude = 28.6139,
    double longitude = 77.2090,
  }) async {
    if (!_isInitialized) {
      throw Exception("PanchangService not initialized.");
    }

    // Simplified masa calculation based on the month
    // This maps Gregorian months to approximate Hindu months
    // Note: This is a rough approximation and may not be accurate for all dates
    return _getApproximateMasa(date, rawTithi);
  }

  String _getApproximateMasa(DateTime date, double rawTithi) {
    // Calculate days since last New Moon (Amavasya)
    final diffDegrees = (rawTithi - 1) * 12;
    final daysSinceNewMoon = diffDegrees / 12.19074;

    // Estimate date of previous New Moon
    final prevNewMoonDate = date.subtract(
      Duration(minutes: (daysSinceNewMoon * 1440).round()),
    );

    // Estimate date of next New Moon (~29.53 days after the previous one)
    const synodicMonth = 29.530588853;
    final nextNewMoonDate = prevNewMoonDate.add(
      Duration(minutes: (synodicMonth * 1440).round()),
    );

    // Approximate sun longitude based on date (1 degree/day from spring equinox)
    double sunLongitude(DateTime d) {
      final marchEquinox = DateTime(d.year, 3, 21);
      final daysFromEquinox = d.difference(marchEquinox).inDays;
      double sunLng = (daysFromEquinox % 365.25) * (360 / 365.25);
      if (sunLng < 0) sunLng += 360;
      return sunLng;
    }

    const masas = [
      'Vaishakha', // Aries
      'Jyeshtha', // Taurus
      'Ashadha', // Gemini
      'Shravana', // Cancer
      'Bhadrapada', // Leo
      'Ashwin', // Virgo
      'Kartika', // Libra
      'Margashirsha', // Scorpio
      'Pausha', // Sagittarius
      'Magha', // Capricorn
      'Phalguna', // Aquarius
      'Chaitra', // Pisces
    ];

    final prevIndex = (sunLongitude(prevNewMoonDate) / 30).floor() % 12;
    final nextIndex = (sunLongitude(nextNewMoonDate) / 30).floor() % 12;

    final masaName = masas[prevIndex];

    // If prevIndex == nextIndex → Adhika month (no sankranti) → return Adhika prefix.
    if (prevIndex == nextIndex) {
      return 'Adhika_$masaName';
    }

    // Nija (real) or normal month (has sankranti) → return plain name (festivals match).
    return masaName;
  }

  Future<DateTime?> findNextFestivalOccurrence(
    Festival festival, {
    DateTime? startDate,
    double latitude = 28.6139,
    double longitude = 77.2090,
  }) async {
    final baseDate = startDate ?? DateTime.now();

    // Handle solar festivals (fixed Gregorian dates) directly to avoid 380-day iteration
    if (festival.conditions == 'Solar' &&
        festival.panchangRules.solarDate != null) {
      final parts = festival.panchangRules.solarDate!.split('-');
      if (parts.length == 2) {
        final month = int.tryParse(parts[0]) ?? 1;
        final day = int.tryParse(parts[1]) ?? 1;
        var nextDate = DateTime(baseDate.year, month, day);
        final baseDateOnly = DateTime(
          baseDate.year,
          baseDate.month,
          baseDate.day,
        );

        if (nextDate.isBefore(baseDateOnly)) {
          nextDate = DateTime(baseDate.year + 1, month, day);
        }
        return nextDate;
      }
    }

    // BUG-05: single 380-day pass (redundant fallback loop removed).
    var date = _estimateFestivalSearchStart(baseDate, festival);
    if (date.isBefore(baseDate)) {
      date = baseDate;
    }

    for (int i = 0; i < 380; i++) {
      final checkDate = DateTime(date.year, date.month, date.day, 6);

      final rawTithi = await calculateTithi(
        checkDate,
        latitude: latitude,
        longitude: longitude,
      );

      final tithiIndex = rawTithi.floor();
      String paksha;
      int tithiNumber;
      if (tithiIndex <= 15) {
        paksha = 'Shukla';
        tithiNumber = tithiIndex;
      } else {
        paksha = 'Krishna';
        tithiNumber = tithiIndex - 15;
      }

      final masa = await calculateMasa(
        checkDate,
        rawTithi,
        latitude: latitude,
        longitude: longitude,
      );

      // BUG-04: pass `date` so weekday constraints are evaluated
      if (festival.matchesTithi(
        paksha,
        tithiNumber,
        masa,
        HinduMonthSystem.amanta,
        date,
      )) {
        return date;
      }

      date = date.add(const Duration(days: 1));
    }

    return null;
  }

  DateTime _estimateFestivalSearchStart(DateTime from, Festival festival) {
    final masa = festival.panchangRules.masa;
    if (masa.isEmpty || masa == '*') {
      return from;
    }

    const approxMonth = {
      'Chaitra': 3,
      'Vaishakha': 4,
      'Jyeshtha': 5,
      'Ashadha': 6,
      'Shravana': 7,
      'Bhadrapada': 8,
      'Ashwin': 9,
      'Kartika': 10,
      'Margashirsha': 11,
      'Pausha': 12,
      'Magha': 1,
      'Phalguna': 2,
    };

    final targetMonth = approxMonth[masa];
    if (targetMonth == null) return from;

    var year = from.year;
    if (targetMonth < from.month - 1) {
      year += 1;
    }

    return DateTime(year, targetMonth);
  }

  /// Calculates the exact start time of a specific tithi (Web Fallback)
  Future<DateTime> calculateTithiStartTime(
    DateTime approxDate,
    int targetTithiNum, {
    double latitude = 28.6139,
    double longitude = 77.2090,
  }) async {
    // Web does not have FFI Swiss Ephemeris.
    // Return approximate date to satisfy compilation.
    return approxDate.subtract(const Duration(hours: 12));
  }

  /// Calculates the exact end time of a specific tithi (Web Fallback)
  Future<DateTime> calculateTithiEndTime(
    DateTime approxDate,
    int targetTithiNum, {
    double latitude = 28.6139,
    double longitude = 77.2090,
  }) async {
    // Web does not have FFI Swiss Ephemeris.
    // Return approximate date to satisfy compilation.
    return approxDate.add(const Duration(hours: 12));
  }
}
