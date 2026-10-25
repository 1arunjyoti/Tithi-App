import 'dart:async';

import '../../../models/festival.dart';
import 'root_solver.dart';

/// Yoga and karana spans that contain sunrise.
typedef YogaKaranaSpan = ({
  int yogaIndex,
  DateTime yogaEnd,
  int karanaIndex,
  DateTime karanaEnd,
});

/// Resolves the yoga and karana spans containing [sunrise] to [tolerance].
///
/// [longitudesAt] returns the sidereal Sun and Moon longitudes for an instant,
/// or null when the ephemeris read fails. Yoga is the SUM of the two longitudes
/// in 27 segments; karana is the elongation in 60 segments of 6 degrees. Both
/// values grow monotonically, so each span end is an upward crossing of the
/// next segment boundary and goes through [solveAngleCrossing] - the same
/// primitive as tithi, nakshatra, new moon and Sankranti. The old provider
/// bisected the step-shaped index to a minute instead.
///
/// Returns null when the sunrise read fails or a bracket cannot be found;
/// callers hide the card instead of showing a wrong span.
Future<YogaKaranaSpan?> resolveYogaKaranaSpan({
  required DateTime sunrise,
  required Future<({double sun, double moon})?> Function(DateTime instant)
      longitudesAt,
  Duration yogaStep = const Duration(hours: 2),
  Duration karanaStep = const Duration(hours: 1),
  Duration tolerance = const Duration(seconds: 1),
}) async {
  final atSunrise = await longitudesAt(sunrise);
  if (atSunrise == null) return null;

  final yogaIndex = yogaIndexFor(atSunrise.sun, atSunrise.moon);
  final karanaIndex = karanaIndexFor(atSunrise.sun, atSunrise.moon);

  final ends = await Future.wait([
    _spanEnd(
      sunrise: sunrise,
      target: (yogaIndex + 1) * (360 / 27),
      step: yogaStep,
      value: (longitudes) => _normalize(longitudes.sun + longitudes.moon),
      longitudesAt: longitudesAt,
      tolerance: tolerance,
    ),
    _spanEnd(
      sunrise: sunrise,
      target: (karanaIndex + 1) * 6,
      step: karanaStep,
      value: (longitudes) => _normalize(longitudes.moon - longitudes.sun),
      longitudesAt: longitudesAt,
      tolerance: tolerance,
    ),
  ]);

  final yogaEnd = ends[0];
  final karanaEnd = ends[1];
  if (yogaEnd == null || karanaEnd == null) return null;

  return (
    yogaIndex: yogaIndex,
    yogaEnd: yogaEnd,
    karanaIndex: karanaIndex,
    karanaEnd: karanaEnd,
  );
}

double _normalize(double degrees) {
  final value = degrees % 360;
  return value < 0 ? value + 360 : value;
}

/// Brackets the next crossing of [target] and solves it with the shared
/// primitive.
Future<DateTime?> _spanEnd({
  required DateTime sunrise,
  required double target,
  required Duration step,
  required double Function(({double sun, double moon}) longitudes) value,
  required Future<({double sun, double moon})?> Function(DateTime instant)
      longitudesAt,
  required Duration tolerance,
}) async {
  var inner = sunrise;
  var outer = sunrise.add(step);
  var bracketed = false;
  for (var i = 0; i < 48; i++) {
    final longitudes = await longitudesAt(outer);
    if (longitudes == null) return null;
    if (signedAngleDelta(value(longitudes), target) > 0) {
      bracketed = true;
      break;
    }
    inner = outer;
    outer = outer.add(step);
    if (outer.difference(sunrise).abs() >= const Duration(hours: 48)) break;
  }
  if (!bracketed) return null;

  // solveRoot wants residual > 0 at `after`. A sample can land exactly on the
  // boundary (residual 0), which the index-based bracket would call "inside";
  // nudge one second past it. That is far below the minute the card displays.
  var after = outer;
  final afterLongitudes = await longitudesAt(after);
  if (afterLongitudes == null) return null;
  if (signedAngleDelta(value(afterLongitudes), target) == 0) {
    after = after.add(const Duration(seconds: 1));
  }

  return solveAngleCrossing(
    before: inner,
    after: after,
    valueAt: (instant) async {
      final longitudes = await longitudesAt(instant);
      return longitudes == null ? null : value(longitudes);
    },
    target: target,
    tolerance: tolerance,
  );
}
