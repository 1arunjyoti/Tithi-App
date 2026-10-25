import 'root_solver.dart';

/// The span of one tithi: the instants its two boundaries are crossed.
typedef TithiSpan = ({DateTime start, DateTime end});

/// Width of one tithi in degrees of elapsed Sun-Moon separation.
const double kTithiSegmentDegrees = 12;

/// Tithi index (1-30) that holds [elongation].
///
/// [elongation] is the elapsed Moon-minus-Sun longitude in degrees (0-360):
/// index 1 is Shukla Pratipada (0-12) and 30 is Krishna Amavasya (348-360),
/// matching `PanchangData.tithiIndex` and `Festival.resolveTithiIndex`.
int tithiIndexForElongation(double elongation) {
  var e = elongation % 360;
  if (e < 0) e += 360;
  return (e / kTithiSegmentDegrees).floor().clamp(0, 29) + 1;
}

/// Resolves the start and end of tithi [tithiIndex] nearest [date].
///
/// [tithiIndex] is the full 1-30 index (1-15 Shukla, 16-30 Krishna), not the
/// paksha-relative number: passing 8 for Krishna Ashtami would silently resolve
/// the Shukla one. [elongationAt] returns the elapsed Moon-minus-Sun longitude
/// for an instant, or null when the ephemeris read fails.
///
/// The search runs outward from [date] so the day's own occurrence (hours
/// away) wins over the adjacent lunation's (~29.5 days), which is what keeps a
/// festival from reporting "ends Aug 6" on Sep 4. Both boundaries are then
/// solved by [solveAngleCrossing] - the same primitive as the tithi transition,
/// nakshatra, yoga/karana and Sankranti edges - so the span is second-precise.
///
/// Returns null for a Kshaya (skipped) tithi or when either edge cannot be
/// bracketed: callers hide the timings instead of showing a wrong-month span.
Future<TithiSpan?> resolveTithiSpan({
  required DateTime date,
  required int tithiIndex,
  required Future<double?> Function(DateTime instant) elongationAt,
  Duration scanStep = const Duration(hours: 2),
  Duration scanWindow = const Duration(days: 2),
  Duration tolerance = const Duration(seconds: 1),
}) async {
  assert(
    tithiIndex >= 1 && tithiIndex <= 30,
    'tithiIndex must be the 1-30 tithi index, got $tithiIndex',
  );

  // A 2 h step cannot skip a 12-degree segment: the fastest mean elongation is
  // ~15.4 deg/day, so the widest a step sees is ~1.3 degrees.
  DateTime? inside;
  for (var offset = Duration.zero; offset <= scanWindow; offset += scanStep) {
    final probes = offset == Duration.zero
        ? [date]
        : [date.add(offset), date.subtract(offset)];
    for (final probe in probes) {
      final elongation = await elongationAt(probe);
      if (elongation == null) return null;
      if (tithiIndexForElongation(elongation) == tithiIndex) {
        inside = probe;
        break;
      }
    }
    if (inside != null) break;
  }
  if (inside == null) return null;
  final anchor = inside;

  /// Walks [sign] away from the anchor until the index leaves the tithi.
  Future<({DateTime inner, DateTime outer})?> bracket(int sign) async {
    var inner = anchor;
    var outer = anchor.add(scanStep * sign);
    for (var i = 0; i < 24; i++) {
      final elongation = await elongationAt(outer);
      if (elongation == null) return null;
      if (tithiIndexForElongation(elongation) != tithiIndex) {
        return (inner: inner, outer: outer);
      }
      inner = outer;
      outer = outer.add(scanStep * sign);
      if (outer.difference(anchor).abs() >= scanWindow) break;
    }
    return null;
  }

  // The two edges are independent, so bracket them concurrently.
  final brackets = await Future.wait([bracket(1), bracket(-1)]);
  final endBracket = brackets[0];
  final startBracket = brackets[1];
  if (endBracket == null || startBracket == null) return null;

  final edges = await Future.wait([
    solveAngleCrossing(
      before: endBracket.inner,
      after: endBracket.outer,
      valueAt: elongationAt,
      // 360 folds to 0, which is the same boundary for tithi 30.
      target: (tithiIndex * kTithiSegmentDegrees) % 360,
      tolerance: tolerance,
    ),
    solveAngleCrossing(
      before: startBracket.outer,
      after: startBracket.inner,
      valueAt: elongationAt,
      target: ((tithiIndex - 1) * kTithiSegmentDegrees) % 360,
      tolerance: tolerance,
    ),
  ]);
  final end = edges[0];
  final start = edges[1];
  if (start == null || end == null || !end.isAfter(start)) return null;

  // A span reaching more than two days from [date] belongs to another
  // lunation, which is the Kshaya case the callers must not display.
  if (start.difference(date).inDays.abs() > 2 ||
      end.difference(date).inDays.abs() > 2) {
    return null;
  }

  return (start: start, end: end);
}
