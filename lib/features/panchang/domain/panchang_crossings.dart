import 'dart:async';

import 'root_solver.dart';

// Phase 3: lunation and solar-ingress crossings built on [solveAngleCrossing].
//
// Both are "estimate, bracket by sampling, solve to seconds" problems. They
// live together because the Adhika-masa rule reads them as a pair: a lunation
// is Adhika when the Sun's rashi is the same at both new moons, so a
// new-moon instant that is hours off can disagree with the Sankranti it sits
// next to.

/// Default scan step. A day cannot hide a crossing: the fastest value used
/// here (elapsed Sun-Moon separation) moves ~13.2 degrees per day, far below
/// the 180-degree fold.
const Duration kCrossingScanStep = Duration(days: 1);

/// Default search window around the estimate. Short enough to hold at most
/// one crossing of the value (a lunation is 29.5 days, a solar year 365).
const Duration kCrossingSearchWindow = Duration(days: 3);

/// Windows [resolveNewMoonInstant] tries in order.
///
/// A mean-motion estimate is normally within a day of the true new moon, so
/// the ±3 day window brackets it. The ±7 day retry covers an estimate that is
/// several days off (for example a caller passing a stale tithi) without
/// spanning two lunations, which would make "the first upward wrap" ambiguous.
const List<Duration> kNewMoonSearchWindows = <Duration>[
  kCrossingSearchWindow,
  Duration(days: 7),
];

/// Thrown when a crossing the calendar cannot proceed without has no root.
class CrossingResolutionException implements Exception {
  const CrossingResolutionException(this.message);

  final String message;

  @override
  String toString() => 'CrossingResolutionException: $message';
}

/// The new-moon instant inside `estimate ± searchWindow`, to [tolerance].
///
/// [elapsedDegreesAt] is the Sun-Moon separation in [0, 360) degrees. Returns
/// null when the window holds no wrap (the estimate is off by more than the
/// window) or a sample fails - callers keep their own fallback.
Future<DateTime?> findNewMoonInstant({
  required DateTime estimate,
  required Future<double?> Function(DateTime instant) elapsedDegreesAt,
  Duration searchWindow = kCrossingSearchWindow,
  Duration scanStep = kCrossingScanStep,
  Duration tolerance = const Duration(seconds: 1),
}) {
  return _findCrossing(
    estimate: estimate,
    valueAt: elapsedDegreesAt,
    target: 0,
    searchWindow: searchWindow,
    scanStep: scanStep,
    tolerance: tolerance,
  );
}

/// The new-moon instant near [estimate], retrying with wider windows.
///
/// Unlike [findNewMoonInstant] this never degrades to a noon estimate. If
/// every window in [windows] holds no upward wrap it returns null, and callers
/// are expected to fail loudly instead of returning a time that can be half a
/// day off: a new moon on the wrong side of a Sankranti flips the Adhika
/// verdict for the whole lunation.
Future<DateTime?> resolveNewMoonInstant({
  required DateTime estimate,
  required Future<double?> Function(DateTime instant) elapsedDegreesAt,
  List<Duration> windows = kNewMoonSearchWindows,
  Duration scanStep = kCrossingScanStep,
  Duration tolerance = const Duration(seconds: 1),
}) async {
  for (final window in windows) {
    final solved = await findNewMoonInstant(
      estimate: estimate,
      elapsedDegreesAt: elapsedDegreesAt,
      searchWindow: window,
      scanStep: scanStep,
      tolerance: tolerance,
    );
    if (solved != null) return solved;
  }
  return null;
}

/// The instant the Sun enters `boundaryDegrees` (a Sankranti), to [tolerance].
///
/// [boundaryDegrees] is the sidereal longitude of the sign's start
/// (`n * 30`), and [sunLongitudeAt] the sidereal Sun longitude at an instant.
Future<DateTime?> findSankrantiInstant({
  required DateTime estimate,
  required Future<double?> Function(DateTime instant) sunLongitudeAt,
  required double boundaryDegrees,
  Duration searchWindow = kCrossingSearchWindow,
  Duration scanStep = kCrossingScanStep,
  Duration tolerance = const Duration(seconds: 1),
}) {
  return _findCrossing(
    estimate: estimate,
    valueAt: sunLongitudeAt,
    target: boundaryDegrees,
    searchWindow: searchWindow,
    scanStep: scanStep,
    tolerance: tolerance,
  );
}

/// Brackets [target] by sampling outward from `estimate - searchWindow` and
/// hands the first straddling pair to [solveAngleCrossing].
Future<DateTime?> _findCrossing({
  required DateTime estimate,
  required Future<double?> Function(DateTime instant) valueAt,
  required double target,
  required Duration searchWindow,
  required Duration scanStep,
  required Duration tolerance,
}) async {
  if (searchWindow <= Duration.zero || scanStep <= Duration.zero) return null;

  var previous = estimate.subtract(searchWindow);
  final previousValue = await valueAt(previous);
  if (previousValue == null) return null;
  var previousResidual = signedAngleDelta(previousValue, target);

  final end = estimate.add(searchWindow);
  while (previous.isBefore(end)) {
    final next = previous.add(scanStep);
    final value = await valueAt(next);
    if (value == null) return null;
    final residual = signedAngleDelta(value, target);
    if (previousResidual <= 0 && residual > 0) {
      return solveAngleCrossing(
        before: previous,
        after: next,
        valueAt: valueAt,
        target: target,
        tolerance: tolerance,
      );
    }
    previous = next;
    previousResidual = residual;
  }
  return null;
}
