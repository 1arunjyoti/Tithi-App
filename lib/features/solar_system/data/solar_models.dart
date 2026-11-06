import 'dart:math' as math;

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

/// Reference points for the heliocentric radial scale:
/// (mean distance from the Sun in AU, drawing radius).
///
/// The radii are exactly [heliocentricOrbitRadii], which is why the ring drawn
/// for a planet is also the radius it has at its mean distance. The scale is
/// logarithmic between points, so distance ratios stay readable while the real
/// distance from the Sun now drives the position (a planet at perihelion sits
/// inside its ring, at aphelion outside).
const List<(double, double)> heliocentricRadiusAnchors = [
  (0.30, 0.10), // just inside Mercury's perihelion
  (0.387, 0.12), // Mercury
  (0.723, 0.20), // Venus
  (1.000, 0.28), // Earth
  (1.524, 0.38), // Mars
  (5.203, 0.55), // Jupiter
  (9.537, 0.70), // Saturn
  (19.19, 0.82), // Uranus
  (30.07, 0.92), // Neptune
];

/// Maps a true heliocentric distance (AU) onto the compressed drawing radius.
///
/// Monotonic in [distanceAU], so relative distances keep their order. Values
/// outside the anchor range clamp to the first/last radius instead of
/// extrapolating a planet off the canvas.
double heliocentricDisplayRadius(double distanceAU) {
  if (!distanceAU.isFinite || distanceAU <= 0) return 0;

  final first = heliocentricRadiusAnchors.first;
  if (distanceAU <= first.$1) return first.$2;

  for (int i = 1; i < heliocentricRadiusAnchors.length; i++) {
    final upper = heliocentricRadiusAnchors[i];
    if (distanceAU <= upper.$1) {
      final lower = heliocentricRadiusAnchors[i - 1];
      final t =
          math.log(distanceAU / lower.$1) / math.log(upper.$1 / lower.$1);
      return lower.$2 + (upper.$2 - lower.$2) * t;
    }
  }

  return heliocentricRadiusAnchors.last.$2;
}

/// A body's chart position in the heliocentric view.
class HeliocentricChartPoint {
  const HeliocentricChartPoint({
    required this.x,
    required this.y,
    required this.radius,
  });

  /// Horizontal chart coordinate, +1 is the outermost orbit.
  final double x;

  /// Vertical chart coordinate (ecliptic north is +y).
  final double y;

  /// Compressed distance from the Sun, in the same units as [x] and [y].
  final double radius;
}

/// Projects a true heliocentric position onto the 2D chart.
///
/// Ecliptic latitude tilts a body out of the plane, so a top-down view sees it
/// at `distance * cos(latitude)`. Longitude is kept exact, which makes the
/// angular ordering match a north-up view of the real system.
HeliocentricChartPoint projectHeliocentric({
  required double longitude,
  required double latitude,
  required double distanceAU,
}) {
  final longitudeRad = longitude * math.pi / 180;
  final latitudeRad = latitude * math.pi / 180;
  final planarDistance = distanceAU * math.cos(latitudeRad);
  final radius = heliocentricDisplayRadius(planarDistance);

  return HeliocentricChartPoint(
    x: math.cos(longitudeRad) * radius,
    y: math.sin(longitudeRad) * radius,
    radius: radius,
  );
}
