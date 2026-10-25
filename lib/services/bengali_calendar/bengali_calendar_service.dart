import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jyotish/jyotish.dart';
import '../../providers/panchang_provider.dart';
import '../solar_events_service.dart';
import 'bengali_calendar_data.dart';
import 'bengali_month_start.dart';

final bengaliCalendarServiceProvider = Provider<BengaliCalendarService>((ref) {
  return BengaliCalendarService(ref);
});

/// Bengali Calendar Service.
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
      final sunrise = solarEventsService.sunrise(
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

    final month = await _monthStartFor(
      monthIndex: monthIndex,
      noon: noon,
      sunLngNow: lng,
      normalized: normalized,
      location: location,
    );

    // Day within the solar month (1-based).
    int day = normalized.difference(month.start).inDays + 1;
    // Defensive: never wrap to 1 (that hid the old Boishakh 5..32 drift).
    // A value outside 1..32 means resolution failed; clamp to the edge so
    // the error stays visible instead of silently restarting the month.
    if (day < 1) day = 1;
    if (day > 32) day = 32;

    // Bangabda year from the resolved month start (handles Poush spanning
    // Dec->Jan: Jan tail days still resolve to the December start, hence the
    // previous gregorian year). Boishakh..Poush (0..8) -> start.year - 593,
    // Magh..Choitro (9..11) -> start.year - 594.
    //
    // [month.index] can differ from the noon's rashi: on the sankranti civil
    // day the Sun is already in the new sign while the Bengal rule still puts
    // the day in the outgoing month (see `_resolveMonthStart`).
    final int bengaliYear =
        month.start.year - (month.index <= 8 ? 593 : 594);

    final result = (
      day: day,
      month: bengaliMonths[month.index],
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
  ///
  /// The returned [index] can be the month before [monthIndex] when [noon]
  /// falls on the sankranti civil day: the Bengal rule gives that day to the
  /// outgoing month, so the answer is the previous month's start.
  Future<({int index, DateTime start})> _monthStartFor({
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
    if (hit != null) return (index: monthIndex, start: hit);
    final prevHit = accept(
      _monthStartCache[_cacheKey(monthIndex, noon.year - 1, lat, lon)],
    );
    if (prevHit != null) return (index: monthIndex, start: prevHit);

    final resolved = await _resolveMonthStart(
      monthIndex: monthIndex,
      noon: noon,
      sunLngNow: sunLngNow,
      location: location,
    );
    // Store under the resolved index: on the sankranti day that is the
    // outgoing month, and the next call for that month must hit this entry.
    _storeMonthStart(
      _cacheKey(resolved.index, resolved.start.year, lat, lon),
      resolved.start,
    );
    return resolved;
  }

  /// Finds Boishakh-1-style month start: solve the Sankranti to a second with
  /// the shared crossing solver, then apply the Bengal rule (the month starts
  /// the day after the Sankranti calendar date).
  ///
  /// Returns the month the civil day containing [noon] belongs to, which is
  /// not always [monthIndex]: the Sun enters the new sign before the Bengal
  /// month starts, so the Sankranti civil day belongs to the outgoing month.
  /// In that case the previous month's start is resolved and returned with
  /// its own index (e.g. 2026-04-14 is Choitro 30, 1432, not Boishakh 1).
  ///
  /// Delegates to [resolveBengaliMonthStart], which owns the estimate, the
  /// 35-day guard scan and the loud failure when neither can find an ingress.
  Future<({int index, DateTime start})> _resolveMonthStart({
    required int monthIndex,
    required DateTime noon,
    required double sunLngNow,
    required GeographicLocation location,
    bool allowMonthBacktrack = true,
  }) {
    return resolveBengaliMonthStart(
      monthIndex: monthIndex,
      noon: noon,
      sunLngNow: sunLngNow,
      sunLongitudeAt: (instant) => _sunLongitude(instant, location),
      allowMonthBacktrack: allowMonthBacktrack,
    );
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
