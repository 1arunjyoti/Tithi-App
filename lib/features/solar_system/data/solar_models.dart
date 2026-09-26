import 'package:jyotish/jyotish.dart';

// Phase 6a: solar-system models extracted from
// services/planetary_view_service.dart. The service re-exports these so
// existing screens/painters keep working during migration.

/// View mode for solar system visualization
enum SolarSystemViewMode {
  /// Sun at center, planets in heliocentric positions (astronomically accurate)
  heliocentric,

  /// Earth at center, planets in geocentric positions (astrologically relevant)
  geocentric,
}

/// Data class representing a planet's visual position
class PlanetVisualData {
  const PlanetVisualData({
    required this.planet,
    required this.longitude,
    required this.latitude,
    required this.isRetrograde,
    required this.zodiacSign,
    required this.degree,
    required this.visualX,
    required this.visualY,
    required this.orbitRadius,
    this.distanceAU,
    this.orbitalPeriodDays,
  });

  final Planet planet;
  final double longitude; // Ecliptic longitude in degrees
  final double latitude; // Ecliptic latitude in degrees
  final bool isRetrograde;
  final String zodiacSign;
  final double degree; // Degree within the sign (0-30)
  final double visualX; // X position for visualization (-1 to 1)
  final double visualY; // Y position for visualization (-1 to 1)
  final double orbitRadius; // Relative orbit radius for display
  final double? distanceAU; // Distance from Sun in AU
  final double? orbitalPeriodDays; // Orbital period in days
}

/// Complete solar system visualization data
class SolarSystemData {
  const SolarSystemData({
    required this.dateTime,
    required this.planets,
    required this.viewMode,
  });

  final DateTime dateTime;
  final List<PlanetVisualData> planets;
  final SolarSystemViewMode viewMode;

  PlanetVisualData? getPlanet(Planet planet) {
    try {
      return planets.firstWhere((p) => p.planet == planet);
    } catch (_) {
      return null;
    }
  }
}

// Relative orbit radii for visualization (logarithmic scale for visibility)
// Heliocentric view - compressed for display
const Map<Planet, double> heliocentricOrbitRadii = {
  Planet.sun: 0.0,
  Planet.mercury: 0.12,
  Planet.venus: 0.20,
  Planet.earth: 0.28,
  Planet.moon: 0.28, // Will be offset from Earth
  Planet.mars: 0.38,
  Planet.jupiter: 0.55,
  Planet.saturn: 0.70,
  Planet.uranus: 0.82,
  Planet.neptune: 0.92,
};

// Geocentric view - Earth at center
const Map<Planet, double> geocentricOrbitRadii = {
  Planet.sun: 0.28,
  Planet.mercury: 0.18,
  Planet.venus: 0.22,
  Planet.moon: 0.12,
  Planet.mars: 0.40,
  Planet.jupiter: 0.55,
  Planet.saturn: 0.70,
  Planet.uranus: 0.82,
  Planet.neptune: 0.92,
};

/// Orbit radii table for [mode]. The static background painter uses this so
/// orbit rings render without a resolved [SolarSystemData].
Map<Planet, double> orbitRadiiForViewMode(SolarSystemViewMode mode) =>
    mode == SolarSystemViewMode.heliocentric
        ? heliocentricOrbitRadii
        : geocentricOrbitRadii;
