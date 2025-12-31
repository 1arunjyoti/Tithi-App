import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:jyotish/jyotish.dart';
import '../services/planetary_view_service.dart';

/// CustomPainter for rendering a 2D solar system visualization
class SolarSystemPainter extends CustomPainter {
  SolarSystemPainter({
    required this.solarSystemData,
    this.selectedPlanetIndex,
    this.isDark = false,
    this.zoomLevel = 1.0,
  });

  final SolarSystemData solarSystemData;
  final int? selectedPlanetIndex;
  final bool isDark;
  final double zoomLevel;

  /// Whether this is geocentric (Earth-centered) view
  bool get isGeocentric =>
      solarSystemData.viewMode == SolarSystemViewMode.geocentric;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = (math.min(size.width, size.height) / 2 - 20) * zoomLevel;

    // Draw background gradient for space effect
    _drawBackground(canvas, size, center, maxRadius);

    // Draw orbit paths
    _drawOrbits(canvas, center, maxRadius);

    // Draw the center body (Sun in heliocentric, Earth in geocentric)
    if (isGeocentric) {
      _drawEarth(canvas, center);
    } else {
      _drawSun(canvas, center);
    }

    // Draw planets
    _drawPlanets(canvas, center, maxRadius);
  }

  void _drawBackground(
    Canvas canvas,
    Size size,
    Offset center,
    double maxRadius,
  ) {
    // Subtle radial gradient for depth
    final bgPaint = Paint()
      ..shader = RadialGradient(
        colors: isDark
            ? [
                const Color(0xFF1A1A2E).withValues(alpha: 0.3),
                Colors.transparent,
              ]
            : [Colors.amber.shade50.withValues(alpha: 0.2), Colors.transparent],
      ).createShader(Rect.fromCircle(center: center, radius: maxRadius));

    canvas.drawCircle(center, maxRadius, bgPaint);
  }

  void _drawOrbits(Canvas canvas, Offset center, double maxRadius) {
    final orbitPaint = Paint()
      ..color = isDark
          ? Colors.white.withValues(alpha: 0.1)
          : Colors.grey.withValues(alpha: 0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    // Draw orbits for each planet
    final uniqueRadii = <double>{};
    for (final planet in solarSystemData.planets) {
      if (planet.orbitRadius > 0) {
        uniqueRadii.add(planet.orbitRadius);
      }
    }

    for (final radius in uniqueRadii) {
      canvas.drawCircle(center, radius * maxRadius, orbitPaint);
    }
  }

  void _drawSun(Canvas canvas, Offset center) {
    // Draw sun glow
    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFFFFD700).withValues(alpha: 0.8),
          const Color(0xFFFF8C00).withValues(alpha: 0.4),
          Colors.transparent,
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: 40));

    canvas.drawCircle(center, 40, glowPaint);

    // Draw sun core
    final sunPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFFFFFFE0),
          const Color(0xFFFFD700),
          const Color(0xFFFF8C00),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: 18));

    canvas.drawCircle(center, 18, sunPaint);
  }

  void _drawEarth(Canvas canvas, Offset center) {
    // Draw earth glow
    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFF4A90D9).withValues(alpha: 0.8),
          const Color(0xFF2E8B57).withValues(alpha: 0.4),
          Colors.transparent,
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: 40));

    canvas.drawCircle(center, 40, glowPaint);

    // Draw earth core (blue ocean with green land hints)
    final earthPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFF87CEEB), // Light sky blue
          const Color(0xFF4A90D9), // Medium blue
          const Color(0xFF2E5090), // Deep blue
        ],
      ).createShader(Rect.fromCircle(center: center, radius: 18));

    canvas.drawCircle(center, 18, earthPaint);

    // Draw "You are here" text
    final textPainter = TextPainter(
      text: TextSpan(text: '🌍', style: const TextStyle(fontSize: 16)),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(
        center.dx - textPainter.width / 2,
        center.dy - textPainter.height / 2,
      ),
    );
  }

  void _drawPlanets(Canvas canvas, Offset center, double maxRadius) {
    for (int i = 0; i < solarSystemData.planets.length; i++) {
      final planet = solarSystemData.planets[i];

      // Skip sun since it's drawn separately at center
      if (planet.orbitRadius == 0) continue;

      // Calculate position
      final x = center.dx + planet.visualX * maxRadius;
      final y =
          center.dy - planet.visualY * maxRadius; // Flip Y for screen coords

      final planetPos = Offset(x, y);
      final planetColor = Color(
        PlanetaryViewService.getPlanetColor(planet.planet),
      );
      final isSelected = selectedPlanetIndex == i;

      // Planet size based on type
      double planetRadius = _getPlanetRadius(planet.planet);
      if (isSelected) planetRadius *= 1.3;

      // Draw selection highlight
      if (isSelected) {
        final highlightPaint = Paint()
          ..color = planetColor.withValues(alpha: 0.3)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(planetPos, planetRadius + 8, highlightPaint);
      }

      // Draw retrograde indicator
      if (planet.isRetrograde) {
        final retrogradePaint = Paint()
          ..color = Colors.red.withValues(alpha: 0.5)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2;
        canvas.drawCircle(planetPos, planetRadius + 4, retrogradePaint);
      }

      // Draw planet glow
      final glowPaint = Paint()
        ..shader =
            RadialGradient(
              colors: [planetColor.withValues(alpha: 0.6), Colors.transparent],
            ).createShader(
              Rect.fromCircle(center: planetPos, radius: planetRadius + 6),
            );
      canvas.drawCircle(planetPos, planetRadius + 6, glowPaint);

      // Draw planet
      final planetPaint = Paint()
        ..shader =
            RadialGradient(
              colors: [
                planetColor.withValues(alpha: 1.0),
                planetColor.withValues(alpha: 0.8),
              ],
            ).createShader(
              Rect.fromCircle(center: planetPos, radius: planetRadius),
            );
      canvas.drawCircle(planetPos, planetRadius, planetPaint);

      // Draw planet label
      _drawPlanetLabel(canvas, planetPos, planet, planetRadius, isSelected);
    }
  }

  double _getPlanetRadius(Planet planet) {
    // Use displayName to identify the planet
    final planetName = planet.displayName.toLowerCase();

    // Relative sizes for visualization (scaled for visibility, not actual scale)
    switch (planetName) {
      case 'sun':
        return 18;
      case 'moon':
        return 5;
      case 'mercury':
        return 4;
      case 'venus':
        return 6;
      case 'earth':
        return 7; // Similar to Venus
      case 'mars':
        return 5;
      case 'jupiter':
        return 12;
      case 'saturn':
        return 10;
      case 'uranus':
        return 8;
      case 'neptune':
        return 8;
      default:
        return 5;
    }
  }

  void _drawPlanetLabel(
    Canvas canvas,
    Offset position,
    PlanetVisualData planet,
    double radius,
    bool isSelected,
  ) {
    final textColor = isDark ? Colors.white : Colors.black87;

    final textPainter = TextPainter(
      text: TextSpan(
        text: PlanetaryViewService.getPlanetDisplayName(planet.planet),
        style: TextStyle(
          color: textColor.withValues(alpha: isSelected ? 1.0 : 0.7),
          fontSize: isSelected ? 12 : 10,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();

    final offset = Offset(
      position.dx - textPainter.width / 2,
      position.dy + radius + 6,
    );
    textPainter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant SolarSystemPainter oldDelegate) {
    return oldDelegate.solarSystemData != solarSystemData ||
        oldDelegate.selectedPlanetIndex != selectedPlanetIndex ||
        oldDelegate.isDark != isDark ||
        oldDelegate.zoomLevel != zoomLevel;
  }
}

/// Hit test helper for planet selection
class PlanetHitTester {
  PlanetHitTester({
    required this.solarSystemData,
    required this.size,
    this.zoomLevel = 1.0,
  });

  final SolarSystemData solarSystemData;
  final Size size;
  final double zoomLevel;

  /// Returns the index of the planet at the given position, or null if none
  int? hitTest(Offset position) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = (math.min(size.width, size.height) / 2 - 20) * zoomLevel;

    for (int i = solarSystemData.planets.length - 1; i >= 0; i--) {
      final planet = solarSystemData.planets[i];
      if (planet.orbitRadius == 0) continue; // Skip sun

      final x = center.dx + planet.visualX * maxRadius;
      final y = center.dy - planet.visualY * maxRadius;
      final planetPos = Offset(x, y);

      final distance = (position - planetPos).distance;
      final hitRadius = 20.0; // Touch target radius

      if (distance <= hitRadius) {
        return i;
      }
    }

    return null;
  }
}
