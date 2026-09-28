import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class MoonAnimationWidget extends StatelessWidget {
  final double phase;
  final bool isWaxing;
  final double size;

  const MoonAnimationWidget({
    super.key,
    required this.phase,
    required this.isWaxing,
    this.size = 200,
  });

  @override
  Widget build(BuildContext context) {
    // Implicitly animate phase changes (date taps, moon scrub) instead of
    // jumping frame-to-frame. TweenAnimationBuilder keeps the current value
    // and glides to the new `phase`; Reduce Motion collapses to 1ms via
    // AppTheme.animationDuration so it jumps instantly when requested.
    return TweenAnimationBuilder<double>(
      duration: AppTheme.animationDuration(
        context,
        const Duration(milliseconds: 350),
      ),
      curve: Curves.easeInOutCubic,
      tween: Tween<double>(end: phase.clamp(0.0, 1.0)),
      builder: (context, animatedPhase, _) => SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: MoonPhasePainter(
            phase: animatedPhase,
            isWaxing: isWaxing,
            color: AppTheme.moonLit,
            shadowColor: AppTheme.moonShadow,
          ),
        ),
      ),
    );
  }
}

class MoonPhasePainter extends CustomPainter {
  final double phase; // 0.0 (New) to 1.0 (Full)
  final bool isWaxing;
  final Color color;
  final Color shadowColor;

  MoonPhasePainter({
    required this.phase,
    required this.isWaxing,
    required this.color,
    required this.shadowColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2;

    // Clamp phase
    double clampedPhase = phase.clamp(0.0, 1.0);

    // Draw background (shadow/unlit part)
    final shadowPaint = Paint()..color = shadowColor;
    canvas.drawCircle(center, radius, shadowPaint);

    // Draw lit part
    final litPaint = Paint()..color = color;

    // We can simulate the phase by drawing a semi-circle and an ellipse
    // The lit part depends on whether it's waxing or waning
    // Waxing: Right side lit. "Light on Right, Light is Growing"
    // Waning: Left side lit.

    // To simplify: Rotate canvas so "Lit side" is always right, then handle phase magnitude
    canvas.save();

    // If Waning (Krishna), rotate 180 so "Right" becomes "Left"
    if (!isWaxing) {
      canvas.translate(center.dx, center.dy);
      canvas.rotate(math.pi);
      canvas.translate(-center.dx, -center.dy);
    }

    // Now assume we are drawing Waxing phase (Light growing from Right)
    // Phase 0: New (All dark). Logic: 100% Shadow.
    // Phase 0.5: Quarter (Right half lit).
    // Phase 1: Full (All lit).

    // However, the geometry is:
    // 1. Draw Right Semicircle?
    //    - If phase < 0.5 (Crescent): Right Semicircle is DARK? No.
    //      - New Moon (0): All Dark.
    //      - Crescent (<0.5): Edge is lit. The terminator bulges INWARDS.
    //      - Quarter (0.5): Straight line.
    //      - Gibbous (>0.5): Bulges OUTWARDS.
    //      - Full (1): All Lit.

    // Correct Logic for "Lit from Right" (Waxing):
    // - Base: Draw RIGHT semicircle in LIGHT color?
    //   - No, if New Moon, everything is dark.
    // Let's use 2 arcs.

    // Algorithm:
    // Draw full Dark Circle (Shadow) - Already done.
    // If phase == 0, return.
    // If phase == 1, draw full Light Circle and return.

    if (clampedPhase >= 0.99) {
      canvas.drawCircle(center, radius, litPaint);
      canvas.restore();
      return;
    }
    if (clampedPhase <= 0.01) {
      canvas.restore();
      return;
    }

    // Amount of illumination determines the width of the ellipsoid terminator
    // The terminator is a semi-ellipse with horizontal radius `r * cos(theta)`
    // Width factor w goes from -1 (New) to 1 (Full) ?
    // Let's map phase 0..1 to width -1..1
    // Actually simpler:
    // Draw a Yellow Circle.
    // Then Draw a Dark Ellipse/Semicircle to cover part of it?

    // Let's try this:
    // 1. Draw Full Light Circle.
    // 2. Draw Dark "Shadow" on top.
    // Shadow mask shifts from Right to Left.
    // Waxing: Shadow recedes to Left.
    // Waning: Shadow grows from Right.
    // Since we rotated for Waning, we just model Waxing (Shadow recedes to Left).
    // New (0.0): Shadow covers all.
    // Full (1.0): Shadow covers none.

    // Actually, drawing the Lit part is usually preferred to avoid anti-aliasing artifacts on background.

    // Lit part Path for Waxing (Right side info):
    // Outer arc: Always the Right Semicircle (from -90 to 90 degrees).
    // Terminator arc: An ellipse connecting (0, -r) to (0, r).
    // Control point x varies.
    // x = r * (2*phase - 1).
    // If phase < 0.5, x is negative (Terminator bulges left, concave crescent).
    // If phase > 0.5, x is positive (Terminator bulges right, convex gibbous).

    // Wait, for Waxing (Right side lit):
    // Crescent (small phase): Lit part is a sliver on the right.
    //   - Outer edge: Right semicircle arc.
    //   - Inner edge: Ellipse bulging to the RIGHT? No, inwards. Bulging LEFT.
    // Gibbous (large phase): Lit part is almost full.
    //   - Outer edge: Right semicircle arc.
    //   - Inner edge: Ellipse bulging LEFT (far left)? No, bulging LEFT creates a hole. Bulging RIGHT makes it fuller.
    // Let's check math.
    // Terminator x coord at center = -R * cos(phase * pi)?
    // Let's use simple interpolation.
    // Offset x = (phase - 0.5) * 2 * R.
    // If phase = 0.5, x = 0 (straight line).
    // If phase = 0, x = -R.
    // If phase = 1, x = R.

    // So:
    // Path:
    // Move to Top (0, -R).
    // ArcTo Bottom (0, R) via Right (R, 0) [This is the constant outer rim for Waxing].
    // Then from Bottom (0, R), draw conic/bezier back to Top (0, -R) through (x, 0).

    final path = Path();
    path.moveTo(center.dx, center.dy - radius); // Top

    // Outer Right Arc (Constant for waxing)
    path.arcToPoint(
      Offset(center.dx, center.dy + radius), // Bottom
      radius: Radius.circular(radius),
    );

    // Inner Terminator Arc (Variable)
    // We need an elliptical arc back to top.
    // Using simple cubicTo or quadraticTo might be approximate, but arcTo with radii is better?
    // Flutter Path doesn't support elliptical arc through point easily?
    // We can use scaling.

    // Scale X based on phase.
    // But we need to close the shape.
    // We drew the right half. The left boundary of this shape is the terminator.
    // If phase < 0.5 (Crescent), we need to CUT OUT a piece?
    // Actually, if phase < 0.5:
    //   The terminator bulges to the RIGHT (x > 0)? No.
    //   If phase=0.1, we have a tiny sliver on the right. The terminator is close to the right edge.
    //   So x should be positive?
    //   Wait, 0 is New. 1 is Full.
    //   0.5 is Half Lit (Right half). Terminator is at x=0.
    //   0.1 is Crescent. Terminator is at x > 0? Yes.
    //   0.9 is Gibbous. Terminator is at x < 0 (left side).

    // So x_terminator = radius * (1 - 2 * phase).
    // If phase=0 (New), x = R. Terminator is at right edge. Area is 0.
    // If phase=0.5, x = 0.
    // If phase=1 (Full), x = -R. Terminator is at left edge. Area is full circle.

    // Let's verify:
    // Waxing: Lit from Right.
    // Shape is bounded by Right Semicircle and Terminator.
    // Terminator passes through (x_terminator, 0).
    // If x_terminator is positive (Crescent), we fill between Right Edge and x_terminator.
    // If x_terminator is negative (Gibbous), we fill Right Semicircle + Left partial ellipse.

    // Improved Algorithm:
    // 1. Draw Right Semicircle (Lit).
    // 2. If phase > 0.5: Draw Left Semi-Ellipsoid (Lit).
    // 3. If phase < 0.5: Erase Left part of Right Semicircle?
    //    Actually, "Erase" = Draw Dark Ellipse.

    // Let's re-evaluate "Draw Lit".
    // Base: Right Semicircle (Always Lit for Waxing? Yes, unless phase < 0.5???)
    // No, for Crescent phase < 0.5, the LIT part is bounded by x_terminator (>0) and Right Edge.
    // So we effectively subtract an ellipse from the Right Semicircle.

    // Strategy:
    // 1. Clear/Draw Background (Shadow).
    // 2. Draw Right Semicircle in Color.
    // 3. Calculate width `w = (1 - 2 * phase) * radius`.
    //    Range: R (New) -> 0 (Quarter) -> -R (Full).
    // 4. Draw a Semi-Ellipse centered at Center with width `abs(w)` and height `R`.
    //    - If phase < 0.5 (Crescent): Draw this Ellipse in SHADOW color. (Eating into the Right Semicircle).
    //    - If phase >= 0.5 (Gibbous): Draw this Ellipse in LIGHT color. (Adding to the Right Semicircle).

    final double w = (1 - 2 * clampedPhase) * radius;
    final Rect ellipseRect = Rect.fromCenter(
      center: center,
      width: w.abs() * 2,
      height: radius * 2,
    );

    // Step 1: Draw Right Semicircle (Light)
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2, // Start at Top (-90 deg)
      math.pi, // Sweep 180 (to Bottom)
      false, // useCenter needed? With fill? Yes usually.
      litPaint,
    );
    // Note: drawArc with false useCenter might be chord? Paint is fill.
    // `useCenter: true` makes a wedge (pie slice).
    // Since it's a semicircle, `useCenter: true` is correct to include the center line.
    // But we want to seamlessly blend.
    // Actually, just drawing the arc with `useCenter: false` fills the chord shape (D-shape) if fill is on. Correct.

    // Step 2: Handle the ellipse part
    if (clampedPhase < 0.5) {
      // Crescent: We need to "erase" the left part of the D-shape.
      // Draw shadow ellipse on top.
      // Left half of the ellipse?
      // Since w is positive here, the ellipse spans -w to w.
      // We want to erase the "bulge" which is on the Left side of the Center line?
      // No, for Crescent, `w` is positive (e.g. 0.8 R).
      // The terminator is at x = w (0.8 R).
      // The lit part is from 0.8 R to R.
      // The Right Semicircle filled 0 to R.
      // We need to erase 0 to 0.8 R.
      // The ellipse covers -0.8 R to 0.8 R.
      // If we draw the RIGHT half of this ellipse in Shadow, it covers 0 to 0.8 R.

      canvas.drawArc(
        ellipseRect,
        -math.pi / 2,
        math.pi,
        false, // Fill chord
        shadowPaint,
      );
    } else {
      // Gibbous: We need to "add" the bulge on the left.
      // w is negative (e.g. -0.8 R). width is 1.6 R.
      // We want to fill 0 to -0.8 R (Left side).
      // The ellipse covers -0.8 R to 0.8 R.
      // Drawing the LEFT half of this ellipse in Light adds the missing piece.

      canvas.drawArc(
        ellipseRect,
        math.pi / 2, // Start at Bottom (90 deg)
        math.pi, // Sweep 180 to Top (270/-90)
        false,
        litPaint,
      );
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant MoonPhasePainter oldDelegate) {
    return oldDelegate.phase != phase || oldDelegate.isWaxing != isWaxing;
  }
}
