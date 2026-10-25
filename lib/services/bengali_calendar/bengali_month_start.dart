import 'dart:async';

import '../../features/panchang/domain/panchang_crossings.dart';
import '../../features/panchang/domain/root_solver.dart';

/// Relative longitude of [sunLongitude] past [boundary], in [0, 360).
///
/// Current sign -> [0, 30); previous sign -> [330, 360).
double relPastBoundary(double sunLongitude, double boundary) =>
    (sunLongitude - boundary + 360) % 360;

/// Thrown when the Sankranti that starts a Bengali month cannot be resolved.
class BengaliMonthStartException implements Exception {
  const BengaliMonthStartException(this.message);

  final String message;

  @override
  String toString() => 'BengaliMonthStartException: $message';
}

/// Resolves the Bengali solar month containing [noon] and its first civil day.
///
/// [monthIndex] is 0 = Boishakh (Mesha) .. 11 = Choitro (Meena), derived from
/// the sidereal Sun at [noon]. [sunLngNow] is that same longitude, passed in so
/// the caller does not pay for a second read, and [sunLongitudeAt] returns the
/// sidereal Sun longitude for any instant.
///
/// The Bengal rule starts a month the day AFTER the Sankranti civil date, so a
/// day whose noon is already in the new sign still belongs to the outgoing
/// month until the next civil day. In that case the previous month is resolved
/// and returned with its own index (e.g. 2026-04-14 is Choitro 30, 1432).
///
/// The Sankranti instant is solved to a second by the shared crossing solver.
/// There is no "historic approximation" fallback: when neither the
/// mean-motion bracket nor the 35-day scan finds an ingress, this throws
/// [BengaliMonthStartException] instead of returning a month start that can be
/// a day off.
Future<({int index, DateTime start})> resolveBengaliMonthStart({
  required int monthIndex,
  required DateTime noon,
  required double sunLngNow,
  required Future<double> Function(DateTime instant) sunLongitudeAt,
  bool allowMonthBacktrack = true,
}) async {
  final double boundary = monthIndex * 30.0;
  final double degInSign = relPastBoundary(sunLngNow, boundary);

  // Guard: callers must pass a noon whose Sun is inside [boundary,
  // boundary + 30). A mismatched boundary (e.g. getMonthStart probing a
  // neighbouring month) yields degInSign up to ~359, which would shoot the
  // estimate ~a year off. The 35-day scan covers that case instead.
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

  // Primary path: the mean-motion estimate is within a day of the true
  // ingress, so the shared crossing helper brackets it and bisects to a
  // second. This is the same code path the panchang uses for its new moon.
  DateTime? ingress;
  if (estimateValid) {
    ingress = await findSankrantiInstant(
      estimate: estNoon,
      sunLongitudeAt: (instant) async => await sunLongitudeAt(instant),
      boundaryDegrees: boundary,
    );
  }

  // Guard path: a mismatched boundary or a late estimate. Walk up to one
  // max-length solar month in the direction the Sun has to travel.
  ingress ??= await _solveFromScan(
    noon: noon,
    boundary: boundary,
    sunLongitudeAt: sunLongitudeAt,
  );

  if (ingress == null) {
    throw BengaliMonthStartException(
      'No Sankranti for month $monthIndex (boundary $boundary°) within '
      '35 days of ${noon.toIso8601String()}.',
    );
  }

  // Bengal rule: the month starts the day after the Sankranti civil date.
  final sankrantiDay = DateTime(ingress.year, ingress.month, ingress.day);
  final monthStart = sankrantiDay.add(const Duration(days: 1));
  // The Sankranti is on this civil day, so the Bengal rule gives the day to
  // the outgoing month. Resolve that month instead of returning day 1 of a
  // month that begins tomorrow - the old noon fallback here produced two
  // Boishakh 1s (2026-04-14 and 2026-04-15).
  if (monthStart.isAfter(noon)) {
    if (allowMonthBacktrack) {
      // The last day of the outgoing month: noon the day before [monthStart],
      // whose Sun is inside the previous boundary.
      final prevNoon = DateTime(
        monthStart.year,
        monthStart.month,
        monthStart.day,
        12,
      ).subtract(const Duration(days: 1));
      final prevIndex = (monthIndex + 11) % 12;
      return resolveBengaliMonthStart(
        monthIndex: prevIndex,
        noon: prevNoon,
        sunLngNow: await sunLongitudeAt(prevNoon),
        sunLongitudeAt: sunLongitudeAt,
        // One step is enough: the outgoing month's start is 29-32 days before
        // [monthStart], so it cannot land on its own Sankranti day.
        allowMonthBacktrack: false,
      );
    }
    // Unreachable from the step above; keep the grid bounded rather than
    // recursing.
    return (
      index: monthIndex,
      start: DateTime(noon.year, noon.month, noon.day),
    );
  }
  // Sanity: the start of the month containing `noon` must lie within
  // (noon - 32d, noon]. Anything else is a mis-resolution (e.g. a
  // neighbouring-month probe) - return the noon-anchored fallback so the
  // calendar grid stays bounded instead of going blank/huge.
  if (noon.difference(monthStart).inDays >= 32) {
    return (
      index: monthIndex,
      start: DateTime(noon.year, noon.month, noon.day),
    );
  }
  return (index: monthIndex, start: monthStart);
}

/// Finds the most recent/next ingress by walking up to 35 days from [noon].
///
/// Returns null when the walk never crosses [boundary], which means the
/// sampler is broken rather than that the month has no start.
Future<DateTime?> _solveFromScan({
  required DateTime noon,
  required double boundary,
  required Future<double> Function(DateTime instant) sunLongitudeAt,
}) async {
  DateTime? before;
  DateTime? after;

  DateTime cursor = noon;
  double relCursor = relPastBoundary(await sunLongitudeAt(cursor), boundary);
  if (relCursor > 180) {
    // Noon is still before the boundary; the ingress is ahead.
    for (int i = 1; i <= 35; i++) {
      cursor = noon.add(Duration(days: i));
      relCursor = relPastBoundary(await sunLongitudeAt(cursor), boundary);
      if (relCursor <= 180) {
        after = cursor;
        before = cursor.subtract(const Duration(days: 1));
        break;
      }
      // Let gestures/frames interleave during long FFI scans.
      if (i % 8 == 0) await Future<void>.delayed(Duration.zero);
    }
  } else {
    for (int i = 0; i < 35; i++) {
      final prev = cursor.subtract(const Duration(days: 1));
      final relPrev = relPastBoundary(await sunLongitudeAt(prev), boundary);
      if (relPrev > 180) {
        before = prev;
        after = cursor;
        break;
      }
      cursor = prev;
      // Let gestures/frames interleave during long FFI scans.
      if (i % 8 == 7) await Future<void>.delayed(Duration.zero);
    }
  }

  if (before == null || after == null) return null;
  return solveAngleCrossing(
    before: before,
    after: after,
    valueAt: (instant) async => await sunLongitudeAt(instant),
    target: boundary,
  );
}
