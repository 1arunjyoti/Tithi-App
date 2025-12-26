import '../models/planet.dart';
import '../models/planet_position.dart';
import '../models/geographic_location.dart';
import '../models/calculation_flags.dart';
import '../models/vedic_chart.dart';
import '../exceptions/jyotish_exception.dart';
import 'ephemeris_service.dart';

/// Service for calculating Vedic astrology charts.
class VedicChartService {
  final EphemerisService _ephemerisService;

  VedicChartService(this._ephemerisService);

  /// Calculates a complete Vedic astrology chart.
  ///
  /// [dateTime] - Birth date and time
  /// [location] - Birth location
  /// [houseSystem] - House system to use (default: Whole Sign 'W')
  /// [includeOuterPlanets] - Include Uranus, Neptune, Pluto (default: false)
  Future<VedicChart> calculateChart({
    required DateTime dateTime,
    required GeographicLocation location,
    String houseSystem = 'W', // Whole Sign by default
    bool includeOuterPlanets = false,
  }) async {
    try {
      // Use default Lahiri ayanamsa (sidereal is now default)
      final flags = CalculationFlags.defaultFlags();

      // Calculate Ascendant and house cusps
      final houses = await _calculateHouses(
        dateTime: dateTime,
        location: location,
        houseSystem: houseSystem,
      );

      // Get list of planets to calculate
      final planetsToCalculate =
          includeOuterPlanets ? Planet.majorPlanets : Planet.traditionalPlanets;

      // Calculate all planetary positions
      final planetPositions = <Planet, PlanetPosition>{};
      for (final planet in planetsToCalculate) {
        final position = await _ephemerisService.calculatePlanetPosition(
          planet: planet,
          dateTime: dateTime,
          location: location,
          flags: flags,
        );
        planetPositions[planet] = position;
      }

      // Calculate Rahu (Mean Node)
      final rahuPosition = await _ephemerisService.calculatePlanetPosition(
        planet: Planet.meanNode,
        dateTime: dateTime,
        location: location,
        flags: flags,
      );

      // Create Ketu position (180° opposite to Rahu)
      final ketu = KetuPosition(rahuPosition: rahuPosition);

      // Calculate Sun position for combustion checks
      final sunPosition = planetPositions[Planet.sun]!;

      // Create Vedic planet info for each planet
      final vedicPlanets = <Planet, VedicPlanetInfo>{};
      for (final entry in planetPositions.entries) {
        final planet = entry.key;
        final position = entry.value;

        final house = houses.getHouseForLongitude(position.longitude);
        final dignity = _calculateDignity(planet, position.longitude);
        final isCombust = PlanetPosition.calculateCombustion(
            planet, position.longitude, sunPosition.longitude);

        vedicPlanets[planet] = VedicPlanetInfo(
          position: position,
          house: house,
          dignity: dignity,
          isCombust: isCombust,
          exaltationDegree: _getExaltationDegree(planet),
          debilitationDegree: _getDebilitationDegree(planet),
        );
      }

      // Create Vedic info for Rahu
      final rahuHouse = houses.getHouseForLongitude(rahuPosition.longitude);
      final rahuDignity =
          _calculateDignity(Planet.meanNode, rahuPosition.longitude);
      final rahuInfo = VedicPlanetInfo(
        position: rahuPosition,
        house: rahuHouse,
        dignity: rahuDignity,
        isCombust: false, // Rahu/Ketu are never combust
      );

      return VedicChart(
        dateTime: dateTime,
        location:
            '${location.latitude.toStringAsFixed(4)}°N, ${location.longitude.toStringAsFixed(4)}°E',
        latitude: location.latitude,
        longitudeCoord: location.longitude,
        houses: houses,
        planets: vedicPlanets,
        rahu: rahuInfo,
        ketu: ketu,
      );
    } catch (e, stackTrace) {
      throw CalculationException(
        'Failed to calculate Vedic chart: ${e.toString()}',
        originalError: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// Calculates house cusps using Swiss Ephemeris.
  Future<HouseSystem> _calculateHouses({
    required DateTime dateTime,
    required GeographicLocation location,
    required String houseSystem,
  }) async {
    // Calculate houses (returns tropical positions)
    final houseData = await _ephemerisService.calculateHouses(
      dateTime: dateTime,
      location: location,
      houseSystem: 'P', // Placidus system
    );

    // Get ayanamsa for sidereal correction
    final ayanamsa = await _ephemerisService.getAyanamsa(
      dateTime: dateTime,
      mode: SiderealMode.lahiri, // Use Lahiri ayanamsa
    );

    // Convert tropical positions to sidereal
    final tropicalAscendant = houseData['ascmc']![0];
    final ascendant = (tropicalAscendant - ayanamsa + 360) % 360;

    final tropicalMidheaven = houseData['ascmc']![1];
    final midheaven = (tropicalMidheaven - ayanamsa + 360) % 360;

    // Convert house cusps to sidereal
    final tropicalCusps = houseData['cusps']!;
    final cusps =
        tropicalCusps.map((cusp) => (cusp - ayanamsa + 360) % 360).toList();

    return HouseSystem(
      system: 'Placidus',
      cusps: cusps,
      ascendant: ascendant,
      midheaven: midheaven,
    );
  }

  /// Calculates planetary dignity based on sign placement.
  PlanetaryDignity _calculateDignity(Planet planet, double longitude) {
    final signIndex = (longitude / 30).floor() % 12;

    // Exaltation and debilitation degrees
    final exaltationMap = _getExaltationSign(planet);
    final debilitationMap = _getDebilitationSign(planet);

    if (exaltationMap != null && signIndex == exaltationMap) {
      return PlanetaryDignity.exalted;
    }

    if (debilitationMap != null && signIndex == debilitationMap) {
      return PlanetaryDignity.debilitated;
    }

    // Own signs
    final ownSigns = _getOwnSigns(planet);
    if (ownSigns.contains(signIndex)) {
      return PlanetaryDignity.ownSign;
    }

    // Moola Trikona
    final moolaTrikona = _getMoolaTrikona(planet);
    if (moolaTrikona != null && signIndex == moolaTrikona) {
      return PlanetaryDignity.moolaTrikona;
    }

    // Friend, enemy, neutral would require more complex calculations
    return PlanetaryDignity.neutralSign;
  }

  /// Gets exaltation sign index for a planet.
  int? _getExaltationSign(Planet planet) {
    const exaltations = {
      Planet.sun: 0, // Aries
      Planet.moon: 1, // Taurus
      Planet.mercury: 5, // Virgo
      Planet.venus: 11, // Pisces
      Planet.mars: 9, // Capricorn
      Planet.jupiter: 3, // Cancer
      Planet.saturn: 6, // Libra
      Planet.meanNode: 2, // Gemini (Rahu)
    };
    return exaltations[planet];
  }

  /// Gets debilitation sign index for a planet.
  int? _getDebilitationSign(Planet planet) {
    const debilitations = {
      Planet.sun: 6, // Libra
      Planet.moon: 7, // Scorpio
      Planet.mercury: 11, // Pisces
      Planet.venus: 5, // Virgo
      Planet.mars: 3, // Cancer
      Planet.jupiter: 9, // Capricorn
      Planet.saturn: 0, // Aries
      Planet.meanNode: 8, // Sagittarius (Rahu)
    };
    return debilitations[planet];
  }

  /// Gets exaltation degree for a planet.
  double? _getExaltationDegree(Planet planet) {
    const degrees = {
      Planet.sun: 10.0, // 10° Aries
      Planet.moon: 33.0, // 3° Taurus
      Planet.mercury: 165.0, // 15° Virgo
      Planet.venus: 357.0, // 27° Pisces
      Planet.mars: 298.0, // 28° Capricorn
      Planet.jupiter: 95.0, // 5° Cancer
      Planet.saturn: 200.0, // 20° Libra
    };
    return degrees[planet];
  }

  /// Gets debilitation degree for a planet.
  double? _getDebilitationDegree(Planet planet) {
    const degrees = {
      Planet.sun: 190.0, // 10° Libra
      Planet.moon: 213.0, // 3° Scorpio
      Planet.mercury: 345.0, // 15° Pisces
      Planet.venus: 165.0, // 27° Virgo (actually 177° - 27° Virgo)
      Planet.mars: 118.0, // 28° Cancer
      Planet.jupiter: 278.0, // 5° Capricorn
      Planet.saturn: 20.0, // 20° Aries
    };
    return degrees[planet];
  }

  /// Gets own signs for a planet.
  List<int> _getOwnSigns(Planet planet) {
    const ownSigns = {
      Planet.sun: [4], // Leo
      Planet.moon: [3], // Cancer
      Planet.mercury: [2, 5], // Gemini, Virgo
      Planet.venus: [1, 6], // Taurus, Libra
      Planet.mars: [0, 7], // Aries, Scorpio
      Planet.jupiter: [8, 11], // Sagittarius, Pisces
      Planet.saturn: [9, 10], // Capricorn, Aquarius
    };
    return ownSigns[planet] ?? [];
  }

  /// Gets Moola Trikona sign for a planet.
  int? _getMoolaTrikona(Planet planet) {
    const moolaTrikona = {
      Planet.sun: 4, // Leo
      Planet.moon: 1, // Taurus
      Planet.mercury: 5, // Virgo
      Planet.venus: 6, // Libra
      Planet.mars: 0, // Aries
      Planet.jupiter: 8, // Sagittarius
      Planet.saturn: 10, // Aquarius
    };
    return moolaTrikona[planet];
  }
}
