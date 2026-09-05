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

  /// Instant the sunrise tithi ends (first tithi boundary after sunrise),
  /// when it falls before the next sunrise. Null when the sunrise tithi
  /// still prevails at the next sunrise (no daytime transition).
  ///
  /// Set by the panchang provider (single-day path only — the month batch
  /// skips it for performance). Enables the two-tithi display
  /// ("Ashtami → Navami") for squeeze cases where a short tithi such as
  /// Navami begins after one sunrise and ends before the next, so it never
  /// prevails at any sunrise and would otherwise be invisible between the
  /// surrounding days (e.g. Oct 4-5 2026: Ashtami → Dashami).
  final DateTime? tithiTransitionTime;

  /// 1-30 index of the tithi taking over at [tithiTransitionTime]
  /// (normally the sunrise tithi's index + 1, wrapping 30 → 1).
  final int? transitionTithiIndex;

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
    this.tithiTransitionTime,
    this.transitionTithiIndex,
  });

  /// Check if this is Shukla Paksha (waxing moon)
  bool get isShukla => paksha == 'Shukla';

  /// Check if this is Krishna Paksha (waning moon)
  bool get isKrishna => paksha == 'Krishna';

  /// Full tithi index in the 1-30 cycle (rawTithi.floor()).
  /// Unlike [tithiNumber] (1-15 within a paksha), this uniquely identifies
  /// the tithi: 1-15 = Shukla, 16-30 = Krishna.
  /// Use this when querying exact tithi start/end times.
  int get tithiIndex => rawTithi.floor().clamp(1, 30);

  /// Check if there are any festivals on this day
  bool get hasFestivals => festivals.isNotEmpty;

  /// Whether a tithi transition occurs between this sunrise and the next,
  /// i.e. the day should show two tithis ("Ashtami → Navami").
  bool get hasTithiTransition =>
      tithiTransitionTime != null &&
      transitionTithiIndex != null &&
      transitionTithiIndex! >= 1 &&
      transitionTithiIndex! <= 30 &&
      transitionTithiIndex != tithiIndex;

  /// Paksha of the tithi taking over at [tithiTransitionTime].
  String get transitionPaksha =>
      transitionTithiIndex != null && transitionTithiIndex! <= 15
      ? 'Shukla'
      : 'Krishna';

  /// Paksha-relative (1-15) number of the tithi taking over.
  int get transitionTithiNumber {
    final idx = transitionTithiIndex ?? tithiIndex;
    return idx <= 15 ? idx : idx - 15;
  }

  /// Name of the tithi taking over at [tithiTransitionTime].
  String get transitionTithiName =>
      tithiNameFor(transitionTithiNumber, transitionPaksha);

  /// Get major festivals only
  List<Festival> get majorFestivals =>
      festivals.where((f) => f.category == 'major').toList();

  /// Get vrat (fasting) days only
  List<Festival> get vrats =>
      festivals.where((f) => f.category == 'vrat').toList();

  /// Create from raw tithi calculation
  ///
  /// [monthSystem] - The calendar display system (Amanta or Purnimant).
  /// Festival matching is ALWAYS done in Amanta: festivals are stored in
  /// Amanta format and [masa]/[masaNextSunrise] are Amanta values computed
  /// by the panchang service. Purnimant conversion is display-only and is
  /// applied by widgets at render time — passing the display system into
  /// matching here would double-shift Krishna-paksha masas (e.g. Amanta
  /// Shravana Krishna misread as Purnimant and shifted to Ashadha),
  /// making Krishna festivals such as Janmashtami disappear.
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
    DateTime? tithiTransitionTime,
    int? transitionTithiIndex,
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
    final tithiName = tithiNameFor(tithiNumber, paksha);

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
        'aparahna' => rawTithiAparahna ?? rawTithi,
        'nishita' => rawTithiNishita ?? rawTithi,
        _ => rawTithi,
      };

      final targetIndex = targetRawTithi.floor();
      final targetPaksha = targetIndex <= 15 ? 'Shukla' : 'Krishna';
      final targetTithiNum = targetIndex <= 15 ? targetIndex : targetIndex - 15;
      // Match in Amanta: both the stored festival rules and `masa` (from
      // calculateMasa) are Amanta. `monthSystem` is display-only; passing it
      // here would convert an already-Amanta masa a second time and drop
      // every Krishna-paksha festival in Purnimant mode.
      bool isMatch = f.matchesTithi(
        targetPaksha,
        targetTithiNum,
        masa,
        HinduMonthSystem.amanta,
        date,
      );

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
            int kshayaTithiNum = skippedIndex <= 15
                ? skippedIndex
                : skippedIndex - 15;

            // If the Kshaya Tithi crosses the Amavasya/Purnima boundary,
            // use masaNextSunrise for the comparison.
            String testMasa = masa;
            if (skippedIndex == 1 || skippedIndex == 16) {
              testMasa = masaNextSunrise.isNotEmpty ? masaNextSunrise : masa;
            }

            // BUG-5: avoid a redundant identical matchesTithi call when
            // testMasa == masa (no boundary crossing for this skipped tithi).
            // Amanta matching (see above): `masa`/`testMasa` are Amanta.
            final matchesCurrent = f.matchesTithi(
              kshayaPaksha,
              kshayaTithiNum,
              masa,
              HinduMonthSystem.amanta,
              date,
            );
            final matchesBoundary =
                testMasa != masa &&
                f.matchesTithi(
                  kshayaPaksha,
                  kshayaTithiNum,
                  testMasa,
                  HinduMonthSystem.amanta,
                  date,
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
      tithiTransitionTime: tithiTransitionTime,
      transitionTithiIndex: transitionTithiIndex,
    );
  }

  /// Tithi name for a paksha-relative number (1-15) and paksha.
  /// Public so festival-scoped UI (e.g. the event detail sheet, which shows
  /// the festival's observed tithi rather than the sunrise tithi) can label
  /// any tithi without a full PanchangData.
  static String tithiNameFor(int tithiNum, String paksha) {
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
    if (tithiNum >= 1 && tithiNum <= 14) {
      return tithiNames[tithiNum];
    }
    if (tithiNum == 15) {
      if (paksha == 'Shukla') return 'Purnima';
      if (paksha == 'Krishna') return 'Amavasya';
      return 'Purnima/Amavasya';
    }
    return 'Unknown';
  }

  @override
  String toString() =>
      'PanchangData($date: $masa $paksha $tithiName, ${festivals.length} festivals)';
}
