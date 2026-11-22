/// Earliest day the forward occurrence scan should start from when looking
/// for a festival's first match on/after [from].
///
/// The Gregorian-month lookup is only a fast-forward hint. It must never land
/// after [from]: a late start skips occurrences at the beginning of the scan
/// window. A January start is the trap — the current year's Pausha estimate
/// falls in October, long after Shattila Ekadashi (Pausha Krishna 11) on
/// Jan 14, so the previous lunisolar year's estimate is used instead. The
/// caller skips matches before [from] when scanning from an earlier hint.
DateTime festivalScanStart(DateTime from, String masa) {
  const approxMonth = {
    'Chaitra': 3,
    'Vaishakha': 4,
    'Jyeshtha': 5,
    'Ashadha': 6,
    'Shravana': 7,
    'Bhadrapada': 8,
    'Ashwin': 9,
    'Kartika': 10,
    'Margashirsha': 11,
    'Pausha': 12,
    'Magha': 1,
    'Phalguna': 2,
  };

  final targetMonth = approxMonth[masa];
  if (targetMonth == null) return from;

  // 45 days of slack covers an Adhika month shifting the real masa later than
  // its Gregorian approximation.
  DateTime estimateFor(int year) =>
      DateTime(year, targetMonth).subtract(const Duration(days: 45));

  final current = estimateFor(from.year);
  if (!current.isAfter(from)) return current;

  final previous = estimateFor(from.year - 1);
  return previous.isAfter(from) ? from : previous;
}
