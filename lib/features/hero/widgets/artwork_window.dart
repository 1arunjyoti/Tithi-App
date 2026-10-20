import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';
import '../domain/hero_content.dart';

/// Opens [images] (asset paths or http(s) URLs) in a floating window above the
/// hero card.
///
/// One image renders standalone; several become a swipeable gallery with a
/// position counter, so a day that stacks festival artwork on the card can be
/// read page by page.
///
/// A dialog-style window rather than a full-screen route: the card stays
/// visible behind a scrim, so context is kept and dismissal is obvious
/// (tap outside, close button, or back).
Future<void> showArtworkWindow(
  BuildContext context, {
  required List<HeroArtwork> images,
  int initialIndex = 0,
}) {
  assert(images.isNotEmpty, 'An artwork window needs at least one picture');
  // Nothing to show, or the card went away between the gesture and this call:
  // opening a dialog from a defunct context throws.
  if (images.isEmpty || !context.mounted) return Future<void>.value();
  final duration = AppTheme.animationDuration(
    context,
    const Duration(milliseconds: 220),
  );
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.black.withValues(alpha: 0.62),
    transitionDuration: duration,
    pageBuilder: (_, _, _) =>
        ArtworkWindow(images: images, initialIndex: initialIndex),
    transitionBuilder: (context, animation, _, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.92, end: 1).animate(curved),
          child: child,
        ),
      );
    },
  );
}

/// Floating festival-artwork window: pinch/double-tap zoom on a black stage,
/// festival name captioned along the bottom, page counter when the day has
/// more than one picture.
class ArtworkWindow extends StatefulWidget {
  const ArtworkWindow({super.key, required this.images, this.initialIndex = 0});

  final List<HeroArtwork> images;
  final int initialIndex;

  @override
  State<ArtworkWindow> createState() => _ArtworkWindowState();
}

class _ArtworkWindowState extends State<ArtworkWindow> {
  late final PageController _pages;
  late int _index;

  /// A pan on a zoomed picture must move the picture, not flip pages, so the
  /// pager is frozen while the current page is magnified.
  bool _zoomed = false;

  @override
  void initState() {
    super.initState();
    // Clamp so a stale index (the deck moved on since the long press) still
    // opens on a page that exists; an empty list must not blow up `clamp`.
    _index = widget.images.isEmpty
        ? 0
        : widget.initialIndex.clamp(0, widget.images.length - 1);
    _pages = PageController(initialPage: _index);
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    // Portrait window sized to the artwork's ~3:4 ratio, clamped so it stays
    // inset on small screens and out of the way on short ones.
    final width = math.min(340.0, media.size.width - 48);
    final height = math.min(width * 4 / 3, media.size.height * 0.62);
    final multiple = widget.images.length > 1;

    return Center(
      child: Material(
        color: Colors.black,
        elevation: 12,
        borderRadius: BorderRadius.circular(24),
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          width: width,
          height: height,
          child: Stack(
            fit: StackFit.expand,
            children: [
              PageView.builder(
                controller: _pages,
                itemCount: widget.images.length,
                physics: _zoomed
                    ? const NeverScrollableScrollPhysics()
                    : const PageScrollPhysics(),
                onPageChanged: (page) => setState(() {
                  _index = page;
                  _zoomed = false;
                }),
                itemBuilder: (context, page) => _ArtworkPage(
                  artwork: widget.images[page],
                  onZoomChanged: (zoomed) {
                    if (page != _index || zoomed == _zoomed) return;
                    setState(() => _zoomed = zoomed);
                  },
                ),
              ),
              if (multiple)
                Positioned(
                  top: 12,
                  left: 12,
                  child: _ArtworkCounter(
                    index: _index,
                    count: widget.images.length,
                  ),
                ),
              Positioned(
                top: 4,
                right: 4,
                child: IconButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                  color: Colors.white,
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.black.withValues(alpha: 0.4),
                  ),
                  icon: const Icon(Icons.close),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One gallery page: pinch/double-tap zoom on a black stage with the festival
/// name captioned along the bottom. Reports its zoom state so the pager can
/// stop stealing horizontal drags while the picture is magnified.
class _ArtworkPage extends StatefulWidget {
  const _ArtworkPage({required this.artwork, required this.onZoomChanged});

  final HeroArtwork artwork;
  final ValueChanged<bool> onZoomChanged;

  @override
  State<_ArtworkPage> createState() => _ArtworkPageState();
}

class _ArtworkPageState extends State<_ArtworkPage> {
  static const double _doubleTapScale = 2.5;

  final TransformationController _transform = TransformationController();
  Offset _doubleTapPosition = Offset.zero;
  bool _zoomed = false;

  @override
  void initState() {
    super.initState();
    _transform.addListener(_reportZoom);
  }

  @override
  void dispose() {
    _transform.removeListener(_reportZoom);
    _transform.dispose();
    super.dispose();
  }

  void _reportZoom() {
    final zoomed = _transform.value.getMaxScaleOnAxis() > 1.01;
    if (zoomed == _zoomed) return;
    _zoomed = zoomed;
    widget.onZoomChanged(zoomed);
  }

  void _handleDoubleTap() {
    final zoomed = _transform.value.getMaxScaleOnAxis() > 1.01;
    if (zoomed) {
      _transform.value = Matrix4.identity();
      return;
    }
    // Scale about the tapped point so the detail under the finger stays put.
    const s = _doubleTapScale;
    _transform.value = Matrix4.identity()
      ..setEntry(0, 0, s)
      ..setEntry(1, 1, s)
      ..setEntry(2, 2, s)
      ..setEntry(0, 3, _doubleTapPosition.dx * (1 - s))
      ..setEntry(1, 3, _doubleTapPosition.dy * (1 - s));
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onDoubleTapDown: (details) =>
              _doubleTapPosition = details.localPosition,
          onDoubleTap: _handleDoubleTap,
          child: InteractiveViewer(
            transformationController: _transform,
            minScale: 1,
            maxScale: 4,
            child: SizedBox.expand(
              child: _ArtworkImage(
                source: widget.artwork.source,
                label: widget.artwork.label,
              ),
            ),
          ),
        ),
        // Bottom scrim + caption, in the hero card's own idiom.
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.72),
                  ],
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 14),
                // The picture above already carries this label as its
                // semantic label; without this a reader says it twice.
                child: ExcludeSemantics(
                  child: Text(
                    widget.artwork.label,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// "2 / 3" position pill (hidden for a single picture).
class _ArtworkCounter extends StatelessWidget {
  const _ArtworkCounter({required this.index, required this.count});

  final int index;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '${index + 1} / $count',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Asset/network image with a static placeholder while a remote copy loads
/// and a quiet failure state — the same graceful degradation as the
/// thumbnail. Deliberately no spinner: an indeterminate progress indicator
/// animates until the frame arrives, which never happens for an asset inside
/// a widget test.
class _ArtworkImage extends StatelessWidget {
  const _ArtworkImage({required this.source, required this.label});

  final String source;
  final String label;

  @override
  Widget build(BuildContext context) {
    if (source.startsWith('http')) {
      return Image.network(
        source,
        fit: BoxFit.contain,
        semanticLabel: label,
        loadingBuilder: (context, child, progress) =>
            progress == null ? child : const _ArtworkPlaceholder(),
        errorBuilder: (context, _, _) => const _ArtworkUnavailable(),
      );
    }
    return Image.asset(
      source,
      fit: BoxFit.contain,
      semanticLabel: label,
      errorBuilder: (context, _, _) => const _ArtworkUnavailable(),
    );
  }
}

class _ArtworkPlaceholder extends StatelessWidget {
  const _ArtworkPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Icon(Icons.image_outlined, color: Colors.white24, size: 48),
    );
  }
}

class _ArtworkUnavailable extends StatelessWidget {
  const _ArtworkUnavailable();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Icon(Icons.broken_image_outlined, color: Colors.white38, size: 48),
    );
  }
}
