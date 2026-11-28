/// Pairs a moonrise with the first set after it.
///
/// A civil day usually contains a morning set and an evening rise, so the
/// same-day set is *before* the rise and cannot bound the Moon's above-horizon
/// span. [nextSet] is the following set from the scheduler's forward scanner.
DateTime? setFollowingRise({
  required DateTime rise,
  DateTime? sameDaySet,
  DateTime? nextSet,
}) {
  if (sameDaySet != null && sameDaySet.isAfter(rise)) return sameDaySet;
  return nextSet;
}

/// A contiguous interval when the Moon is above the horizon while the Sun is
/// below it - the offline, weather-free definition of "good moon viewing".
class MoonViewingWindow {
  const MoonViewingWindow({
    required this.start,
    required this.end,
    required this.isMorning,
  });

  final DateTime start;
  final DateTime end;

  /// True for the pre-sunrise window, false for the evening window.
  final bool isMorning;

  Duration get duration => end.difference(start);
}

/// Picks the longest overlap between the Moon's above-horizon span and the
/// dark spans adjacent to [date].
///
/// Moon rise/set instants may come from the prev/next-day fallbacks (about
/// once a month the Moon does not rise or set on a civil day), so their real
/// dates are used instead of the requested date. [morningSunrise] is sunrise
/// on the requested day, [eveningSunset] is sunset on it and [nextSunrise] is
/// the following day's sunrise. The previous sunset is approximated as one
/// solar day before [eveningSunset] (it varies only a few minutes).
///
/// Returns null when the Moon is down throughout darkness (new moon, or a
/// Moon that sets before sunset and rises after sunrise).
MoonViewingWindow? bestMoonViewingWindow({
  required DateTime? moonrise,
  required DateTime? moonset,
  required DateTime morningSunrise,
  required DateTime eveningSunset,
  required DateTime nextSunrise,
}) {
  if (moonrise == null || moonset == null || !moonset.isAfter(moonrise)) {
    return null;
  }

  final previousSunset = eveningSunset.subtract(const Duration(days: 1));
  final morningStart = _overlap(
    moonrise,
    moonset,
    previousSunset,
    morningSunrise,
  );
  final eveningStart = _overlap(moonrise, moonset, eveningSunset, nextSunrise);
  final morningEnd = morningStart == null
      ? null
      : _earlier(moonset, morningSunrise);
  final eveningEnd = eveningStart == null
      ? null
      : _earlier(moonset, nextSunrise);

  if (morningStart == null || morningEnd == null) {
    if (eveningStart == null || eveningEnd == null) return null;
    return MoonViewingWindow(
      start: eveningStart,
      end: eveningEnd,
      isMorning: false,
    );
  }
  if (eveningStart == null || eveningEnd == null) {
    return MoonViewingWindow(
      start: morningStart,
      end: morningEnd,
      isMorning: true,
    );
  }

  return morningEnd.difference(morningStart) >=
          eveningEnd.difference(eveningStart)
      ? MoonViewingWindow(start: morningStart, end: morningEnd, isMorning: true)
      : MoonViewingWindow(
          start: eveningStart,
          end: eveningEnd,
          isMorning: false,
        );
}

DateTime _earlier(DateTime a, DateTime b) => a.isBefore(b) ? a : b;

DateTime? _overlap(
  DateTime aStart,
  DateTime aEnd,
  DateTime bStart,
  DateTime bEnd,
) {
  final start = aStart.isAfter(bStart) ? aStart : bStart;
  final end = aEnd.isBefore(bEnd) ? aEnd : bEnd;
  return end.isAfter(start) ? start : null;
}
