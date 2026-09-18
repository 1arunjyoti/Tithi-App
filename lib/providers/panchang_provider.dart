import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import '../models/festival.dart';
import '../models/hindu_month_system.dart';
import '../models/panchang_data.dart';
import '../services/festival_matching_pipeline.dart';
import '../services/panchang_service.dart';
import '../services/storage_service.dart';
import '../services/sunrise_calculator.dart';
import '../utils/date_utils.dart';
import 'festival_provider.dart';
import 'location_provider.dart';
import 'calendar_provider.dart';

const _panchangLocationSignatureKey = '__location_signature__';

// Sync in-memory cache for selected-date UI (EventList + Paksha).
//
// The adaptive Hindu/Bengali grid publishes its already-resolved, filtered
// day records here. A date tap can then refine only that day's transition
// instead of making panchangForDateProvider start a second, Gregorian-month
// batch. The cache also remains the stale-content fallback while that small
// refinement completes.
final Map<DateTime, PanchangData> _panchangUiCache = {};
const int _panchangUiCacheMax = 100;

DateTime _normalizeUiDate(DateTime d) => DateTime(d.year, d.month, d.day);

/// Last successful [PanchangData] for [date], if any.
PanchangData? cachedPanchangUiSync(DateTime date) {
  return _panchangUiCache[_normalizeUiDate(date)];
}

void storePanchangUiSync(DateTime date, PanchangData data) {
  final normalizedDate = _normalizeUiDate(date);
  final existing = _panchangUiCache[normalizedDate];
  // The adaptive month batch deliberately omits the expensive intraday
  // transition search. Do not replace a previously refined result with that
  // cheaper record when an adaptive grid rebuilds.
  if (existing?.hasTithiTransition == true && !data.hasTithiTransition) {
    data = data.copyWith(
      tithiTransitionTime: existing!.tithiTransitionTime,
      transitionTithiIndex: existing.transitionTithiIndex,
    );
  }
  if (_panchangUiCache.length >= _panchangUiCacheMax) {
    final toRemove =
        _panchangUiCache.keys.take(_panchangUiCacheMax ~/ 5).toList();
    for (final k in toRemove) {
      _panchangUiCache.remove(k);
    }
  }
  _panchangUiCache[normalizedDate] = data;
}

String _dateKey(DateTime date) => panchangDateKey(date);

String _locationSignature(double latitude, double longitude) {
  return '${latitude.toStringAsFixed(4)}_${longitude.toStringAsFixed(4)}';
}

String _cacheKey(
  DateTime date,
  double latitude,
  double longitude, [
  String suffix = '',
]) {
  return '${_dateKey(date)}_${_locationSignature(latitude, longitude)}${suffix.isNotEmpty ? "_$suffix" : ""}';
}

/// Shared preparation for the Hive panchang cache box (also used by the
/// calendar's adaptive cell computation so festival flags skip the
/// single-day transition search).
Future<Box<dynamic>> preparePanchangCacheBox(
  double latitude,
  double longitude,
) async {
  final cacheBox = await StorageService().openPanchangCacheBox();
  final expectedSignature = _locationSignature(latitude, longitude);
  final storedSignature =
      cacheBox.get(_panchangLocationSignatureKey) as String?;

  if (storedSignature != expectedSignature) {
    await cacheBox.clear();
    await cacheBox.put(_panchangLocationSignatureKey, expectedSignature);
  }

  return cacheBox;
}

double? _getCachedRawTithi(
  Box<dynamic> cacheBox,
  DateTime date,
  double latitude,
  double longitude, {
  String suffix = '',
}) {
  final cached = cacheBox.get(_cacheKey(date, latitude, longitude, suffix));
  if (cached is num) {
    return cached.toDouble();
  }
  return null;
}

Future<void> _storeCachedRawTithi(
  Box<dynamic> cacheBox,
  DateTime date,
  double latitude,
  double longitude,
  double rawTithi, {
  String suffix = '',
}) async {
  await cacheBox.put(_cacheKey(date, latitude, longitude, suffix), rawTithi);
}

// ---------------------------------------------------------------------------
// Shared Hive access for the Hindu/Bengali calendar services.
// The monthly batch writes sunrise raw-tithi ('') and sunrise masa ('masa2')
// per date+location; the lunar services read those same entries (and write
// back their own FFI results) so Gregorian usage warms Hindu/Bengali month
// grids and vice versa. Without this sharing, every cold lunar-month slice
// redozens of sequential masa/tithi resolutions (~hundreds of blocking FFI
// calls) while Gregorian month turns read straight from this box.
// ---------------------------------------------------------------------------

/// Suffix of the sunrise-masa entry (versioned: bump when masa attribution
/// logic changes, in lockstep with the batch path's key above).
const String panchangMasaCacheSuffix = 'masa2';

/// Key builder identical to the batch path's (date + 4dp location + suffix).
String panchangCacheKey(
  DateTime date,
  double latitude,
  double longitude, [
  String suffix = '',
]) => _cacheKey(date, latitude, longitude, suffix);

/// Null-safe reads (a wrong-typed entry degrades to a miss, never a throw).
double? readPanchangCacheDouble(Box<dynamic> cacheBox, String key) {
  final cached = cacheBox.get(key);
  return cached is num ? cached.toDouble() : null;
}

/// Null-safe reads (a wrong-typed entry degrades to a miss, never a throw).
String? readPanchangCacheString(Box<dynamic> cacheBox, String key) {
  final cached = cacheBox.get(key);
  return cached is String ? cached : null;
}

// ---------------------------------------------------------------------------
// SMELL-03: Shared computation helpers – eliminate the duplicated 5-point
// tithi calculation block that previously existed in both panchangForDateProvider
// and the computeDateEntry closure inside monthlyPanchangProvider.
// ---------------------------------------------------------------------------

/// Resolves a single raw-tithi value: returns the cached value if present,
/// otherwise computes it via [service] and stores it in [cacheBox].
Future<double> _resolveTithiPoint(
  Box<dynamic> cacheBox,
  DateTime normalizedDate,
  double latitude,
  double longitude,
  PanchangService service,
  DateTime time, {
  String suffix = '',
}) async {
  final cached = _getCachedRawTithi(
    cacheBox, normalizedDate, latitude, longitude,
    suffix: suffix,
  );
  if (cached != null) return cached;
  final computed = await service.calculateTithi(
    time, latitude: latitude, longitude: longitude,
  );
  await _storeCachedRawTithi(
    cacheBox, normalizedDate, latitude, longitude, computed,
    suffix: suffix,
  );
  return computed;
}

/// Locates the first tithi boundary after [sunrise] — i.e. the end of the
/// sunrise (udaya) tithi — within the window ([sunrise], [nextSunrise]].
///
/// [segments] must be time-ordered (time, rawTithi) points starting at
/// [sunrise] and ending at [nextSunrise] (the provider passes its five
/// checkpoints). The first segment straddling the boundary brackets it;
/// bisection via [getRawTithi] then refines it to ~1-minute precision.
///
/// Returns null when no boundary falls in the window (the sunrise tithi
/// still prevails at the next sunrise), or when the refined instant fails
/// validation (wrong tithi just past it, or outside the window) — callers
/// then show the single udaya tithi as before.
///
/// Tithi increases monotonically, so at most the exit from the sunrise
/// tithi is searched even in squeeze cases where two boundaries fall in
/// one window (e.g. Oct 4 2026: Ashtami → Navami → Dashami): surfacing the
/// first one already makes the "lost" tithi (Navami) visible again.
Future<({int toIndex, DateTime at})?> findSunriseTithiTransition({
  required DateTime sunrise,
  required DateTime nextSunrise,
  required double rawTithiAtSunrise,
  required List<({DateTime time, double rawTithi})> segments,
  required Future<double> Function(DateTime time) getRawTithi,
}) async {
  int norm(double raw) => raw.floor().clamp(1, 30);

  final from = norm(rawTithiAtSunrise);
  final to = from % 30 + 1;

  // Ordered, strictly increasing points within [sunrise, nextSunrise].
  final points = segments
      .where((s) => !s.time.isBefore(sunrise) && !s.time.isAfter(nextSunrise))
      .toList()
    ..sort((a, b) => a.time.compareTo(b.time));
  if (points.isEmpty || points.first.time.isAfter(sunrise)) {
    points.insert(0, (time: sunrise, rawTithi: rawTithiAtSunrise));
  }

  // First segment leaving the sunrise tithi brackets the boundary.
  // (Two boundaries can never fall in one short segment: tithis last
  // 19-26h while checkpoint segments span a few hours.)
  DateTime? lo;
  DateTime? hi;
  for (var i = 0; i + 1 < points.length; i++) {
    if (norm(points[i].rawTithi) == from && norm(points[i + 1].rawTithi) != from) {
      lo = points[i].time;
      hi = points[i + 1].time;
      break;
    }
  }
  if (lo == null || hi == null) return null;
  if (!hi.isAfter(sunrise)) return null;
  DateTime low = lo;
  DateTime high = hi;

  // Bisect the exit-from-`from` instant to ~1 minute.
  var guard = 0;
  while (high.difference(low).inMinutes > 1 && guard++ < 60) {
    final mid = low.add(Duration(minutes: high.difference(low).inMinutes ~/ 2));
    if (norm(await getRawTithi(mid)) == from) {
      low = mid;
    } else {
      high = mid;
    }
  }

  // Validate: inside the window, and the expected tithi prevails just after.
  if (!high.isAfter(sunrise) || high.isAfter(nextSunrise)) return null;
  if (norm(await getRawTithi(high.add(const Duration(minutes: 2)))) != to) {
    return null;
  }
  return (toIndex: to, at: high);
}

/// All five intraday tithi checkpoints plus the instants they were sampled at.
///
/// Extracted so the single-day path can reuse the month batch's results:
/// the month map is the single source of truth for festival matches, and the
/// single-day view only resolves the daytime transition on top of it.
typedef TithiCheckpoints = ({
  DateTime sunriseTime,
  DateTime sunsetTime,
  DateTime nextSunriseTime,
  DateTime madhyahnaTime,
  DateTime aparahnaTime,
  DateTime nishitaTime,
  DateTime dominantTime,
  double rawTithi,
  double rawTithiMadhyahna,
  double rawTithiAparahna,
  double rawTithiNishita,
  double rawTithiNextSunrise,
  double rawTithiDominant,
});

/// Resolves the five cached tithi checkpoints for [normalizedDate].
Future<TithiCheckpoints> resolveTithiCheckpoints({
  required DateTime normalizedDate,
  required PanchangService service,
  required double latitude,
  required double longitude,
  required Box<dynamic> cacheBox,
}) async {
  final sunriseTime = SunriseCalculator.calculateSunriseIST(
    date: normalizedDate, latitude: latitude, longitude: longitude,
  );
  final sunsetTime = SunriseCalculator.calculateSunsetIST(
    date: normalizedDate, latitude: latitude, longitude: longitude,
  );
  final nextSunriseTime = SunriseCalculator.calculateSunriseIST(
    date: normalizedDate.add(const Duration(days: 1)),
    latitude: latitude, longitude: longitude,
  );

  final madhyahnaTime = sunriseTime.add(
    Duration(minutes: sunsetTime.difference(sunriseTime).inMinutes ~/ 2),
  );
  final aparahnaTime = sunriseTime.add(
    Duration(minutes: sunsetTime.difference(sunriseTime).inMinutes * 3 ~/ 4),
  );
  final nishitaTime = sunsetTime.add(
    Duration(minutes: nextSunriseTime.difference(sunsetTime).inMinutes ~/ 2),
  );
  // Dominant-tithi checkpoint (Drik grace): the instant up to which a tithi
  // beginning after sunrise still counts for this Gregorian day.
  final dominantTime = sunriseTime.add(kDominantTithiGrace);

  final rawTithi = await _resolveTithiPoint(
    cacheBox, normalizedDate, latitude, longitude, service, sunriseTime,
  );
  final rawTithiMadhyahna = await _resolveTithiPoint(
    cacheBox, normalizedDate, latitude, longitude, service, madhyahnaTime,
    suffix: 'madhyahna',
  );
  final rawTithiAparahna = await _resolveTithiPoint(
    cacheBox, normalizedDate, latitude, longitude, service, aparahnaTime,
    suffix: 'aparahna',
  );
  final rawTithiNishita = await _resolveTithiPoint(
    cacheBox, normalizedDate, latitude, longitude, service, nishitaTime,
    suffix: 'nishita',
  );
  final rawTithiNextSunrise = await _resolveTithiPoint(
    cacheBox, normalizedDate, latitude, longitude, service, nextSunriseTime,
    suffix: 'nextSunrise',
  );
  final rawTithiDominant = await _resolveTithiPoint(
    cacheBox, normalizedDate, latitude, longitude, service, dominantTime,
    suffix: 'dominant',
  );

  return (
    sunriseTime: sunriseTime,
    sunsetTime: sunsetTime,
    nextSunriseTime: nextSunriseTime,
    madhyahnaTime: madhyahnaTime,
    aparahnaTime: aparahnaTime,
    nishitaTime: nishitaTime,
    dominantTime: dominantTime,
    rawTithi: rawTithi,
    rawTithiMadhyahna: rawTithiMadhyahna,
    rawTithiAparahna: rawTithiAparahna,
    rawTithiNishita: rawTithiNishita,
    rawTithiNextSunrise: rawTithiNextSunrise,
    rawTithiDominant: rawTithiDominant,
  );
}

/// Locates the end of the sunrise tithi (first tithi boundary after
/// [checkpoints].sunriseTime) so squeeze cases still surface both tithis.
/// Best-effort — null means the day shows its single udaya tithi as before.
/// Positive results persist in [cacheBox] (same location-scoped keys as the
/// tithi checkpoints) so repeat visits are zero-FFI.
Future<({DateTime? at, int? index})> resolveDayTransition({
  required DateTime normalizedDate,
  required PanchangService service,
  required double latitude,
  required double longitude,
  required Box<dynamic> cacheBox,
  required TithiCheckpoints checkpoints,
}) async {
  final transTimeKey =
      _cacheKey(normalizedDate, latitude, longitude, 'transitionTime');
  final transIndexKey =
      _cacheKey(normalizedDate, latitude, longitude, 'transitionIndex');
  final cachedTime = cacheBox.get(transTimeKey);
  final cachedIndex = cacheBox.get(transIndexKey);
  if (cachedTime is int && cachedIndex is int) {
    final at = DateTime.fromMillisecondsSinceEpoch(cachedTime);
    if (cachedIndex >= 1 &&
        cachedIndex <= 30 &&
        at.isAfter(checkpoints.sunriseTime) &&
        !at.isAfter(checkpoints.nextSunriseTime)) {
      return (at: at, index: cachedIndex);
    }
  }
  try {
    final found = await findSunriseTithiTransition(
      sunrise: checkpoints.sunriseTime,
      nextSunrise: checkpoints.nextSunriseTime,
      rawTithiAtSunrise: checkpoints.rawTithi,
      segments: [
        (time: checkpoints.sunriseTime, rawTithi: checkpoints.rawTithi),
        (time: checkpoints.madhyahnaTime, rawTithi: checkpoints.rawTithiMadhyahna),
        (time: checkpoints.aparahnaTime, rawTithi: checkpoints.rawTithiAparahna),
        (time: checkpoints.nishitaTime, rawTithi: checkpoints.rawTithiNishita),
        (time: checkpoints.nextSunriseTime, rawTithi: checkpoints.rawTithiNextSunrise),
      ],
      getRawTithi: (t) => service.calculateTithi(
        t, latitude: latitude, longitude: longitude,
      ),
    );
    if (found != null) {
      await cacheBox.put(
        transTimeKey,
        found.at.millisecondsSinceEpoch,
      );
      await cacheBox.put(transIndexKey, found.toIndex);
    }
    return (at: found?.at, index: found?.toIndex);
  } catch (e) {
    debugPrint('Tithi transition search skipped: $e');
    return (at: null, index: null);
  }
}

/// Computes [PanchangData] for a single normalised date.
/// All five tithi checkpoints (sunrise, madhyahna, aparahna, nishita,
/// nextSunrise) are resolved through [_resolveTithiPoint] so results are
/// automatically cached to / served from the Hive panchang cache box.
///
/// When [includeTransition] is true, the first tithi boundary after sunrise
/// is also located (via [findSunriseTithiTransition], bracketed by the five
/// checkpoints and refined by bisection) so the day can show two tithis
/// ("Ashtami → Navami"). This costs extra ephemeris calls, so only the
/// single-day path enables it — the month batch leaves it off.
Future<PanchangData> computePanchangData({
  required DateTime normalizedDate,
  required PanchangService service,
  required List<Festival> festivals,
  required HinduMonthSystem monthSystem,
  required double latitude,
  required double longitude,
  required Box<dynamic> cacheBox,
  bool includeTransition = false,
}) async {
  final TithiCheckpoints checkpoints = await resolveTithiCheckpoints(
    normalizedDate: normalizedDate,
    service: service,
    latitude: latitude,
    longitude: longitude,
    cacheBox: cacheBox,
  );
  final sunriseTime = checkpoints.sunriseTime;
  final sunsetTime = checkpoints.sunsetTime;
  final nextSunriseTime = checkpoints.nextSunriseTime;
  final rawTithi = checkpoints.rawTithi;
  final rawTithiMadhyahna = checkpoints.rawTithiMadhyahna;
  final rawTithiAparahna = checkpoints.rawTithiAparahna;
  final rawTithiNishita = checkpoints.rawTithiNishita;
  final rawTithiNextSunrise = checkpoints.rawTithiNextSunrise;
  final rawTithiDominant = checkpoints.rawTithiDominant;

  // PERF-1: Cache masa computation by date to avoid redundant FFI + astronomical
  // calculations. Masa rarely changes between consecutive days.
  // Suffix v2: masa attribution changed (true-new-moon verdicts, then
  // wrap-interpolated + bisected sampling instants). This box otherwise only
  // clears on location change, so old strings would serve stale verdicts
  // forever — bump the suffix again if attribution logic changes.
  final masaCacheKey = _cacheKey(normalizedDate, latitude, longitude, 'masa2');
  final masaNextCacheKey =
      _cacheKey(normalizedDate, latitude, longitude, 'masaNext2');

  var masa = cacheBox.get(masaCacheKey) as String?;
  masa ??= await service.calculateMasa(
    sunriseTime, rawTithi, latitude: latitude, longitude: longitude,
  );
  await cacheBox.put(masaCacheKey, masa);

  var masaNextSunrise = cacheBox.get(masaNextCacheKey) as String?;
  masaNextSunrise ??= await service.calculateMasa(
    nextSunriseTime, rawTithiNextSunrise,
    latitude: latitude, longitude: longitude,
  );
  await cacheBox.put(masaNextCacheKey, masaNextSunrise);

  // Nakshatra at sunrise (for nakshatra-conditioned festivals such as
  // Saraswati Avahan on Mula). Computed only when some festival needs it —
  // otherwise the extra Moon FFI call per day is skipped. Hive-cached like
  // the tithi checkpoints.
  String? nakshatraAtSunrise;
  if (festivals.any((f) => f.nakshatraCondition != null)) {
    final nakKey = _cacheKey(normalizedDate, latitude, longitude, 'nakshatra');
    final cachedNak = cacheBox.get(nakKey);
    if (cachedNak is String && hinduNakshatras.contains(cachedNak)) {
      nakshatraAtSunrise = cachedNak;
    } else {
      nakshatraAtSunrise = await service.calculateNakshatra(
        sunriseTime, latitude: latitude, longitude: longitude,
      );
      if (nakshatraAtSunrise != null) {
        await cacheBox.put(nakKey, nakshatraAtSunrise);
      }
    }
  }

  // Daytime transition (single-day path only): locate the end of the
  // sunrise tithi so squeeze cases (short tithi touching no sunrise)
  // still surface both tithis. Best-effort — a null result simply means
  // the day shows its single udaya tithi as before. Shared with the
  // single-day provider (month batch skips this for speed); see
  // resolveDayTransition.
  DateTime? transitionTime;
  int? transitionIndex;
  if (includeTransition) {
    final found = await resolveDayTransition(
      normalizedDate: normalizedDate,
      service: service,
      latitude: latitude,
      longitude: longitude,
      cacheBox: cacheBox,
      checkpoints: checkpoints,
    );
    transitionTime = found.at;
    transitionIndex = found.index;
  }

  return PanchangData.fromRawTithi(
    date: normalizedDate,
    rawTithi: rawTithi,
    masa: masa,
    allFestivals: festivals,
    monthSystem: monthSystem,
    sunrise: sunriseTime,
    sunset: sunsetTime,
    rawTithiMadhyahna: rawTithiMadhyahna,
    rawTithiAparahna: rawTithiAparahna,
    rawTithiNishita: rawTithiNishita,
    rawTithiNextSunrise: rawTithiNextSunrise,
    masaNextSunrise: masaNextSunrise,
    nakshatraAtSunrise: nakshatraAtSunrise,
    rawTithiDominant: rawTithiDominant,
    tithiTransitionTime: transitionTime,
    transitionTithiIndex: transitionIndex,
  );
}

/// Provider for PanchangService (already exists, re-export)
final panchangServiceProvider = Provider<PanchangService>((ref) {
  return PanchangService();
});

/// Synchronous coordinates provider with Delhi fallback baked in.
final resolvedCoordinatesProvider =
    Provider<({double latitude, double longitude})>((ref) {
      final coords = ref.watch(coordinatesProvider);
      return coords.maybeWhen(
        data: (value) => (latitude: value.latitude, longitude: value.longitude),
        orElse: () => (latitude: 28.6139, longitude: 77.2090),
      );
    });

/// Provider that tracks if the panchang service is initialized
final panchangInitProvider = FutureProvider<void>((ref) async {
  final service = ref.read(panchangServiceProvider);
  await service.init();
});

/// Provider for panchang data of a specific date.
///
/// Single source of truth for festival matches: a Vriddhi-filtered month
/// record. Gregorian views supply it through [monthlyPanchangProvider];
/// Hindu/Bengali adaptive views publish their equivalent resolved record to
/// the UI cache. This provider only resolves the daytime tithi transition on
/// top (the month batches skip that search for speed).
/// On cold start / deep-link the month batch loads first (~30 Hive-cached
/// FFI reads); the direct-compute fallback below runs only if that fails.
final panchangForDateProvider = FutureProvider.autoDispose
    .family<PanchangData, DateTime>((ref, date) async {
      final normalized = DateTime(date.year, date.month, date.day);
      final adaptiveGridEntry = cachedPanchangUiSync(normalized);
      // Ensure service is initialized
      await ref.watch(panchangInitProvider.future);

      final service = ref.read(panchangServiceProvider);
      final coords = ref.watch(resolvedCoordinatesProvider);
      final latitude = coords.latitude;
      final longitude = coords.longitude;
      final cacheBox = await preparePanchangCacheBox(latitude, longitude);

      // Hindu/Bengali adaptive grids have already computed this record,
      // including its Vriddhi-filtered festivals. Reuse it and resolve only
      // the optional intraday transition; requesting monthlyPanchangProvider
      // here would redo an entire Gregorian month on every cold date tap.
      if (adaptiveGridEntry != null) {
        try {
          final checkpoints = await resolveTithiCheckpoints(
            normalizedDate: normalized,
            service: service,
            latitude: latitude,
            longitude: longitude,
            cacheBox: cacheBox,
          );
          final transition = await resolveDayTransition(
            normalizedDate: normalized,
            service: service,
            latitude: latitude,
            longitude: longitude,
            cacheBox: cacheBox,
            checkpoints: checkpoints,
          );
          final data = transition.at == null || transition.index == null
              ? adaptiveGridEntry.copyWith(clearTransition: true)
              : adaptiveGridEntry.copyWith(
                  tithiTransitionTime: transition.at,
                  transitionTithiIndex: transition.index,
                );
          storePanchangUiSync(normalized, data);
          return data;
        } catch (e) {
          // The cached daily record is complete enough for the selected-date
          // UI. A failed optional transition lookup must not fall through to
          // an expensive duplicate month batch.
          debugPrint('Cached single-day transition lookup skipped: $e');
          return adaptiveGridEntry;
        }
      }

      // Ensure festivals are loaded before the cold month/direct paths.
      await ref.watch(festivalInitProvider.future);

      try {
        final monthData = await ref.watch(
          monthlyPanchangProvider(DateTime(normalized.year, normalized.month))
              .future,
        );
        final entry = monthData[normalized];
        if (entry != null) {
          // Month batch skips the transition search: resolve it here for the
          // two-tithi display ("Ashtami → Navami") on squeeze days.
          final checkpoints = await resolveTithiCheckpoints(
            normalizedDate: normalized,
            service: service,
            latitude: latitude,
            longitude: longitude,
            cacheBox: cacheBox,
          );
          final transition = await resolveDayTransition(
            normalizedDate: normalized,
            service: service,
            latitude: latitude,
            longitude: longitude,
            cacheBox: cacheBox,
            checkpoints: checkpoints,
          );
          final data = (transition.at == null || transition.index == null)
              ? entry.copyWith(clearTransition: true)
              : entry.copyWith(
                  tithiTransitionTime: transition.at,
                  transitionTithiIndex: transition.index,
                );
          // Feed the stale-UI LRU so date taps render instantly next time.
          storePanchangUiSync(date, data);
          return data;
        }
      } catch (e) {
        debugPrint('Month-map single-day lookup failed, falling back: $e');
      }

      final festivals = ref.read(festivalProvider);
      final monthSystem = ref.watch(hinduMonthSystemProvider);
      final data = await computePanchangData(
        normalizedDate: normalized,
        service: service,
        festivals: festivals,
        monthSystem: monthSystem,
        latitude: latitude,
        longitude: longitude,
        cacheBox: cacheBox,
        // Single-day detail: also locate the daytime tithi transition so
        // squeeze cases show two tithis (month batch skips this for speed).
        // NOTE: this fallback path is unfiltered for Vriddhi; it runs only
        // when the month map itself failed to load.
        includeTransition: true,
      );
      // Feed the stale-UI LRU so date taps render instantly next time.
      storePanchangUiSync(date, data);
      return data;
    });

/// Provider for today's panchang.
/// Watches [todayDateProvider] so it automatically refreshes at midnight
/// without requiring an app restart (BUG-03 fix).
final todayPanchangProvider = FutureProvider<PanchangData>((ref) async {
  final today = ref.watch(todayDateProvider);
  return ref.watch(panchangForDateProvider(today).future);
});

/// Provider for current paksha (for theming)
final currentPakshaProvider = Provider<AsyncValue<String>>((ref) {
  return ref.watch(todayPanchangProvider).whenData((data) => data.paksha);
});

bool _isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// Current-time source for live-tithi evaluation. Defaults to the wall
/// clock; tests override it with a fixed instant to simulate boundary
/// crossings deterministically (widget-test pumps advance fake timers but
/// not the wall clock, so time-travel assertions need this seam).
final liveNowProvider = Provider<DateTime>((ref) => DateTime.now());

/// Intraday tithi-change ticker for the live hero.
///
/// Watches today's single-day record and arms a single one-shot [Timer] for
/// the next tithi boundary strictly in the future (transition instant, or —
/// once flipped — the follow-on end of the incoming tithi on kshaya days,
/// resolved through [tithiTimingsProvider] only then). Firing bumps the
/// tick so [livePanchangProvider] relabels; the timer is cancelled and
/// re-armed on every rebuild (date tap, midnight rollover, reload).
/// Dormant while browsing non-today dates and on boundary-free (vriddhi)
/// days. No polling, no FFI at fire time for the common single flip.
class LiveTithiTickNotifier extends AutoDisposeNotifier<int> {
  Timer? _timer;
  int _tick = 0;

  /// Grace after a boundary before flipping, mirroring the midnight
  /// refresh's +1s: the stored instant is minute-precise, so firing
  /// marginally late guarantees `now` compares past it.
  static const _flipGrace = Duration(seconds: 1);

  @override
  int build() {
    ref.onDispose(() {
      _timer?.cancel();
      _timer = null;
    });
    final selected = ref.watch(selectedDateProvider);
    final today = ref.watch(todayDateProvider);
    _timer?.cancel();
    _timer = null;
    if (!_isSameDay(selected, today)) return _tick;

    final day = ref.watch(panchangForDateProvider(today)).valueOrNull;
    if (day == null ||
        !day.hasTithiTransition ||
        day.tithiTransitionTime == null) {
      return _tick;
    }
    final now = ref.watch(liveNowProvider);
    final transitionTime = day.tithiTransitionTime!;
    if (now.isBefore(transitionTime)) {
      _arm(transitionTime, now);
      return _tick;
    }
    // Already flipped: chain onto the incoming tithi's end when it is a
    // second INTRADAY boundary (kshaya squeeze). A normal next-day end
    // falls past tomorrow's sunrise and arms nothing — midnight rollover
    // owns the date change.
    final transitionIndex = day.transitionTithiIndex;
    if (transitionIndex == null) return _tick;
    final coords = ref.watch(resolvedCoordinatesProvider);
    final followOnEnd = ref
        .watch(
          tithiTimingsProvider((
            date: day.date,
            tithiIndex: transitionIndex,
            latitude: coords.latitude,
            longitude: coords.longitude,
          )),
        )
        .valueOrNull
        ?.end;
    if (followOnEnd == null) return _tick;
    final nextSunrise = SunriseCalculator.calculateSunriseIST(
      date: day.date.add(const Duration(days: 1)),
      latitude: coords.latitude,
      longitude: coords.longitude,
    );
    if (followOnEnd.isAfter(transitionTime) &&
        followOnEnd.isAfter(now) &&
        followOnEnd.isBefore(nextSunrise)) {
      _arm(followOnEnd, now);
    }
    return _tick;
  }

  void _arm(DateTime instant, DateTime now) {
    final delay = instant.difference(now) + _flipGrace;
    if (delay.isNegative) return;
    _timer = Timer(delay, () {
      _tick++;
      state = _tick;
    });
  }
}

final liveTithiTickProvider =
    NotifierProvider.autoDispose<LiveTithiTickNotifier, int>(
      LiveTithiTickNotifier.new,
    );

/// Day record with the displayed label advanced to the tithi prevailing
/// right now ([PanchangData.withLiveLabel]) — but only for today. Browsed
/// dates stay frozen on their sunrise labels. Festivals, masa and the
/// sunrise record are preserved untouched (sunrise pinning), so only the
/// label — title, timings queries keyed by it, hero chip — goes live.
///
/// The kshaya follow-on boundary is resolved here (same [tithiTimingsProvider]
/// instance the tick provider watches, so one lookup serves both) and only
/// once flipped; pre-flip this costs zero extra FFI.
final livePanchangProvider = FutureProvider.autoDispose
    .family<PanchangData, DateTime>((ref, day) async {
      ref.watch(liveTithiTickProvider);
      final base = await ref.watch(panchangForDateProvider(day).future);
      final today = ref.watch(todayDateProvider);
      if (!_isSameDay(day, today)) return base;
      final now = ref.watch(liveNowProvider);
      DateTime? followOnTime;
      int? followOnIndex;
      if (base.hasTithiTransition &&
          base.tithiTransitionTime != null &&
          base.transitionTithiIndex != null &&
          !now.isBefore(base.tithiTransitionTime!)) {
        // Best-effort: a failing ephemeris lookup here must never take down
        // the hero — the first flip needs zero FFI, so degrade to it.
        try {
          final coords = ref.watch(resolvedCoordinatesProvider);
          final timings = await ref.watch(
            tithiTimingsProvider((
              date: base.date,
              tithiIndex: base.transitionTithiIndex!,
              latitude: coords.latitude,
              longitude: coords.longitude,
            )).future,
          );
          final nextSunrise = SunriseCalculator.calculateSunriseIST(
            date: base.date.add(const Duration(days: 1)),
            latitude: coords.latitude,
            longitude: coords.longitude,
          );
          if (timings != null &&
              timings.end.isAfter(base.tithiTransitionTime!) &&
              timings.end.isBefore(nextSunrise)) {
            followOnTime = timings.end;
            followOnIndex = base.transitionTithiIndex! % 30 + 1;
          }
        } catch (_) {
          // Follow-on stays unresolved: label holds the flipped-to tithi.
        }
      }
      return base.withLiveLabel(
        now,
        followOnTime: followOnTime,
        followOnIndex: followOnIndex,
      );
    });

/// Batch provider for monthly panchang data
/// Pre-loads entire month to eliminate N+1 query pattern in calendar.
/// autoDispose with a 5-minute keepAlive: TableCalendar swipes back/forth
/// between the same 2-3 months, so recently visited/precached months stay
/// warm for instant landing instead of recomputing ~210 FFI calls — but
/// each entry holds ~42 PanchangData, so idle months are released rather
/// than retained for the whole session (unbounded family growth).
final monthlyPanchangProvider = FutureProvider.autoDispose
    .family<Map<DateTime, PanchangData>, DateTime>((ref, focusedMonth) async {
      final keepAliveLink = ref.keepAlive();
      final releaseTimer = Timer(
        const Duration(minutes: 5),
        keepAliveLink.close,
      );
      ref.onDispose(releaseTimer.cancel);

      // Ensure service is initialized
      await ref.watch(panchangInitProvider.future);
      await ref.watch(festivalInitProvider.future);

      final service = ref.read(panchangServiceProvider);
      final festivals = ref.read(festivalProvider);
      final monthSystem = ref.watch(hinduMonthSystemProvider);

      final coords = ref.watch(resolvedCoordinatesProvider);
      final latitude = coords.latitude;
      final longitude = coords.longitude;
      final cacheBox = await preparePanchangCacheBox(latitude, longitude);

      // Generate dates for the entire month view (including previous/next month overflow)
      final firstDayOfMonth = DateTime(focusedMonth.year, focusedMonth.month);
      final lastDayOfMonth = DateTime(
        focusedMonth.year,
        focusedMonth.month + 1,
        0,
      );

      // Include days from previous month to fill first week
      final startDate = firstDayOfMonth.subtract(
        Duration(days: firstDayOfMonth.weekday % 7),
      );
      // Include days from next month to fill last week
      final endDate = lastDayOfMonth.add(
        Duration(days: 7 - (lastDayOfMonth.weekday % 7)),
      );

      // Grid dates are derived from [startDate]/[endDate] below; the
      // computation set is padded by 2 days for Vriddhi edge runs.
      const batchSize = 8;
      // Full computation map, padded by 2 days on each side: Vriddhi runs
      // can straddle the grid edge, and trimming a run without its neighbor
      // would keep the wrong day. Padding days are Hive-cached, so the cost
      // is ~zero on repeat visits. Only grid dates are returned.
      final fullData = <DateTime, PanchangData>{};

      Future<MapEntry<DateTime, PanchangData>> computeDateEntry(
        DateTime normalizedDate,
      ) async {
        return MapEntry(
          normalizedDate,
          await computePanchangData(
            normalizedDate: normalizedDate,
            service: service,
            festivals: festivals,
            monthSystem: monthSystem,
            latitude: latitude,
            longitude: longitude,
            cacheBox: cacheBox,
          ),
        );
      }

      final paddedStart = startDate.subtract(const Duration(days: 2));
      final paddedEnd = endDate.add(const Duration(days: 2));
      final allDates = <DateTime>[];
      for (
        var date = paddedStart;
        date.isBefore(paddedEnd) || date.isAtSameMomentAs(paddedEnd);
        date = date.add(const Duration(days: 1))
      ) {
        allDates.add(DateTime(date.year, date.month, date.day));
      }

      for (var i = 0; i < allDates.length; i += batchSize) {
        final end = (i + batchSize) > allDates.length
            ? allDates.length
            : i + batchSize;
        final batch = allDates.sublist(i, end);
        final entries = await Future.wait(batch.map(computeDateEntry));
        for (final entry in entries) {
          fullData[entry.key] = entry.value;
        }
      }

      // Single code path for Vriddhi trimming: the month map (padded) is
      // filtered once here; every consumer reads the filtered result.
      final filtered = applyVriddhiFilter(fullData);
      final monthData = <DateTime, PanchangData>{};
      for (
        var date = startDate;
        date.isBefore(endDate) || date.isAtSameMomentAs(endDate);
        date = date.add(const Duration(days: 1))
      ) {
        final key = DateTime(date.year, date.month, date.day);
        final value = filtered[key];
        if (value != null) monthData[key] = value;
      }

      return monthData;
    });

/// Provider to calculate the exact start and end times for a specific Tithi on-demand.
/// [tithiIndex] is the full 1-30 tithi index (1-15 = Shukla, 16-30 = Krishna),
/// i.e. the festival's OBSERVED tithi ([Festival.resolveTithiIndex]) — which
/// can differ from the day's sunrise tithi when a timingOverride applies.
/// NOTE: do NOT pass the 1-15 paksha-relative [PanchangData.tithiNumber] here —
/// doing so silently resolves Krishna tithis to the wrong (Shukla) fortnight.
///
/// Returns null when the tithi has no occurrence near [date] (Kshaya /
/// skipped tithi): the nearest occurrence would belong to another lunation,
/// so callers must hide timings instead of showing a wrong-month span.
final tithiTimingsProvider =
    FutureProvider.family<
      ({DateTime start, DateTime end})?,
      ({DateTime date, int tithiIndex, double latitude, double longitude})
    >((ref, params) async {
      final service = ref.read(panchangServiceProvider);
      if (!service.isInitialized) {
        await service.init();
      }

      // Calculate start and end times via binary search in the native service
      final startTime = await service.calculateTithiStartTime(
        params.date,
        params.tithiIndex,
        latitude: params.latitude,
        longitude: params.longitude,
      );

      final endTime = await service.calculateTithiEndTime(
        params.date,
        params.tithiIndex,
        latitude: params.latitude,
        longitude: params.longitude,
      );

      // Guard: a tithi lasts <26h, so a span starting/ending more than 2
      // days from the festival day belongs to another lunation (Kshaya).
      if (startTime.difference(params.date).inDays.abs() > 2 ||
          endTime.difference(params.date).inDays.abs() > 2) {
        return null;
      }

      return (start: startTime, end: endTime);
    });
