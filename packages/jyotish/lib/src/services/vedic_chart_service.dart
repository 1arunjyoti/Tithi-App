import '../exceptions/jyotish_exception.dart';
import '../models/calculation_flags.dart';
import '../models/geographic_location.dart';
import '../models/planet.dart';
import '../models/planet_position.dart';
import '../models/vedic_chart.dart';
import 'ephemeris_service.dart';
import 'planetary_dignity.dart';

/// Service for calculating Vedic astrology charts.
class VedicChartService {
  VedicChartService(this._ephemerisService);
  final EphemerisService _ephemerisService;

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

      // Calculate Ascendant and house cusps. The chart always uses the
      // selected sidereal frame, so the requested house system and ayanamsa
      // both affect the cusps.
      final houses = await _calculateHouses(
        dateTime: dateTime,
        location: location,
        houseSystem: houseSystem,
        flags: flags,
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
        final dignity = dignityForLongitude(planet, position.longitude);
        final isCombust = PlanetPosition.calculateCombustion(
            planet, position.longitude, sunPosition.longitude);

        vedicPlanets[planet] = VedicPlanetInfo(
          position: position,
          house: house,
          dignity: dignity,
          isCombust: isCombust,
          exaltationDegree: exaltationDegreeFor(planet),
          debilitationDegree: debilitationDegreeFor(planet),
        );
      }

      // Create Vedic info for Rahu
      final rahuHouse = houses.getHouseForLongitude(rahuPosition.longitude);
      final rahuDignity =
          dignityForLongitude(Planet.meanNode, rahuPosition.longitude);
      final rahuInfo = VedicPlanetInfo(
        position: rahuPosition,
        house: rahuHouse,
        dignity: rahuDignity,
        isCombust: false, // Rahu/Ketu are never combust
      );

      return VedicChart(
        dateTime: dateTime,
        location: _locationLabel(location),
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
  ///
  /// The cusps are requested in the chart's sidereal frame directly. The old
  /// path calculated Placidus cusps always, then subtracted ayanamsa from the
  /// ascendant, MC and every cusp; that ignored [houseSystem] and could not
  /// answer a requested system correctly.
  Future<HouseSystem> _calculateHouses({
    required DateTime dateTime,
    required GeographicLocation location,
    required String houseSystem,
    required CalculationFlags flags,
  }) async {
    final code = houseSystem.toUpperCase();
    final name = _houseSystemNames[code];
    if (name == null) {
      throw ArgumentError.value(
        houseSystem,
        'houseSystem',
        'Unsupported Swiss Ephemeris house-system code. Supported: '
            '${_houseSystemNames.keys.join(', ')}',
      );
    }

    final houseData = await _ephemerisService.calculateHouses(
      dateTime: dateTime,
      location: location,
      houseSystem: code,
      flags: flags,
    );
    final cusps = houseData['cusps']!;
    final ascmc = houseData['ascmc']!;

    return HouseSystem(
      system: name,
      cusps: cusps,
      ascendant: ascmc[0],
      midheaven: ascmc[1],
    );
  }
}

/// Display names for the house systems supported by this package.
///
/// 'G' (Gauquelin) is deliberately absent: it writes 36 cusps, while this
/// binding allocates the standard 13-element buffer.
const Map<String, String> _houseSystemNames = {
  'P': 'Placidus',
  'K': 'Koch',
  'O': 'Porphyry',
  'R': 'Regiomontanus',
  'C': 'Campanus',
  'A': 'Equal (Ascendant)',
  'D': 'Equal (MC)',
  'E': 'Equal',
  'V': 'Vehlow',
  'W': 'Whole Sign',
  'X': 'Meridian',
  'H': 'Horizontal',
  'T': 'Polich/Page',
  'B': 'Alcabitius',
  'M': 'Morinus',
  'U': 'Krusinski',
};

String _locationLabel(GeographicLocation location) {
  final latDirection = location.latitude < 0 ? 'S' : 'N';
  final lonDirection = location.longitude < 0 ? 'W' : 'E';
  return '${location.latitude.abs().toStringAsFixed(4)}°$latDirection, '
      '${location.longitude.abs().toStringAsFixed(4)}°$lonDirection';
}
