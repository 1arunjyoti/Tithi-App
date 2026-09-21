import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:jyotish/jyotish.dart';
import '../data/solar_models.dart';
import '../../../services/planetary_view_service.dart';
import '../../../theme/app_theme.dart';

/// Static background layer: gradient, stars, guides, zodiac ring, orbit
/// paths, and the center body. Depends only on view configuration — never
/// on per-frame [SolarSystemData] — so during animation this layer paints
/// once and stays cached behind its own RepaintBoundary while only the
/// planet layer repaints.
class SolarSystemStaticPainter extends CustomPainter {
  SolarSystemStaticPainter({
    required this.viewMode,
    this.isDark = false,
    this.zoomLevel = 1.0,
    this.showZodiac = false,
    this.panOffset = Offset.zero,
  });

  final SolarSystemViewMode viewMode;
  final bool isDark;
  final double zoomLevel;
  final bool showZodiac;
  final Offset panOffset;

  /// Whether this is geocentric (Earth-centered) view
  bool get isGeocentric => viewMode == SolarSystemViewMode.geocentric;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = (math.min(size.width, size.height) / 2 - 20) * zoomLevel;

    // Draw background gradient and stars
    _drawBackground(canvas, size, center, maxRadius);

    canvas.save();
    canvas.translate(panOffset.dx, panOffset.dy);

    // Subtle radial guides to visually separate sections from the center
    if (showZodiac) {
      _drawCenterGuides(canvas, center, maxRadius);
    }

    // Draw Zodiac Ring (if enabled)
    if (showZodiac) {
      _drawZodiacRing(canvas, center, maxRadius);
    }

    // Draw orbit paths
    _drawOrbits(canvas, center, maxRadius);

    // Draw the center body (Sun in heliocentric, Earth in geocentric)
    if (isGeocentric) {
      _drawEarth(canvas, center);
    } else {
      _drawSun(canvas, center);
    }
    canvas.restore();
  }

  void _drawCenterGuides(Canvas canvas, Offset center, double maxRadius) {
    final guidePaint = Paint()
      ..color = isDark
          ? AppTheme.spaceStar.withValues(alpha: 0.08)
          : AppTheme.spaceStar.withValues(alpha: 0.12)
      ..strokeWidth = 1.0;

    for (int i = 0; i < 12; i++) {
      final angle = i * 30 * math.pi / 180;
      final end = Offset(
        center.dx + maxRadius * math.cos(angle),
        center.dy + maxRadius * math.sin(angle),
      );
      canvas.drawLine(center, end, guidePaint);
    }
  }

  void _drawBackground(
    Canvas canvas,
    Size size,
    Offset center,
    double maxRadius,
  ) {
    // Deep space background (centralized illustration palette)
    final bgRect = Rect.fromLTWH(0, 0, size.width, size.height);
    final bgPaint = Paint()
      ..shader = RadialGradient(
        colors: AppTheme.spaceBackgroundGradient(isDark),
        radius: 1.5,
      ).createShader(bgRect);
    canvas.drawRect(bgRect, bgPaint);

    // Draw stars
    // We use a deterministic random seed so stars don't flicker on repaint
    final random = math.Random(42);
    final starPaint = Paint()..color = AppTheme.spaceStar.withValues(alpha: 0.8);

    // Draw about 100 random stars
    for (int i = 0; i < 100; i++) {
      final r = maxRadius * 1.5 * math.sqrt(random.nextDouble());
      final theta = random.nextDouble() * 2 * math.pi;
      final x = center.dx + r * math.cos(theta);
      final y = center.dy + r * math.sin(theta);

      // Skip if outside canvas
      if (x < 0 || x > size.width || y < 0 || y > size.height) continue;

      final starSize = random.nextDouble() * 1.5 + 0.5;
      // Twinkle effect (based on time would be better, but static is fine for now)
      final alpha = 0.3 + random.nextDouble() * 0.7;

      starPaint.color = AppTheme.spaceStar.withValues(alpha: alpha);
      canvas.drawCircle(Offset(x, y), starSize, starPaint);
    }
  }

  void _drawZodiacRing(Canvas canvas, Offset center, double maxRadius) {
    final radius =
        maxRadius * 1.05; // Slightly outside the outermost planet orbit area
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = isDark
          ? AppTheme.spaceStar.withValues(alpha: 0.15)
          : AppTheme.spaceStar.withValues(alpha: 0.2);

    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );

    // Draw 12 segments
    for (int i = 0; i < 12; i++) {
      final startAngle = i * 30 * math.pi / 180;
      // In Flutter canvas, 0 is right, positive angle is clockwise.
      // In Astronomy, 0 is Aries (Right), increasing longitude is Counter-Clockwise.
      // So we need to negate the angle for drawing.
      // Adjust by -30 degrees so the segment centers align with the sign?
      // No, 0-30 deg is Aries.

      // Draw sector line
      final lineAngle = -startAngle;
      final p1 = Offset(
        center.dx + radius * 0.85 * math.cos(lineAngle),
        center.dy + radius * 0.85 * math.sin(lineAngle),
      );
      final p2 = Offset(
        center.dx + radius * math.cos(lineAngle),
        center.dy + radius * math.sin(lineAngle),
      );
      canvas.drawLine(p1, p2, paint);

      // Draw Label in the middle of the sector
      // Center of Aries is 15 deg.
      final midAngle = -(startAngle + 15 * math.pi / 180);
      final labelRadius = radius * 0.92;
      final lx = center.dx + labelRadius * math.cos(midAngle);
      final ly = center.dy + labelRadius * math.sin(midAngle);

      final signName = PlanetaryViewService.getZodiacName(i);
      // Use first 3 letters or symbol if available.
      final label = signName.substring(0, 3).toUpperCase();

      textPainter.text = TextSpan(
        text: label,
        style: TextStyle(
          color: isDark
              ? AppTheme.spaceStar.withValues(alpha: 0.5)
              : AppTheme.spaceStar.withValues(alpha: 0.6),
          fontSize: 10,
          fontWeight: FontWeight.w500,
        ),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(lx - textPainter.width / 2, ly - textPainter.height / 2),
      );
    }

    // Draw degree labels every 15 degrees
    for (int i = 0; i < 24; i++) {
      final degree = i * 15;
      final degreeAngle = -(degree * math.pi / 180);
      final degreeRadius = radius * 1.12;
      final dx = center.dx + degreeRadius * math.cos(degreeAngle);
      final dy = center.dy + degreeRadius * math.sin(degreeAngle);

      textPainter.text = TextSpan(
        text: '$degree°',
        style: TextStyle(
          color: isDark
              ? AppTheme.spaceStar.withValues(alpha: 0.45)
              : AppTheme.spaceStar.withValues(alpha: 0.55),
          fontSize: 9,
          fontWeight: FontWeight.w500,
        ),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(dx - textPainter.width / 2, dy - textPainter.height / 2),
      );
    }

    // Draw outer circle
    canvas.drawCircle(center, radius, paint);
    canvas.drawCircle(center, radius * 0.85, paint);
  }

  void _drawOrbits(Canvas canvas, Offset center, double maxRadius) {
    final orbitPaint = Paint()
      ..color = isDark
          ? AppTheme.spaceStar.withValues(alpha: 0.1)
          : AppTheme.spaceStar.withValues(
              alpha: 0.15,
            ) // Lighter visibility on dark space bg
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    // Rings from the shared table (identical source as the computed
    // positions), so this layer renders without a SolarSystemData.
    final uniqueRadii = <double>{
      for (final r in orbitRadiiForViewMode(viewMode).values)
        if (r > 0) r,
    };

    for (final radius in uniqueRadii) {
      canvas.drawCircle(center, radius * maxRadius, orbitPaint);
    }
  }

  void _drawSun(Canvas canvas, Offset center) {
    // Draw sun glow
    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          AppTheme.sunMid.withValues(alpha: 0.8),
          AppTheme.sunOuter.withValues(alpha: 0.4),
          Colors.transparent,
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: 40));

    canvas.drawCircle(center, 40, glowPaint);

    // Draw sun core
    final sunPaint = Paint()
      ..shader = const RadialGradient(
        colors: [AppTheme.sunInner, AppTheme.sunMid, AppTheme.sunOuter],
      ).createShader(Rect.fromCircle(center: center, radius: 18));

    canvas.drawCircle(center, 18, sunPaint);
  }

  void _drawEarth(Canvas canvas, Offset center) {
    // Draw earth glow
    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          AppTheme.earthMid.withValues(alpha: 0.8),
          AppTheme.earthGlowGreen.withValues(alpha: 0.4),
          Colors.transparent,
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: 40));

    canvas.drawCircle(center, 40, glowPaint);

    // Draw earth core (blue ocean with green land hints)
    final earthPaint = Paint()
      ..shader = const RadialGradient(
        colors: [
          AppTheme.earthLight,
          AppTheme.earthMid,
          AppTheme.earthDeep,
        ],
      ).createShader(Rect.fromCircle(center: center, radius: 18));

    canvas.drawCircle(center, 18, earthPaint);

    // Draw "You are here" text marker or just symbol
    // Let's stick to the subtle text or maybe just the icon
    final textPainter = TextPainter(
      text: const TextSpan(
        text: '🌍',
        style: TextStyle(fontSize: 16, shadows: [Shadow(blurRadius: 10)]),
      ),
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
  @override
  bool shouldRepaint(covariant SolarSystemStaticPainter oldDelegate) {
    return oldDelegate.viewMode != viewMode ||
        oldDelegate.isDark != isDark ||
        oldDelegate.zoomLevel != zoomLevel ||
        oldDelegate.showZodiac != showZodiac ||
        oldDelegate.panOffset != panOffset;
  }
}


/// Dynamic planet layer: positions, selection, retrograde rings, labels.
/// Repaints every data frame; the static background stays cached.
class SolarSystemPainter extends CustomPainter {
  SolarSystemPainter({
    required this.solarSystemData,
    this.selectedPlanetIndex,
    this.zoomLevel = 1.0,
    this.panOffset = Offset.zero,
  });

  final SolarSystemData solarSystemData;
  final int? selectedPlanetIndex;
  final double zoomLevel;
  final Offset panOffset;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = (math.min(size.width, size.height) / 2 - 20) * zoomLevel;

    canvas.save();
    canvas.translate(panOffset.dx, panOffset.dy);

    // Draw planets
    _drawPlanets(canvas, center, maxRadius);
    canvas.restore();
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

      // Draw orbit position indicator on the orbit ring (optional, but helps visualization)
      // _drawOrbitMarker(canvas, planetPos, planetRadius, planetColor);

      // Draw selection highlight
      if (isSelected) {
        final highlightPaint = Paint()
          ..color = planetColor.withValues(alpha: 0.3)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(planetPos, planetRadius + 8, highlightPaint);

        // Draw crosshair or line to center? Maybe too busy.
      }

      // Draw retrograde indicator
      if (planet.isRetrograde) {
        final retrogradePaint = Paint()
          ..color = AppTheme.retrogradeIndicator.withValues(alpha: 0.6)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5;

        canvas.drawCircle(planetPos, planetRadius + 4, retrogradePaint);
      }

      // Draw planet glow (shadow for depth)
      final glowPaint = Paint()
        ..shader =
            RadialGradient(
              colors: [planetColor.withValues(alpha: 0.5), Colors.transparent],
            ).createShader(
              Rect.fromCircle(center: planetPos, radius: planetRadius + 8),
            );
      canvas.drawCircle(planetPos, planetRadius + 8, glowPaint);

      // Draw planet body with gradient for 3D effect
      // Light source assumed from Center (Sun)
      // Vector from Planet to Center
      final dx = center.dx - x;
      final dy = center.dy - y;
      final dist = math.sqrt(dx * dx + dy * dy);
      // Normalized light vector
      final lx = (dx / dist) * planetRadius * 0.5;
      final ly = (dy / dist) * planetRadius * 0.5;

      final planetPaint = Paint()
        ..shader =
            RadialGradient(
              center: Alignment(
                lx / planetRadius,
                ly / planetRadius,
              ), // Offset highlight towards sun
              colors: [
                planetColor.withValues(alpha: 1.0),
                Color.lerp(planetColor, Colors.black, 0.6)!, // Shadow side
              ],
              stops: const [0.3, 1.0],
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
        return 6;
      case 'mercury':
        return 5;
      case 'venus':
        return 7;
      case 'earth':
        return 7;
      case 'mars':
        return 6;
      case 'jupiter':
        return 14;
      case 'saturn':
        return 12; // Without rings. Rings would specific drawing.
      case 'uranus':
        return 9;
      case 'neptune':
        return 9;
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
    const textColor = AppTheme.spaceStar; // Always white on space background

    final textPainter = TextPainter(
      text: TextSpan(
        text: PlanetaryViewService.getPlanetDisplayName(planet.planet),
        style: TextStyle(
          color: textColor.withValues(alpha: isSelected ? 1.0 : 0.7),
          fontSize: isSelected ? 12 : 10,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          shadows: const [Shadow(blurRadius: 2)],
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
        oldDelegate.zoomLevel != zoomLevel ||
        oldDelegate.panOffset != panOffset;
  }
}


class PlanetHitTester {
  PlanetHitTester({
    required this.solarSystemData,
    required this.size,
    this.zoomLevel = 1.0,
    this.panOffset = Offset.zero,
  });

  final SolarSystemData solarSystemData;
  final Size size;
  final double zoomLevel;
  final Offset panOffset;

  /// Returns the index of the planet at the given position, or null if none
  int? hitTest(Offset position) {
    final center = Offset(size.width / 2, size.height / 2);
    final adjustedCenter = Offset(
      center.dx + panOffset.dx,
      center.dy + panOffset.dy,
    );
    final maxRadius = (math.min(size.width, size.height) / 2 - 20) * zoomLevel;

    for (int i = solarSystemData.planets.length - 1; i >= 0; i--) {
      final planet = solarSystemData.planets[i];
      if (planet.orbitRadius == 0) continue; // Skip sun

      final x = adjustedCenter.dx + planet.visualX * maxRadius;
      final y = adjustedCenter.dy - planet.visualY * maxRadius;
      final planetPos = Offset(x, y);

      final distance = (position - planetPos).distance;
      const hitRadius = 20.0; // Touch target radius

      if (distance <= hitRadius) {
        return i;
      }
    }

    return null;
  }
}
