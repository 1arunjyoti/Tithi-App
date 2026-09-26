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

  /// Nakshatra prevailing at sunrise (canonical name, e.g. 'Mula'), when
  /// computed. Null on the web fallback (no ephemeris) and in unit tests
  /// that build days without it — nakshatra festivals then don't match.
  final String? nakshatra;

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
    this.nakshatra,
    this.tithiTransitionTime,
    this.transitionTithiIndex,
  });

  /// Check if this is Shukla Paksha (waxing moon)
  bool get isShukla => paksha == 'Shukla';

  /// Check if this is Krishna Paksha (waning moon)
  bool get isKrishna => paksha == 'Krishna';

  /// Full tithi index in the 1-30 cycle, derived from the DISPLAYED label
  /// ([paksha]/[tithiNumber]).
  /// Unlike [tithiNumber] (1-15 within a paksha), this uniquely identifies
  /// the tithi: 1-15 = Shukla, 16-30 = Krishna.
  /// Use this when querying exact tithi start/end times.
  /// Derived from the label (not [rawTithi]) so a live-flipped record stays
  /// self-consistent: after the flip to Ashtami, timings queries keyed by
  /// this resolve Ashtami's span. Identical to `rawTithi.floor()` whenever
  /// the label is the sunrise tithi (all non-live records).
  int get tithiIndex =>
      (paksha == 'Shukla' ? tithiNumber : tithiNumber + 15).clamp(1, 30);

  /// Check if there are any festivals on this day
  bool get hasFestivals => festivals.isNotEmpty;

  /// Whether a tithi transition occurs between this sunrise and the next,
  /// i.e. the day should show two tithis ("Ashtami → Navami").
  /// Compared against the SUNRISE tithi ([rawTithi]), not the displayed
  /// label: once a live hero flips to the incoming tithi, the boundary
  /// that got it there must stay visible as the day's history.
  bool get hasTithiTransition =>
      tithiTransitionTime != null &&
      transitionTithiIndex != null &&
      transitionTithiIndex! >= 1 &&
      transitionTithiIndex! <= 30 &&
      transitionTithiIndex != rawTithi.floor().clamp(1, 30);

  /// Whether the daytime transition EXITS the currently displayed label
  /// ([tithiIndex]) into a later tithi (e.g. label Saptami → Ashtami).
  /// False when the transition ENTERS the displayed label — i.e. after a
  /// live flip, or on squeeze days whose label already is the incoming
  /// tithi: the [tithiTransitionTime] is then the label's beginning, not
  /// its end, and "next tithi" wording must not name the current tithi.
  bool get transitionExitsLabel =>
      hasTithiTransition && transitionTithiIndex != tithiIndex;

  /// 1-30 index of the SUNRISE tithi. Unlike [tithiIndex] (the displayed
  /// label, which a live hero may advance intraday), this never moves: it
  /// names the tithi the day started with, for history lines ("Saptami
  /// till 1:02 PM") and sunrise-pinned festival context.
  int get sunriseTithiIndex => rawTithi.floor().clamp(1, 30);

  /// Paksha of the sunrise tithi.
  String get sunrisePaksha => sunriseTithiIndex <= 15 ? 'Shukla' : 'Krishna';

  /// Paksha-relative (1-15) number of the sunrise tithi.
  int get sunriseTithiNumber => sunriseTithiIndex <= 15
      ? sunriseTithiIndex
      : sunriseTithiIndex - 15;

  /// Name of the sunrise tithi.
  String get sunriseTithiName =>
      tithiNameFor(sunriseTithiNumber, sunrisePaksha);

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
    double? rawTithiPradosha,
    double? rawTithiNextSunrise,
    String masaNextSunrise = '',
    String? nakshatraAtSunrise,
    double? rawTithiDominant,
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

      // Nakshatra override (e.g. Saraswati Avahan on Mula): masa + paksha +
      // prevailing nakshatra at sunrise; the stored tithi is ignored and
      // there is no Kshaya fallback (a nakshatra always owns a sunrise).
      if (f.nakshatraCondition != null) {
        return matchesFestivalOnDay(
          festival: f,
          paksha: paksha,
          tithiNumber: tithiNumber,
          masa: masa,
          nakshatra: nakshatraAtSunrise,
          date: date,
        );
      }

      // SMELL-05: Select the appropriate timing checkpoint generically via
      // timingOverride instead of hard-coding festival IDs.
      // BUG-04: pass `date` so weekday constraints are evaluated.
      double targetRawTithi = switch (f.panchangRules.timingOverride) {
        'madhyahna' => rawTithiMadhyahna ?? rawTithi,
        'aparahna' => rawTithiAparahna ?? rawTithi,
        'nishita' => rawTithiNishita ?? rawTithi,
        'pradosha' => rawTithiPradosha ?? rawTithi,
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

      // Dominant-tithi grace (Drik convention): a festival with no
      // timingOverride additionally matches when its tithi begins within
      // ~60 min after sunrise (sampled as `rawTithiDominant` by callers).
      // Additive only — sunrise matches above are never removed, so the
      // Bisuddha two-day Shashthi (Oct 16+17 2026) survives while Saptami
      // extends onto the 17th. Override festivals keep their own
      // checkpoint; nakshatra/Solar festivals returned earlier.
      if (!isMatch && rawTithiDominant != null) {
        if (f.panchangRules.timingOverride == null ||
            !timingOverrideCheckpoints.contains(
              f.panchangRules.timingOverride,
            )) {
          final domIndex = rawTithiDominant.floor().clamp(1, 30);
          if (domIndex != targetIndex) {
            final domPaksha = domIndex <= 15 ? 'Shukla' : 'Krishna';
            final domNum = domIndex <= 15 ? domIndex : domIndex - 15;
            // New-moon wrap inside the grace window starts a new lunation.
            var domMasa = masa;
            if (tithiIndex == 30 &&
                domIndex == 1 &&
                masaNextSunrise.isNotEmpty) {
              domMasa = masaNextSunrise;
            }
            isMatch = f.matchesTithi(
              domPaksha,
              domNum,
              domMasa,
              HinduMonthSystem.amanta,
              date,
            );
          }
        }
      }

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

    // Optional same-day ordering: stable sort by displayPriority. No-op
    // unless 2+ matches carry a rank, so missing == current behaviour.
    sortFestivalsByDisplayPriority(matchingFestivals);

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
      nakshatra: nakshatraAtSunrise,
      tithiTransitionTime: tithiTransitionTime,
      transitionTithiIndex: transitionTithiIndex,
    );
  }

  /// Copy with replaced festival list and/or transition fields.
  ///
  /// Used by the shared festival-matching pipeline (vriddhi filtering) and
  /// by the single-day provider when reusing the month-map entry: the month
  /// batch skips the daytime transition search, so the single-day path
  /// resolves it separately and attaches it here without re-matching.
  /// The [tithiNumber]/[tithiName]/[paksha] overrides serve the live hero:
  /// intraday the displayed label advances while festivals, masa and the
  /// sunrise record stay pinned.
  PanchangData copyWith({
    List<Festival>? festivals,
    String? nakshatra,
    DateTime? tithiTransitionTime,
    int? transitionTithiIndex,
    bool clearTransition = false,
    int? tithiNumber,
    String? tithiName,
    String? paksha,
  }) {
    return PanchangData(
      date: date,
      rawTithi: rawTithi,
      tithiNumber: tithiNumber ?? this.tithiNumber,
      tithiName: tithiName ?? this.tithiName,
      paksha: paksha ?? this.paksha,
      masa: masa,
      festivals: festivals ?? this.festivals,
      sunrise: sunrise,
      sunset: sunset,
      nakshatra: nakshatra ?? this.nakshatra,
      tithiTransitionTime: clearTransition
          ? null
          : (tithiTransitionTime ?? this.tithiTransitionTime),
      transitionTithiIndex: clearTransition
          ? null
          : (transitionTithiIndex ?? this.transitionTithiIndex),
    );
  }

  /// Displayed label (paksha-relative number, paksha, name, 1-30 index) in
  /// effect at [now].
  ///
  /// Before [tithiTransitionTime] (or when there is none) this is the day's
  /// sunrise label. From the transition instant on, it is the incoming
  /// tithi; on rare kshaya days a located second boundary ([followOnTime] /
  /// [followOnIndex], resolved by the live-tick provider via the tithi
  /// timings search) advances it once more. Pure — the hero's liveness is a
  /// view over this, and unit tests pin the sequencing without timers.
  ({int number, String paksha, String name, int index}) liveLabelAt(
    DateTime now, {
    DateTime? followOnTime,
    int? followOnIndex,
  }) {
    int index = tithiIndex;
    if (hasTithiTransition &&
        !now.isBefore(tithiTransitionTime!) &&
        transitionTithiIndex != null) {
      index = transitionTithiIndex!.clamp(1, 30);
    }
    if (followOnTime != null &&
        followOnIndex != null &&
        followOnIndex >= 1 &&
        followOnIndex <= 30 &&
        !now.isBefore(followOnTime)) {
      index = followOnIndex;
    }
    final labelPaksha = index <= 15 ? 'Shukla' : 'Krishna';
    final labelNumber = index <= 15 ? index : index - 15;
    return (
      number: labelNumber,
      paksha: labelPaksha,
      name: tithiNameFor(labelNumber, labelPaksha),
      index: index,
    );
  }

  /// Copy with the displayed label advanced to the tithi prevailing at
  /// [now] (see [liveLabelAt]). Everything else — festivals, masa,
  /// sunrise record, transition history — is preserved, so a flipped hero
  /// still opens a sheet that knows the day started as the sunrise tithi.
  /// Returns `this` when the label is unchanged (identity preserves the
  /// hero's content-fade key and avoids pointless rebuilds).
  PanchangData withLiveLabel(
    DateTime now, {
    DateTime? followOnTime,
    int? followOnIndex,
  }) {
    final live = liveLabelAt(
      now,
      followOnTime: followOnTime,
      followOnIndex: followOnIndex,
    );
    if (live.number == tithiNumber && live.paksha == paksha) return this;
    return copyWith(
      tithiNumber: live.number,
      tithiName: live.name,
      paksha: live.paksha,
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
