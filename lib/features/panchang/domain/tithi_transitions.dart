import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

import '../../../models/festival.dart';
import '../../../models/hindu_month_system.dart';
import '../../../models/panchang_data.dart';
import '../../../services/panchang_service.dart';
import '../data/panchang_cache.dart';
import 'panchang_day.dart';
import 'panchang_day_resolver.dart';
import 'root_solver.dart';

// ---------------------------------------------------------------------------
// Shared computation helpers – formerly SMELL-03 block inside
// providers/panchang_provider.dart (duplicated 5-point tithi calculation).
// Pure domain logic: no Riverpod refs, testable in isolation.
// ---------------------------------------------------------------------------

/// Resolves a single raw-tithi value: returns the cached value if present,
/// otherwise computes it via [service] and stores it in [cacheBox].
Future<double> resolveTithiPoint(
  Box<dynamic> cacheBox,
  DateTime normalizedDate,
  double latitude,
  double longitude,
  PanchangService service,
  DateTime time, {
  String suffix = '',
}) async {
  final cached = getCachedRawTithi(
    cacheBox,
    normalizedDate,
    latitude,
    longitude,
    suffix: suffix,
  );
  if (cached != null) return cached;
  final computed = await service.calculateTithi(
    time,
    latitude: latitude,
    longitude: longitude,
  );
  await storeCachedRawTithi(
    cacheBox,
    normalizedDate,
    latitude,
    longitude,
    computed,
    suffix: suffix,
  );
  return computed;
}

/// Locates the first tithi boundary after [sunrise] — i.e. the end of the
/// sunrise (udaya) tithi — within the window ([sunrise], [nextSunrise]].
///
/// [segments] must be time-ordered (time, rawTithi) points starting at
/// [sunrise] and ending at [nextSunrise]. Returns null when no boundary
/// falls in the window or validation fails — callers show the single udaya
/// tithi as before.
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

  final points = segments
      .where((s) => !s.time.isBefore(sunrise) && !s.time.isAfter(nextSunrise))
      .toList()
    ..sort((a, b) => a.time.compareTo(b.time));
  if (points.isEmpty || points.first.time.isAfter(sunrise)) {
    points.insert(0, (time: sunrise, rawTithi: rawTithiAtSunrise));
  }

  DateTime? lo;
  DateTime? hi;
  for (var i = 0; i + 1 < points.length; i++) {
    if (norm(points[i].rawTithi) == from &&
        norm(points[i + 1].rawTithi) != from) {
      lo = points[i].time;
      hi = points[i + 1].time;
      break;
    }
  }
  if (lo == null || hi == null) return null;
  if (!hi.isAfter(sunrise)) return null;

  // The boundary is the elapsed angle reaching `from * 12` degrees (tithi n
  // spans [(n-1)*12, n*12); tithi 30 wraps to 0). Solved to the second instead
  // of the old 1-minute bisection, so the sheet's countdown cannot be a minute
  // stale.
  final solved = await solveAngleCrossing(
    before: lo,
    after: hi,
    valueAt: (time) async => (await getRawTithi(time) - 1) * 12,
    target: (from % 30) * 12.0,
  );
  if (solved == null) return null;

  if (!solved.isAfter(sunrise) || solved.isAfter(nextSunrise)) return null;
  if (norm(await getRawTithi(solved.add(const Duration(minutes: 2)))) != to) {
    return null;
  }
  return (toIndex: to, at: solved);
}

/// All intraday tithi checkpoints plus the instants they were sampled at.
/// Pradosha samples its window midpoint (sunset + N/10). Nishita samples both
/// edges of its window (`sunset + 7/15 night` and `+ 8/15 night`), because the
/// observance rule is "the tithi at the opening, or one still current at the
/// close". Moonrise is the lunar anchor the day already records, not a solar
/// offset.
///
/// Every instant is nullable: at polar latitudes the Sun may not rise or set,
/// so the anchor a checkpoint needs can be absent. [rawTithi] is always
/// present - it is sampled at sunrise, or at civil noon when there is no
/// sunrise, and [tithiSample] records which.
typedef TithiCheckpoints = ({
  DateTime? sunriseTime,
  DateTime? sunsetTime,
  DateTime? nextSunriseTime,
  DateTime? madhyahnaTime,
  DateTime? aparahnaTime,
  DateTime? nishitaTime,
  DateTime? nishitaEndTime,
  DateTime? pradoshaTime,
  DateTime? moonriseTime,
  DateTime? dominantTime,
  double rawTithi,
  PanchangTithiSample tithiSample,
  DateTime tithiSampledAt,
  double? rawTithiMadhyahna,
  double? rawTithiAparahna,
  double? rawTithiNishita,
  double? rawTithiNishitaEnd,
  double? rawTithiPradosha,
  double? rawTithiMoonrise,
  double? rawTithiNextSunrise,
  double? rawTithiDominant,
});

/// Resolves the intraday tithi checkpoints for [normalizedDate].
///
/// Thin adapter over [PanchangDayResolver]: the canonical day computes the
/// instants and the tithi at each one, while this function keeps the Hive
/// tithi cache (one value per date, place, and sample point) that the month
/// batch depends on for speed.
Future<TithiCheckpoints> resolveTithiCheckpoints({
  required DateTime normalizedDate,
  required PanchangService service,
  required double latitude,
  required double longitude,
  required Box<dynamic> cacheBox,
  double altitudeMeters = 0,
  String? timezoneId,
}) async {
  final resolver = PanchangDayResolver(service: service);
  final day = await resolver.resolve(
    date: normalizedDate,
    place: PanchangPlace(
      latitude: latitude,
      longitude: longitude,
      altitudeMeters: altitudeMeters,
      timezoneId: timezoneId,
    ),
    tithiSampler: (instant, samplePoint) => resolveTithiPoint(
      cacheBox,
      normalizedDate,
      latitude,
      longitude,
      service,
      instant,
      suffix: samplePoint,
    ),
    // The provider resolves the daytime transition separately because it
    // caches the result; the canonical day would compute it twice.
    computeTransition: false,
  );

  return (
    sunriseTime: day.solar.sunrise,
    sunsetTime: day.solar.sunset,
    nextSunriseTime: day.solar.nextSunrise,
    madhyahnaTime: day.checkpoints.madhyahna,
    aparahnaTime: day.checkpoints.aparahna,
    nishitaTime: day.checkpoints.nishita,
    nishitaEndTime: day.checkpoints.nishitaEnd,
    pradoshaTime: day.checkpoints.pradosha,
    moonriseTime: day.solar.moonrise,
    dominantTime: day.checkpoints.dominant,
    rawTithi: day.tithi.rawAtSample,
    tithiSample: day.tithi.sample,
    tithiSampledAt: day.tithi.sampledAt,
    rawTithiMadhyahna: day.checkpointTithis.madhyahna,
    rawTithiAparahna: day.checkpointTithis.aparahna,
    rawTithiNishita: day.checkpointTithis.nishita,
    rawTithiNishitaEnd: day.checkpointTithis.nishitaEnd,
    rawTithiPradosha: day.checkpointTithis.pradosha,
    rawTithiMoonrise: day.checkpointTithis.moonrise,
    rawTithiNextSunrise: day.checkpointTithis.nextSunrise,
    rawTithiDominant: day.checkpointTithis.dominant,
  );
}

/// Locates the end of the sunrise tithi. Best-effort — null means the day
/// shows its single udaya tithi. Positive results persist in [cacheBox].
Future<({DateTime? at, int? index})> resolveDayTransition({
  required DateTime normalizedDate,
  required PanchangService service,
  required double latitude,
  required double longitude,
  required Box<dynamic> cacheBox,
  required TithiCheckpoints checkpoints,
}) async {
  final transTimeKey =
      buildCacheKey(normalizedDate, latitude, longitude, 'transitionTime');
  final transIndexKey =
      buildCacheKey(normalizedDate, latitude, longitude, 'transitionIndex');

  // No solar window means no daytime transition to look for. The day still
  // renders its single tithi instead of failing.
  final sunrise = checkpoints.sunriseTime;
  final nextSunrise = checkpoints.nextSunriseTime;
  final madhyahna = checkpoints.madhyahnaTime;
  final aparahna = checkpoints.aparahnaTime;
  final nishita = checkpoints.nishitaTime;
  final rawMadhyahna = checkpoints.rawTithiMadhyahna;
  final rawAparahna = checkpoints.rawTithiAparahna;
  final rawNishita = checkpoints.rawTithiNishita;
  final rawNextSunrise = checkpoints.rawTithiNextSunrise;
  if (sunrise == null ||
      nextSunrise == null ||
      madhyahna == null ||
      aparahna == null ||
      nishita == null ||
      rawMadhyahna == null ||
      rawAparahna == null ||
      rawNishita == null ||
      rawNextSunrise == null) {
    return (at: null, index: null);
  }

  final cachedTime = cacheBox.get(transTimeKey);
  final cachedIndex = cacheBox.get(transIndexKey);
  if (cachedTime is int && cachedIndex is int) {
    final at = DateTime.fromMillisecondsSinceEpoch(cachedTime);
    if (cachedIndex >= 1 &&
        cachedIndex <= 30 &&
        at.isAfter(sunrise) &&
        !at.isAfter(nextSunrise)) {
      return (at: at, index: cachedIndex);
    }
  }
  try {
    final found = await findSunriseTithiTransition(
      sunrise: sunrise,
      nextSunrise: nextSunrise,
      rawTithiAtSunrise: checkpoints.rawTithi,
      segments: [
        (time: sunrise, rawTithi: checkpoints.rawTithi),
        (time: madhyahna, rawTithi: rawMadhyahna),
        (time: aparahna, rawTithi: rawAparahna),
        (time: nishita, rawTithi: rawNishita),
        (time: nextSunrise, rawTithi: rawNextSunrise),
      ],
      getRawTithi: (t) => service.calculateTithi(
        t,
        latitude: latitude,
        longitude: longitude,
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
/// When [includeTransition] is true, the first tithi boundary after sunrise
/// is also located (month batch leaves it off for speed).
Future<PanchangData> computePanchangData({
  required DateTime normalizedDate,
  required PanchangService service,
  required List<Festival> festivals,
  required HinduMonthSystem monthSystem,
  required double latitude,
  required double longitude,
  required Box<dynamic> cacheBox,
  bool includeTransition = false,
  double altitudeMeters = 0,
  String? timezoneId,
}) async {
  final TithiCheckpoints checkpoints = await resolveTithiCheckpoints(
    normalizedDate: normalizedDate,
    service: service,
    latitude: latitude,
    longitude: longitude,
    cacheBox: cacheBox,
    altitudeMeters: altitudeMeters,
    timezoneId: timezoneId,
  );
  final sunriseTime = checkpoints.sunriseTime;
  final sunsetTime = checkpoints.sunsetTime;
  final nextSunriseTime = checkpoints.nextSunriseTime;
  final rawTithi = checkpoints.rawTithi;
  final rawTithiMadhyahna = checkpoints.rawTithiMadhyahna;
  final rawTithiAparahna = checkpoints.rawTithiAparahna;
  final rawTithiNishita = checkpoints.rawTithiNishita;
  final rawTithiNishitaEnd = checkpoints.rawTithiNishitaEnd;
  final rawTithiPradosha = checkpoints.rawTithiPradosha;
  final rawTithiMoonrise = checkpoints.rawTithiMoonrise;
  final rawTithiNextSunrise = checkpoints.rawTithiNextSunrise;
  final rawTithiDominant = checkpoints.rawTithiDominant;

  final masaCacheKey =
      buildCacheKey(normalizedDate, latitude, longitude, 'masa2');
  final masaNextCacheKey =
      buildCacheKey(normalizedDate, latitude, longitude, 'masaNext2');

  var masa = cacheBox.get(masaCacheKey) as String?;
  masa ??= await service.calculateMasa(
    checkpoints.tithiSampledAt,
    rawTithi,
    latitude: latitude,
    longitude: longitude,
  );
  await cacheBox.put(masaCacheKey, masa);

  // Next-sunrise masa only exists when there is a next sunrise. Without it the
  // Kshaya comparison has nothing to compare, so leave the value empty rather
  // than reusing the current month and inventing a match.
  var masaNextSunrise = '';
  if (nextSunriseTime != null && rawTithiNextSunrise != null) {
    masaNextSunrise = cacheBox.get(masaNextCacheKey) as String? ?? '';
    if (masaNextSunrise.isEmpty) {
      masaNextSunrise = await service.calculateMasa(
        nextSunriseTime,
        rawTithiNextSunrise,
        latitude: latitude,
        longitude: longitude,
      );
      await cacheBox.put(masaNextCacheKey, masaNextSunrise);
    }
  }

  String? nakshatraAtSunrise;
  if (festivals.any((f) => f.nakshatraCondition != null)) {
    final nakKey =
        buildCacheKey(normalizedDate, latitude, longitude, 'nakshatra');
    final cachedNak = cacheBox.get(nakKey);
    if (cachedNak is String && hinduNakshatras.contains(cachedNak)) {
      nakshatraAtSunrise = cachedNak;
    } else {
      nakshatraAtSunrise = await service.calculateNakshatra(
        checkpoints.tithiSampledAt,
        latitude: latitude,
        longitude: longitude,
      );
      if (nakshatraAtSunrise != null) {
        await cacheBox.put(nakKey, nakshatraAtSunrise);
      }
    }
  }

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
    rawTithiNishitaEnd: rawTithiNishitaEnd,
    rawTithiPradosha: rawTithiPradosha,
    rawTithiMoonrise: rawTithiMoonrise,
    rawTithiNextSunrise: rawTithiNextSunrise,
    masaNextSunrise: masaNextSunrise,
    nakshatraAtSunrise: nakshatraAtSunrise,
    rawTithiDominant: rawTithiDominant,
    tithiTransitionTime: transitionTime,
    transitionTithiIndex: transitionIndex,
  );
}

/// Bisects a nakshatra edge bracketed by [lo]/[hi] to [tolerance].
///
/// [sunriseIndex] is the nakshatra whose edge is being found. The solver aims
/// half a nakshatra past the sunrise index (or before it, for [findStart]) so
/// the bracket straddles the edge rather than starting exactly on it; both
/// directions are then the same upward crossing, which is what
/// [solveAngleCrossing] expects.
Future<DateTime?> bisectNakshatraEdge({
  required DateTime lo,
  required DateTime hi,
  required int sunriseIndex,
  required bool findStart,
  required Future<int?> Function(DateTime time) indexAt,
  Duration tolerance = const Duration(seconds: 1),
}) {
  const segment = 360.0 / 27.0;
  return solveAngleCrossing(
    before: lo,
    after: hi,
    valueAt: (time) async {
      final index = await indexAt(time);
      return index == null ? null : index * segment;
    },
    target: (sunriseIndex + (findStart ? -0.5 : 0.5)) * segment,
    tolerance: tolerance,
  );
}
