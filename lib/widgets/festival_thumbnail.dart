import 'package:flutter/material.dart';

import '../models/festival.dart';

/// Best-effort glyph per festival category (the bundle ships no per-festival
/// icon metadata). Major festivals get the gold sun from the redesign mock,
/// vrats the temple glyph, everything else the celebration glyph.
IconData festivalRowIcon(Festival festival) {
  return switch (festival.category) {
    'major' => Icons.wb_sunny_rounded,
    'vrat' => Icons.temple_buddhist,
    _ => Icons.celebration_rounded,
  };
}

/// Square festival thumbnail: the bundled artwork when the festival ships one
/// ([Visuals.image]), otherwise a category glyph on a tinted tile.
///
/// Shared by the festival rows (home card, all-festivals list, tithi sheet)
/// and the search results, so every surface uses the same picture and the
/// same cache entry. Asset paths and network URLs are both accepted (same
/// contract as the hero artwork); a missing/broken asset falls back to the
/// glyph instead of rendering an error box.
class FestivalThumbnail extends StatelessWidget {
  const FestivalThumbnail({
    super.key,
    required this.festival,
    required this.size,
    required this.backgroundColor,
    required this.glyphColor,
    this.borderRadius = 14,
    this.glyphSize = 24,
    this.glyphIcon,
  });

  final Festival festival;

  /// Logical side of the square slot.
  final double size;

  /// Fill behind the glyph (and behind a network image while it loads).
  final Color backgroundColor;

  /// Glyph tint used when the festival has no artwork.
  final Color glyphColor;

  final double borderRadius;
  final double glyphSize;

  /// Overrides the category glyph; defaults to [festivalRowIcon].
  final IconData? glyphIcon;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(borderRadius);
    final Widget glyph = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: backgroundColor, borderRadius: radius),
      alignment: Alignment.center,
      child: Icon(
        glyphIcon ?? festivalRowIcon(festival),
        size: glyphSize,
        color: glyphColor,
      ),
    );

    final source = festival.visuals.image.trim();
    if (source.isEmpty) return glyph;

    // Decode at the size the slot draws (the bundle ships portrait artwork)
    // rather than at full resolution; identical sources share one cached
    // decode across every row and screen.
    final pixelRatio = MediaQuery.maybeDevicePixelRatioOf(context) ?? 1.0;
    final cacheWidth = (size * pixelRatio).round();
    final Widget image = source.startsWith('http')
        ? Image.network(
            source,
            cacheWidth: cacheWidth,
            fit: BoxFit.cover,
            excludeFromSemantics: true,
            loadingBuilder: (context, child, progress) =>
                progress == null ? child : glyph,
            errorBuilder: (context, _, _) => glyph,
          )
        : Image.asset(
            source,
            cacheWidth: cacheWidth,
            fit: BoxFit.cover,
            excludeFromSemantics: true,
            errorBuilder: (context, _, _) => glyph,
          );

    return SizedBox(
      width: size,
      height: size,
      child: ClipRRect(borderRadius: radius, child: image),
    );
  }
}
