import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/app_motion.dart';

/// What a tab does while the shell is switching tabs.
enum TabLayerRole {
  /// The tab being switched *to*: it fades in and slides into place.
  entering,

  /// The tab being switched *away from*: it slides out, staying opaque, and
  /// acts as the backdrop the incoming tab fades in over.
  exiting,

  /// Every other tab: invisible, but kept in the tree so its state survives.
  idle,
}

/// One tab of a tabbed shell, cross-faded and slid between during a switch.
///
/// The layer owns only the *presentation* of the switch. The child (the tab's
/// screen) is passed through untouched, so it is never rebuilt while the
/// transition runs and its state - scroll offset, search text, filters -
/// survives every switch.
///
/// Only one of the two tabs fades: the incoming one. The outgoing tab keeps
/// opacity 1 and slides away underneath it, so the page is backed by opaque
/// pixels for the whole switch. Fading both would make the pair translucent in
/// the middle of the transition (at half way the composite is 25% route
/// background), and it would cost a second full-screen layer per frame.
///
/// Visibility matches what an `IndexedStack` did: only the visible tab is
/// hit-testable, focusable and exposed to accessibility services. The hidden
/// tabs stay in the tree (and stay laid out) so they come back exactly as they
/// were.
///
/// Each layer keeps its own animation state rather than sharing a clock, so a
/// switch that interrupts another one continues from wherever the tab had
/// got to instead of snapping to a start value.
class AnimatedTabLayer extends StatefulWidget {
  const AnimatedTabLayer({
    super.key,
    required this.role,
    required this.slide,
    required this.child,
    this.direction = 1,
    this.initiallyVisible = false,
    this.onExited,
  });

  /// What this layer does during the current switch.
  final TabLayerRole role;

  /// +1 when the tab being shown sits to the *right* of the one it replaces,
  /// -1 for the reverse. The incoming tab slides in from that side and the
  /// outgoing one leaves towards it.
  final int direction;

  /// How far (logical pixels) the tabs travel during the switch.
  final double slide;

  /// Whether the tab starts out visible and still.
  ///
  /// True for the tab the shell opens with: it must be there on the first
  /// frame, not fade in over the app's launch. A tab opened *later* (the
  /// first visit to a tab) starts hidden and fades in.
  final bool initiallyVisible;

  /// Called when an exiting tab has finished leaving.
  final VoidCallback? onExited;

  /// The tab's content. Never rebuilt by the transition.
  final Widget child;

  @override
  State<AnimatedTabLayer> createState() => _AnimatedTabLayerState();
}

class _AnimatedTabLayerState extends State<AnimatedTabLayer>
    with TickerProviderStateMixin {
  static const Duration _duration = AppMotion.emphasized;

  /// 1 = fully visible, 0 = fully hidden.
  late final AnimationController _presence = AnimationController(
    vsync: this,
    duration: _duration,
  )..value = widget.initiallyVisible ? 1 : 0;

  /// Horizontal offset in logical pixels. Unbounded: the default controller
  /// clamps to 0..1, which would swallow a 24px offset.
  late final AnimationController _offset = AnimationController.unbounded(
    vsync: this,
    duration: _duration,
  );

  late final Listenable _clock = Listenable.merge([_presence, _offset]);

  /// Whether the opening animation has been started. `didChangeDependencies`
  /// runs on every inherited-widget change, and the animation must only be
  /// kicked off once.
  bool _started = false;

  @override
  void initState() {
    super.initState();
    // The exit is over when the layer has finished *sliding* out: its opacity
    // no longer animates (it stays opaque as the backdrop), so it cannot be
    // the signal any more.
    _offset.addStatusListener(_onOffsetStatus);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // The Reduce Motion setting can change under the app; keep the switch in
    // step with it.
    _applyDuration();
    if (_started) return;
    _started = true;
    if (!widget.initiallyVisible && widget.role == TabLayerRole.entering) {
      // A tab opened for the first time: it fades in from the side the switch
      // is heading towards.
      _offset.value = widget.direction * widget.slide;
      _presence.animateTo(1, curve: AppMotion.standardCurve);
      _offset.animateTo(0, curve: AppMotion.standardCurve);
    }
  }

  void _applyDuration() {
    final duration = AppTheme.animationDuration(context, _duration);
    _presence.duration = duration;
    _offset.duration = duration;
  }

  @override
  void didUpdateWidget(covariant AnimatedTabLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.role != widget.role) {
      _applyRole(oldWidget.role);
    }
  }

  /// Start the animation for the new role.
  ///
  /// [previous] tells a fresh switch apart from one that interrupts another:
  /// a tab coming in from idle starts at the far side of the screen, while an
  /// interrupted one carries on from wherever it had got to.
  void _applyRole(TabLayerRole previous) {
    switch (widget.role) {
      case TabLayerRole.entering:
        if (previous == TabLayerRole.idle) {
          _presence.value = 0;
          _offset.value = widget.direction * widget.slide;
        }
        _presence.animateTo(1, curve: AppMotion.standardCurve);
        _offset.animateTo(0, curve: AppMotion.standardCurve);
      case TabLayerRole.exiting:
        // Opaque backdrop: whatever the tab's opacity was when it started
        // leaving (it may have been fading in), it ramps to 1 so the incoming
        // tab always has something solid to land on.
        _presence.animateTo(1, curve: AppMotion.standardCurve);
        _offset.animateTo(
          -widget.direction * widget.slide,
          curve: AppMotion.standardCurve,
        );
      case TabLayerRole.idle:
        // A switch that interrupts another demotes a tab that is still on
        // screen, mid-slide. Fading it out over the remaining duration keeps
        // it from vanishing in a single frame - the incoming tab is only
        // partly opaque, so a snap would flash the route behind. A tab whose
        // exit already finished (offset no longer animating) is fully
        // covered, so it can snap.
        if (_presence.value > 0 && _offset.isAnimating) {
          _presence.animateTo(0, curve: AppMotion.standardCurve);
        } else {
          _presence.stop();
          _presence.value = 0;
        }
        // Leave the offset where it stopped: moving it now would be a visible
        // jump, and the next entrance resets it anyway.
        _offset.stop();
    }
  }

  void _onOffsetStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    if (widget.role != TabLayerRole.exiting) return;
    widget.onExited?.call();
  }

  @override
  void dispose() {
    _offset.removeStatusListener(_onOffsetStatus);
    _presence.dispose();
    _offset.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final visible = widget.role == TabLayerRole.entering;
    return ExcludeFocus(
      // `IgnorePointer` stops taps, not focus: without this a hidden (or still
      // leaving) tab can take keyboard and switch-access focus and hand it to
      // a widget the user cannot see.
      excluding: !visible,
      child: ExcludeSemantics(
        // Only the visible tab reaches the accessibility tree: the hidden ones
        // are still laid out (their scroll offsets must survive), but a screen
        // reader must not find three screens of content stacked on each other.
        excluding: !visible,
        child: IgnorePointer(
          // A tab that is sliding away must not take taps while it leaves.
          ignoring: !visible,
          child: AnimatedBuilder(
            animation: _clock,
            // The child is passed through, never rebuilt: a transition is a
            // presentation change, and rebuilding a calendar grid on every
            // frame of it would defeat the point.
            child: widget.child,
            builder: (context, child) {
              return Opacity(
                // 1 while exiting: `RenderOpacity` paints straight through at
                // full opacity, so the backdrop costs no saveLayer.
                opacity: _presence.value.clamp(0.0, 1.0),
                child: Transform.translate(
                  offset: Offset(_offset.value, 0),
                  child: child,
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
