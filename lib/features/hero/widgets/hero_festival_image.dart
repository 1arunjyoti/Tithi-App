import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';

// Right-side festival artwork for the hero moon row. Moved verbatim from
// widgets/paksha_hero_card.dart (_HeroFestivalImage).
//
// Handles asset paths and network URLs. Shows a translucent placeholder
// while a network image loads, and collapses to nothing if the image fails
// to resolve — so a missing/broken picture degrades to the current
// text-only layout instead of an empty box or error icon.
class HeroFestivalImage extends StatefulWidget {
  const HeroFestivalImage({
    super.key,
    required this.source,
    required this.semanticsLabel,
    required this.highContrast,
    this.width = 96,
  });

  final String source;
  final String semanticsLabel;
  final bool highContrast;

  /// Responsive slot width; height follows a ~1:1.2 ratio that suits
  /// deity artwork without stretching the card (other ratios center-crop
  /// via [BoxFit.cover]).
  final double width;

  @override
  State<HeroFestivalImage> createState() => _HeroFestivalImageState();
}

class _HeroFestivalImageState extends State<HeroFestivalImage> {
  bool _failed = false;

  @override
  void didUpdateWidget(covariant HeroFestivalImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Selected date changed (calendar tap): retry the new source instead of
    // staying collapsed from a previous failure.
    if (oldWidget.source != widget.source) _failed = false;
  }

  void _markFailed() {
    // Image callbacks fire during build; defer so setState runs after.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _failed = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) return const SizedBox.shrink();

    final placeholder = Container(
      color: widget.highContrast
          ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.08)
          : Colors.white.withValues(alpha: 0.12),
    );

    final Widget image;
    if (widget.source.startsWith('http')) {
      image = Image.network(
        widget.source,
        fit: BoxFit.cover,
        semanticLabel: widget.semanticsLabel,
        loadingBuilder: (context, child, progress) =>
            progress == null ? child : placeholder,
        errorBuilder: (context, _, _) {
          _markFailed();
          return const SizedBox.shrink();
        },
      );
    } else {
      image = Image.asset(
        widget.source,
        fit: BoxFit.cover,
        errorBuilder: (context, _, _) {
          _markFailed();
          return const SizedBox.shrink();
        },
      );
    }

    return Semantics(
      label: widget.semanticsLabel,
      image: true,
      child: Container(
        width: widget.width,
        height: widget.width * 1.2,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: widget.highContrast
                ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.2)
                : AppTheme.heroChipBorder(context),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: image,
      ),
    );
  }
}
