import 'package:flutter/foundation.dart';
import '../../models/festival.dart';
import '../../models/hindu_month_system.dart';
import '../festival_matching_pipeline.dart';
import '../sunrise_calculator.dart';
import '../../core/location/location_defaults.dart';

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
    double latitude = kDefaultLatitude,
    double longitude = kDefaultLongitude,
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

  /// Sun+Moon longitudes are unsupported without an ephemeris (web
  /// fallback): always null, so the yoga/karana card hides on web.
  /// Documented limitation, not silent drift.
  Future<({double sun, double moon})?> calculateSunMoonLongitudes(
    DateTime date, {
    double latitude = kDefaultLatitude,
    double longitude = kDefaultLongitude,
  }) async {
    return null;
  }

  /// Nakshatra is unsupported without an ephemeris (web fallback): always
  /// null, so nakshatra-conditioned festivals (e.g. Saraswati Avahan on
  /// Mula) don't match on web. Documented limitation, not silent drift.
  Future<String?> calculateNakshatra(
    DateTime date, {
    double latitude = kDefaultLatitude,
    double longitude = kDefaultLongitude,
  }) async {
    return null;
  }

  Future<String> calculateMasa(
    DateTime date,
    double rawTithi, {
    double latitude = kDefaultLatitude,
    double longitude = kDefaultLongitude,
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
    double latitude = kDefaultLatitude,
    double longitude = kDefaultLongitude,
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
      Future<bool> matchesOn(DateTime day) async {
        final probe = DateTime(day.year, day.month, day.day, 6);
        final probeRawTithi = await calculateTithi(
          probe,
          latitude: latitude,
          longitude: longitude,
        );
        final probeIndex = probeRawTithi.floor();
        final String probePaksha;
        final int probeTithiNumber;
        if (probeIndex <= 15) {
          probePaksha = 'Shukla';
          probeTithiNumber = probeIndex;
        } else {
          probePaksha = 'Krishna';
          probeTithiNumber = probeIndex - 15;
        }
        final probeMasa = await calculateMasa(
          probe,
          probeRawTithi,
          latitude: latitude,
          longitude: longitude,
        );
        // Nakshatra override: web has no ephemeris (always null), so such
        // festivals never match here — documented in calculateNakshatra.
        final probeNakshatra = festival.nakshatraCondition != null
            ? await calculateNakshatra(
                probe,
                latitude: latitude,
                longitude: longitude,
              )
            : null;
        // BUG-04: pass `date` so weekday constraints are evaluated.
        // Shared pipeline: matches agree with the UI grid by construction.
        final probeMatch = matchesFestivalOnDay(
          festival: festival,
          paksha: probePaksha,
          tithiNumber: probeTithiNumber,
          masa: probeMasa,
          nakshatra: probeNakshatra,
          date: day,
        );
        if (probeMatch) return true;
        // Dominant-tithi grace (Drik rule, same as the UI batch).
        const sunriseOverrides = {'madhyahna', 'aparahna', 'nishita'};
        final usesSunrise = festival.panchangRules.timingOverride == null ||
            !sunriseOverrides.contains(festival.panchangRules.timingOverride);
        if (usesSunrise && festival.nakshatraCondition == null) {
          final daySunrise = SunriseCalculator.calculateSunriseIST(
            date: DateTime(day.year, day.month, day.day),
            latitude: latitude,
            longitude: longitude,
          );
          final domRaw = await calculateTithi(
            daySunrise.add(kDominantTithiGrace),
            latitude: latitude,
            longitude: longitude,
          );
          final domIndex = domRaw.floor().clamp(1, 30);
          if (domIndex != probeIndex) {
            final String domPaksha;
            final int domNum;
            if (domIndex <= 15) {
              domPaksha = 'Shukla';
              domNum = domIndex;
            } else {
              domPaksha = 'Krishna';
              domNum = domIndex - 15;
            }
            var domMasa = probeMasa;
            if (probeIndex == 30 && domIndex == 1) {
              domMasa = await calculateMasa(
                daySunrise.add(kDominantTithiGrace),
                domRaw,
                latitude: latitude,
                longitude: longitude,
              );
            }
            return festival.matchesTithi(
              domPaksha,
              domNum,
              domMasa,
              HinduMonthSystem.amanta,
              day,
            );
          }
        }
        return false;
      }

      // BUG-04: pass `date` so weekday constraints are evaluated.
      // Shared pipeline: a Vriddhi run resolves to first/last/both days so
      // countdown, search, export and notifications agree with the UI grid.
      if (await matchesOn(date)) {
        final baseDateOnly = DateTime(
          baseDate.year,
          baseDate.month,
          baseDate.day,
        );
        final resolved = await resolveVriddhiCandidate(
          festival: festival,
          candidate: date,
          baseDate: baseDateOnly,
          matchesDay: matchesOn,
        );
        if (resolved.occurrence != null) {
          final o = resolved.occurrence!;
          return DateTime(o.year, o.month, o.day);
        }
        date = resolved.resumeFrom;
        continue;
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
    double latitude = kDefaultLatitude,
    double longitude = kDefaultLongitude,
  }) async {
    // Web does not have FFI Swiss Ephemeris.
    // Return approximate date to satisfy compilation.
    return approxDate.subtract(const Duration(hours: 12));
  }

  /// Calculates the exact end time of a specific tithi (Web Fallback)
  Future<DateTime> calculateTithiEndTime(
    DateTime approxDate,
    int targetTithiNum, {
    double latitude = kDefaultLatitude,
    double longitude = kDefaultLongitude,
  }) async {
    // Web does not have FFI Swiss Ephemeris.
    // Return approximate date to satisfy compilation.
    return approxDate.add(const Duration(hours: 12));
  }
}
