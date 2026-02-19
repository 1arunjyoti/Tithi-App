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

  /// Calculates the Hindu Date details for a given Gregorian date.
  Future<({int tithi, int fullTithi, String paksha, String masa, int vsYear, int shakaYear})>
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
    // VS = Gregorian + 57 usually.
    // Transition happens at Chaitra Shukla Pratipada.
    // If Date is before Chaitra Shukla 1 -> Year is (Gregorian + 56).
    // If Date is on/after -> (Gregorian + 57).

    int vsYear = date.year + 57;
    // int monthIndex = hinduMonths.indexOf(masa); // Unused

    // Logic to determine if we are in the "late" part of Gregorian year (Mar-Dec) or "early" (Jan-Mar).
    // Chaitra is usually March/April.
    // Only Chaitra, Phalguna, Magh, Pausha are ambiguous regarding Gregorian Year?
    // Actually, simple rule:
    // If the calculated Masa is 'Chaitra'.. 'Phalguna'
    // The sequence for a VS year is Chaitra(0) ... Phalguna(11).
    // This sequence usually spans Gregorian N (Mar) to N+1 (Mar).
    // Example: Chaitra 2081 starts April 2024.
    // Phalguna 2081 ends March 2025.
    // So for a date in April 2024 -> VS 2081.
    // For a date in Feb 2025 -> VS 2081. (GregYear + 56).

    // So:
    // If date is Jan/Feb/March:
    //    It could be VS (Year+56) if it's Phalguna/Magh/Pausha or late Chaitra(prev year?).
    //    Wait, Chaitra starts the new year.
    //    So if we are in Jan/Feb, we are in end of VS(Previous). i.e. 2025 -> VS 2081.
    //    2025 + 56 = 2081.
    //    So if date.month < 3 -> vsYear = date.year + 56.
    //    If date.month > 4 -> vsYear = date.year + 57.
    //    If date.month == 3 (March) or 4 (April), we need to check Masa.

    if (date.month < 3) {
      vsYear = date.year + 56;
    } else if (date.month > 4) {
      vsYear = date.year + 57;
    } else {
      // March or April.
      // If Masa is Chaitra ->
      //    If Paksha is Shukla -> New Year started -> +57.
      //    If Paksha is Krishna (Amanta Chaitra vs Purnimanta?)
      //    Amanta system: Month starts at Shukla Pratipada.
      //    So Chaitra Shukla 1 is Day 1.
      //    So if Masa is Chaitra, it is ALWAYS the new year in Amanta.
      //    So Chaitra -> +57.
      // If Masa is Phalguna -> Old Year -> +56.
      // If Masa is Vaishakha -> New Year -> +57.

      if (masa == 'Chaitra' || masa == 'Vaishakha' || masa == 'Jyeshtha') {
        vsYear = date.year + 57;
      } else {
        // Phalguna or before
        vsYear = date.year + 56;
      }
    }

    // Edge Case: 'Unknown' masa
    if (masa == 'Unknown') {
      // Fallback
      vsYear = date.year + 57;
    }

    // 4. Calculate Shaka Samvat Year
    // Shaka = Gregorian - 78 (after new year) or - 79 (before)
    // New Year is same as Vikram: Chaitra Shukla 1
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

    for (int i = 0; i < 35; i++) {
      final hDate = await calculateDate(search);
      if (hDate.masa == targetMasa &&
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
