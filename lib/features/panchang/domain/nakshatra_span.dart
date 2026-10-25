import 'dart:async';

import '../../../models/festival.dart';
import 'root_solver.dart';

/// The nakshatra containing sunrise plus its two edge instants.
typedef NakshatraSpan = ({
  int index,
  String nakshatra,
  DateTime start,
  DateTime end,
});

/// Resolves the nakshatra prevailing at [sunrise] and both of its edges.
///
/// [indexAt] folds the sidereal Moon longitude into 0-26 (or null when the
/// ephemeris read fails). Both edges are bracketed in [step] increments - a
/// nakshatra lasts ~19-26 h, so the first bracket closes within ~13 probes -
/// and solved by [bisectNakshatraEdge], the same crossing primitive as tithi,
/// yoga/karana and the new moon.
///
/// Returns null when the sunrise sample fails, a bracket is not found within
/// [cap], or a solved edge is implausibly far from [sunrise]: callers hide the
/// card instead of showing a wrong span.
Future<NakshatraSpan?> resolveNakshatraSpan({
  required DateTime sunrise,
  required Future<int?> Function(DateTime time) indexAt,
  Duration step = const Duration(hours: 2),
  Duration cap = const Duration(hours: 48),
  Duration tolerance = const Duration(seconds: 1),
}) async {
  final sunriseIndex = await indexAt(sunrise);
  if (sunriseIndex == null) return null;

  Future<({DateTime inner, DateTime outer})?> bracket(int sign) async {
    var inner = sunrise;
    var outer = sunrise.add(step * sign);
    for (var i = 0; i < 24; i++) {
      final idx = await indexAt(outer);
      if (idx == null) return null;
      if (idx != sunriseIndex) return (inner: inner, outer: outer);
      inner = outer;
      outer = outer.add(step * sign);
      if (outer.difference(sunrise).abs() >= cap) break;
    }
    return null;
  }

  // The two edges are independent (all state is immutable or scoped to the
  // stateless [indexAt] closure), so bracket and solve them concurrently to
  // halve the cold-open probe latency.
  final brackets = await Future.wait([bracket(1), bracket(-1)]);
  final endBracket = brackets[0];
  final startBracket = brackets[1];
  if (endBracket == null || startBracket == null) return null;

  final edges = await Future.wait([
    bisectNakshatraEdge(
      lo: endBracket.inner,
      hi: endBracket.outer,
      sunriseIndex: sunriseIndex,
      findStart: false,
      indexAt: indexAt,
      tolerance: tolerance,
    ),
    bisectNakshatraEdge(
      lo: startBracket.outer,
      hi: startBracket.inner,
      sunriseIndex: sunriseIndex,
      findStart: true,
      indexAt: indexAt,
      tolerance: tolerance,
    ),
  ]);
  final end = edges[0];
  final start = edges[1];
  if (end == null || start == null) return null;

  // Guard: a span reaching absurdly far from the day is a failed search, not a
  // real nakshatra (same 2-day rule as the tithi timings).
  if (start.difference(sunrise).inDays.abs() > 2 ||
      end.difference(sunrise).inDays.abs() > 2) {
    return null;
  }

  return (
    index: sunriseIndex,
    nakshatra: hinduNakshatras[sunriseIndex],
    start: start,
    end: end,
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
