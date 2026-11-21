import 'package:flutter/foundation.dart' show listEquals;
import 'package:material_ui/material_ui.dart';

import '../../../theme/app_metrics.dart';
import '../../../theme/app_motion.dart';
import '../../../theme/app_theme.dart';
import '../domain/hero_content.dart';
import 'hero_artwork_cards.dart';
import 'hero_deck_rotation.dart';
import 'hero_festival_image.dart';

/// Right-side festival artwork slot.
///
/// One picture renders exactly as the single-image slot always has. Two or
/// more render as a deck: the headline festival sits in front, the next ones
/// peek diagonally above and to the right (dimmed), and a position pill marks
/// where the deck is. Swiping sideways rotates it — the front picture goes to
/// the back — so every festival on the day can be read without opening the
/// gallery. The outer footprint never changes with the count or the position,
/// so the moon text column keeps its width on every date.
///
/// A deck also turns by itself every [HeroDeckRotation.interval] until the
/// user takes over, so a day with several pictures reveals all of them
/// without a gesture. The idle motion stops for good on the first swipe or
/// long press, pauses while the page is scrolling, while the card is scrolled
/// out of the viewport, while a sheet or dialog covers the card and while the
/// app is in the background, and never starts under Reduce Motion or while a
/// screen reader is running.
class HeroArtworkStack extends StatefulWidget {
  const HeroArtworkStack({
    super.key,
    required this.artworks,
    required this.width,
    required this.highContrast,
    required this.hint,
    required this.swipeHint,
    required this.onLongPress,
  });

  final List<HeroArtwork> artworks;
  final double width;
  final bool highContrast;

  /// Accessibility hint for the single-picture slot (long press only).
  final String hint;

  /// Accessibility hint for the deck (swipe to rotate + long press).
  final String swipeHint;

  /// Long press carrying the index of the picture currently in front.
  final ValueChanged<int> onLongPress;

  @override
  State<HeroArtworkStack> createState() => _HeroArtworkStackState();
}

class _HeroArtworkStackState extends State<HeroArtworkStack>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  /// Which artwork is in front; the others follow it (rotating deck).
  int _index = 0;

  /// Diagonal step between stacked cards, in logical pixels.
  static const double _peek = 5;

  /// Cards drawn behind the headline picture; the pill and the gallery carry
  /// the rest.
  static const int _maxBackCards = 2;

  /// Travel that still counts as a swipe when the release itself was slow.
  static const double _swipeDistance = 16;

  /// Idle turns cross-dissolve slowly: nobody asked for the change, so it
  /// should settle in rather than snap.
  static const Duration _autoTurnDuration = Duration(milliseconds: 1200);

  /// A swipe the user just made is already decided; swapping quickly keeps it
  /// feeling direct.
  static const Duration _swipeTurnDuration = Duration(milliseconds: 220);

  /// The idle clock (timer, lifecycle, page scroll, user takeover).
  late final HeroDeckRotation _rotation;

  /// True when the last change came from the timer, so the next transition
  /// uses the slow curve instead of the swipe tempo.
  bool _autoTurn = false;

  /// A finger is on the deck (never rotate mid-drag).
  bool _dragging = false;

  /// Horizontal travel of the drag in progress.
  double _dragDx = 0;

  /// Crossfade between the deck in front and its replacement. Hand-driven
  /// rather than an AnimatedSwitcher because a switcher cannot change the
  /// duration of a transition already in flight: the outgoing deck would
  /// finish at the old speed while the new one was still fading in.
  late final AnimationController _fade;
  late final CurvedAnimation _fadeIn;
  late final Animation<double> _fadeOut;

  /// The deck fading out, captured when it was replaced; null once the fade
  /// is done.
  ({List<HeroArtwork> deck, int index})? _outgoing;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _rotation = HeroDeckRotation(
      canRotate: () => _shouldAutoRotate,
      canTick: () => mounted && !_dragging && _isOnScreen,
      isOnScreen: () => _isOnScreen,
      onTick: () => _stepBy(1),
    );
    _fade = AnimationController(
      vsync: this,
      value: 1,
      duration: _swipeTurnDuration,
    )..addStatusListener(_onFadeStatus);
    _fadeIn = CurvedAnimation(parent: _fade, curve: AppMotion.emphasizedCurve);
    _fadeOut = ReverseAnimation(_fadeIn);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _rotation.setAppActive(state == AppLifecycleState.resumed);
  }

  void _onFadeStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed || _outgoing == null) return;
    setState(() => _outgoing = null);
  }

  /// The pictures in display order: the one in front first.
  List<HeroArtwork> get _ordered => [
    for (var i = 0; i < widget.artworks.length; i++)
      widget.artworks[(_index + i) % widget.artworks.length],
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // MediaQuery only resolves dependencies after initState, and it can
    // change (Reduce Motion, screen reader, text scaling) at any time.
    _rotation.bindScroll(
      Scrollable.maybeOf(context)?.position.isScrollingNotifier,
    );
    _rotation.sync();
  }

  @override
  void didUpdateWidget(covariant HeroArtworkStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A different day means a different deck: start from its headline again
    // instead of keeping a position that no longer applies.
    if (!listEquals(oldWidget.artworks, widget.artworks) ||
        _index >= widget.artworks.length) {
      _index = 0;
      _autoTurn = false;
      _outgoing = null;
      // Jump any half-finished crossfade to its end: the decks it was blending
      // belong to the old day.
      _fade.value = 1;
      _rotation.resetForNewDeck();
    }
  }

  @override
  void dispose() {
    _rotation.dispose();
    WidgetsBinding.instance.removeObserver(this);
    _fade.removeStatusListener(_onFadeStatus);
    _fadeIn.dispose();
    _fade.dispose();
    super.dispose();
  }

  /// Rotating artwork is motion the user did not ask for, so it stays off
  /// under Reduce Motion and while a screen reader is announcing the deck
  /// (a label that changes every few seconds is noise there).
  bool get _shouldAutoRotate {
    if (widget.artworks.length < 2) return false;
    // Another screen on top mutes this route's tickers; rotating there would
    // only queue transitions that can never finish.
    if (!TickerMode.valuesOf(context).enabled) return false;
    // A sheet or dialog over the card hides it just as well, and popups do
    // not mute tickers.
    if (ModalRoute.of(context)?.isCurrent == false) return false;
    final media = MediaQuery.maybeOf(context);
    if (media == null) return false;
    return !media.disableAnimations && !media.accessibleNavigation;
  }

  /// Whether any part of the deck overlaps the window.
  ///
  /// Only called from the idle tick and from a settled scroll, never during
  /// the first build (where the render box has no size yet), so the rect is
  /// always from a completed layout.
  bool get _isOnScreen {
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) return false;
    final window = MediaQuery.maybeSizeOf(context);
    if (window == null) return true;
    final rect = box.localToGlobal(Offset.zero) & box.size;
    return rect.overlaps(Offset.zero & window);
  }

  /// Rotates the deck by [delta] pictures (1 = left swipe, i.e. next).
  ///
  /// [userInitiated] marks a swipe or a screen-reader action: the deck stops
  /// turning by itself from then on.
  void _stepBy(int delta, {bool userInitiated = false}) {
    final count = widget.artworks.length;
    if (count < 2) return;
    if (userInitiated) _rotation.pauseForUser();
    setState(() {
      // The deck on screen becomes the layer fading out, then it advances.
      _outgoing = (deck: _ordered, index: _index);
      _autoTurn = !userInitiated;
      _index = (_index + delta) % count;
    });
    _fade.duration = AppTheme.animationDuration(
      context,
      _autoTurn ? _autoTurnDuration : _swipeTurnDuration,
    );
    _fade.forward(from: 0);
  }

  void _onLongPress() {
    _rotation.pauseForUser();
    widget.onLongPress(_index);
  }

  void _onDragEnd(DragEndDetails details) {
    if (widget.artworks.length < 2) return;
    // Distance decides a slow drag; velocity rescues a quick flick.
    final travelled = _dragDx.abs() >= _swipeDistance
        ? _dragDx
        : -(details.primaryVelocity ?? 0);
    _dragDx = 0;
    if (travelled.abs() < _swipeDistance) return;
    _stepBy(travelled < 0 ? 1 : -1, userInitiated: true);
  }

  @override
  Widget build(BuildContext context) {
    final artworks = widget.artworks;
    final count = artworks.length;
    // Defensive: the parent hides the slot on a day without artwork, but an
    // empty list must never reach `ordered.first` below.
    if (count == 0) return const SizedBox.shrink();
    if (count == 1) {
      final only = artworks.first;
      return HeroFestivalImage(
        source: only.source,
        semanticsLabel: only.label,
        highContrast: widget.highContrast,
        width: widget.width,
        hint: widget.hint,
        onLongPress: () => widget.onLongPress(0),
      );
    }

    // Rotated view: the front picture followed by the ones behind it.
    final ordered = _ordered;
    final backCount = count - 1 < _maxBackCards ? count - 1 : _maxBackCards;
    final inset = _peek * backCount;
    final radius = BorderRadius.circular(AppRadius.card);
    // Decode the thumbnail at the size it is drawn instead of the full asset:
    // the same cache entry then serves the front card, the peeking cards and
    // the single-picture slot, at a fraction of the memory.
    final pixelRatio = MediaQuery.maybeDevicePixelRatioOf(context) ?? 1.0;
    final cacheWidth = (widget.width * pixelRatio).round();

    // One node for the whole deck: the labels list every festival, so a
    // screen reader hears all of them instead of just the top picture.
    // Switch Access / TalkBack rotate it through the scroll actions.
    return Semantics(
      container: true,
      image: true,
      label: ordered.map((artwork) => artwork.label).join(', '),
      hint: widget.swipeHint,
      onLongPress: _onLongPress,
      onScrollLeft: () => _stepBy(1, userInitiated: true),
      onScrollRight: () => _stepBy(-1, userInitiated: true),
      excludeSemantics: true,
      child: GestureDetector(
        // Only gestures this deck actually consumes stop the idle rotation, so
        // a scroll that merely starts on the picture keeps it turning.
        behavior: HitTestBehavior.opaque,
        onLongPress: _onLongPress,
        onHorizontalDragStart: (_) {
          // Only a finished swipe counts as taking over: a drag that stops
          // short never turns the deck, so it must not silence it either.
          _dragging = true;
          _dragDx = 0;
        },
        onHorizontalDragUpdate: (details) => _dragDx += details.delta.dx,
        onHorizontalDragCancel: () => _dragging = false,
        onHorizontalDragEnd: (details) {
          _dragging = false;
          _onDragEnd(details);
        },
        child: SizedBox(
          width: widget.width,
          height: widget.width * 1.2,
          child: Stack(
            children: [
              if (_outgoing != null)
                FadeTransition(
                  // The replaced deck holds still while the new one fades
                  // over it; a page slide would not read in this slot.
                  opacity: _fadeOut,
                  child: _deck(
                    _outgoing!.deck,
                    index: _outgoing!.index,
                    backCount: backCount,
                    inset: inset,
                    radius: radius,
                    cacheWidth: cacheWidth,
                  ),
                ),
              FadeTransition(
                opacity: _fadeIn,
                child: ScaleTransition(
                  scale: Tween<double>(
                    // An idle turn settles up from slightly smaller; a swipe
                    // brings the new picture up from further back. Neither
                    // exceeds the slot, so the Stack never crops the rounded
                    // corners mid-fade.
                    begin: _autoTurn ? 0.98 : 0.92,
                    end: 1,
                  ).animate(_fadeIn),
                  child: _deck(
                    ordered,
                    index: _index,
                    backCount: backCount,
                    inset: inset,
                    radius: radius,
                    cacheWidth: cacheWidth,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// One whole deck — back cards, headline picture and position pill — for
  /// [deck], whose first entry is the picture in front.
  Widget _deck(
    List<HeroArtwork> deck, {
    required int index,
    required int backCount,
    required double inset,
    required BorderRadius radius,
    required int cacheWidth,
  }) {
    return Stack(
      children: [
        // Farthest card first so nearer cards paint over it.
        for (var i = backCount; i >= 1; i--)
          Positioned(
            left: _peek * i,
            top: inset - _peek * i,
            right: inset - _peek * i,
            bottom: _peek * i,
            child: HeroArtworkCard(
              artwork: deck[i],
              radius: radius,
              highContrast: widget.highContrast,
              cacheWidth: cacheWidth,
              dim: i == 1 ? 0.32 : 0.5,
            ),
          ),
        // Headline picture: bottom-left of the deck, inset by the room the
        // back cards need.
        Positioned(
          left: 0,
          top: inset,
          right: inset,
          bottom: 0,
          child: Stack(
            fit: StackFit.expand,
            children: [
              HeroArtworkCard(
                artwork: deck.first,
                radius: radius,
                highContrast: widget.highContrast,
                cacheWidth: cacheWidth,
              ),
              Positioned(
                right: 6,
                bottom: 6,
                child: HeroArtworkPositionBadge(
                  index: index,
                  count: widget.artworks.length,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
