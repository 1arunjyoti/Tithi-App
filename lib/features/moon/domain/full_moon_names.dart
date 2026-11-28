import '../../../l10n/app_localizations.dart';
import '../../../utils/tithi_localization.dart';

/// Traditional seasonal name of a Gregorian-month full moon.
///
/// These are Farmer's Almanac style names (Wolf, Snow, Worm, ...). They are
///DisplayName strings, not astronomical events: the name follows the month of
///the instant, not the lunar month. September/October also carry the movable
///"Harvest Moon" name - see [isHarvestMoon].
String? traditionalFullMoonName(int month, AppLocalizations l10n) {
  return switch (month) {
    1 => l10n.wolfMoon,
    2 => l10n.snowMoon,
    3 => l10n.wormMoon,
    4 => l10n.pinkMoon,
    5 => l10n.flowerMoon,
    6 => l10n.strawberryMoon,
    7 => l10n.buckMoon,
    8 => l10n.sturgeonMoon,
    9 => l10n.cornMoon,
    10 => l10n.huntersMoon,
    11 => l10n.beaverMoon,
    12 => l10n.coldMoon,
    _ => null,
  };
}

/// The Harvest Moon is the full moon closest to the September equinox, so it
/// can fall in September or October. [purnimas] must contain both months'
/// instants; returns false when either is missing (no guess).
bool isHarvestMoon(DateTime fullMoon, List<DateTime> purnimas) {
  if (fullMoon.month != 9 && fullMoon.month != 10) return false;
  final september = purnimas.where((p) => p.month == 9).toList();
  final october = purnimas.where((p) => p.month == 10).toList();
  if (september.isEmpty || october.isEmpty) return false;
  final equinox = DateTime(fullMoon.year, 9, 22, 12);
  final sepNearest = september.reduce((a, b) => _closerTo(a, b, equinox));
  final octNearest = october.reduce((a, b) => _closerTo(a, b, equinox));
  final candidate =
      _distanceMs(sepNearest, equinox) <= _distanceMs(octNearest, equinox)
      ? september
      : october;
  return candidate.any((p) => _sameCivilDay(p, fullMoon));
}

int _distanceMs(DateTime a, DateTime b) => a.difference(b).abs().inMilliseconds;

DateTime _closerTo(DateTime a, DateTime b, DateTime anchor) =>
    _distanceMs(a, anchor) <= _distanceMs(b, anchor) ? a : b;

/// Blue Moon (monthly definition): the second full moon in a Gregorian month.
///
/// Marking every subsequent full moon in that month keeps the common
/// "once in a blue moon" meaning when a month happens to hold three.
List<DateTime> blueMoonPurnimas(List<DateTime> purnimas) {
  final counts = <String, int>{};
  for (final purnima in purnimas) {
    final key = '${purnima.year}-${purnima.month}';
    counts[key] = (counts[key] ?? 0) + 1;
  }
  final seen = <String>{};
  return purnimas.where((purnima) {
    final key = '${purnima.year}-${purnima.month}';
    if ((counts[key] ?? 0) < 2) return false;
    if (!seen.add(key)) return true;
    return false;
  }).toList();
}

/// True when [date] is a Blue Moon in [purnimas] (calendar-day comparison).
bool isBlueMoon(DateTime date, List<DateTime> purnimas) =>
    blueMoonPurnimas(purnimas).any((p) => _sameCivilDay(p, date));

bool _sameCivilDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// A named Purnima in the Hindu lunar calendar (Guru Purnima, Sharad Purnima,
/// ...), or null when this month has no widely used special name.
String? namedPurnimaForMasa(String masa, AppLocalizations l10n) {
  // Adhika/Nija prefixes say which of two identical months this is, not which
  // festival it carries.
  final clean = masa
      .replaceAll('_', ' ')
      .replaceFirst(RegExp(r'^(Adhika|Nija)\s+', caseSensitive: false), '')
      .trim();
  return switch (clean) {
    'Ashadha' => l10n.guruPurnima,
    'Shravana' => l10n.shravaniPurnima,
    'Ashwin' => l10n.sharadPurnima,
    'Kartika' => l10n.kartikiPurnima,
    'Phalguna' => l10n.holiPurnima,
    _ => null,
  };
}

/// "Sharad Purnima" when a special name exists, otherwise "`Month` Purnima".
String indianFullMoonName(String masa, AppLocalizations l10n) =>
    namedPurnimaForMasa(masa, l10n) ??
    '${localizedHinduMonthName(masa, l10n)} ${l10n.purnima}';

/// Mean synodic month (new moon to new moon) in days.
const double kSynodicMonthDays = 29.530588853;

/// Days since the previous new moon from a raw sunrise tithi in [1, 31].
///
/// Tithi 1 starts just after conjunction and tithi 31 ends at the next one, so
/// the 30 tithi segments map linearly onto the synodic month. A wrap value in
/// (0, 1] is late Amavasya and is shifted forward first, matching
/// `MoonPhaseService._normalizeRawTithi`.
double lunarAgeDays(double rawTithi) {
  final shifted = rawTithi < 1 ? rawTithi + 30 : rawTithi;
  return ((shifted - 1) / 30 * kSynodicMonthDays).clamp(0.0, kSynodicMonthDays);
}

/// The eight classical phase stages from a lit fraction (0-1) and its side.
enum MoonPhaseStage {
  newMoon,
  waxingCrescent,
  firstQuarter,
  waxingGibbous,
  fullMoon,
  waningGibbous,
  lastQuarter,
  waningCrescent,
}

/// Maps a lit fraction to a named stage.
///
/// Thresholds are deliberately wide (2% / 48% / 52% / 98%): a tithi-derived
/// fraction is a smooth approximation, so a knife-edge boundary would make the
/// label flicker between adjacent days.
MoonPhaseStage moonPhaseStage(double illuminatedFraction, bool isWaxing) {
  final lit = illuminatedFraction.clamp(0.0, 1.0);
  if (lit <= 0.02) return MoonPhaseStage.newMoon;
  if (lit >= 0.98) return MoonPhaseStage.fullMoon;
  if (lit < 0.48) {
    return isWaxing
        ? MoonPhaseStage.waxingCrescent
        : MoonPhaseStage.waningCrescent;
  }
  if (lit > 0.52) {
    return isWaxing
        ? MoonPhaseStage.waxingGibbous
        : MoonPhaseStage.waningGibbous;
  }
  return isWaxing ? MoonPhaseStage.firstQuarter : MoonPhaseStage.lastQuarter;
}

String moonPhaseStageName(MoonPhaseStage stage, AppLocalizations l10n) {
  return switch (stage) {
    MoonPhaseStage.newMoon => l10n.newMoon,
    MoonPhaseStage.waxingCrescent => l10n.waxingCrescent,
    MoonPhaseStage.firstQuarter => l10n.firstQuarterMoon,
    MoonPhaseStage.waxingGibbous => l10n.waxingGibbous,
    MoonPhaseStage.fullMoon => l10n.fullMoon,
    MoonPhaseStage.waningGibbous => l10n.waningGibbous,
    MoonPhaseStage.lastQuarter => l10n.lastQuarterMoon,
    MoonPhaseStage.waningCrescent => l10n.waningCrescent,
  };
}
