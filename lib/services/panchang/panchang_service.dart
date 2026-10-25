import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:jyotish/jyotish.dart';
import '../../features/panchang/domain/panchang_crossings.dart';
import '../../features/panchang/domain/panchang_day.dart';
import '../../features/panchang/domain/panchang_day_projection.dart';
import '../../features/panchang/domain/panchang_day_resolver.dart';
import '../../models/festival.dart';
import '../../models/hindu_month_system.dart';
import '../festival_matching_pipeline.dart';
import '../panchang_init/panchang_init.dart';
import '../solar_events_service.dart';
import '../../core/location/location_defaults.dart';

/// Native (mobile/desktop) implementation of PanchangService
/// Uses FFI-based Swiss Ephemeris for accurate calculations
class PanchangService {
  PanchangService();

  bool _isInitialized = false;
  late String _ephePath;

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

  /// Clears every in-memory calculation cache.
  ///
  /// Hive entries are invalidated by the version tag in
  /// `locationSignature`; this handles the process-local caches that would
  /// otherwise keep serving results from the previous solar convention.
  static void clearCaches() {
    _tithiCache.clear();
    _sunLongitudeCache.clear();
    solarEventsService.clearCache();
  }

  Future<void> init() async {
    if (_isInitialized) return;

    try {
      // Copy ephemeris files and initialize
      _ephePath = await copyEphemerisFiles(rootBundle);

      // Initialize Jyotish/SwissEph with the path
      await Jyotish().initialize(ephemerisPath: _ephePath);

      // Install the native Hindu rise/set calculator after the ephemeris
      // files exist. Failure is non-fatal: the solar service keeps its
      // labelled NOAA fallback.
      solarEventsService.configureSwiss(ephemerisPath: _ephePath);
      clearCaches();

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
    double latitude = kDefaultLatitude,
    double longitude = kDefaultLongitude,
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

  /// Sidereal (Lahiri) ecliptic longitudes of the Sun and Moon in degrees.
  ///
  /// Powers the yoga (sum) and karana (difference) computations, which each
  /// need both longitudes at the same instant. Returns null instead of
  /// throwing when uninitialized or the ephemeris call fails, so callers
  /// degrade to hiding rather than breaking the whole day.
  Future<({double sun, double moon})?> calculateSunMoonLongitudes(
    DateTime date, {
    double latitude = kDefaultLatitude,
    double longitude = kDefaultLongitude,
  }) async {
    if (!_isInitialized) return null;
    try {
      // PERF-3: one parallel batch — the two FFI calls are independent.
      final positions = await Jyotish().getMultiplePlanetPositions(
        planets: [Planet.sun, Planet.moon],
        dateTime: date,
        location: GeographicLocation(
          latitude: latitude,
          longitude: longitude,
        ),
      );
      final sun = positions[Planet.sun];
      final moon = positions[Planet.moon];
      if (sun == null || moon == null) return null;
      return (sun: sun.longitude, moon: moon.longitude);
    } catch (e) {
      if (kDebugMode) {
        print('calculateSunMoonLongitudes failed: $e');
      }
      return null;
    }
  }

  /// Nakshatra prevailing at [date] (canonical name, e.g. 'Mula').
  ///
  /// Derived from the sidereal Moon longitude — the same Lahiri frame
  /// [calculateTithi] uses: index = floor(longitude / (360/27)).
  /// Returns null instead of throwing when uninitialized or the ephemeris
  /// call fails, so one bad sample degrades to "nakshatra festivals don't
  /// match today" rather than breaking the whole day.
  Future<String?> calculateNakshatra(
    DateTime date, {
    double latitude = kDefaultLatitude,
    double longitude = kDefaultLongitude,
  }) async {
    if (!_isInitialized) return null;
    try {
      final moon = await Jyotish().getPlanetPosition(
        planet: Planet.moon,
        dateTime: date,
        location: GeographicLocation(
          latitude: latitude,
          longitude: longitude,
        ),
      );
      return nakshatraForLongitude(moon.longitude);
    } catch (e) {
      if (kDebugMode) {
        print('calculateNakshatra failed: $e');
      }
      return null;
    }
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

    final location = GeographicLocation(
      latitude: latitude,
      longitude: longitude,
    );

    // Lunation-exact new moons (see _adhikaVerdict): the old code sampled the
    // Sun at mean-motion ESTIMATES (query date minus mean elapsed days, plus
    // a mean 29.53d month). Those estimates can sit on opposite sides of a
    // sankranti from the true new moons, so Adhika detection fired only for
    // the few days whose estimates happened to land right — adjacent dates
    // in one Adhika month disagreed (Adhika vs plain). Sampling at refined
    // true new moons makes the verdict lunation-wide and stable.
    final verdict = await _adhikaVerdict(date, rawTithi, location);

    // Nija (real) masa detection:
    // If it has a sankranti, it's either a normal month or a Nija month.
    // In either case, it should be the plain masa name so festivals DO match (e.g. June 25 shows).
    // Adhika months carry the 'Adhika_' prefix so regular festivals DO NOT
    // match (e.g. skip May 27).
    return verdict.adhika ? 'Adhika_${verdict.masa}' : verdict.masa;
  }

  static DateTime _noon(DateTime dt) =>
      DateTime(dt.year, dt.month, dt.day, 12);

  /// Memoized verdicts per lunation. All dates (and all intraday checkpoints)
  /// of one lunation share a single verdict — that sharing is load-bearing
  /// for consistency: per-date sampling is what made Adhika flicker between
  /// adjacent days. Bounded; entries are deterministic so eviction only costs
  /// recomputation.
  static const int _maxLunationVerdicts = 8;
  static final Map<String, ({DateTime n1, DateTime n2, bool adhika, String masa})>
      _lunationVerdicts = {};

  /// Adhika verdict for the lunation containing [date].
  /// Mean-motion estimate first (lunations are ~29.2-29.8d apart, so an
  /// estimate within 3d pins exactly one memoized lunation); on a miss,
  /// refine both new moons to their wrap-interpolated instants and sample
  /// the Sun there. The ~14 extra tithi reads happen once per lunation —
  /// later dates (and the Hive masa cache afterwards) pay ~zero.
  Future<({bool adhika, String masa})> _adhikaVerdict(
    DateTime date,
    double rawTithi,
    GeographicLocation location,
  ) async {
    final diffDegrees = (rawTithi - 1) * 12;
    final daysSinceNewMoon = diffDegrees / 12.19074;
    final estPrev = _noon(
      date.subtract(
        Duration(minutes: (daysSinceNewMoon * 1440).round()),
      ),
    );

    for (final entry in _lunationVerdicts.values) {
      if ((entry.n1.difference(estPrev).inHours).abs() <= 72) {
        return (adhika: entry.adhika, masa: entry.masa);
      }
    }

    final n1 = await _refineNewMoonInstant(estPrev, location);
    final n2 = await _refineNewMoonInstant(
      _noon(n1.add(const Duration(days: 29, hours: 12))),
      location,
    );
    // OPT-7: Sun-longitude cache helper avoids redundant FFI calls.
    final sunLongPrev = await _getCachedSunLongitude(n1, location);
    final sunLongNext = await _getCachedSunLongitude(n2, location);
    final verdict = resolveAdhikaVerdict(
      sunLongN1: sunLongPrev,
      sunLongN2: sunLongNext,
    );

    final key =
        '${n1.year}-${n1.month.toString().padLeft(2, '0')}-${n1.day.toString().padLeft(2, '0')}';
    if (_lunationVerdicts.length >= _maxLunationVerdicts) {
      _lunationVerdicts.remove(_lunationVerdicts.keys.first);
    }
    _lunationVerdicts[key] = (
      n1: n1,
      n2: n2,
      adhika: verdict.adhika,
      masa: verdict.masa,
    );
    return verdict;
  }

  /// New-moon instant near [centerNoon], resolved to the second.
  ///
  /// The elapsed Sun-Moon angle is monotone, so the wrap is a plain root: the
  /// shared solver brackets it with daily samples and bisects to a second.
  /// The previous version stopped at ~±3 h after two halving rounds and a
  /// linear interpolation - enough to put a new moon on the wrong side of a
  /// Sankranti and flip the Adhika verdict for the lunation. Falls back to the
  /// noon closest to the new moon when the window holds no wrap (the estimate
  /// is off by more than the search window).
  Future<DateTime> _refineNewMoonInstant(
    DateTime centerNoon,
    GeographicLocation location,
  ) async {
    Future<double> rawTithiAt(DateTime at) => calculateTithi(
      at,
      latitude: location.latitude,
      longitude: location.longitude,
    );

    final solved = await findNewMoonInstant(
      estimate: centerNoon,
      elapsedDegreesAt: (at) async => (await rawTithiAt(at) - 1) * 12,
    );
    if (solved != null) return solved;

    DateTime best = centerNoon;
    double bestScore = double.infinity;
    for (int d = -3; d <= 3; d++) {
      final at = centerNoon.add(Duration(days: d));
      final score = newMoonDistance(await rawTithiAt(at));
      if (score < bestScore) {
        bestScore = score;
        best = at;
      }
    }
    return best;
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

    // BUG-05: single 420-day pass – the redundant brute-force fallback loop
    // is removed. We start from the heuristic estimate (clamped to baseDate)
    // and search forward once. 420 (not 380) covers Adhika-stretched gaps:
    // a lunisolar year is ~354d but an intercalary month pushes same-festival
    // gaps toward ~384d, and a Kshaya-skip year can push further.
    var date = _estimateFestivalSearchStart(baseDate, festival);
    if (date.isBefore(baseDate)) {
      date = baseDate;
    }

    for (int i = 0; i < 420; i++) {
      // One canonical day, projected into the same PanchangData the UI grid
      // matches against, so the scan and the grid cannot disagree about a
      // match. The previous inline copy of sunrise/override/dominant/Kshaya
      // matching was a second definition of a match, and had already drifted:
      // it accepted a sunrise match for a `timingOverride` festival that the
      // grid rejects. A polar day no longer throws here either - the day
      // carries a null sunrise instead.
      Future<bool> matchesOn(DateTime day) async {
        final dayOnly = DateTime(day.year, day.month, day.day);
        final resolved = await PanchangDayResolver(service: this).resolve(
          date: dayOnly,
          place: PanchangPlace(latitude: latitude, longitude: longitude),
          // Only a nakshatra-conditioned festival reads a limb; yoga and
          // karana would be wasted ephemeris reads.
          computeLimbs: festival.nakshatraCondition != null,
          // The scan never shows the daytime transition.
          computeTransition: false,
        );

        // Kshaya and the dominant-grace wrap compare against the next
        // lunation. calculateMasa memoizes per lunation, so this is a cache
        // lookup on all but the first day of each lunation.
        final nextSunrise = resolved.solar.nextSunrise;
        final rawNextSunrise = resolved.checkpointTithis.nextSunrise;
        final masaNextSunrise = nextSunrise != null && rawNextSunrise != null
            ? await calculateMasa(
                nextSunrise,
                rawNextSunrise,
                latitude: latitude,
                longitude: longitude,
              )
            : '';

        final projected = projectPanchangDay(
          resolved,
          festivals: [festival],
          masaNextSunrise: masaNextSunrise,
          nakshatraAtSunrise: resolved.limbs.nakshatra,
        );
        return projected.festivals.isNotEmpty;
      }

      // BUG-04: pass `date` so weekday constraints are evaluated
      if (await matchesOn(date)) {
        // Shared pipeline: a Vriddhi run resolves to first/last/both days so
        // countdown, search, export and notifications agree with the UI grid.
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
          return DateTime(
            resolved.occurrence!.year,
            resolved.occurrence!.month,
            resolved.occurrence!.day,
          );
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

    // No year rollover here: the 420-day forward scan from [baseDate] finds
    // next year's occurrence on its own when this year's has truly passed.
    // Rolling to year+1 when targetMonth < from.month - 1 skipped imminent
    // occurrences whose real lunar date falls 1-2 months AFTER the crude
    // Gregorian approximation (e.g. Bhadrapada ~= Aug but Mahalaya 2026 is
    // Oct 10: on Oct 3 the old code jumped to Aug 2027 and returned the 2027
    // date, flipping the countdown from 7 days to ~362 days). The estimate
    // is only a fast-forward optimization, so it must never start AFTER
    // [from]: an early estimate is clamped up by the caller (safe, just scans
    // more), a late estimate would skip the very occurrence we want.
    // SMELL-14: Subtract 45 days from the Gregorian approximation so that
    // Adhika (intercalary) months — which can shift the real Hindu month ~30
    // days later than the heuristic estimates — are still covered by the
    // caller’s 420-day forward search window.  The caller clamps the result
    // back to [baseDate] if it falls in the past.
    final estimate = DateTime(from.year, targetMonth);
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
    double latitude = kDefaultLatitude,
    double longitude = kDefaultLongitude,
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
    double latitude = kDefaultLatitude,
    double longitude = kDefaultLongitude,
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
