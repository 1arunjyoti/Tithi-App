import 'dart:math' as math;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jyotish/jyotish.dart';

/// View mode for solar system visualization
enum SolarSystemViewMode {
  /// Sun at center, planets in heliocentric positions (astronomically accurate)
  heliocentric,

  /// Earth at center, planets in geocentric positions (astrologically relevant)
  geocentric,
}

/// Provider for PlanetaryViewService
final planetaryViewServiceProvider = Provider<PlanetaryViewService>((ref) {
  return PlanetaryViewService();
});

/// Provider for current view mode
class SolarSystemViewModeNotifier extends Notifier<SolarSystemViewMode> {
  @override
  SolarSystemViewMode build() => SolarSystemViewMode.heliocentric;

  void setViewMode(SolarSystemViewMode viewMode) {
    state = viewMode;
  }
}

final solarSystemViewModeProvider =
    NotifierProvider<SolarSystemViewModeNotifier, SolarSystemViewMode>(
      SolarSystemViewModeNotifier.new,
    );

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

/// Service for calculating and preparing planetary visualization data
class PlanetaryViewService {
  PlanetaryViewService();

  // Actual semi-major axis in AU (for reference and display)
  static const Map<Planet, double> _distanceAU = {
    Planet.sun: 0.0,
    Planet.mercury: 0.39,
    Planet.venus: 0.72,
    Planet.earth: 1.00,
    Planet.moon: 1.00, // Same as Earth (orbits Earth)
    Planet.mars: 1.52,
    Planet.jupiter: 5.20,
    Planet.saturn: 9.58,
    Planet.uranus: 19.22,
    Planet.neptune: 30.05,
  };

  // Orbital periods in Earth days
  static const Map<Planet, double> _orbitalPeriods = {
    Planet.sun: 0.0,
    Planet.mercury: 88.0,
    Planet.venus: 224.7,
    Planet.earth: 365.25,
    Planet.moon: 27.3, // Sidereal month
    Planet.mars: 687.0,
    Planet.jupiter: 4333.0,
    Planet.saturn: 10759.0,
    Planet.uranus: 30687.0,
    Planet.neptune: 60190.0,
  };

  // Relative orbit radii for visualization (logarithmic scale for visibility)
  // Heliocentric view - compressed for display
  static const Map<Planet, double> _heliocentricOrbitRadii = {
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
  static const Map<Planet, double> _geocentricOrbitRadii = {
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

  // Zodiac signs mapping
  static const List<String> _zodiacSigns = [
    'Aries',
    'Taurus',
    'Gemini',
    'Cancer',
    'Leo',
    'Virgo',
    'Libra',
    'Scorpio',
    'Sagittarius',
    'Capricorn',
    'Aquarius',
    'Pisces',
  ];

  // Hindi zodiac signs
  static const List<String> _zodiacSignsHi = [
    'मेष',
    'वृषभ',
    'मिथुन',
    'कर्क',
    'सिंह',
    'कन्या',
    'तुला',
    'वृश्चिक',
    'धनु',
    'मकर',
    'कुंभ',
    'मीन',
  ];

  /// Get solar system data for a given date
  Future<SolarSystemData> getSolarSystemData({
    required DateTime dateTime,
    double latitude = 28.6139,
    double longitude = 77.2090,
    SolarSystemViewMode viewMode = SolarSystemViewMode.heliocentric,
  }) async {
    final location = GeographicLocation(
      latitude: latitude,
      longitude: longitude,
    );

    // Get positions for all major planets
    // In heliocentric view, include Earth; in geocentric view, exclude it
    final planetsToShow = viewMode == SolarSystemViewMode.heliocentric
        ? [
            Planet.sun,
            Planet.mercury,
            Planet.venus,
            Planet.earth,
            Planet.moon,
            Planet.mars,
            Planet.jupiter,
            Planet.saturn,
            Planet.uranus,
            Planet.neptune,
          ]
        : [
            Planet.sun,
            Planet.moon,
            Planet.mercury,
            Planet.venus,
            Planet.mars,
            Planet.jupiter,
            Planet.saturn,
            Planet.uranus,
            Planet.neptune,
          ];

    // Use astronomical flags (tropical, heliocentric) for heliocentric view
    // to match NASA's Eyes on the Solar System
    final flags = viewMode == SolarSystemViewMode.heliocentric
        ? CalculationFlags.astronomical()
        : CalculationFlags.astronomical(heliocentric: false);

    final positions = await Jyotish().getMultiplePlanetPositions(
      planets: planetsToShow,
      dateTime: dateTime,
      location: location,
      flags: flags,
    );

    final visualDataList = <PlanetVisualData>[];

    // Get Earth position for Moon offset in heliocentric view
    PlanetPosition? earthPosition;
    if (viewMode == SolarSystemViewMode.heliocentric) {
      earthPosition = positions[Planet.earth];
    }

    // Select orbit radii based on view mode
    final orbitRadii = viewMode == SolarSystemViewMode.heliocentric
        ? _heliocentricOrbitRadii
        : _geocentricOrbitRadii;

    for (final entry in positions.entries) {
      final planet = entry.key;
      final position = entry.value;

      // Calculate visual position
      double orbitRadius = orbitRadii[planet] ?? 0.5;
      double angleRad;
      double visualX, visualY;

      if (viewMode == SolarSystemViewMode.heliocentric &&
          planet == Planet.moon &&
          earthPosition != null) {
        // Position Moon relative to Earth in heliocentric view
        final earthAngle = earthPosition.longitude * math.pi / 180;
        final earthOrbitRadius = orbitRadii[Planet.earth] ?? 0.28;
        final earthX = math.cos(earthAngle) * earthOrbitRadius;
        final earthY = math.sin(earthAngle) * earthOrbitRadius;

        // Moon orbits around Earth at a small offset
        const moonOffset = 0.04; // Small offset for visibility
        angleRad = position.longitude * math.pi / 180;
        visualX = earthX + math.cos(angleRad) * moonOffset;
        visualY = earthY + math.sin(angleRad) * moonOffset;
        orbitRadius = earthOrbitRadius; // Same visual orbit as Earth
      } else {
        angleRad = position.longitude * math.pi / 180;
        visualX = math.cos(angleRad) * orbitRadius;
        visualY = math.sin(angleRad) * orbitRadius;
      }

      // Determine zodiac sign
      final signIndex = (position.longitude / 30).floor() % 12;
      final zodiacSign = _zodiacSigns[signIndex];
      final degreeInSign = position.longitude % 30;

      visualDataList.add(
        PlanetVisualData(
          planet: planet,
          longitude: position.longitude,
          latitude: position.latitude,
          isRetrograde: position.longitudeSpeed < 0,
          zodiacSign: zodiacSign,
          degree: degreeInSign,
          visualX: visualX,
          visualY: visualY,
          orbitRadius: orbitRadius,
          distanceAU: _distanceAU[planet],
          orbitalPeriodDays: _orbitalPeriods[planet],
        ),
      );
    }

    // Sort by orbit radius for proper layering
    visualDataList.sort((a, b) => a.orbitRadius.compareTo(b.orbitRadius));

    return SolarSystemData(
      dateTime: dateTime,
      planets: visualDataList,
      viewMode: viewMode,
    );
  }

  /// Get zodiac sign name (optionally in Hindi)
  static String getZodiacName(int signIndex, {bool hindi = false}) {
    if (signIndex < 0 || signIndex >= 12) return '';
    return hindi ? _zodiacSignsHi[signIndex] : _zodiacSigns[signIndex];
  }

  /// Get planet display name
  static String getPlanetDisplayName(Planet planet, {bool hindi = false}) {
    const namesEn = {
      Planet.sun: 'Sun',
      Planet.moon: 'Moon',
      Planet.mercury: 'Mercury',
      Planet.venus: 'Venus',
      Planet.mars: 'Mars',
      Planet.jupiter: 'Jupiter',
      Planet.saturn: 'Saturn',
      Planet.uranus: 'Uranus',
      Planet.neptune: 'Neptune',
    };

    const namesHi = {
      Planet.sun: 'सूर्य',
      Planet.moon: 'चंद्र',
      Planet.mercury: 'बुध',
      Planet.venus: 'शुक्र',
      Planet.mars: 'मंगल',
      Planet.jupiter: 'गुरु',
      Planet.saturn: 'शनि',
      Planet.uranus: 'अरुण',
      Planet.neptune: 'वरुण',
    };

    return hindi
        ? (namesHi[planet] ?? planet.displayName)
        : (namesEn[planet] ?? planet.displayName);
  }

  /// Get planet color for visualization
  static int getPlanetColor(Planet planet) {
    const colors = {
      Planet.sun: 0xFFFFD700, // Gold
      Planet.moon: 0xFFC0C0C0, // Silver
      Planet.mercury: 0xFF00BFFF, // Deep sky blue
      Planet.venus: 0xFFFF69B4, // Hot pink
      Planet.mars: 0xFFFF4500, // Red-orange
      Planet.jupiter: 0xFFFFB347, // Light orange
      Planet.saturn: 0xFFFFFACD, // Lemon chiffon
      Planet.uranus: 0xFF40E0D0, // Turquoise
      Planet.neptune: 0xFF4169E1, // Royal blue
    };
    return colors[planet] ?? 0xFFFFFFFF;
  }

  /// Format degree string (e.g., "15° 23' Aries")
  static String formatDegree(double longitude) {
    final signIndex = (longitude / 30).floor() % 12;
    final degreeInSign = longitude % 30;
    final degrees = degreeInSign.floor();
    final minutes = ((degreeInSign - degrees) * 60).floor();

    return "$degrees° $minutes' ${_zodiacSigns[signIndex]}";
  }
}
