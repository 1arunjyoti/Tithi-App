import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/panchang_provider.dart';
import 'sunrise_calculator.dart';

final hinduCalendarServiceProvider = Provider<HinduCalendarService>((ref) {
  return HinduCalendarService(ref);
});

class HinduCalendarService {
  final Ref _ref;

  HinduCalendarService(this._ref);

  // Standard Hindu Lunar Months (Amanta) starting from Chaitra (New Year)
  List<String> get hinduMonths => const [
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

  /// Returns true if this month has a special prefix (Adhika or Nija).
  /// Adhika = extra intercalary month; Nija = real month following an Adhika.
  bool isAdhikaMasa(String masa) =>
      masa.startsWith('Adhika_') || masa.startsWith('Nija_');

  /// Returns the base masa name, stripping any prefix.
  /// e.g. 'Adhika_Jyeshtha' / 'Nija_Jyeshtha' -> 'Jyeshtha', 'Jyeshtha' -> 'Jyeshtha'
  String baseMasaName(String masa) => baseMasaNameStatic(masa);

  /// Calculates the Hindu Date details for a given Gregorian date.
  ///
  /// The tithi and masa follow the udaya (sunrise) rule, consistent with
  /// [PanchangData]: they are evaluated at sunrise, not at midnight.
  /// Midnight evaluation picks the previous tithi whenever a boundary falls
  /// between 00:00 and sunrise (e.g. Sep 5 2026: Ashtami ends 00:13, so
  /// midnight reads Ashtami/23 while sunrise correctly reads Navami/24).
  Future<
    ({
      int tithi,
      int fullTithi,
      String paksha,
      String masa,
      int vsYear,
      int shakaYear,
    })
  >
  calculateDate(DateTime date) async {
    final service = _ref.read(panchangServiceProvider);

    // Ensure initialized
    await _ref.read(panchangInitProvider.future);

    final coords = _ref.read(resolvedCoordinatesProvider);
    final normalized = DateTime(date.year, date.month, date.day);
    final sunrise = SunriseCalculator.calculateSunriseIST(
      date: normalized,
      latitude: coords.latitude,
      longitude: coords.longitude,
    );

    // 1. Calculate Tithi at sunrise (udaya tithi, 1-based 1..30:
    // 1-15 Shukla with 15 = Purnima, 16-30 Krishna).
    final rawTithi = await service.calculateTithi(
      sunrise,
      latitude: coords.latitude,
      longitude: coords.longitude,
    );

    int tithi = rawTithi.floor().clamp(1, 30);

    // Tithi Number: 1 to 15.
    String paksha = 'Shukla';
    int displayTithi = tithi; // 1..30 (raw tithi)
    int fullTithi = tithi; // 1..30

    if (displayTithi > 15) {
      paksha = 'Krishna';
      displayTithi -= 15;
    }

    // 2. Calculate Masa at sunrise, matching the tithi instant.
    String masa = await service.calculateMasa(
      sunrise,
      rawTithi,
      latitude: coords.latitude,
      longitude: coords.longitude,
    );

    // 3. Calculate Year (Vikram Samvat)
    // VS = Gregorian + 57 on/after Chaitra Shukla Pratipada (New Year),
    // Gregorian + 56 before it. See vikramSamvatYear for the boundary rules.
    int vsYear = vikramSamvatYear(
      gregorianYear: date.year,
      gregorianMonth: date.month,
      masa: masa,
    );

    // Edge Case: 'Unknown' masa
    if (masa == 'Unknown') {
      // Fallback
      vsYear = date.year + 57;
    }

    // 4. Calculate Shaka Samvat Year (traditional lunisolar Shaka shares the
    // same Chaitra Shukla Pratipada New Year as Vikram; NOT the 1957 official
    // solar civil calendar fixed at March 22).
    // Shaka = Gregorian - 78 (after new year) or - 79 (before), which is
    // exactly VS - 135 in both cases, so derive it to keep the invariant.
    final shakaYear = vsYear - 135; // VS - Shaka difference is 135 years

    return (
      tithi: displayTithi,
      fullTithi: fullTithi,
      paksha: paksha,
      masa: masa,
      vsYear: vsYear,
      shakaYear: shakaYear,
    );
  }

  /// Vikram Samvat year for a Gregorian year/month and (Amanta) masa.
  ///
  /// Pure boundary logic, extracted for testability. Implements the spec rule:
  /// +57 on/after Chaitra Shukla Pratipada (New Year), +56 before it.
  /// - Jan/Feb can only hold the old year's tail (Pausha..Phalguna) -> +56.
  /// - May..Dec can only hold the new year (Vaishakha onwards) -> +57.
  /// - Mar/Apr straddles the New Year, so the masa decides: months from
  ///   Chaitra onwards (Chaitra/Vaishakha/...) are the new year (+57),
  ///   Phalguna and earlier are the old year (+56). In Amanta, any Chaitra
  ///   day is on/after New Year by definition.
  static int vikramSamvatYear({
    required int gregorianYear,
    required int gregorianMonth,
    required String masa,
  }) {
    if (gregorianMonth < 3) {
      return gregorianYear + 56;
    }
    if (gregorianMonth > 4) {
      return gregorianYear + 57;
    }
    // March or April: use baseMasaName to handle Adhika prefix
    // (e.g. 'Adhika_Jyeshtha' -> 'Jyeshtha').
    final baseMasa = baseMasaNameStatic(masa);
    if (baseMasa == 'Chaitra' ||
        baseMasa == 'Vaishakha' ||
        baseMasa == 'Jyeshtha') {
      return gregorianYear + 57;
    }
    // Phalguna or before
    return gregorianYear + 56;
  }

  /// Static base-masa helper so [vikramSamvatYear] stays instance-free.
  static String baseMasaNameStatic(String masa) {
    if (masa.startsWith('Adhika_')) return masa.substring(7);
    if (masa.startsWith('Nija_')) return masa.substring(5);
    return masa;
  }

  /// returns the Gregorian Date for the Start (Shukla Pratipada) of the given Hindu Month/Year
  Future<DateTime> getMonthStart(int vsYear, int monthIndex) async {
    // 1. Approximate Gregorian Start
    // VS 2081 -> Chaitra starts April 2024.
    // approxGregYear = vsYear - 57.
    int gYear = vsYear - 57;

    // Chaitra(0) -> March/April.
    // Offset from March roughly?
    // Chaitra ~ March 20.
    // Add monthIndex * 29.5 days.

    DateTime baseline = DateTime(gYear, 3, 20); // Equinox ish
    // Add roughly monthIndex * 29.5
    DateTime estimate = baseline.add(
      Duration(days: (monthIndex * 29.5).round()),
    );

    // 2. Refine
    // Search window +/- 15 days?
    // Find day where calculateDate returns {masa: targetMasa, tithi: 1, paksha: Shukla}

    DateTime search = estimate.subtract(const Duration(days: 15));
    final targetMasa = hinduMonths[monthIndex];

    for (int i = 0; i < 65; i++) {
      final hDate = await calculateDate(search);
      // Skip 'Nija_' months (second occurrence after an Adhika) so we find
      // the first (Adhika or normal) occurrence which is where festivals fall.
      // NOTE: only Nija_ is skipped — Adhika_ IS a first occurrence. (A past
      // revision excluded both prefixes, which made Adhika years unresolvable
      // and fell through to the estimate fallback.)
      final isNija = hDate.masa.startsWith('Nija_');
      if (!isNija &&
          baseMasaName(hDate.masa) == targetMasa &&
          hDate.tithi == 1 &&
          hDate.paksha == 'Shukla') {
        return search;
      }
      search = search.add(const Duration(days: 1));
    }

    // Fallback: If not found (rare, maybe skipped tithi), return estimate
    return estimate;
  }

  /// Start of the lunar month CONTAINING [date]: one day past the nearest
  /// earlier masa change, matched by FULL masa name so Adhika/Nija months
  /// slice exactly one masa each. Masa-pinned (not tithi-pinned) on purpose:
  /// a Kshaya Pratipada (tithi 1 with no sunrise — observed in this era, e.g.
  /// Ashadha 1948 missing tithis 4 and 28) has no tithi-1 day to find, but
  /// the masa transition is always observable. Masa attribution is constant
  /// per lunation (memoized verdict), so transitions are clean single steps.
  Future<DateTime> monthStartContaining(DateTime date) async {
    final first = await calculateDate(date);
    final targetMasa = first.masa;
    var day = DateTime(date.year, date.month, date.day - 1);
    for (int i = 0; i < 34; i++) {
      final hDate = await calculateDate(day);
      if (hDate.masa != targetMasa) {
        return day.add(const Duration(days: 1));
      }
      day = day.subtract(const Duration(days: 1));
    }
    return DateTime(date.year, date.month, date.day - 29);
  }

  /// Start of the masa immediately AFTER the month beginning at [monthStart]:
  /// the first date past it with a different masa. Correct by construction
  /// across Adhika→Nija→base transitions (and across year ends), with or
  /// without an observable Pratipada.
  Future<DateTime> nextMonthStartAfter(DateTime monthStart) async {
    final first = await calculateDate(monthStart);
    final currentMasa = first.masa;
    var day = DateTime(
      monthStart.year,
      monthStart.month,
      monthStart.day + 1,
    );
    for (int i = 0; i < 35; i++) {
      final hDate = await calculateDate(day);
      if (hDate.masa != currentMasa) {
        return day;
      }
      day = day.add(const Duration(days: 1));
    }
    return DateTime(
      monthStart.year,
      monthStart.month,
      monthStart.day + 30,
    );
  }

  /// Start of the masa immediately BEFORE the month beginning at [monthStart].
  Future<DateTime> prevMonthStartBefore(DateTime monthStart) async {
    final day = DateTime(
      monthStart.year,
      monthStart.month,
      monthStart.day - 1,
    );
    return monthStartContaining(day);
  }

  /// Start of the NEXT masa from anywhere inside a month: the first date
  /// past [date] with a different masa. Single forward scan — swipe/chevron
  /// "next" without index arithmetic (which skips Nija months entirely) and
  /// without assuming an observable Pratipada.
  Future<DateTime> nextMasaStartFrom(DateTime date) async {
    final first = await calculateDate(date);
    final currentMasa = first.masa;
    var day = DateTime(date.year, date.month, date.day + 1);
    for (int i = 0; i < 35; i++) {
      final hDate = await calculateDate(day);
      if (hDate.masa != currentMasa) {
        return day;
      }
      day = day.add(const Duration(days: 1));
    }
    return DateTime(date.year, date.month, date.day + 30);
  }

  /// Start of the PREVIOUS masa from anywhere inside a month: resolve the
  /// containing month's start first, then step one masa back. (A single
  /// backward scan would stop at the current month's own start region.)
  Future<DateTime> prevMasaStartFrom(DateTime date) async {
    final currentStart = await monthStartContaining(date);
    return prevMonthStartBefore(currentStart);
  }
}
