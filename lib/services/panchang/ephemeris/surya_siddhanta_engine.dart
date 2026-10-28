/// Pure-Dart implementation of the Surya Siddhanta Sun and Moon theory.
///
/// Only the two bodies a Panchang needs are implemented. For the Sun and the
/// Moon the Surya Siddhanta prescribes a single correction - the *manda*
/// (equation of centre) - with no sighra (conjunction) iteration. That is what
/// makes a faithful engine tractable here.
///
/// ## What is implemented
///
/// 1. **Ahargana** - civil days elapsed since the Kali Yuga epoch
///    (midnight at Ujjain, Friday 18 Feb 3102 BCE, JD 588465.5).
/// 2. **Mean longitudes** - revolutions per Mahayuga converted to degrees per
///    day and multiplied by the ahargana.
/// 3. **Manda correction** - `asin(C/360 * sin(kendra))` taken as a magnitude,
///    subtracted from apogee to perigee (kendra 0..180) and added on the
///    return half. The circumference is blended between the text's even and
///    odd values by `|jya(kendra)| / R`.
/// 4. **Jya** - the traditional 24-entry sine table (R = 3438) with linear
///    interpolation, so the result is Siddhantic rather than modern
///    trigonometry.
///
/// ## What is deliberately *not* implemented
///
/// The text anchors every mean longitude at 0 for the Kali epoch and gives no
/// bija (seed) correction. Two consequences, both measured against the modern
/// sidereal ephemeris:
///
/// - The epoch frame is not the modern one. Aligning the classical Sun to
///   Lahiri needs an epoch offset near -11.6 degrees, and the Moon a similar
///   one; this is a constant, not a drift.
/// - The Moon carries only the manda term. Evection, variation, and the
///   amplitude gap (the text's 32 gives 5.10 degrees against the modern 6.29)
///   leave several degrees of variation that no epoch offset can remove.
///
/// Real Surya Siddhanta panjikas therefore carry a bija. Rather than hard-code
/// a guess, both are expressed by [SuryaSiddhantaTuning], whose default is the
/// literal classical text. Supply a calibrated tuning to match a specific
/// printed panjika; `tool/surya_siddhanta_probe.dart fit` solves all six
/// parameters and reaches roughly 1.4 degrees RMS against the modern
/// ephemeris over 1900-2100.
library;

import 'dart:math' as math;

/// Days in a Mahayuga (4,320,000 solar years).
const int kSuryaSiddhantaDaysPerMahayuga = 1577917828;

/// Solar years in a Mahayuga.
const int kSuryaSiddhantaYearsPerMahayuga = 4320000;

/// Sun revolutions per Mahayuga.
const int kSuryaSiddhantaSunRevolutions = 4320000;

/// Moon revolutions per Mahayuga.
const int kSuryaSiddhantaMoonRevolutions = 57753336;

/// Moon's apogee (mandocca) revolutions per Mahayuga, prograde.
const int kSuryaSiddhantaMoonApsisRevolutions = 488203;

/// Moon's ascending node revolutions per Mahayuga (retrograde; not used by the
/// Panchang limbs this engine serves, kept for provenance).
const int kSuryaSiddhantaMoonNodeRevolutions = 232238;

/// Julian Day of the Kali Yuga epoch.
///
/// This is the conventional value for 18 Feb 3102 BCE, read as a UT-based
/// Julian Day. The text places the epoch at *midnight at Ujjain*
/// (75.768 E), which is 5.051 h ahead of UT, so the literal epoch is
/// JD 588465.29. That 0.21 d difference moves the Moon about 2.8 degrees and
/// the Sun about 0.2 - a constant offset of the same kind as an epoch
/// longitude. It is left in the published convention and absorbed by
/// [SuryaSiddhantaTuning] rather than silently corrected here, so the
/// "classical" tuning keeps meaning "the published epoch constant".
const double kSuryaSiddhantaKaliEpochJd = 588465.5;

/// Radius of the great circle used by the Siddhantic sine table.
const double kSuryaSiddhantaRadius = 3438.0;

/// Sun's apogee longitude at the epoch, `77 deg 17 min`.
const double kSuryaSiddhantaSunApogee = 77.0 + 17.0 / 60.0;

/// Mean solar year implied by the Mahayuga constants, in days.
const double kSuryaSiddhantaSolarYear =
    kSuryaSiddhantaDaysPerMahayuga / kSuryaSiddhantaYearsPerMahayuga;

/// The 24 jya-pindas of the Surya Siddhanta: `R * sin(3.75 * (i + 1))`.
///
/// Entry 0 is sin(3 deg 45 min), entry 23 is sin(90 deg) = R.
const List<double> kSuryaSiddhantaSineTable = [
  225, 449, 671, 890, 1105, 1315, 1520, 1719, 1910, 2093, 2267, 2431, //
  2585, 2728, 2859, 2978, 3084, 3177, 3256, 3321, 3372, 3409, 3431, 3438,
];

/// Arc covered by one sine-table entry, in arc minutes (`3 deg 45 min`).
const double kSuryaSiddhantaSineStepArcMinutes = 225.0;

/// Calibration parameters that reconcile the literal text with a printed
/// panjika.
///
/// Every field defaults to the uncalibrated classical text, so
/// [SuryaSiddhantaTuning.classical] reproduces a textbook computation and
/// nothing silently assumes a publisher's correction.
///
/// The model is deliberately small and physical:
///
/// ```
/// meanLongitude = epochLongitude
///               + dailyMotion * ahargana
///               + bijaArcSecondsPerYear * yearsSinceEpoch / 3600
/// ```
///
/// A printed panjika's bija is normally expressed as an annual rate in arc
/// seconds applied to the mean longitude, which is exactly
/// [bijaArcSecondsPerYear]. [epochLongitude] absorbs a constant offset (an
/// epoch that differs from the text's 0-at-Kali assumption).
class SuryaSiddhantaTuning {
  const SuryaSiddhantaTuning({
    this.sunEpochLongitude = 0.0,
    this.moonEpochLongitude = 0.0,
    this.moonApsisEpochLongitude = 0.0,
    this.sunBijaArcSecondsPerYear = 0.0,
    this.moonBijaArcSecondsPerYear = 0.0,
    this.moonApsisBijaArcSecondsPerYear = 0.0,
  });

  /// Literal Surya Siddhanta: no epoch offset, no bija.
  static const SuryaSiddhantaTuning classical = SuryaSiddhantaTuning();

  /// Degrees added to the Sun's mean longitude at the epoch.
  final double sunEpochLongitude;

  /// Degrees added to the Moon's mean longitude at the epoch.
  final double moonEpochLongitude;

  /// Degrees added to the Moon's apogee longitude at the epoch.
  final double moonApsisEpochLongitude;

  /// Annual bija applied to the Sun's mean longitude, in arc seconds.
  final double sunBijaArcSecondsPerYear;

  /// Annual bija applied to the Moon's mean longitude, in arc seconds.
  final double moonBijaArcSecondsPerYear;

  /// Annual bija applied to the Moon's apogee, in arc seconds.
  final double moonApsisBijaArcSecondsPerYear;

  /// True when every parameter is zero, i.e. the literal text.
  bool get isClassical =>
      sunEpochLongitude == 0 &&
      moonEpochLongitude == 0 &&
      moonApsisEpochLongitude == 0 &&
      sunBijaArcSecondsPerYear == 0 &&
      moonBijaArcSecondsPerYear == 0 &&
      moonApsisBijaArcSecondsPerYear == 0;

  /// Stable tag for cache keys and provenance records.
  ///
  /// Two tunings that produce different positions must produce different tags,
  /// so the values go in at full `double` precision: `toString` round-trips,
  /// whereas a fixed number of decimals can collide for tunings that differ
  /// below the last printed digit.
  String get tag => isClassical
      ? 'ss-classical'
      : 'ss-'
            '${sunEpochLongitude}_'
            '${moonEpochLongitude}_'
            '${moonApsisEpochLongitude}_'
            '${sunBijaArcSecondsPerYear}_'
            '${moonBijaArcSecondsPerYear}_'
            '$moonApsisBijaArcSecondsPerYear';

  SuryaSiddhantaTuning copyWith({
    double? sunEpochLongitude,
    double? moonEpochLongitude,
    double? moonApsisEpochLongitude,
    double? sunBijaArcSecondsPerYear,
    double? moonBijaArcSecondsPerYear,
    double? moonApsisBijaArcSecondsPerYear,
  }) {
    return SuryaSiddhantaTuning(
      sunEpochLongitude: sunEpochLongitude ?? this.sunEpochLongitude,
      moonEpochLongitude: moonEpochLongitude ?? this.moonEpochLongitude,
      moonApsisEpochLongitude:
          moonApsisEpochLongitude ?? this.moonApsisEpochLongitude,
      sunBijaArcSecondsPerYear:
          sunBijaArcSecondsPerYear ?? this.sunBijaArcSecondsPerYear,
      moonBijaArcSecondsPerYear:
          moonBijaArcSecondsPerYear ?? this.moonBijaArcSecondsPerYear,
      moonApsisBijaArcSecondsPerYear:
          moonApsisBijaArcSecondsPerYear ??
          this.moonApsisBijaArcSecondsPerYear,
    );
  }

  @override
  String toString() => 'SuryaSiddhantaTuning($tag)';
}

/// Surya Siddhanta Sun and Moon positions, in sidereal degrees.
///
/// The longitudes are already sidereal: the Sun's revolution count equals the
/// number of sidereal years in a Mahayuga, so no ayanamsa is applied.
class SuryaSiddhantaEngine {
  const SuryaSiddhantaEngine({
    this.tuning = SuryaSiddhantaTuning.classical,
  });

  final SuryaSiddhantaTuning tuning;

  /// Ahargana for [instant]: civil days since the Kali Yuga epoch.
  ///
  /// [instant] is converted to UTC first, so a local `DateTime` is interpreted
  /// as the absolute instant it represents.
  static double aharganaAt(DateTime instant) =>
      julianDayAt(instant) - kSuryaSiddhantaKaliEpochJd;

  /// Julian Day (UT) for [instant].
  ///
  /// Uses the Unix epoch anchor (JD 2440587.5) rather than a calendar
  /// algorithm, so the result is exact for every `DateTime` Dart can build.
  static double julianDayAt(DateTime instant) {
    final utc = instant.toUtc();
    return utc.microsecondsSinceEpoch / Duration.microsecondsPerDay +
        2440587.5;
  }

  /// Mean longitude of the Sun, in degrees `[0, 360)`.
  double meanSunLongitude(double ahargana) =>
      _meanLongitude(kSuryaSiddhantaSunRevolutions, ahargana) +
      tuning.sunEpochLongitude +
      _bija(tuning.sunBijaArcSecondsPerYear, ahargana);

  /// Mean longitude of the Moon, in degrees `[0, 360)`.
  double meanMoonLongitude(double ahargana) =>
      _meanLongitude(kSuryaSiddhantaMoonRevolutions, ahargana) +
      tuning.moonEpochLongitude +
      _bija(tuning.moonBijaArcSecondsPerYear, ahargana);

  /// Mean longitude of the Moon's apogee, in degrees `[0, 360)`.
  double meanMoonApsisLongitude(double ahargana) =>
      _meanLongitude(kSuryaSiddhantaMoonApsisRevolutions, ahargana) +
      tuning.moonApsisEpochLongitude +
      _bija(tuning.moonApsisBijaArcSecondsPerYear, ahargana);

  /// True longitude of the Sun (Ravisphuta), in degrees `[0, 360)`.
  double trueSunLongitude(double ahargana) {
    final mean = meanSunLongitude(ahargana);
    final kendra = _norm(mean - kSuryaSiddhantaSunApogee);
    return _norm(
      mean +
          _mandaCorrection(
            kendra: kendra,
            evenCircumference: 14.0,
            oddCircumference: 13.0 + 40.0 / 60.0,
          ),
    );
  }

  /// True longitude of the Moon (Candrasphuta), in degrees `[0, 360)`.
  double trueMoonLongitude(double ahargana) {
    final mean = meanMoonLongitude(ahargana);
    final apsis = meanMoonApsisLongitude(ahargana);
    final kendra = _norm(mean - apsis);
    return _norm(
      mean +
          _mandaCorrection(
            kendra: kendra,
            evenCircumference: 32.0,
            oddCircumference: 31.0 + 40.0 / 60.0,
          ),
    );
  }

  /// True sidereal longitudes of both bodies at [instant].
  ({double sun, double moon}) longitudesAt(DateTime instant) {
    final ahargana = aharganaAt(instant);
    return (
      sun: trueSunLongitude(ahargana),
      moon: trueMoonLongitude(ahargana),
    );
  }

  // --- internals ---------------------------------------------------------

  /// `bija * yearsSinceEpoch`, converted from arc seconds to degrees.
  static double _bija(double arcSecondsPerYear, double ahargana) {
    if (arcSecondsPerYear == 0) return 0;
    return arcSecondsPerYear * (ahargana / kSuryaSiddhantaSolarYear) / 3600.0;
  }

  /// `revolutions * 360 * ahargana / daysPerMahayuga`, normalized.
  static double _meanLongitude(int revolutions, double ahargana) {
    final degrees =
        360.0 * revolutions * ahargana / kSuryaSiddhantaDaysPerMahayuga;
    return _norm(degrees);
  }

  /// Manda (equation of centre) in degrees, signed for [kendra].
  ///
  /// The equation is `asin(C / 360 * sin(kendra))` taken as a magnitude, then
  /// subtracted while the kendra runs from apogee to perigee (0..180) and
  /// added on the return half.
  ///
  /// `C` is blended between the text's even and odd circumferences by
  /// `|jya(kendra)| / R`: 14 (Sun) and 32 (Moon) at the cardinal points,
  /// 13 deg 40 min and 31 deg 40 min at 90 and 270. The text states two values
  /// per quadrant; the smooth blend is a deliberate simplification worth under
  /// 0.13 degrees of correction.
  static double _mandaCorrection({
    required double kendra,
    required double evenCircumference,
    required double oddCircumference,
  }) {
    final jya = jyaOf(kendra);
    final circumference =
        evenCircumference -
        (evenCircumference - oddCircumference) *
            jya.abs() /
            kSuryaSiddhantaRadius;
    // The equation of centre is a *magnitude*; only the quadrant decides the
    // sign. Feeding the signed jya in and then applying the quadrant rule
    // would double-count the sign and invert the correction over the half
    // orbit that runs from perigee back to apogee.
    final magnitude = _asinDegrees(
      circumference / 360.0 * jya.abs() / kSuryaSiddhantaRadius,
    );
    return kendra < 180.0 ? -magnitude : magnitude;
  }

  /// Siddhantic sine (jya): `R * sin(angle)`, signed across all quadrants.
  ///
  /// Linear interpolation over the 24-entry table, which is what the text
  /// prescribes. Interpolating a 24-point table introduces at most ~0.05% error
  /// against a modern sine - immaterial next to the model's own drift, and it
  /// keeps the engine faithful to the source.
  static double jyaOf(double angleDegrees) {
    final angle = _norm(angleDegrees);
    final quadrant = (angle / 90.0).floor();
    final remainder = angle - quadrant * 90.0;

    // Fold into the first quadrant, then restore the sign.
    final effective = quadrant.isOdd ? 90.0 - remainder : remainder;
    final sign = quadrant >= 2 ? -1.0 : 1.0;

    final indexFloat =
        effective * 60.0 / kSuryaSiddhantaSineStepArcMinutes;
    final index = indexFloat.floor();
    if (index >= kSuryaSiddhantaSineTable.length) {
      return sign * kSuryaSiddhantaSineTable.last;
    }

    final base = index == 0 ? 0.0 : kSuryaSiddhantaSineTable[index - 1];
    final next = kSuryaSiddhantaSineTable[index];
    final fraction = indexFloat - index;
    return sign * (base + fraction * (next - base));
  }

  static double _asinDegrees(double ratio) {
    final clamped = ratio.clamp(-1.0, 1.0);
    return _degrees(math.asin(clamped));
  }

  static double _degrees(double radians) => radians * 180.0 / math.pi;

  static double _norm(double degrees) {
    final value = degrees % 360.0;
    return value < 0 ? value + 360.0 : value;
  }
}
