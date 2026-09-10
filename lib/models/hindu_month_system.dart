/// Hindu Month System enum for Amanta/Purnimant calendar support
///
/// - **Amanta**: Month ends at Amavasya (New Moon) - South India, Maharashtra, Gujarat
/// - **Purnimant**: Month ends at Purnima (Full Moon) - North India (Vikram Samvat)
///
/// Only Krishna Paksha month names differ between systems.
/// Shukla Paksha month names are identical in both systems.
library;

enum HinduMonthSystem { amanta, purnimant }

extension HinduMonthSystemExt on HinduMonthSystem {
  String get label => switch (this) {
    HinduMonthSystem.amanta => 'Amanta',
    HinduMonthSystem.purnimant => 'Purnimant',
  };

  String get description => switch (this) {
    HinduMonthSystem.amanta =>
      'Month ends at Amavasya (South India, Maharashtra, Gujarat)',
    HinduMonthSystem.purnimant =>
      'Month ends at Purnima (North India - Vikram Samvat)',
  };

  String get shortDescription => switch (this) {
    HinduMonthSystem.amanta => 'New Moon ending',
    HinduMonthSystem.purnimant => 'Full Moon ending',
  };
}

/// List of Hindu months in order (used for conversion)
const List<String> hinduMonthsOrder = [
  'Chaitra',
  'Vaishakha',
  'Jyeshtha',
  'Ashadha',
  'Shravana',
  'Bhadrapada',
  'Ashwin',
  'Kartika',
  'Margashirsha',
  'Pausha',
  'Magha',
  'Phalguna',
];

/// Converts an Amanta month name to Purnimant equivalent during Krishna Paksha.
///
/// In Purnimant system, Krishna Paksha belongs to the NEXT month.
/// Example: Phalguna Krishna (Amanta) = Chaitra Krishna (Purnimant)
String convertAmantaToPurnimant(String amantaMasa, String paksha) {
  if (paksha != 'Krishna') return amantaMasa; // No change for Shukla

  final index = hinduMonthsOrder.indexOf(amantaMasa);
  if (index == -1) return amantaMasa; // Unknown month, return as-is

  // Krishna Paksha in Purnimant = next month
  final nextIndex = (index + 1) % 12;
  return hinduMonthsOrder[nextIndex];
}

/// Display label for an Amanta [amantaMasa] on a [paksha] day under [system].
///
/// Single definition for UI and export so the two can never drift: Shukla
/// days are identical in both systems; Krishna days take the next month's
/// name in Purnimant (e.g. Janmashtami day: Shravana -> Bhadrapada).
/// Unknown/Adhika names pass through unchanged.
String displayMasaName(
  String amantaMasa,
  String paksha,
  HinduMonthSystem system,
) {
  if (system != HinduMonthSystem.purnimant) return amantaMasa;
  return convertAmantaToPurnimant(amantaMasa, paksha);
}

/// Converts a Purnimant month name to Amanta equivalent during Krishna Paksha.
///
/// This is the reverse of convertAmantaToPurnimant.
/// Example: Chaitra Krishna (Purnimant) = Phalguna Krishna (Amanta)
String convertPurnimantToAmanta(String purnimantMasa, String paksha) {
  if (paksha != 'Krishna') return purnimantMasa; // No change for Shukla

  final index = hinduMonthsOrder.indexOf(purnimantMasa);
  if (index == -1) return purnimantMasa; // Unknown month, return as-is

  // Krishna Paksha in Amanta = previous month
  final prevIndex = (index - 1 + 12) % 12;
  return hinduMonthsOrder[prevIndex];
}

// --- Hindu Year Era ---

/// Hindu Year Era for calendar display
/// - Vikram Samvat: Starts 57 BCE (North India, Nepal)
/// - Shaka Samvat: Starts 78 CE (Official Indian Calendar, South India)
enum HinduYearEra { vikramSamvat, shakaSamvat }

/// Amanta masa names by sidereal Sun rashi (0 = Aries .. 11 = Pisces).
/// A lunation's masa takes the name of the rashi holding its first new moon.
const List<String> masaNamesBySunRashi = [
  'Vaishakha', // 0-30 Aries
  'Jyeshtha', // 30-60 Taurus
  'Ashadha', // 60-90 Gemini
  'Shravana', // 90-120 Cancer
  'Bhadrapada', // 120-150 Leo
  'Ashwin', // 150-180 Virgo
  'Kartika', // 180-210 Libra
  'Margashirsha', // 210-240 Scorpio
  'Pausha', // 240-270 Sagittarius
  'Magha', // 270-300 Capricorn
  'Phalguna', // 300-330 Aquarius
  'Chaitra', // 330-360 Pisces
];

/// Map Sun's sidereal longitude to rashi index (0-11).
int sunRashiIndex(double longitude) {
  double l = longitude % 360;
  if (l < 0) l += 360;
  return (l / 30).floor().clamp(0, 11);
}

/// Pure Adhika verdict + naming for a bracketing new-moon pair.
/// Adhika (intercalary) masa: no Surya Sankranti between the new moons,
/// i.e. both instants share a rashi. The name comes from the first new moon.
/// Pure (no ephemeris) so it is directly unit-testable.
({bool adhika, String masa}) resolveAdhikaVerdict({
  required double sunLongN1,
  required double sunLongN2,
}) {
  final prevIndex = sunRashiIndex(sunLongN1);
  final nextIndex = sunRashiIndex(sunLongN2);
  final masaName = masaNamesBySunRashi[prevIndex];
  return (adhika: prevIndex == nextIndex, masa: masaName);
}

/// Pure: distance of [rawTithi] (1..30) to the new-moon wrap point (30.0) on
/// the 30-cycle. Used to pick the candidate instant nearest a true new moon
/// without any ephemeris, so it is directly unit-testable.
double newMoonDistance(double rawTithi) {
  final t = rawTithi % 30;
  return (30.0 - t) % 30;
}

/// Pure: index i such that the new moon falls between candidate tithis[i]
/// (pre-wrap, high) and tithis[i+1] (post-wrap, low); -1 when no adjacent
/// pair straddles the wrap. Pure (no ephemeris) so directly unit-testable.
int wrapPairIndex(List<double> tithis) {
  for (int i = 0; i + 1 < tithis.length; i++) {
    if (tithis[i] > 20.0 && tithis[i + 1] < 10.0) return i;
  }
  return -1;
}

/// Pure: linear interpolation of the new-moon instant between [dayA] (tithi
/// [tA], pre-wrap) and [dayB] (tithi [tB], post-wrap). Tithi rate varies
/// smoothly, so over 24h this pins the instant to ~±2h for free — no extra
/// ephemeris calls. Sampling the Sun there (instead of at noon) keeps
/// same-day transit/new-moon coincidences on the correct side. Pure, so
/// directly unit-testable.
DateTime interpolateNewMoonInstant(
  DateTime dayA,
  double tA,
  DateTime dayB,
  double tB,
) {
  final before = (30.0 - tA).clamp(0.0, 30.0);
  final after = tB.clamp(0.0, 30.0);
  final total = before + after;
  final frac = total <= 0 ? 0.5 : before / total;
  final micros = (dayB.difference(dayA).inMicroseconds * frac).round();
  return dayA.add(Duration(microseconds: micros));
}

extension HinduYearEraExt on HinduYearEra {
  String get label => switch (this) {
    HinduYearEra.vikramSamvat => 'Vikram Samvat',
    HinduYearEra.shakaSamvat => 'Shaka Samvat',
  };

  String get shortLabel => switch (this) {
    HinduYearEra.vikramSamvat => 'Vikram',
    HinduYearEra.shakaSamvat => 'Shaka',
  };

  String get description => switch (this) {
    HinduYearEra.vikramSamvat => 'Starts 57 BCE (North India, Nepal, Gujarat)',
    HinduYearEra.shakaSamvat =>
      'Starts 78 CE (Official Indian Calendar, South India)',
  };

  /// Calculate the year in this era from a Gregorian year
  /// Note: This is a simplified calculation; actual transition depends on masa
  int fromGregorianYear(int gregorianYear, {bool afterNewYear = true}) {
    return switch (this) {
      HinduYearEra.vikramSamvat =>
        afterNewYear ? gregorianYear + 57 : gregorianYear + 56,
      HinduYearEra.shakaSamvat =>
        afterNewYear ? gregorianYear - 78 : gregorianYear - 79,
    };
  }
}
