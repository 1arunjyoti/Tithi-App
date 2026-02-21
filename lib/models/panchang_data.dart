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
      if (f.conditions == 'Solar' && f.panchangRules.solarDate != null) {
        final dateStr =
            "${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
        if (f.panchangRules.solarDate == dateStr) {
          return true;
        }
      }

      double targetRawTithi = rawTithi;
      if (f.id == 'ganesh_chaturthi' && rawTithiMadhyahna != null) {
        targetRawTithi = rawTithiMadhyahna;
      } else if (f.id == 'maha_shivaratri' && rawTithiNishita != null) {
        targetRawTithi = rawTithiNishita;
      } else if ((f.id == 'vijayadashami' || f.id == 'dussehra') &&
          rawTithiAparahna != null) {
        targetRawTithi = rawTithiAparahna;
      } else if (f.id == 'parashurama_jayanti' && rawTithiMadhyahna != null) {
        targetRawTithi = rawTithiMadhyahna;
      } else {
        // Standard check: Does it match Sunrise Tithi?
        final targetIndex = targetRawTithi.floor();
        String targetPaksha = targetIndex <= 15 ? 'Shukla' : 'Krishna';
        int targetTithiNum = targetIndex <= 15 ? targetIndex : targetIndex - 15;
        bool isMatch = f.matchesTithi(
          targetPaksha,
          targetTithiNum,
          masa,
          monthSystem,
        );

        // Fallback for Kshaya Tithi:
        // If it didn't match the Sunrise Tithi, check if the required Tithi
        // falls entirely between this Sunrise and the next Sunrise.
        if (!isMatch && rawTithiNextSunrise != null) {
          int currentSunriseIndex = rawTithi.floor();
          int nextSunriseIndex = rawTithiNextSunrise.floor();

          if (nextSunriseIndex < currentSunriseIndex) {
            nextSunriseIndex += 30; // Handle wrap-around
          }

          // If the difference > 1, there is at least one skipped Tithi
          if (nextSunriseIndex - currentSunriseIndex > 1) {
            for (int i = currentSunriseIndex + 1; i < nextSunriseIndex; i++) {
              int skippedIndex = i > 30 ? i - 30 : i;

              String kshayaPaksha = skippedIndex <= 15 ? 'Shukla' : 'Krishna';
              int kshayaTithiNum = skippedIndex <= 15
                  ? skippedIndex
                  : skippedIndex - 15;

              // If the Kshaya Tithi crosses the Amavasya/Purnima boundary, it belongs to the next month/paksha
              // Use the masaNextSunrise if it evaluates true.
              String testMasa = masa;
              if (skippedIndex == 1 || skippedIndex == 16) {
                testMasa = masaNextSunrise.isNotEmpty ? masaNextSunrise : masa;
              }

              if (f.matchesTithi(
                    kshayaPaksha,
                    kshayaTithiNum,
                    masa,
                    monthSystem,
                  ) ||
                  f.matchesTithi(
                    kshayaPaksha,
                    kshayaTithiNum,
                    testMasa,
                    monthSystem,
                  )) {
                return true;
              }
            }
          }
        }
        return isMatch;
      }

      final targetIndex = targetRawTithi.floor();
      String targetPaksha = targetIndex <= 15 ? 'Shukla' : 'Krishna';
      int targetTithiNum = targetIndex <= 15 ? targetIndex : targetIndex - 15;

      return f.matchesTithi(targetPaksha, targetTithiNum, masa, monthSystem);
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
