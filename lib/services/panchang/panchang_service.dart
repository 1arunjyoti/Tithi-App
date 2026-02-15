import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/festival.dart';

// Provider for PanchangService
final panchangServiceProvider = Provider<PanchangService>((ref) {
  return PanchangService();
});

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
    final newMoonDate = date.subtract(
      Duration(minutes: (daysSinceNewMoon * 1440).round()),
    );

    // Approximate sun longitude based on date
    // The Sun moves approximately 1 degree per day
    // Spring equinox (March 21) = 0 degrees Aries
    final marchEquinox = DateTime(newMoonDate.year, 3, 21);
    final daysFromEquinox = newMoonDate.difference(marchEquinox).inDays;
    double sunLongitude = (daysFromEquinox % 365.25) * (360 / 365.25);
    if (sunLongitude < 0) sunLongitude += 360;

    // Map to masa (same as native implementation)
    final index = (sunLongitude / 30).floor() % 12;

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

    return masas[index];
  }

  Future<DateTime?> findNextFestivalOccurrence(
    Festival festival, {
    DateTime? startDate,
    double latitude = 28.6139,
    double longitude = 77.2090,
  }) async {
    var date = startDate ?? DateTime.now();

    // Limit search to ~380 days
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

      if (festival.matchesTithi(paksha, tithiNumber, masa)) {
        return date;
      }

      date = date.add(const Duration(days: 1));
    }

    return null;
  }
}
