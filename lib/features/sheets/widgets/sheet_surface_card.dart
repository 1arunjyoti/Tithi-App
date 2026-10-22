import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';

// Canonical surface body card shared by the tithi detail sheet
// (TimingsCard/NakshatraCard/AuspiciousCard idiom: cardTheme fill, 16pt
// radius, no glass blur) and the festival event sheet (description,
// fasting, rituals, mantra). Replaces the event sheet's glassmorphism
// cards so both sheets share the same fill, radius and high-contrast
// behavior. An optional [border] covers the mantra accent-border variant.
class SheetSurfaceCard extends StatelessWidget {
  const SheetSurfaceCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.border,
    this.clipBehavior = Clip.none,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final BoxBorder? border;

  /// Clips the child to the card radius; tappable cards (see
  /// `SheetLinkTile`) need this so their ripple stays inside the surface.
  final Clip clipBehavior;

  @override
  Widget build(BuildContext context) {
    final decoration = AppTheme.sheetCardDecoration(context);
    return Container(
      width: double.infinity,
      padding: padding,
      clipBehavior: clipBehavior,
      decoration: border == null
          ? decoration
          : decoration.copyWith(border: border),
      child: child,
    );
  }
}
