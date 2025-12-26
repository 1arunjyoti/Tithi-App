import '../constants/planet_constants.dart';

/// Calculation flags for Swiss Ephemeris.
///
/// This library is designed for Vedic astrology and uses sidereal zodiac
/// with Lahiri ayanamsa by default.
class CalculationFlags {
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

  /// Creates calculation flags for Vedic astrology (sidereal calculations).
  ///
  /// [useSwissEphemeris] - Use Swiss Ephemeris (default: true)
  /// [calculateSpeed] - Calculate planetary speed/velocity (default: true)
  /// [siderealMode] - Ayanamsa for sidereal calculations (default: Lahiri)
  /// [useTopocentric] - Use topocentric positions (default: false)
  /// [useEquatorial] - Use equatorial coordinates (default: false)
  const CalculationFlags({
    this.useSwissEphemeris = true,
    this.calculateSpeed = true,
    this.siderealMode = SiderealMode.lahiri,
    this.useTopocentric = false,
    this.useEquatorial = false,
  });

  /// Creates default calculation flags (Lahiri sidereal, geocentric, with speed).
  factory CalculationFlags.defaultFlags() => const CalculationFlags();

  /// Creates flags for sidereal calculations with custom ayanamsa.
  factory CalculationFlags.sidereal(SiderealMode mode) => CalculationFlags(
        siderealMode: mode,
      );

  /// Creates flags for sidereal calculations with Lahiri ayanamsa.
  factory CalculationFlags.siderealLahiri() => const CalculationFlags(
        siderealMode: SiderealMode.lahiri,
      );

  /// Creates flags for topocentric calculations.
  factory CalculationFlags.topocentric() => const CalculationFlags(
        useTopocentric: true,
      );

  /// Converts flags to Swiss Ephemeris integer flag value.
  /// Note: We always calculate tropical and subtract ayanamsa manually
  /// because SEFLG_SIDEREAL doesn't work properly in the compiled library.
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

    return flag;
  }

  /// Gets the sidereal mode constant.
  int get siderealModeConstant => siderealMode.constant;

  @override
  String toString() {
    return 'CalculationFlags('
        'swissEph: $useSwissEphemeris, '
        'speed: $calculateSpeed, '
        'ayanamsa: ${siderealMode.name}, '
        'topocentric: $useTopocentric, '
        'equatorial: $useEquatorial)';
  }

  /// Creates a copy with optional parameter overrides.
  CalculationFlags copyWith({
    bool? useSwissEphemeris,
    bool? calculateSpeed,
    SiderealMode? siderealMode,
    bool? useTopocentric,
    bool? useEquatorial,
  }) {
    return CalculationFlags(
      useSwissEphemeris: useSwissEphemeris ?? this.useSwissEphemeris,
      calculateSpeed: calculateSpeed ?? this.calculateSpeed,
      siderealMode: siderealMode ?? this.siderealMode,
      useTopocentric: useTopocentric ?? this.useTopocentric,
      useEquatorial: useEquatorial ?? this.useEquatorial,
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

  final int constant;
  final String name;

  const SiderealMode(this.constant, this.name);

  @override
  String toString() => name;
}
