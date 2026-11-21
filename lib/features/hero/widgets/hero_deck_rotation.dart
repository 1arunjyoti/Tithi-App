import 'dart:async';

import 'package:flutter/foundation.dart';

/// Owns the hero artwork deck's idle-rotation clock.
///
/// A deck turns itself every [interval] so a day with several pictures reveals
/// all of them without a gesture. That clock depends on state that lives
/// outside the timer: the app lifecycle, the enclosing page's scrolling flag
/// and a "user took over" latch. The widget supplies the context-dependent
/// gates ([canRotate]) and the per-tick guard ([canTick]) as callbacks, so
/// this class holds no [BuildContext] and the timing rules stay in one place.
class HeroDeckRotation {
  HeroDeckRotation({
    required this.canRotate,
    required this.canTick,
    required this.isOnScreen,
    required this.onTick,
  });

  /// How long each picture stays in front while the deck turns by itself.
  static const Duration interval = Duration(seconds: 10);

  /// Context gates, re-evaluated on every [sync]: deck size, Reduce Motion, a
  /// running screen reader, muted tickers and a route covering the card.
  final bool Function() canRotate;

  /// Per-tick guard: the card is mounted, not being dragged and on screen.
  final bool Function() canTick;

  /// Whether any part of the deck overlaps the window.
  final bool Function() isOnScreen;

  /// Advances the deck one picture.
  final VoidCallback onTick;

  /// Drives the idle rotation; null when it is off for any reason.
  Timer? _timer;

  /// False while the app is in the background: nothing to rotate for.
  bool _appActive = true;

  /// The enclosing page's scrolling flag. While it is true the deck must hold
  /// still: a 1.2s cross-dissolve started mid-fling repaints two image layers
  /// every frame right under the finger.
  bool _pageScrolling = false;

  /// Set once the user has moved the deck themselves. From then on it only
  /// moves on request, so a picture they picked never slides away underneath
  /// them — and it is the pause control WCAG 2.2.2 asks for.
  bool _userTookOver = false;

  /// The enclosing [Scrollable]'s scrolling flag, bound from the widget.
  ValueNotifier<bool>? _scrollNotifier;

  /// Pauses on background, re-arms on resume.
  ///
  /// Nobody can see the card in the background, and the timer must not fire
  /// there; it is re-armed when the app comes back.
  void setAppActive(bool active) {
    if (active == _appActive) return;
    _appActive = active;
    sync();
  }

  /// Follows the enclosing [Scrollable]'s scrolling flag, so an idle turn never
  /// starts — and a running one stops — while the page is moving.
  void bindScroll(ValueNotifier<bool>? notifier) {
    if (identical(notifier, _scrollNotifier)) return;
    _scrollNotifier?.removeListener(_onScrollChanged);
    _scrollNotifier = notifier;
    _pageScrolling = notifier?.value ?? false;
    notifier?.addListener(_onScrollChanged);
  }

  void _onScrollChanged() {
    final scrolling = _scrollNotifier?.value ?? false;
    if (scrolling == _pageScrolling) return;
    _pageScrolling = scrolling;
    if (!scrolling && !isOnScreen()) {
      // The page settled with the card out of sight: keep the picture as it is
      // and stop the clock instead of turning for an empty viewport.
      _cancel();
      return;
    }
    // Stops the timer on the first drag frame and starts a fresh countdown
    // once the page settles again.
    sync();
  }

  /// Stops the idle motion for good: a swipe or long press is the pause
  /// control WCAG 2.2.2 asks for.
  void pauseForUser() {
    _userTookOver = true;
    _cancel();
  }

  /// A different day means a different deck: the user's takeover no longer
  /// applies, so the idle motion may start again.
  void resetForNewDeck() {
    _userTookOver = false;
    _cancel();
    sync();
  }

  /// Arms or disarms the timer against the current gates.
  ///
  /// An armed timer is kept rather than restarted, so a sync triggered by an
  /// unrelated dependency change does not postpone the next turn.
  void sync() {
    if (!_shouldRotate) {
      _cancel();
      return;
    }
    _timer ??= Timer.periodic(interval, (_) {
      if (canTick()) onTick();
    });
  }

  bool get _shouldRotate =>
      _appActive && !_pageScrolling && !_userTookOver && canRotate();

  void _cancel() {
    _timer?.cancel();
    _timer = null;
  }

  /// Detaches from the page scroll and stops the clock.
  void dispose() {
    _scrollNotifier?.removeListener(_onScrollChanged);
    _scrollNotifier = null;
    _cancel();
  }
}
