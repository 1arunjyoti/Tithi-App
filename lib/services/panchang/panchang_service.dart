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
        if (month < 1 || month > 12 || day < 1 || day > 31) return null;
        final baseDateOnly = DateTime(
          baseDate.year,
          baseDate.month,
          baseDate.day,
        );
        // Dart's DateTime normalizes overflow (DateTime(2025, 2, 29) becomes
        // Mar 1), so verify the construction round-trips and walk forward to
        // the next year that actually contains the date (next leap year for
        // Feb 29; 9 iterations cover century leap exceptions). Invalid dates
        // (e.g. Feb 30) never resolve and correctly return null.
        DateTime? candidateFor(int year) {
          final d = DateTime(year, month, day);
          if (d.month != month || d.day != day) return null;
          return d;
        }

        for (var i = 0; i < 9; i++) {
          final candidate = candidateFor(baseDateOnly.year + i);
          if (candidate != null && !candidate.isBefore(baseDateOnly)) {
            return candidate;
          }
        }
        return null;
      }
    }

    // BUG-05: single 420-day pass (redundant fallback loop removed).
    // 420 (not 380) covers Adhika-stretched gaps (~384d) and Kshaya skips.
    var date = _estimateFestivalSearchStart(baseDate, festival);
    if (date.isBefore(baseDate)) {
      date = baseDate;
    }

    for (int i = 0; i < 420; i++) {
      Future<bool> matchesOn(DateTime day) async {
        // Sample at TRUE sunrise (not a fixed 06:00): the UI batch matches at
        // sunrise, so a fixed 06:00 probe disagrees by a day whenever the
        // tithi changes between 06:00 and sunrise.
        final dayOnly = DateTime(day.year, day.month, day.day);
        final probe = SunriseCalculator.calculateSunriseIST(
          date: dayOnly,
          latitude: latitude,
          longitude: longitude,
        );
        final probeRawTithi = await calculateTithi(
          probe,
          latitude: latitude,
          longitude: longitude,
        );
        // Clamp: the web mean-motion approximation can yield ~0.x near the
        // wrap (native guards this in calculateTithi); floor() 0 would derive
        // a bogus Shukla-0 tithi that matches nothing and skews Kshaya gaps.
        final probeIndex = probeRawTithi.floor().clamp(1, 30);
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
        // Timing-override checkpoint (same as the UI batch in
        // PanchangData.fromRawTithi): festivals observed at madhyahna,
        // aparahna, nishita or pradosha match the tithi prevailing at that
        // intraday instant — not the sunrise probe. Without this, a tithi
        // starting after sunrise but prevailing at dusk (e.g. Trayodashi for
        // Pradosh Vrata) is missed entirely by the forward scan.
        // Masa stays the sunrise masa (probeMasa), matching the UI batch
        // which matches override festivals against the sunrise masa — not
        // the checkpoint masa — so sankranti-boundary days agree.
        final override = festival.panchangRules.timingOverride;
        if (override != null &&
            timingOverrideCheckpoints.contains(override) &&
            festival.nakshatraCondition == null) {
          final checkpoint = SunriseCalculator.checkpointTimeFor(
            day,
            override,
            latitude,
            longitude,
          );
          if (checkpoint != null) {
            final cpRaw = await calculateTithi(
              checkpoint,
              latitude: latitude,
              longitude: longitude,
            );
            final cpIndex = cpRaw.floor().clamp(1, 30);
            final String cpPaksha;
            final int cpNum;
            if (cpIndex <= 15) {
              cpPaksha = 'Shukla';
              cpNum = cpIndex;
            } else {
              cpPaksha = 'Krishna';
              cpNum = cpIndex - 15;
            }
            if (matchesFestivalOnDay(
              festival: festival,
              paksha: cpPaksha,
              tithiNumber: cpNum,
              masa: probeMasa,
              nakshatra: null,
              date: day,
            )) {
              return true;
            }
            // Checkpoint missed: fall through to the Kshaya fallback below
            // (mirrors PanchangData.fromRawTithi). Do NOT return false here.
          }
          // No checkpoint, or checkpoint missed: fall through to Kshaya.
        }
        // Dominant-tithi grace (Drik rule, same as the UI batch).
        final usesSunrise = festival.panchangRules.timingOverride == null ||
            !timingOverrideCheckpoints.contains(
              festival.panchangRules.timingOverride,
            );
        if (usesSunrise && festival.nakshatraCondition == null) {
          // `probe` IS today's sunrise (see above): reuse it instead of
          // recomputing the same instant.
          final daySunrise = probe;
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
            if (festival.matchesTithi(
              domPaksha,
              domNum,
              domMasa,
              HinduMonthSystem.amanta,
              day,
            )) {
              return true;
            }
            // Dominant missed: fall through to the Kshaya fallback below
            // (mirrors the UI batch). Do NOT return false here.
          }
        }
        // Kshaya fallback (same as PanchangData.fromRawTithi): a tithi that
        // begins after one sunrise and ends before the next never prevails at
        // any sunrise, so probe/checkpoint/dominant all miss it. Without this
        // the calendar grid shows the festival (via the UI batch) but the
        // forward scan skips the day and jumps to next year.
        // Nakshatra festivals returned with probeMatch above (a nakshatra
        // always owns a sunrise, so there is no Kshaya fallback for them).
        if (festival.nakshatraCondition == null) {
          final nextSunriseDay = SunriseCalculator.calculateSunriseIST(
            date: DateTime(day.year, day.month, day.day).add(
              const Duration(days: 1),
            ),
            latitude: latitude,
            longitude: longitude,
          );
          final rawNext = await calculateTithi(
            nextSunriseDay,
            latitude: latitude,
            longitude: longitude,
          );
          var currentSunriseIndex = probeRawTithi.floor();
          var nextSunriseIndex = rawNext.floor();
          if (currentSunriseIndex < 1) currentSunriseIndex = 1;
          if (currentSunriseIndex > 30) currentSunriseIndex = 30;
          if (nextSunriseIndex < 1) nextSunriseIndex = 1;
          if (nextSunriseIndex > 30) nextSunriseIndex = 30;

          if (nextSunriseIndex < currentSunriseIndex) {
            nextSunriseIndex += 30; // Handle wrap-around.
          }

          if (nextSunriseIndex - currentSunriseIndex > 1) {
            String? masaNextSunrise;
            for (int i = currentSunriseIndex + 1; i < nextSunriseIndex; i++) {
              final skippedIndex = i > 30 ? i - 30 : i;
              final String kshayaPaksha = skippedIndex <= 15
                  ? 'Shukla'
                  : 'Krishna';
              final int kshayaTithiNum = skippedIndex <= 15
                  ? skippedIndex
                  : skippedIndex - 15;

              if (festival.matchesTithi(
                kshayaPaksha,
                kshayaTithiNum,
                probeMasa,
                HinduMonthSystem.amanta,
                day,
              )) {
                return true;
              }

              // New-moon wrap inside the skipped span starts a new lunation.
              if (skippedIndex == 1 || skippedIndex == 16) {
                masaNextSunrise ??= await calculateMasa(
                  nextSunriseDay,
                  rawNext,
                  latitude: latitude,
                  longitude: longitude,
                );
                if (masaNextSunrise.isNotEmpty &&
                    masaNextSunrise != probeMasa &&
                    festival.matchesTithi(
                      kshayaPaksha,
                      kshayaTithiNum,
                      masaNextSunrise,
                      HinduMonthSystem.amanta,
                      day,
                    )) {
                  return true;
                }
              }
            }
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

    // No year rollover (see native impl): the 420-day forward scan finds
    // next year's occurrence on its own. Jumping to year+1 when the approx
    // month looks "past" skips imminent lunar occurrences 1-2 months later
    // than the Gregorian guess (e.g. Mahalaya 2026). The estimate must never
    // start after [from]; subtract 45 days (Adhika buffer, same as native)
    // so the fast-forward stays on the early/safe side.
    return DateTime(
      from.year,
      targetMonth,
    ).subtract(const Duration(days: 45));
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
