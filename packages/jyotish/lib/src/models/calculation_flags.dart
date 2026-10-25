import '../constants/planet_constants.dart';

/// Calculation flags for Swiss Ephemeris.
///
/// This library is designed for Vedic astrology and uses sidereal zodiac
/// with Lahiri ayanamsa by default.
class CalculationFlags {
  /// Creates calculation flags for Vedic astrology (sidereal calculations).
  ///
  /// [useSwissEphemeris] - Use Swiss Ephemeris (default: true)
  /// [calculateSpeed] - Calculate planetary speed/velocity (default: true)
  /// [siderealMode] - Ayanamsa for sidereal calculations (default: Lahiri)
  /// [useTopocentric] - Use topocentric positions (default: false)
  /// [useEquatorial] - Use equatorial coordinates (default: false)
  /// [useHeliocentric] - Use heliocentric (Sun-centered) positions (default: false)
  /// [useTropical] - Use tropical zodiac, skip sidereal conversion (default: false)
  /// [useNativeSidereal] - Ask Swiss Ephemeris for sidereal positions with
  /// `SEFLG_SIDEREAL` instead of subtracting ayanamsa from the tropical
  /// longitude in Dart (default: false, preserving historical output)
  /// [requireSwissEphemeris] - Reject a Moshier fallback instead of returning
  /// its position as if it were Swiss Ephemeris output (default: false)
  const CalculationFlags({
    this.useSwissEphemeris = true,
    this.calculateSpeed = true,
    this.siderealMode = SiderealMode.lahiri,
    this.useTopocentric = false,
    this.useEquatorial = false,
    this.useHeliocentric = false,
    this.useTropical = false,
    this.useNativeSidereal = false,
    this.requireSwissEphemeris = false,
  });

  /// Creates default calculation flags (Lahiri sidereal, geocentric, with speed).
  factory CalculationFlags.defaultFlags() => const CalculationFlags();

  /// Creates flags for sidereal calculations with custom ayanamsa.
  ///
  /// Ayanamsa is subtracted from the tropical longitude in Dart, the
  /// package's historical behaviour. Use [CalculationFlags.nativeSidereal] to
  /// let Swiss Ephemeris apply it instead.
  factory CalculationFlags.sidereal(SiderealMode mode) => CalculationFlags(
        siderealMode: mode,
      );

  /// Creates flags that request sidereal positions from Swiss Ephemeris.
  ///
  /// The result comes from `swe_calc_ut(SEFLG_SIDEREAL)` after setting
  /// [siderealMode]; no ayanamsa is subtracted in Dart. This is opt-in while
  /// the two paths are compared, because it can differ from the historical
  /// output by a small amount.
  factory CalculationFlags.nativeSidereal(SiderealMode mode) =>
      CalculationFlags(
        siderealMode: mode,
        useNativeSidereal: true,
      );

  /// Creates flags for sidereal calculations with Lahiri ayanamsa.
  factory CalculationFlags.siderealLahiri() => const CalculationFlags(
        siderealMode: SiderealMode.lahiri,
      );

  /// Creates flags for topocentric calculations.
  factory CalculationFlags.topocentric() => const CalculationFlags(
        useTopocentric: true,
      );

  /// Creates flags for astronomical (tropical, heliocentric) calculations.
  /// This is used for accurate solar system visualization matching NASA.
  factory CalculationFlags.astronomical({bool heliocentric = true}) =>
      CalculationFlags(
        useTropical: true,
        useHeliocentric: heliocentric,
      );

  /// Use Swiss Ephemeris (high precision)
  final bool useSwissEphemeris;

  /// Calculate speed (velocity)
  final bool calculateSpeed;

  /// Sidereal ayanamsa mode (Lahiri by default for Vedic astrology)
  final SiderealMode siderealMode;

  /// Use topocentric positions (observed from surface of Earth)
  /// instead of geocentric (from Earth's center)
  final bool useTopocentric;

  /// Use equatorial coordinates instead of ecliptic
  final bool useEquatorial;

  /// Use heliocentric (Sun-centered) positions
  /// instead of geocentric (Earth-centered)
  final bool useHeliocentric;

  /// Use tropical zodiac (skip sidereal/ayanamsa conversion)
  /// For astronomical display rather than Vedic astrology
  final bool useTropical;

  /// Let Swiss Ephemeris apply the ayanamsa via `SEFLG_SIDEREAL`.
  ///
  /// When false (default), the package keeps its historical behaviour:
  /// calculate tropically, then subtract
  /// `swe_get_ayanamsa_ut()` from the ecliptic longitude in Dart. The manual
  /// path is only valid for ecliptic coordinates; native sidereal is the
  /// authoritative frame.
  final bool useNativeSidereal;

  /// Reject a result produced by the Moshier analytical fallback.
  ///
  /// Swiss Ephemeris succeeds with Moshier when a requested `.se1` file is
  /// missing; that is useful for a cache warm-up but must not be presented as
  /// Swiss Ephemeris data. When true, [EphemerisService] throws
  /// `EphemerisBackendException` instead of returning the fallback position.
  final bool requireSwissEphemeris;

  /// Converts flags to Swiss Ephemeris integer flag value.
  ///
  /// By default ecliptic planet positions are calculated tropically and
  /// converted by subtracting ayanamsa in Dart, which preserves the package's
  /// historical output. With [useNativeSidereal], `SEFLG_SIDEREAL` is set and
  /// the engine applies the ayanamsa. Houses always use the native sidereal
  /// flag through `swe_houses_ex`. Equatorial sidereal requests are rejected
  /// rather than subtracted, because ayanamsa is an ecliptic offset, not an RA
  /// offset.
  int toSwissEphFlag() {
    int flag = 0;

    if (useSwissEphemeris) {
      flag |= SwissEphConstants.swissEph;
    }

    if (calculateSpeed) {
      flag |= SwissEphConstants.speed;
    }

    if (useTopocentric) {
      flag |= SwissEphConstants.topocentricFlag;
    }

    if (useEquatorial) {
      flag |= SwissEphConstants.equatorial;
    }

    if (useHeliocentric) {
      flag |= SwissEphConstants.heliocentric;
    }

    if (useNativeSidereal) {
      flag |= SwissEphConstants.sidereal;
    }

    return flag;
  }

  /// Gets the sidereal mode constant.
  int get siderealModeConstant => siderealMode.constant;

  @override
  String toString() {
    return 'CalculationFlags('
        'swissEph: $useSwissEphemeris, '
        'speed: $calculateSpeed, '
        'ayanamsa: ${siderealMode.label}, '
        'topocentric: $useTopocentric, '
        'equatorial: $useEquatorial, '
        'heliocentric: $useHeliocentric, '
        'tropical: $useTropical, '
        'nativeSidereal: $useNativeSidereal, '
        'requireSwiss: $requireSwissEphemeris)';
  }

  @override
  bool operator ==(Object other) {
    return other is CalculationFlags &&
        other.useSwissEphemeris == useSwissEphemeris &&
        other.calculateSpeed == calculateSpeed &&
        other.siderealMode == siderealMode &&
        other.useTopocentric == useTopocentric &&
        other.useEquatorial == useEquatorial &&
        other.useHeliocentric == useHeliocentric &&
        other.useTropical == useTropical &&
        other.useNativeSidereal == useNativeSidereal &&
        other.requireSwissEphemeris == requireSwissEphemeris;
  }

  @override
  int get hashCode => Object.hash(
        useSwissEphemeris,
        calculateSpeed,
        siderealMode,
        useTopocentric,
        useEquatorial,
        useHeliocentric,
        useTropical,
        useNativeSidereal,
        requireSwissEphemeris,
      );

  /// Creates a copy with optional parameter overrides.
  CalculationFlags copyWith({
    bool? useSwissEphemeris,
    bool? calculateSpeed,
    SiderealMode? siderealMode,
    bool? useTopocentric,
    bool? useEquatorial,
    bool? useHeliocentric,
    bool? useTropical,
    bool? useNativeSidereal,
    bool? requireSwissEphemeris,
  }) {
    return CalculationFlags(
      useSwissEphemeris: useSwissEphemeris ?? this.useSwissEphemeris,
      calculateSpeed: calculateSpeed ?? this.calculateSpeed,
      siderealMode: siderealMode ?? this.siderealMode,
      useTopocentric: useTopocentric ?? this.useTopocentric,
      useEquatorial: useEquatorial ?? this.useEquatorial,
      useHeliocentric: useHeliocentric ?? this.useHeliocentric,
      useTropical: useTropical ?? this.useTropical,
      useNativeSidereal: useNativeSidereal ?? this.useNativeSidereal,
      requireSwissEphemeris:
          requireSwissEphemeris ?? this.requireSwissEphemeris,
    );
  }
}

/// Sidereal ayanamsa modes supported by Swiss Ephemeris.
enum SiderealMode {
  faganBradley(SwissEphConstants.sidmFaganBradley, 'Fagan/Bradley'),
  lahiri(SwissEphConstants.sidmLahiri, 'Lahiri'),
  deluce(SwissEphConstants.sidmDeluce, 'De Luce'),
  raman(SwissEphConstants.sidmRaman, 'Raman'),
  ushashashi(SwissEphConstants.sidmUshashashi, 'Ushashashi'),
  krishnamurti(SwissEphConstants.sidmKrishnamurti, 'Krishnamurti'),
  djwhalKhul(SwissEphConstants.sidmDjwhalKhul, 'Djwhal Khul'),
  yukteshwar(SwissEphConstants.sidmYukteshwar, 'Yukteshwar'),
  jnBhasin(SwissEphConstants.sidmJnBhasin, 'JN Bhasin'),
  babylonianKugler1(
      SwissEphConstants.sidmBabylonianKugler1, 'Babylonian/Kugler 1'),
  babylonianKugler2(
      SwissEphConstants.sidmBabylonianKugler2, 'Babylonian/Kugler 2'),
  babylonianKugler3(
      SwissEphConstants.sidmBabylonianKugler3, 'Babylonian/Kugler 3'),
  babylonianHuber(SwissEphConstants.sidmBabylonianHuber, 'Babylonian/Huber'),
  babylonianEtpsc(SwissEphConstants.sidmBabylonianEtpsc, 'Babylonian/ETPSC'),
  aldebaran15Tau(SwissEphConstants.sidmAldebaran15Tau, 'Aldebaran at 15 Tau'),
  hipparchos(SwissEphConstants.sidmHipparchos, 'Hipparchos'),
  sassanian(SwissEphConstants.sidmSassanian, 'Sassanian'),
  galcentMulaWilhelm(
      SwissEphConstants.sidmGalcentMulaWilhelm, 'Galactic Center Mula Wilhelm'),
  ayanamsa(SwissEphConstants.sidmAyanamsa, 'Ayanamsa'),
  galcentCochrane(
      SwissEphConstants.sidmGalcentCochrane, 'Galactic Center Cochrane'),
  galequIau1958(SwissEphConstants.sidmGalequIau1958, 'Gal Eq IAU 1958'),
  galequTrue(SwissEphConstants.sidmGalequTrue, 'Gal Eq True'),
  galequMula(SwissEphConstants.sidmGalequMula, 'Gal Eq Mula'),
  galalignMardyks(SwissEphConstants.sidmGalalignMardyks, 'Gal Align Mardyks'),
  trueCitra(SwissEphConstants.sidmTrueCitra, 'True Citra'),
  trueRevati(SwissEphConstants.sidmTrueRevati, 'True Revati'),
  truePushya(SwissEphConstants.sidmTruePushya, 'True Pushya'),
  galcentRothers(
      SwissEphConstants.sidmGalcentRothers, 'Galactic Center Others'),
  galcent0Sag(SwissEphConstants.sidmGalcent0Sag, 'Galactic Center 0 Sag'),
  j2000(SwissEphConstants.sidmJ2000, 'J2000'),
  j1900(SwissEphConstants.sidmJ1900, 'J1900'),
  b1950(SwissEphConstants.sidmB1950, 'B1950'),
  suryasiddhanta(SwissEphConstants.sidmSuryasiddhanta, 'Surya Siddhanta'),
  suryasiddhantaMsun(
      SwissEphConstants.sidmSuryasiddhantaMsun, 'Surya Siddhanta MSun'),
  aryabhata(SwissEphConstants.sidmAryabhata, 'Aryabhata'),
  aryabhataMsun(SwissEphConstants.sidmAryabhataMsun, 'Aryabhata MSun'),
  ssRevati(SwissEphConstants.sidmSsRevati, 'SS Revati'),
  ssCitra(SwissEphConstants.sidmSsCitra, 'SS Citra'),
  trueSherpas(SwissEphConstants.sidmTrueSherpas, 'True Sherpas'),
  trueMula(SwissEphConstants.sidmTrueMula, 'True Mula'),
  galcentMula0(SwissEphConstants.sidmGalcentMula0, 'Galactic Center Mula 0'),
  galcentMulaVerneau(
      SwissEphConstants.sidmGalcentMulaVerneau, 'Galactic Center Mula Verneau'),
  valensBow(SwissEphConstants.sidmValensBow, 'Valens Bow');

  const SiderealMode(this.constant, this.label);

  /// Swiss Ephemeris `SE_SIDM_*` integer.
  final int constant;

  /// Human-readable ayanamsa name for display only.
  ///
  /// This is deliberately not called `name`: the enum's built-in [Enum.name]
  /// is the stable identifier that can be persisted. Cache and storage keys
  /// should use [persistenceKey] (the integer constant) or `name`, never
  /// [label], because labels may be reworded.
  final String label;

  /// Stable value for persistence and cache keys.
  ///
  /// The integer is assigned by Swiss Ephemeris and does not change when a
  /// display label is edited or the enum is reordered.
  int get persistenceKey => constant;

  @override
  String toString() => label;
}
