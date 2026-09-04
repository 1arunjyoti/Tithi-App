import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:jyotish/jyotish.dart';
import '../../models/festival.dart';
import '../../models/hindu_month_system.dart';
import '../panchang_init/panchang_init.dart';

/// Native (mobile/desktop) implementation of PanchangService
/// Uses FFI-based Swiss Ephemeris for accurate calculations
class PanchangService {
  PanchangService();

  bool _isInitialized = false;
  String? _ephePath;

  /// BUG-08: cache is static so all PanchangService instances share it
  /// (background isolate + main isolate no longer maintain separate cache copies).
  /// BUG-MEDIUM-5: Bounded LRU cache – evicts oldest entries when size exceeds
  /// [_maxCacheSize] to prevent unbounded memory growth on long-running sessions.
  static const int _maxCacheSize = 500;
  static final Map<String, double> _tithiCache = {};

  /// OPT-7: Cache for Sun’s ecliptic longitude keyed by date+hour.
  /// calculateMasa makes two getPlanetPosition(Sun) calls per invocation;
  /// day-to-day calls on adjacent dates overlap heavily, so caching cuts FFI
  /// work substantially when computing a full month of panchang data.
  static const int _maxSunCacheSize = 100;
  static final Map<String, double> _sunLongitudeCache = {};

  bool get isInitialized => _isInitialized;

  bool get hasFullSupport => _isInitialized;

  Future<void> init() async {
    if (_isInitialized) return;

    try {
      // Copy ephemeris files and initialize
      _ephePath = await copyEphemerisFiles(rootBundle);

      // Initialize Jyotish/SwissEph with the path
      await Jyotish().initialize(ephemerisPath: _ephePath);

      if (kDebugMode) {
        print("Swiss Ephemeris files copied to $_ephePath");
      }

      _isInitialized = true;
    } catch (e) {
      if (kDebugMode) {
        print("Error initializing PanchangService: $e");
      }
      rethrow;
    }
  }

  Future<double> calculateTithi(
    DateTime date, {
    double latitude = 28.6139,
    double longitude = 77.2090,
  }) async {
    if (!_isInitialized) {
      throw Exception("PanchangService not initialized.");
    }

    // Generate cache key
    final cacheKey =
        '${date.millisecondsSinceEpoch}_${latitude.toStringAsFixed(4)}_${longitude.toStringAsFixed(4)}';

    // Check cache first
    if (_tithiCache.containsKey(cacheKey)) {
      return _tithiCache[cacheKey]!;
    }

    final location = GeographicLocation(
      latitude: latitude,
      longitude: longitude,
    );

    final sun = await Jyotish().getPlanetPosition(
      planet: Planet.sun,
      dateTime: date,
      location: location,
    );
    final moon = await Jyotish().getPlanetPosition(
      planet: Planet.moon,
      dateTime: date,
      location: location,
    );

    double diff = moon.longitude - sun.longitude;
    if (diff < 0) {
      diff += 360;
    }

    // Tithi = diff / 12
    // We add 1 because Tithi starts from 1, not 0.
    // Guard against the floating-point fringe where diff rounds to exactly
    // 360°, which would produce tithi = 31.0 — out of the [1, 30] cycle.
    double tithi = (diff / 12) + 1;
    if (tithi >= 31.0) tithi -= 30.0;

    // Store in cache with LRU eviction
    if (_tithiCache.length >= _maxCacheSize) {
      // Remove the oldest ~20% of entries to amortize eviction cost
      final keysToRemove = _tithiCache.keys.take(_maxCacheSize ~/ 5).toList();
      for (final key in keysToRemove) {
        _tithiCache.remove(key);
      }
    }
    _tithiCache[cacheKey] = tithi;

    return tithi;
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

    final location = GeographicLocation(
      latitude: latitude,
      longitude: longitude,
    );

    // OPT-7: use the Sun-longitude cache helper to avoid redundant FFI calls.
    final sunLongPrev = await _getCachedSunLongitude(prevNewMoonDate, location);
    final sunLongNext = await _getCachedSunLongitude(nextNewMoonDate, location);

    const masas = [
      'Vaishakha', // 0-30 Aries
      'Jyeshtha', // 30-60 Taurus
      'Ashadha', // 60-90 Gemini
      'Shravana', // 90-120 Cancer
      'Bhadrapada', // 120-150 Leo
      'Ashwin', // 150-180 Virgo
      'Kartika', // 180-210 Libra
      'Margashirsha', // 210-240 Scorpio
      'Pausha', // 240-270 Sagittarius
      'Magha', // 270-300 Capricorn
      'Phalguna', // 300-330 Aquarius
      'Chaitra', // 330-360 Pisces
    ];

    // Map Sun's sidereal longitude to zodiac index
    int zodiacIndex(double lng) {
      double l = lng % 360;
      if (l < 0) l += 360;
      return (l / 30).floor().clamp(0, 11);
    }

    final prevIndex = zodiacIndex(sunLongPrev);
    final nextIndex = zodiacIndex(sunLongNext);

    final masaName = masas[prevIndex];

    // Adhika (intercalary) masa detection:
    // If prevIndex == nextIndex, no Surya Sankranti occurred this month → Adhika month.
    // In this case, return the 'Adhika_' prefix so regular festivals DO NOT match (e.g., skip May 27).
    if (prevIndex == nextIndex) {
      return 'Adhika_$masaName';
    }

    // Nija (real) masa detection:
    // If it has a sankranti, it's either a normal month or a Nija month.
    // In either case, it should be the plain masa name so festivals DO match (e.g. June 25 shows).
    return masaName;
  }

  /// OPT-7: Returns the Sun’s ecliptic longitude for [dt], using a bounded
  /// in-memory cache keyed by (date+hour) to avoid repeated FFI calls when
  /// [calculateMasa] is invoked on adjacent new-moon dates.
  Future<double> _getCachedSunLongitude(
    DateTime dt,
    GeographicLocation location,
  ) async {
    final key =
        '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}-${dt.hour.toString().padLeft(2, '0')}';
    if (_sunLongitudeCache.containsKey(key)) return _sunLongitudeCache[key]!;

    final sun = await Jyotish().getPlanetPosition(
      planet: Planet.sun,
      dateTime: dt,
      location: location,
    );

    if (_sunLongitudeCache.length >= _maxSunCacheSize) {
      final toRemove =
          _sunLongitudeCache.keys.take(_maxSunCacheSize ~/ 5).toList();
      for (final k in toRemove) {
        _sunLongitudeCache.remove(k);
      }
    }
    _sunLongitudeCache[key] = sun.longitude;
    return sun.longitude;
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

    // BUG-05: single 380-day pass – the redundant brute-force fallback loop
    // is removed. We start from the heuristic estimate (clamped to baseDate)
    // and search forward once.
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

    // SMELL-14: Subtract 45 days from the Gregorian approximation so that
    // Adhika (intercalary) months — which can shift the real Hindu month ~30
    // days later than the heuristic estimates — are still covered by the
    // caller’s 380-day forward search window.  The caller clamps the result
    // back to [baseDate] if it falls in the past.
    final estimate = DateTime(year, targetMonth);
    return estimate.subtract(const Duration(days: 45));
  }

  /// Shared helper: finds the occurrence of [targetTithiNum] nearest to
  /// [approxDate] by searching outward in 2-hour steps (up to ±15 days).
  ///
  /// This matters because [approxDate] is the festival day at midnight, which
  /// is often still the *previous* tithi (e.g. Saptami at 00:00 while sunrise
  /// is Ashtami). A one-directional walk from there picks the wrong lunation:
  /// walking backward finds last month's occurrence (hence "Ends: Aug 6" for
  /// a Sep 4 festival), walking forward finds next month's. Searching outward
  /// guarantees the day's own occurrence (hours away) wins over the adjacent
  /// lunation's (~29.5 days away). Returns null for a Kshaya (skipped) tithi.
  Future<DateTime?> _findNearestTithiOccurrence(
    DateTime approxDate,
    int targetTithiNum,
    Future<int> Function(DateTime dt) getTithi,
  ) async {
    if (await getTithi(approxDate) == targetTithiNum) return approxDate;
    // ±15 days in 2-hour steps = 180 iterations per side.
    for (var step = 1; step <= 180; step++) {
      final forward = approxDate.add(Duration(hours: step * 2));
      if (await getTithi(forward) == targetTithiNum) return forward;
      final backward = approxDate.subtract(Duration(hours: step * 2));
      if (await getTithi(backward) == targetTithiNum) return backward;
    }
    return null;
  }

  /// BUG-06: Calculates the exact start time of a specific tithi using binary
  /// search instead of linear stepping, reducing worst-case FFI calls from
  /// O(hours + minutes) ≈ 168 to O(log(minutes in 2 days)) ≈ 25.
  ///
  /// [targetTithiNum] is the full 1-30 tithi index (rawTithi.floor():
  /// 1-15 = Shukla, 16-30 = Krishna). Pass e.g. 23 for Krishna Ashtami,
  /// NOT 8 — the paksha-relative number is ambiguous.
  Future<DateTime> calculateTithiStartTime(
    DateTime approxDate,
    int targetTithiNum, {
    double latitude = 28.6139,
    double longitude = 77.2090,
  }) async {
    assert(
      targetTithiNum >= 1 && targetTithiNum <= 30,
      'targetTithiNum must be the 1-30 tithi index, got $targetTithiNum',
    );
    final location = GeographicLocation(
      latitude: latitude,
      longitude: longitude,
    );

    Future<int> getTithi(DateTime dt) async {
      final sun = await Jyotish().getPlanetPosition(
        planet: Planet.sun,
        dateTime: dt,
        location: location,
      );
      final moon = await Jyotish().getPlanetPosition(
        planet: Planet.moon,
        dateTime: dt,
        location: location,
      );
      double diff = moon.longitude - sun.longitude;
      if (diff < 0) diff += 360;
      // BUG-1: guard wrap at 360° (same fix as calculateTithi)
      double raw = (diff / 12) + 1;
      if (raw >= 31.0) raw -= 30.0;
      return raw.floor();
    }

    // Anchor on the nearest occurrence: approxDate (midnight) is often still
    // the previous tithi, so establish `hi` inside the day's own occurrence
    // rather than walking blindly forward (which overshoots to next month
    // when approxDate is already past the tithi).
    final inside = await _findNearestTithiOccurrence(
      approxDate,
      targetTithiNum,
      getTithi,
    );
    // Kshaya (skipped) tithi — no occurrence nearby; return approx as fallback.
    if (inside == null) return approxDate;

    // Establish a search window: lo must be outside the target tithi,
    // hi must be inside it.
    DateTime lo = inside.subtract(const Duration(days: 2));
    DateTime hi = inside;

    // Walk lo back until it is outside the target tithi (normally 0
    // iterations: a tithi lasts <26h so 2 days back is always outside).
    var loGuard = 0;
    while (await getTithi(lo) == targetTithiNum && loGuard++ < 360) {
      lo = lo.subtract(const Duration(hours: 2));
    }

    // Binary search: narrow lo/hi until they are 1 minute apart.
    while (hi.difference(lo).inMinutes > 1) {
      final mid =
          lo.add(Duration(minutes: hi.difference(lo).inMinutes ~/ 2));
      if (await getTithi(mid) == targetTithiNum) {
        hi = mid;
      } else {
        lo = mid;
      }
    }

    return hi; // first minute of the target tithi
  }

  /// BUG-06: Calculates the exact end time of a specific tithi using binary
  /// search instead of linear stepping.
  ///
  /// [targetTithiNum] is the full 1-30 tithi index (see [calculateTithiStartTime]).
  Future<DateTime> calculateTithiEndTime(
    DateTime approxDate,
    int targetTithiNum, {
    double latitude = 28.6139,
    double longitude = 77.2090,
  }) async {
    assert(
      targetTithiNum >= 1 && targetTithiNum <= 30,
      'targetTithiNum must be the 1-30 tithi index, got $targetTithiNum',
    );
    final location = GeographicLocation(
      latitude: latitude,
      longitude: longitude,
    );

    Future<int> getTithi(DateTime dt) async {
      final sun = await Jyotish().getPlanetPosition(
        planet: Planet.sun,
        dateTime: dt,
        location: location,
      );
      final moon = await Jyotish().getPlanetPosition(
        planet: Planet.moon,
        dateTime: dt,
        location: location,
      );
      double diff = moon.longitude - sun.longitude;
      if (diff < 0) diff += 360;
      // BUG-1: guard wrap at 360° (same fix as calculateTithi)
      double raw = (diff / 12) + 1;
      if (raw >= 31.0) raw -= 30.0;
      return raw.floor();
    }

    // Anchor on the nearest occurrence: approxDate (midnight) is often still
    // the previous tithi, so establish `lo` inside the day's own occurrence
    // rather than walking backward (which falls back to last month's
    // occurrence — the "Ends: Aug 6 for a Sep 4 festival" bug).
    final inside = await _findNearestTithiOccurrence(
      approxDate,
      targetTithiNum,
      getTithi,
    );
    // Kshaya (skipped) tithi — no occurrence nearby; return approx as fallback.
    if (inside == null) return approxDate;

    // Establish a search window: lo must be inside the target tithi,
    // hi must be outside it.
    DateTime lo = inside;
    DateTime hi = inside.add(const Duration(days: 2));

    // Walk hi forward until it is outside the target tithi (normally 0
    // iterations: a tithi lasts <26h so 2 days ahead is always outside).
    var hiGuard = 0;
    while (await getTithi(hi) == targetTithiNum && hiGuard++ < 360) {
      hi = hi.add(const Duration(hours: 2));
    }

    // Binary search: narrow lo/hi until they are 1 minute apart.
    while (hi.difference(lo).inMinutes > 1) {
      final mid =
          lo.add(Duration(minutes: hi.difference(lo).inMinutes ~/ 2));
      if (await getTithi(mid) == targetTithiNum) {
        lo = mid;
      } else {
        hi = mid;
      }
    }

    return hi; // first minute after the target tithi ends
  }
}
