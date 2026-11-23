import 'package:material_ui/material_ui.dart';

import '../../../theme/app_metrics.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/app_typography.dart';
import '../domain/hero_content.dart';

/// One picture in the hero's artwork slot: cover-cropped, rounded, scrimmed
/// and hairline-edged like the single-image slot. [dim] darkens the cards
/// behind the headline so the deck recedes instead of competing.
class HeroArtworkCard extends StatelessWidget {
  const HeroArtworkCard({
    super.key,
    required this.artwork,
    required this.radius,
    required this.highContrast,
    required this.cacheWidth,
    this.dim = 0,
  });

  final HeroArtwork artwork;
  final BorderRadius radius;
  final bool highContrast;

  /// Decode width in device pixels: the picture is a ~76-110 pt thumbnail, so
  /// decoding the full 600x800 asset would waste memory for every card.
  final int cacheWidth;

  final double dim;

  @override
  Widget build(BuildContext context) {
    final placeholder = ColoredBox(
      color: highContrast
          ? context.colors.primary.withValues(alpha: 0.08)
          : Colors.white.withValues(alpha: 0.12),
    );
    final source = artwork.source;
    final Widget image = source.startsWith('http')
        ? Image.network(
            source,
            cacheWidth: cacheWidth,
            fit: BoxFit.cover,
            excludeFromSemantics: true,
            loadingBuilder: (context, child, progress) =>
                progress == null ? child : placeholder,
            errorBuilder: (context, _, _) => placeholder,
          )
        : Image.asset(
            source,
            cacheWidth: cacheWidth,
            fit: BoxFit.cover,
            excludeFromSemantics: true,
            errorBuilder: (context, _, _) => placeholder,
          );

    return ClipRRect(
      borderRadius: radius,
      child: Stack(
        fit: StackFit.expand,
        children: [
          image,
          // Bottom scrim: settles the picture into the card.
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: radius,
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: const [0.55, 1],
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: highContrast ? 0.18 : 0.3),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (dim > 0)
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: radius,
                    color: Colors.black.withValues(alpha: dim),
                  ),
                ),
              ),
            ),
          // Hairline inner light edge, as on the single-image slot.
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: radius,
                  border: Border.all(
                    color: highContrast
                        ? context.colors.primary.withValues(alpha: 0.25)
                        : Colors.white.withValues(alpha: 0.22),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Position pill on the headline picture ("1/2" = first of two pictures).
/// Compact by design: the slot is 76-110 pt wide, so the spaces the gallery
/// counter uses ("1 / 2") would crowd the artwork.
class HeroArtworkPositionBadge extends StatelessWidget {
  const HeroArtworkPositionBadge({
    super.key,
    required this.index,
    required this.count,
  });

  final int index;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s6,
        vertical: AppSpacing.s2,
      ),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: Colors.white.withValues(alpha: 0.24)),
      ),
      child: Text(
        '${index + 1}/$count',
        style: const TextStyle(
          color: Colors.white,
          fontSize: AppTypography.sizeMicro,
          fontWeight: AppTypography.bold,
        ),
      ),
    );
  }
}
