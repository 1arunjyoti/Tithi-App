import '../../../models/festival.dart';
import '../../../models/panchang_data.dart' show BhadraWindow;
import 'root_solver.dart';

// Bhadra (Vishti) windows for one civil day.
//
// Vishti is the seventh movable karana: it repeats every seven karanas, i.e.
// whenever `karanaIndex` is a positive multiple of seven up to 56. Raksha
// Bandhan and a few other muhurta-sensitive observances must not start while
// Bhadra prevails, so the event sheet needs the exact intervals rather than a
// single karana sample at sunrise.

/// Whether a 0-59 [karanaIndex] names Vishti (Bhadra).
///
/// Indices 1-56 run the seven movable karanas through eight cycles, so Vishti
/// is every seventh one (7, 14, ... 56). The fixed karanas at 0 and 57-59 are
/// never Vishti.
bool isVishtiKarana(int karanaIndex) {
  final idx = karanaIndex % 60;
  return idx >= 1 && idx <= 56 && idx % 7 == 0;
}

/// Resolves the Bhadra (Vishti) intervals overlapping
/// `sunrise..nextSunrise`.
///
/// [longitudesAt] returns the sidereal Sun/Moon longitudes, or null when the
/// ephemeris read fails. A failure returns an empty list: callers then leave
/// the puja window untrimmed instead of inventing a Bhadra-free slot.
///
/// The scan step is one hour. A karana spans 6 degrees of elongation and the
/// fastest mean motion is ~16.4 degrees/day (~0.68 degrees/hour), so a step
/// can never skip a whole karana. Edges are solved with the shared
/// [solveAngleCrossing] primitive on the elongation, so they are
/// second-precise like every other boundary in the engine.
Future<List<BhadraWindow>> resolveBhadraWindows({
  required DateTime sunrise,
  required DateTime nextSunrise,
  required Future<({double sun, double moon})?> Function(DateTime instant)
  longitudesAt,
  Duration scanStep = const Duration(hours: 1),
  Duration tolerance = const Duration(seconds: 1),
}) async {
  if (!nextSunrise.isAfter(sunrise) || scanStep <= Duration.zero) {
    return const [];
  }

  Future<double?> elongationAt(DateTime instant) async {
    final longitudes = await longitudesAt(instant);
    if (longitudes == null) return null;
    var elapsed = longitudes.moon - longitudes.sun;
    if (elapsed < 0) elapsed += 360;
    return elapsed;
  }

  /// Solves the karana boundary between [before] and [after], whose karana
  /// index at [after] is [nextIndex].
  Future<DateTime?> boundary(
    DateTime before,
    DateTime after,
    int nextIndex,
  ) {
    return solveAngleCrossing(
      before: before,
      after: after,
      valueAt: elongationAt,
      // Karana n covers elongation [n*6, (n+1)*6); entering it crosses n*6.
      target: (nextIndex * 6) % 360,
      tolerance: tolerance,
    );
  }

  final windows = <BhadraWindow>[];
  DateTime? open;

  // Sample every scan step plus the closing sunrise, so a transition in the
  // final partial segment is never missed.
  final samples = <DateTime>[];
  for (
    var instant = sunrise;
    instant.isBefore(nextSunrise);
    instant = instant.add(scanStep)
  ) {
    samples.add(instant);
  }
  samples.add(nextSunrise);

  final first = await longitudesAt(samples.first);
  if (first == null) return const [];
  var previousVishti = isVishtiKarana(
    karanaIndexFor(first.sun, first.moon),
  );
  // A window already open at sunrise is clipped to the day boundary.
  if (previousVishti) open = sunrise;

  for (var i = 1; i < samples.length; i++) {
    final previous = samples[i - 1];
    final instant = samples[i];
    final longitudes = await longitudesAt(instant);
    if (longitudes == null) return const [];
    final index = karanaIndexFor(longitudes.sun, longitudes.moon);
    final vishti = isVishtiKarana(index);

    if (vishti != previousVishti) {
      final edge = await boundary(previous, instant, index);
      if (edge == null) return const [];
      if (vishti) {
        open = edge;
      } else if (open != null) {
        windows.add((start: open, end: edge));
        open = null;
      }
    }

    previousVishti = vishti;
  }

  // Still in Bhadra at the next sunrise: clip to the day boundary.
  if (open != null) {
    windows.add((start: open, end: nextSunrise));
  }

  return windows;
}

/// The longest sub-interval of `start..end` outside every [windows] entry,
/// or null when Bhadra covers the whole span.
///
/// Used by the puja-kala resolver: Raksha Bandhan trims its aparahna window to
/// the Bhadra-free part and falls back to Pradosha when none is left.
({DateTime start, DateTime end})? bhadraFreeWindow({
  required DateTime start,
  required DateTime end,
  required List<BhadraWindow> windows,
}) {
  if (!end.isAfter(start)) return null;

  final overlaps = windows
      .where((w) => w.start.isBefore(end) && w.end.isAfter(start))
      .toList()
    ..sort((a, b) => a.start.compareTo(b.start));

  ({DateTime start, DateTime end})? best;
  var cursor = start;
  for (final window in overlaps) {
    if (window.start.isAfter(cursor)) {
      final candidate = (
        start: cursor,
        end: window.start.isBefore(end) ? window.start : end,
      );
      if (best == null ||
          candidate.end.difference(candidate.start) >
              best.end.difference(best.start)) {
        best = candidate;
      }
    }
    if (window.end.isAfter(cursor)) cursor = window.end;
    if (!cursor.isBefore(end)) break;
  }
  if (cursor.isBefore(end)) {
    final candidate = (start: cursor, end: end);
    if (best == null ||
        candidate.end.difference(candidate.start) >
            best.end.difference(best.start)) {
      best = candidate;
    }
  }
  return best;
}
