import 'package:flutter/material.dart';

// Right-side festival artwork for the hero moon row. Moved verbatim from
// widgets/paksha_hero_card.dart (_HeroFestivalImage).
//
// Handles asset paths and network URLs. Shows a translucent placeholder
// while a network image loads, and collapses to nothing if the image fails
// to resolve — so a missing/broken picture degrades to the current
// text-only layout instead of an empty box or error icon.
//
// Optional [onLongPress] turns the thumbnail into a second gesture target:
// the handler is invoked on long press only, so a plain tap still falls
// through to the card's own InkWell (the detail sheet).
class HeroFestivalImage extends StatefulWidget {
  const HeroFestivalImage({
    super.key,
    required this.source,
    required this.semanticsLabel,
    required this.highContrast,
    this.width = 96,
    this.onLongPress,
    this.hint,
  });

  final String source;
  final String semanticsLabel;
  final bool highContrast;

  /// Responsive slot width; height follows a ~1:1.2 ratio that suits
  /// deity artwork without stretching the card (other ratios center-crop
  /// via [BoxFit.cover]).
  final double width;

  /// Long-press handler (null = thumbnail is not a gesture target).
  final VoidCallback? onLongPress;

  /// Accessibility hint for [onLongPress], read after [semanticsLabel].
  final String? hint;

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

    // Decode at the size this slot draws instead of the full asset (these are
    // 600x800): the deck uses the same formula, so the two share one cache
    // entry for the same picture.
    final pixelRatio = MediaQuery.maybeDevicePixelRatioOf(context) ?? 1.0;
    final cacheWidth = (widget.width * pixelRatio).round();

    final Widget image;
    if (widget.source.startsWith('http')) {
      image = Image.network(
        widget.source,
        cacheWidth: cacheWidth,
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
        cacheWidth: cacheWidth,
        fit: BoxFit.cover,
        errorBuilder: (context, _, _) {
          _markFailed();
          return const SizedBox.shrink();
        },
      );
    }

    const radius = BorderRadius.all(Radius.circular(24));
    Widget framed = SizedBox(
      width: widget.width,
      height: widget.width * 1.2,
      child: ClipRRect(
        borderRadius: radius,
        child: Stack(
          fit: StackFit.expand,
          children: [
            image,
            // Bottom scrim: settles the picture into the card instead of
            // ending on a hard edge.
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
                        Colors.black.withValues(
                          alpha: widget.highContrast ? 0.18 : 0.3,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // Hairline inner light edge: reads as a framed print and picks
            // up the hero's specular top highlight.
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: radius,
                    border: Border.all(
                      color: widget.highContrast
                          ? Theme.of(
                              context,
                            ).colorScheme.primary.withValues(alpha: 0.25)
                          : Colors.white.withValues(alpha: 0.22),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    // Long press only: no tap callbacks here, so the card's InkWell keeps
    // owning taps (this recognizer rejects on pointer-up and the ancestor
    // tap wins).
    final onLongPress = widget.onLongPress;
    if (onLongPress != null) {
      framed = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onLongPress: onLongPress,
        child: framed,
      );
    }

    return Semantics(
      label: widget.semanticsLabel,
      image: true,
      hint: widget.hint,
      onLongPress: onLongPress,
      child: framed,
    );
  }
}
