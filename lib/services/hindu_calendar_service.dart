import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/panchang_provider.dart';

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

    // 1. Calculate Tithi
    final rawTithi = await service.calculateTithi(date);

    int tithi = rawTithi.floor();

    // Tithi Number: 1 to 15.
    String paksha = 'Shukla';
    int displayTithi = tithi; // 1..30 (raw tithi)
    int fullTithi = tithi; // 1..30

    if (displayTithi > 15) {
      paksha = 'Krishna';
      displayTithi -= 15;
    }

    // 2. Calculate Masa
    String masa = await service.calculateMasa(date, rawTithi);

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
      if (!isAdhikaMasa(hDate.masa) &&
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
}
