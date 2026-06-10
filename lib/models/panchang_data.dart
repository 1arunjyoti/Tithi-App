import 'festival.dart';
import 'hindu_month_system.dart';

/// Panchang data for a specific date
class PanchangData {
  final DateTime date;
  final double rawTithi;
  final int tithiNumber;
  final String tithiName;
  final String paksha;
  final String masa;
  final List<Festival> festivals;
  final DateTime? sunrise;
  final DateTime? sunset;

  const PanchangData({
    required this.date,
    required this.rawTithi,
    required this.tithiNumber,
    required this.tithiName,
    required this.paksha,
    this.masa = '',
    this.festivals = const [],
    this.sunrise,
    this.sunset,
  });

  /// Check if this is Shukla Paksha (waxing moon)
  bool get isShukla => paksha == 'Shukla';

  /// Check if this is Krishna Paksha (waning moon)
  bool get isKrishna => paksha == 'Krishna';

  /// Check if there are any festivals on this day
  bool get hasFestivals => festivals.isNotEmpty;

  /// Get major festivals only
  List<Festival> get majorFestivals =>
      festivals.where((f) => f.category == 'major').toList();

  /// Get vrat (fasting) days only
  List<Festival> get vrats =>
      festivals.where((f) => f.category == 'vrat').toList();

  /// Create from raw tithi calculation
  ///
  /// [monthSystem] - The calendar system to use for festival matching.
  /// Defaults to Amanta. When Purnimant is selected, the masa is converted
  /// for accurate festival matching since festivals are stored in Amanta format.
  factory PanchangData.fromRawTithi({
    required DateTime date,
    required double rawTithi,
    String masa = '',
    List<Festival> allFestivals = const [],
    HinduMonthSystem monthSystem = HinduMonthSystem.amanta,
    DateTime? sunrise,
    DateTime? sunset,
    double? rawTithiMadhyahna,
    double? rawTithiAparahna,
    double? rawTithiNishita,
    double? rawTithiNextSunrise,
    String masaNextSunrise = '',
  }) {
    final tithiIndex = rawTithi.floor();

    // Determine paksha and tithi number
    String paksha;
    int tithiNumber;
    if (tithiIndex <= 15) {
      paksha = 'Shukla';
      tithiNumber = tithiIndex;
    } else {
      paksha = 'Krishna';
      tithiNumber = tithiIndex - 15;
    }

    // Get tithi name
    final tithiName = _getTithiName(tithiNumber);

    // Find matching festivals (pass month system for proper conversion)
    final matchingFestivals = allFestivals.where((f) {
      // Solar festivals: matched by Gregorian date only
      if (f.conditions == 'Solar' && f.panchangRules.solarDate != null) {
        final dateStr =
            "${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
        return f.panchangRules.solarDate == dateStr;
      }

      // SMELL-05: Select the appropriate timing checkpoint generically via
      // timingOverride instead of hard-coding festival IDs.
      // BUG-04: pass `date` so weekday constraints are evaluated.
      double targetRawTithi = switch (f.panchangRules.timingOverride) {
        'madhyahna' => rawTithiMadhyahna ?? rawTithi,
        'aparahna'  => rawTithiAparahna  ?? rawTithi,
        'nishita'   => rawTithiNishita   ?? rawTithi,
        _           => rawTithi,
      };

      final targetIndex = targetRawTithi.floor();
      final targetPaksha = targetIndex <= 15 ? 'Shukla' : 'Krishna';
      final targetTithiNum =
          targetIndex <= 15 ? targetIndex : targetIndex - 15;
      bool isMatch =
          f.matchesTithi(targetPaksha, targetTithiNum, masa, monthSystem, date);

      // Fallback for Kshaya Tithi: if the required tithi falls entirely
      // between this sunrise and the next, count it as matching today.
      if (!isMatch && rawTithiNextSunrise != null) {
        int currentSunriseIndex = rawTithi.floor();
        int nextSunriseIndex = rawTithiNextSunrise.floor();

        if (nextSunriseIndex < currentSunriseIndex) {
          nextSunriseIndex += 30; // Handle wrap-around
        }

        if (nextSunriseIndex - currentSunriseIndex > 1) {
          for (int i = currentSunriseIndex + 1; i < nextSunriseIndex; i++) {
            int skippedIndex = i > 30 ? i - 30 : i;
            String kshayaPaksha = skippedIndex <= 15 ? 'Shukla' : 'Krishna';
            int kshayaTithiNum =
                skippedIndex <= 15 ? skippedIndex : skippedIndex - 15;

            // If the Kshaya Tithi crosses the Amavasya/Purnima boundary,
            // use masaNextSunrise for the comparison.
            String testMasa = masa;
            if (skippedIndex == 1 || skippedIndex == 16) {
              testMasa = masaNextSunrise.isNotEmpty ? masaNextSunrise : masa;
            }

            // BUG-5: avoid a redundant identical matchesTithi call when
            // testMasa == masa (no boundary crossing for this skipped tithi).
            final matchesCurrent = f.matchesTithi(
              kshayaPaksha, kshayaTithiNum, masa, monthSystem, date,
            );
            final matchesBoundary = testMasa != masa &&
                f.matchesTithi(
                  kshayaPaksha, kshayaTithiNum, testMasa, monthSystem, date,
                );
            if (matchesCurrent || matchesBoundary) {
              return true;
            }
          }
        }
      }

      return isMatch;
    }).toList();

    return PanchangData(
      date: date,
      rawTithi: rawTithi,
      tithiNumber: tithiNumber,
      tithiName: tithiName,
      paksha: paksha,
      masa: masa,
      festivals: matchingFestivals,
      sunrise: sunrise,
      sunset: sunset,
    );
  }

  static String _getTithiName(int tithiNum) {
    const tithiNames = [
      '',
      'Pratipada',
      'Dwitiya',
      'Tritiya',
      'Chaturthi',
      'Panchami',
      'Shashthi',
      'Saptami',
      'Ashtami',
      'Navami',
      'Dashami',
      'Ekadashi',
      'Dwadashi',
      'Trayodashi',
      'Chaturdashi',
      'Purnima/Amavasya',
    ];
    if (tithiNum >= 1 && tithiNum <= 15) {
      return tithiNames[tithiNum];
    }
    return 'Unknown';
  }

  @override
  String toString() =>
      'PanchangData($date: $masa $paksha $tithiName, ${festivals.length} festivals)';
}
