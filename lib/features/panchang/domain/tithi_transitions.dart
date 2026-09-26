import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

import '../../../models/festival.dart';
import '../../../models/hindu_month_system.dart';
import '../../../models/panchang_data.dart';
import '../../../services/festival_matching_pipeline.dart';
import '../../../services/panchang_service.dart';
import '../../../services/sunrise_calculator.dart';
import '../data/panchang_cache.dart';

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
  DateTime low = lo;
  DateTime high = hi;

  var guard = 0;
  while (high.difference(low).inMinutes > 1 && guard++ < 60) {
    final mid =
        low.add(Duration(minutes: high.difference(low).inMinutes ~/ 2));
    if (norm(await getRawTithi(mid)) == from) {
      low = mid;
    } else {
      high = mid;
    }
  }

  if (!high.isAfter(sunrise) || high.isAfter(nextSunrise)) return null;
  if (norm(await getRawTithi(high.add(const Duration(minutes: 2)))) != to) {
    return null;
  }
  return (toIndex: to, at: high);
}

/// All six intraday tithi checkpoints plus the instants they were sampled at.
/// Pradosha samples its window midpoint (sunset + N/10), mirroring nishita
/// (night midpoint = its window midpoint) and madhyahna (midday).
typedef TithiCheckpoints = ({
  DateTime sunriseTime,
  DateTime sunsetTime,
  DateTime nextSunriseTime,
  DateTime madhyahnaTime,
  DateTime aparahnaTime,
  DateTime nishitaTime,
  DateTime pradoshaTime,
  DateTime dominantTime,
  double rawTithi,
  double rawTithiMadhyahna,
  double rawTithiAparahna,
  double rawTithiNishita,
  double rawTithiPradosha,
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
    date: normalizedDate,
    latitude: latitude,
    longitude: longitude,
  );
  final sunsetTime = SunriseCalculator.calculateSunsetIST(
    date: normalizedDate,
    latitude: latitude,
    longitude: longitude,
  );
  final nextSunriseTime = SunriseCalculator.calculateSunriseIST(
    date: normalizedDate.add(const Duration(days: 1)),
    latitude: latitude,
    longitude: longitude,
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
  final pradoshaTime = sunsetTime.add(
    Duration(minutes: nextSunriseTime.difference(sunsetTime).inMinutes ~/ 10),
  );
  final dominantTime = sunriseTime.add(kDominantTithiGrace);

  final rawTithi = await resolveTithiPoint(
    cacheBox,
    normalizedDate,
    latitude,
    longitude,
    service,
    sunriseTime,
  );
  final rawTithiMadhyahna = await resolveTithiPoint(
    cacheBox,
    normalizedDate,
    latitude,
    longitude,
    service,
    madhyahnaTime,
    suffix: 'madhyahna',
  );
  final rawTithiAparahna = await resolveTithiPoint(
    cacheBox,
    normalizedDate,
    latitude,
    longitude,
    service,
    aparahnaTime,
    suffix: 'aparahna',
  );
  final rawTithiNishita = await resolveTithiPoint(
    cacheBox,
    normalizedDate,
    latitude,
    longitude,
    service,
    nishitaTime,
    suffix: 'nishita',
  );
  final rawTithiPradosha = await resolveTithiPoint(
    cacheBox,
    normalizedDate,
    latitude,
    longitude,
    service,
    pradoshaTime,
    suffix: 'pradosha',
  );
  final rawTithiNextSunrise = await resolveTithiPoint(
    cacheBox,
    normalizedDate,
    latitude,
    longitude,
    service,
    nextSunriseTime,
    suffix: 'nextSunrise',
  );
  final rawTithiDominant = await resolveTithiPoint(
    cacheBox,
    normalizedDate,
    latitude,
    longitude,
    service,
    dominantTime,
    suffix: 'dominant',
  );

  return (
    sunriseTime: sunriseTime,
    sunsetTime: sunsetTime,
    nextSunriseTime: nextSunriseTime,
    madhyahnaTime: madhyahnaTime,
    aparahnaTime: aparahnaTime,
    nishitaTime: nishitaTime,
    pradoshaTime: pradoshaTime,
    dominantTime: dominantTime,
    rawTithi: rawTithi,
    rawTithiMadhyahna: rawTithiMadhyahna,
    rawTithiAparahna: rawTithiAparahna,
    rawTithiNishita: rawTithiNishita,
    rawTithiPradosha: rawTithiPradosha,
    rawTithiNextSunrise: rawTithiNextSunrise,
    rawTithiDominant: rawTithiDominant,
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
        (
          time: checkpoints.madhyahnaTime,
          rawTithi: checkpoints.rawTithiMadhyahna
        ),
        (
          time: checkpoints.aparahnaTime,
          rawTithi: checkpoints.rawTithiAparahna
        ),
        (
          time: checkpoints.nishitaTime,
          rawTithi: checkpoints.rawTithiNishita
        ),
        (
          time: checkpoints.nextSunriseTime,
          rawTithi: checkpoints.rawTithiNextSunrise
        ),
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
  final rawTithiPradosha = checkpoints.rawTithiPradosha;
  final rawTithiNextSunrise = checkpoints.rawTithiNextSunrise;
  final rawTithiDominant = checkpoints.rawTithiDominant;

  final masaCacheKey =
      buildCacheKey(normalizedDate, latitude, longitude, 'masa2');
  final masaNextCacheKey =
      buildCacheKey(normalizedDate, latitude, longitude, 'masaNext2');

  var masa = cacheBox.get(masaCacheKey) as String?;
  masa ??= await service.calculateMasa(
    sunriseTime,
    rawTithi,
    latitude: latitude,
    longitude: longitude,
  );
  await cacheBox.put(masaCacheKey, masa);

  var masaNextSunrise = cacheBox.get(masaNextCacheKey) as String?;
  masaNextSunrise ??= await service.calculateMasa(
    nextSunriseTime,
    rawTithiNextSunrise,
    latitude: latitude,
    longitude: longitude,
  );
  await cacheBox.put(masaNextCacheKey, masaNextSunrise);

  String? nakshatraAtSunrise;
  if (festivals.any((f) => f.nakshatraCondition != null)) {
    final nakKey =
        buildCacheKey(normalizedDate, latitude, longitude, 'nakshatra');
    final cachedNak = cacheBox.get(nakKey);
    if (cachedNak is String && hinduNakshatras.contains(cachedNak)) {
      nakshatraAtSunrise = cachedNak;
    } else {
      nakshatraAtSunrise = await service.calculateNakshatra(
        sunriseTime,
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
    rawTithiPradosha: rawTithiPradosha,
    rawTithiNextSunrise: rawTithiNextSunrise,
    masaNextSunrise: masaNextSunrise,
    nakshatraAtSunrise: nakshatraAtSunrise,
    rawTithiDominant: rawTithiDominant,
    tithiTransitionTime: transitionTime,
    transitionTithiIndex: transitionIndex,
  );
}

/// Bisects a nakshatra edge bracketed by [lo]/[hi] to ~1-minute precision.
Future<DateTime?> bisectNakshatraEdge({
  required DateTime lo,
  required DateTime hi,
  required int sunriseIndex,
  required bool findStart,
  required Future<int?> Function(DateTime time) indexAt,
}) async {
  var guard = 0;
  while (hi.difference(lo).inMinutes > 1 && guard++ < 60) {
    final mid = lo.add(Duration(minutes: hi.difference(lo).inMinutes ~/ 2));
    final idx = await indexAt(mid);
    if (idx == null) return null;
    if (findStart ? idx == sunriseIndex : idx != sunriseIndex) {
      hi = mid;
    } else {
      lo = mid;
    }
  }
  return hi;
}
