import 'dart:async';

// Phase 3: one adaptive root solver for every astronomical crossing.
//
// Tithi, nakshatra, yoga, karana, new-moon and Sankranti boundaries are all
// "an angle passes a multiple of some segment" events. They used to be found
// with three different bisections (1-minute tithi, 1-minute nakshatra, ~20 s
// Sankranti) plus a two-round new-moon approximation that could still be off
// by hours - enough to flip an Adhika-masa verdict near a Sankranti. This
// module owns the primitive; callers only supply the sampler and the target.

/// Signed difference `value - target` folded into (-180, 180], in degrees.
///
/// The fold is what makes a crossing solver work on cyclic longitudes: just
/// below the target the residual is a small negative number, just above it a
/// small positive one, no matter how many whole turns lie between.
double signedAngleDelta(double value, double target) {
  final delta = (value - target) % 360;
  if (delta > 180) return delta - 360;
  if (delta <= -180) return delta + 360;
  return delta;
}

/// Bisects `[before, after]` down to the instant [residualAt] turns positive.
///
/// The bracket contract is strict and verified up front: the residual must be
/// `<= 0` at [before] and `> 0` at [after], with exactly one upward crossing
/// inside. A bracket that does not satisfy it returns null instead of a
/// plausible-looking wrong instant - the failure mode that made an Adhika
/// verdict flicker when a coarse estimate landed on the far side of a
/// Sankranti.
///
/// Only upward crossings (negative -> positive residual) are solved. A
/// descending crossing fails the up-front check and returns null; callers that
/// need one must invert the sampler (e.g. sample `-value` or shift the target
/// by 180 degrees) so the crossing is upward again.
///
/// [residualAt] may return null (a failed ephemeris read); that aborts the
/// search instead of guessing.
///
/// The result is the first instant known to be past the crossing, within
/// [tolerance] of it.
Future<DateTime?> solveRoot({
  required DateTime before,
  required DateTime after,
  required Future<double?> Function(DateTime instant) residualAt,
  Duration tolerance = const Duration(seconds: 1),
  int maxIterations = 64,
}) async {
  if (!after.isAfter(before) || tolerance <= Duration.zero) return null;

  final startResidual = await residualAt(before);
  if (startResidual == null || startResidual > 0) return null;
  final endResidual = await residualAt(after);
  if (endResidual == null || endResidual <= 0) return null;

  var lo = before;
  var hi = after;
  for (var i = 0; i < maxIterations; i++) {
    if (hi.difference(lo) <= tolerance) return hi;
    final mid = DateTime.fromMicrosecondsSinceEpoch(
      lo.microsecondsSinceEpoch +
          (hi.microsecondsSinceEpoch - lo.microsecondsSinceEpoch) ~/ 2,
    );
    // A degenerate midpoint (bracket already at microsecond scale) would loop
    // forever without this guard.
    if (!mid.isAfter(lo) || !mid.isBefore(hi)) return hi;
    final residual = await residualAt(mid);
    if (residual == null) return null;
    if (residual > 0) {
      hi = mid;
    } else {
      lo = mid;
    }
  }
  return hi;
}

/// Solves the instant [valueAt] crosses [target] (mod 360) inside the bracket.
///
/// One primitive for every cyclic crossing: tithi and karana use the elapsed
/// Sun-Moon separation (targets `n * 12` and `n * 6`), nakshatra the sidereal
/// Moon longitude (`n * 360 / 27`), yoga the sidereal Sun + Moon sum
/// (`n * 360 / 27`), the new moon the elapsed separation crossing `0`, and a
/// Sankranti the sidereal Sun longitude crossing `n * 30`.
///
/// The bracket must hold exactly one crossing, which every caller guarantees
/// by construction (a day for a Sankranti, hours for a tithi or nakshatra).
Future<DateTime?> solveAngleCrossing({
  required DateTime before,
  required DateTime after,
  required Future<double?> Function(DateTime instant) valueAt,
  required double target,
  Duration tolerance = const Duration(seconds: 1),
  int maxIterations = 64,
}) {
  return solveRoot(
    before: before,
    after: after,
    residualAt: (instant) async {
      final value = await valueAt(instant);
      return value == null ? null : signedAngleDelta(value, target);
    },
    tolerance: tolerance,
    maxIterations: maxIterations,
  );
}
