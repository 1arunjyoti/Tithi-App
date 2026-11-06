import 'dart:math' as math;
import 'package:jyotish/jyotish.dart';
import '../features/solar_system/data/solar_cache.dart';
import '../features/solar_system/data/solar_models.dart';
import '../theme/app_theme.dart';
import '../core/location/location_defaults.dart';

// Phase 6a: models, orbit tables, and view-state providers live in
// features/solar_system (data) and providers/planetary_view_provider.dart.
// Re-exported here so existing screens/painters keep compiling.
export '../features/solar_system/data/solar_models.dart'
    show SolarSystemViewMode, PlanetVisualData, SolarSystemData;

/// Service for calculating and preparing planetary visualization data
class PlanetaryViewService {
  PlanetaryViewService();

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

  // Orbit radii tables live in features/solar_system/data/solar_models.dart
  // (shared with the static background painter). Reference data below
  // stays here: it annotates computed positions only.

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

  /// Get solar system data for a given date.
  ///
  /// Positions move slowly, so results are cached by hour + view mode +
  /// rounded location (see solar_cache.dart): date scrubbing and animation
  /// replays skip the batched FFI call while "Today" still matches the live
  /// sky instead of showing midnight.
  Future<SolarSystemData> getSolarSystemData({
    required DateTime dateTime,
    double latitude = kDefaultLatitude,
    double longitude = kDefaultLongitude,
    SolarSystemViewMode viewMode = SolarSystemViewMode.heliocentric,
  }) async {
    final cacheKey = solarCacheKey(dateTime, viewMode, latitude, longitude);
    final cached = cachedSolarData(cacheKey);
    if (cached != null) return cached;

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

    // Heliocentric longitude of the Moon is Earth's longitude (it is measured
    // from the Sun), so it cannot say which side of Earth the Moon is on.
    // Fetch the geocentric Moon as well and use its longitude as the offset
    // direction around Earth.
    PlanetPosition? geocentricMoon;
    if (viewMode == SolarSystemViewMode.heliocentric) {
      final moonPositions = await Jyotish().getMultiplePlanetPositions(
        planets: const [Planet.moon],
        dateTime: dateTime,
        location: location,
        flags: CalculationFlags.astronomical(heliocentric: false),
      );
      geocentricMoon = moonPositions[Planet.moon];
    }

    // Select orbit radii based on view mode (shared table; the static
    // background painter reads the same source so rings always match).
    final orbitRadii = orbitRadiiForViewMode(viewMode);

    for (final entry in positions.entries) {
      final planet = entry.key;
      final position = entry.value;

      // Calculate visual position
      double orbitRadius;
      double visualX, visualY;

      if (viewMode == SolarSystemViewMode.heliocentric) {
        if (planet == Planet.moon &&
            earthPosition != null &&
            geocentricMoon != null) {
          // Position Moon relative to Earth in heliocentric view
          final earthPoint = projectHeliocentric(
            longitude: earthPosition.longitude,
            latitude: earthPosition.latitude,
            distanceAU: earthPosition.distance,
          );

          // Moon orbits around Earth at a small offset
          const moonOffset = 0.04; // Small offset for visibility
          final moonAngle = geocentricMoon.longitude * math.pi / 180;
          visualX = earthPoint.x + math.cos(moonAngle) * moonOffset;
          visualY = earthPoint.y + math.sin(moonAngle) * moonOffset;
          orbitRadius = earthPoint.radius; // Same visual orbit as Earth
        } else {
          // Real heliocentric distance places the planet on its orbit; the
          // shared scale keeps the layout readable while preserving the true
          // distance ordering (and eccentricity) that NASA's Eyes shows.
          final point = projectHeliocentric(
            longitude: position.longitude,
            latitude: position.latitude,
            distanceAU: position.distance,
          );
          orbitRadius = point.radius;
          visualX = point.x;
          visualY = point.y;
        }
      } else {
        orbitRadius = orbitRadii[planet] ?? 0.5;
        final angleRad = position.longitude * math.pi / 180;
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
          distanceAU: position.distance,
          orbitalPeriodDays: _orbitalPeriods[planet],
        ),
      );
    }

    // Sort by orbit radius for proper layering
    visualDataList.sort((a, b) => a.orbitRadius.compareTo(b.orbitRadius));

    final data = SolarSystemData(
      dateTime: dateTime,
      planets: visualDataList,
      viewMode: viewMode,
    );
    storeSolarData(cacheKey, data);
    return data;
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

  /// Get planet color for visualization.
  /// Delegates to [AppTheme] so the palette lives in a single place.
  static int getPlanetColor(Planet planet) {
    const colors = {
      Planet.sun: AppTheme.planetSun,
      Planet.moon: AppTheme.planetMoon,
      Planet.mercury: AppTheme.planetMercury,
      Planet.venus: AppTheme.planetVenus,
      Planet.mars: AppTheme.planetMars,
      Planet.jupiter: AppTheme.planetJupiter,
      Planet.saturn: AppTheme.planetSaturn,
      Planet.uranus: AppTheme.planetUranus,
      Planet.neptune: AppTheme.planetNeptune,
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
