import '../models/planet.dart';
import '../models/vedic_chart.dart';

/// Calculates planetary dignity from a sidereal longitude.
///
/// Dignity is evaluated in this order:
/// 1. exaltation sign,
/// 2. debilitation sign,
/// 3. moola-trikona degree range,
/// 4. own sign,
/// 5. neutral.
///
/// Moola-trikona must be checked before the generic own-sign rule: six of the
/// seven traditional planets have both a moola-trikona and an own sign, and
/// testing own sign first makes the moola-trikona result unreachable.
PlanetaryDignity dignityForLongitude(Planet planet, double longitude) {
  if (!longitude.isFinite) {
    throw ArgumentError.value(longitude, 'longitude', 'Must be finite');
  }

  final normalized = _normalize(longitude);
  final signIndex = (normalized / 30).floor() % 12;
  final degreeInSign = normalized - (signIndex * 30);

  if (_exaltationSigns[planet] == signIndex) {
    return PlanetaryDignity.exalted;
  }
  if (_debilitationSigns[planet] == signIndex) {
    return PlanetaryDignity.debilitated;
  }

  final moolaTrikona = _moolaTrikonaRanges[planet];
  if (moolaTrikona != null &&
      moolaTrikona.signIndex == signIndex &&
      degreeInSign >= moolaTrikona.startDegree &&
      degreeInSign <= moolaTrikona.endDegree) {
    return PlanetaryDignity.moolaTrikona;
  }

  if (_ownSigns[planet]?.contains(signIndex) ?? false) {
    return PlanetaryDignity.ownSign;
  }

  return PlanetaryDignity.neutralSign;
}

/// Exact exaltation degree for [planet], or null when the body has none.
double? exaltationDegreeFor(Planet planet) => _exaltationDegrees[planet];

/// Exact debilitation degree for [planet], or null when the body has none.
///
/// Debilitation is the point opposite exaltation. In particular Venus is
/// 27° Virgo (177° absolute), not 15° Virgo (165°), and Jupiter is 5°
/// Capricorn (275°), not 278°.
double? debilitationDegreeFor(Planet planet) => _debilitationDegrees[planet];

double _normalize(double longitude) {
  final normalized = longitude % 360;
  return normalized < 0 ? normalized + 360 : normalized;
}

class _MoolaTrikonaRange {
  const _MoolaTrikonaRange({
    required this.signIndex,
    required this.startDegree,
    required this.endDegree,
  });

  /// Sign index (0 = Aries).
  final int signIndex;

  /// First degree inside the sign, inclusive.
  final double startDegree;

  /// Last degree inside the sign, inclusive.
  final double endDegree;
}

const Map<Planet, int> _exaltationSigns = {
  Planet.sun: 0, // Aries
  Planet.moon: 1, // Taurus
  Planet.mercury: 5, // Virgo
  Planet.venus: 11, // Pisces
  Planet.mars: 9, // Capricorn
  Planet.jupiter: 3, // Cancer
  Planet.saturn: 6, // Libra
  Planet.meanNode: 2, // Gemini (Rahu)
};

const Map<Planet, int> _debilitationSigns = {
  Planet.sun: 6, // Libra
  Planet.moon: 7, // Scorpio
  Planet.mercury: 11, // Pisces
  Planet.venus: 5, // Virgo
  Planet.mars: 3, // Cancer
  Planet.jupiter: 9, // Capricorn
  Planet.saturn: 0, // Aries
  Planet.meanNode: 8, // Sagittarius (Rahu)
};

const Map<Planet, List<int>> _ownSigns = {
  Planet.sun: [4], // Leo
  Planet.moon: [3], // Cancer
  Planet.mercury: [2, 5], // Gemini, Virgo
  Planet.venus: [1, 6], // Taurus, Libra
  Planet.mars: [0, 7], // Aries, Scorpio
  Planet.jupiter: [8, 11], // Sagittarius, Pisces
  Planet.saturn: [9, 10], // Capricorn, Aquarius
};

const Map<Planet, double> _exaltationDegrees = {
  Planet.sun: 10.0, // 10° Aries
  Planet.moon: 33.0, // 3° Taurus
  Planet.mercury: 165.0, // 15° Virgo
  Planet.venus: 357.0, // 27° Pisces
  Planet.mars: 298.0, // 28° Capricorn
  Planet.jupiter: 95.0, // 5° Cancer
  Planet.saturn: 200.0, // 20° Libra
};

const Map<Planet, double> _debilitationDegrees = {
  Planet.sun: 190.0, // 10° Libra
  Planet.moon: 213.0, // 3° Scorpio
  Planet.mercury: 345.0, // 15° Pisces
  Planet.venus: 177.0, // 27° Virgo
  Planet.mars: 118.0, // 28° Cancer
  Planet.jupiter: 275.0, // 5° Capricorn
  Planet.saturn: 20.0, // 20° Aries
};

/// Traditional moola-trikona ranges, measured from the start of the sign.
const Map<Planet, _MoolaTrikonaRange> _moolaTrikonaRanges = {
  Planet.sun: _MoolaTrikonaRange(
    signIndex: 4, // Leo
    startDegree: 0.0,
    endDegree: 20.0,
  ),
  Planet.moon: _MoolaTrikonaRange(
    signIndex: 1, // Taurus
    startDegree: 4.0,
    endDegree: 30.0,
  ),
  Planet.mars: _MoolaTrikonaRange(
    signIndex: 0, // Aries
    startDegree: 0.0,
    endDegree: 12.0,
  ),
  Planet.mercury: _MoolaTrikonaRange(
    signIndex: 5, // Virgo
    startDegree: 16.0,
    endDegree: 20.0,
  ),
  Planet.jupiter: _MoolaTrikonaRange(
    signIndex: 8, // Sagittarius
    startDegree: 0.0,
    endDegree: 10.0,
  ),
  Planet.venus: _MoolaTrikonaRange(
    signIndex: 6, // Libra
    startDegree: 0.0,
    endDegree: 15.0,
  ),
  Planet.saturn: _MoolaTrikonaRange(
    signIndex: 10, // Aquarius
    startDegree: 0.0,
    endDegree: 20.0,
  ),
};
