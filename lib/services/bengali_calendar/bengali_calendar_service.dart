import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jyotish/jyotish.dart';
import '../../providers/panchang_provider.dart';
import '../sunrise_calculator.dart';
import 'bengali_calendar_data.dart';

final bengaliCalendarServiceProvider = Provider<BengaliCalendarService>((ref) {
  return BengaliCalendarService(ref);
});

/// Native implementation of Bengali Calendar Service
/// Uses FFI-based Swiss Ephemeris for accurate calculations.
///
/// West Bengal rule (Bisuddha Siddhanta / Drik): each solar month begins the
/// day AFTER its sankranti calendar date (sunrise-to-midnight -> next day,
/// after-midnight -> day-after-next from the effective day; both collapse to
/// sankranti-date + 1 in calendar terms).
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

  /// Month-start cache keyed by sankranti gregorian year + month index (+
  /// rounded coords). Solar months are 29-32 days, so a cached start plus a
  /// range/month check lets every other day of the same month skip the
  /// ~18-FFI sankranti resolution entirely.
  static final Map<String, DateTime> _monthStartCache = {};
  static const int _maxMonthStartCache = 24;
  static final BengaliCalendarDateCache _dateCache = BengaliCalendarDateCache(
    maxEntries: 600,
  );

  static String _cacheKey(
    int monthIndex,
    int gregYear,
    double latitude,
    double longitude,
  ) {
    return '${latitude.toStringAsFixed(1)}_${longitude.toStringAsFixed(1)}_${monthIndex}_$gregYear';
  }

  static void _storeMonthStart(String key, DateTime monthStart) {
    if (_monthStartCache.length >= _maxMonthStartCache) {
      _monthStartCache.remove(_monthStartCache.keys.first);
    }
    _monthStartCache[key] = monthStart;
  }

  Future<double> _sunLongitude(
    DateTime instant,
    GeographicLocation location,
  ) async {
    final pos = await Jyotish().getPlanetPosition(
      planet: Planet.sun,
      dateTime: instant,
      location: location,
    );
    return pos.longitude;
  }

  /// Relative longitude of [sunLng] past [boundary], in [0, 360).
  /// Current sign -> [0, 30); previous sign -> [330, 360).
  static double _relPastBoundary(double sunLng, double boundary) {
    return (sunLng - boundary + 360) % 360;
  }

  /// Calculates the Bengali Date (West Bengal System) using Sun's position.
  /// Returns a record ({int day, String month, int year}).
  Future<BengaliCalendarDate> calculateDate(
    DateTime date, {
    double latitude = 22.5726, // Kolkata
    double longitude = 88.3639,
  }) async {
    // Calendar-day normalization. The Bengali day runs sunrise->sunrise
    // (guide Sec 3.5): an intraday time before today's sunrise still belongs
    // to the previous Bengali day. Exact-midnight inputs (calendar cells)
    // are treated as that calendar date with no shift.
    var normalized = DateTime(date.year, date.month, date.day);
    final hasTime = date.hour != 0 || date.minute != 0 || date.second != 0;
    if (hasTime) {
      final sunrise = SunriseCalculator.calculateSunriseIST(
        date: normalized,
        latitude: latitude,
        longitude: longitude,
      );
      if (date.isBefore(sunrise)) {
        normalized = normalized.subtract(const Duration(days: 1));
      }
    }

    final dateCacheKey = bengaliCalendarDateCacheKey(
      normalized,
      latitude,
      longitude,
    );
    final cached = _dateCache.read(dateCacheKey);
    if (cached != null) return cached;

    // Ensure core service is initialized only for a cache miss.
    await _ref.read(panchangInitProvider.future);

    final location = GeographicLocation(
      latitude: latitude,
      longitude: longitude,
    );

    // Query at local noon for a stable rashi (midnight queries flip early
    // near a sankranti).
    final noon = DateTime(
      normalized.year,
      normalized.month,
      normalized.day,
      12,
    );

    // Get Sun's current position to determine current Month
    final double lng = await _sunLongitude(noon, location);

    // Month Index: 0=Boishakh (Mesha/Aries) .. 11=Choitro (Meena/Pisces).
    // Note: Jyotish returns Nirayana (Sidereal) Longitude.
    // Aries starts at 0 degrees.
    final int monthIndex = (lng / 30).floor() % 12;

    final monthStart = await _monthStartFor(
      monthIndex: monthIndex,
      noon: noon,
      sunLngNow: lng,
      normalized: normalized,
      location: location,
    );

    // Day within the solar month (1-based).
    int day = normalized.difference(monthStart).inDays + 1;
    // Defensive: never wrap to 1 (that hid the old Boishakh 5..32 drift).
    // A value outside 1..32 means resolution failed; clamp to the edge so
    // the error stays visible instead of silently restarting the month.
    if (day < 1) day = 1;
    if (day > 32) day = 32;

    // Bangabda year from the resolved month start (handles Poush spanning
    // Dec->Jan: Jan tail days still resolve to the December start, hence the
    // previous gregorian year). Boishakh..Poush (0..8) -> start.year - 593,
    // Magh..Choitro (9..11) -> start.year - 594.
    final int bengaliYear = monthStart.year - (monthIndex <= 8 ? 593 : 594);

    final result = (
      day: day,
      month: bengaliMonths[monthIndex],
      year: bengaliYear,
    );
    _dateCache.store(dateCacheKey, result);
    return result;
  }

  /// Cached-or-resolved month start for [monthIndex] containing [noon].
  ///
  /// Cache is keyed by sankranti gregorian year. Months spanning Jan 1
  /// (Poush Dec->Jan) miss on [noon.year], so the previous-year entry is
  /// tried too and accepted only when [normalized] falls inside its
  /// 29..32-day span (month index already matches by construction).
  Future<DateTime> _monthStartFor({
    required int monthIndex,
    required DateTime noon,
    required double sunLngNow,
    required DateTime normalized,
    required GeographicLocation location,
  }) async {
    final lat = location.latitude;
    final lon = location.longitude;

    DateTime? accept(DateTime? candidate) {
      if (candidate == null) return null;
      final start = candidate; // midnight local
      if (normalized.isBefore(start)) return null;
      // Solar months are 29-32 days; 32 is a safe exclusive upper bound
      // combined with the monthIndex match (the caller derived monthIndex
      // from the Sun at noon, so a stale entry from 2+ months back whose
      // span happens to overlap is rejected by the month check upstream --
      // here the key already pins monthIndex).
      if (normalized.difference(start).inDays >= 32) return null;
      return start;
    }

    final hit = accept(
      _monthStartCache[_cacheKey(monthIndex, noon.year, lat, lon)],
    );
    if (hit != null) return hit;
    final prevHit = accept(
      _monthStartCache[_cacheKey(monthIndex, noon.year - 1, lat, lon)],
    );
    if (prevHit != null) return prevHit;

    final resolved = await _resolveMonthStart(
      monthIndex: monthIndex,
      noon: noon,
      sunLngNow: sunLngNow,
      location: location,
    );
    _storeMonthStart(_cacheKey(monthIndex, resolved.year, lat, lon), resolved);
    return resolved;
  }

  /// Finds Boishakh-1-style month start: bracket the sankranti between two
  /// local noons (estimate from degrees-in-sign, +/-3d scan), bisect the
  /// ~24h window to ~20s, then apply the Bengal rule (month starts the day
  /// after the sankranti calendar date).
  Future<DateTime> _resolveMonthStart({
    required int monthIndex,
    required DateTime noon,
    required double sunLngNow,
    required GeographicLocation location,
  }) async {
    final double boundary = monthIndex * 30.0;
    final double degInSign = _relPastBoundary(sunLngNow, boundary);

    // Guard: callers must pass a noon whose Sun is inside [boundary,
    // boundary+30). A mismatched boundary (e.g. getMonthStart probing a
    // neighbouring month) yields degInSign up to ~359, which would shoot
    // the estimate ~a year off and poison the month grid (blank/huge
    // months). Fall back to scanning around noon in that case.
    final bool estimateValid = degInSign < 35;
    // Mean sun motion ~0.9856 deg/day.
    final estIngressNoon = estimateValid
        ? noon.subtract(Duration(minutes: (degInSign / 0.9856 * 1440).round()))
        : noon;
    final estNoon = DateTime(
      estIngressNoon.year,
      estIngressNoon.month,
      estIngressNoon.day,
      12,
    );

    // Bracket: consecutive noons straddling the boundary.
    DateTime? beforeNoon;
    DateTime? afterNoon;
    for (int d = -3; d <= 3; d++) {
      final a = estNoon.add(Duration(days: d));
      final b = a.add(const Duration(days: 1));
      final relA = _relPastBoundary(await _sunLongitude(a, location), boundary);
      if (relA <= 180) continue; // already in the new sign
      final relB = _relPastBoundary(await _sunLongitude(b, location), boundary);
      if (relB <= 180 && relB < 32) {
        beforeNoon = a;
        afterNoon = b;
        break;
      }
    }

    // Fallback: full backward scan (up to one max-length month) from noon.
    if (beforeNoon == null || afterNoon == null) {
      DateTime cursor = noon;
      double relCursor = _relPastBoundary(
        await _sunLongitude(cursor, location),
        boundary,
      );
      // If noon itself is somehow pre-ingress (shouldn't happen since
      // monthIndex came from this noon), step forward instead.
      if (relCursor > 180) {
        for (int i = 1; i <= 35; i++) {
          cursor = noon.add(Duration(days: i));
          relCursor = _relPastBoundary(
            await _sunLongitude(cursor, location),
            boundary,
          );
          if (relCursor <= 180) {
            afterNoon = cursor;
            beforeNoon = cursor.subtract(const Duration(days: 1));
            break;
          }
          // Let gestures/frames interleave during long FFI scans.
          if (i % 8 == 0) await Future<void>.delayed(Duration.zero);
        }
      } else {
        for (int i = 0; i < 35; i++) {
          final prev = cursor.subtract(const Duration(days: 1));
          final relPrev = _relPastBoundary(
            await _sunLongitude(prev, location),
            boundary,
          );
          if (relPrev > 180) {
            beforeNoon = prev;
            afterNoon = cursor;
            break;
          }
          cursor = prev;
          // Let gestures/frames interleave during long FFI scans.
          if (i % 8 == 7) await Future<void>.delayed(Duration.zero);
        }
      }
    }

    if (beforeNoon == null || afterNoon == null) {
      // Last resort: historic approximation (Apr 14 anchor). Day numbers
      // may be off by ~1 but never 5..32.
      final approx = noon.subtract(Duration(days: degInSign ~/ 1));
      return DateTime(approx.year, approx.month, approx.day);
    }

    // Bisect to ~20s (24h / 2^12).
    var lo = beforeNoon;
    var hi = afterNoon;
    for (int i = 0; i < 12; i++) {
      final mid = DateTime.fromMillisecondsSinceEpoch(
        (lo.millisecondsSinceEpoch + hi.millisecondsSinceEpoch) ~/ 2,
      );
      final relMid = _relPastBoundary(
        await _sunLongitude(mid, location),
        boundary,
      );
      if (relMid > 180) {
        lo = mid;
      } else {
        hi = mid;
      }
    }

    // Bengal rule: month starts the day after the sankranti calendar date.
    final sankrantiDay = DateTime(hi.year, hi.month, hi.day);
    final monthStart = sankrantiDay.add(const Duration(days: 1));
    // Sanity: the start of the month containing `noon` must lie within
    // (noon - 32d, noon]. Anything else is a mis-resolution (e.g. a
    // neighbouring-month probe) — return the noon-anchored fallback so the
    // calendar grid stays bounded instead of going blank/huge.
    if (monthStart.isAfter(noon)) {
      final fallback = DateTime(noon.year, noon.month, noon.day);
      return fallback;
    }
    if (noon.difference(monthStart).inDays >= 32) {
      final fallback = DateTime(noon.year, noon.month, noon.day);
      return fallback;
    }
    return monthStart;
  }

  /// returns the Gregorian Date for the 1st of the given Bengali Month/Year
  ///
  /// Bounded sweep around the 15th anchor: finds the day reading back as
  /// day 1 of [monthIndex] via [calculateDate] (which itself is cached).
  /// Never returns a date more than ~3 weeks from the anchor, so the
  /// calendar grid can never go blank/huge from a year-jump mis-resolution.
  Future<DateTime> getMonthStart(int bengaliYear, int monthIndex) async {
    // 1. Approximate Gregorian Start
    int gYear = bengaliYear + (monthIndex <= 8 ? 593 : 594);

    const lat = 22.5726;
    const lon = 88.3639;
    final directHit = _monthStartCache[_cacheKey(monthIndex, gYear, lat, lon)];
    if (directHit != null) return directHit;

    int gMonth = 4 + monthIndex;
    if (gMonth > 12) gMonth -= 12;

    final DateTime estimate = DateTime(gYear, gMonth, 15);

    // 2. Refine: sweep around the anchor for day 1 of the requested month.
    DateTime search = estimate.subtract(const Duration(days: 8));

    for (int i = 0; i < 22; i++) {
      DateTime cand;
      try {
        cand = DateTime(search.year, search.month, search.day);
      } catch (_) {
        search = search.add(const Duration(days: 1));
        continue;
      }
      try {
        final bDate = await calculateDate(cand);
        final bMonthIndex = _getBengaliMonthIndex(bDate.month);
        if (bMonthIndex == monthIndex && bDate.day == 1) {
          return cand;
        }
      } catch (_) {
        // Best-effort sweep; keep looking.
      }
      search = search.add(const Duration(days: 1));
      // Let gestures/frames interleave during long FFI scans.
      if (i % 8 == 7) await Future<void>.delayed(Duration.zero);
    }

    return estimate; // Fallback (bounded — keeps the grid sane).
  }

  int _getBengaliMonthIndex(String name) {
    // Alias-aware (guide spellings + legacy 'Jyoishtho'/'Agrahayan'/...
    // + Sanskrit), so older strings still resolve instead of -1.
    final i = bengaliMonthIndexOf(name);
    return i >= 0 ? i : bengaliMonths.indexOf(name);
  }
}
