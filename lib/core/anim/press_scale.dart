import 'package:flutter/gestures.dart' show kTouchSlop;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/accessibility_provider.dart';
import '../../theme/app_theme.dart';

/// Press-down microinteraction (100ms tier): scales [child] to
/// [pressedScale] while the pointer is down, springs back on
/// release/cancel.
///
/// Listener-based — not a GestureDetector — so it never competes in the
/// gesture arena with the child's own ripple/`onPressed`. Haptic
/// ([HapticFeedback.lightImpact]) fires on press-down when [haptic] is true
/// and the accessibility setting allows it. Reduce Motion skips the scale
/// (but keeps the haptic); [enabled] skips everything (disabled buttons).
/// Pass `haptic: false` where the tap callback already buzzes (scale only,
/// no double-buzz).
///
/// A drag is not a press: once the pointer travels past the touch slop the
/// press is dropped for the rest of that gesture, so scrolling a list that
/// starts on a card never leaves it shrunk under the finger. Raw pointers are
/// not cancelled when an enclosing scrollable wins the arena, so this has to
/// be handled here.
class PressScale extends ConsumerStatefulWidget {
  const PressScale({
    super.key,
    required this.child,
    this.enabled = true,
    this.haptic = true,
    this.pressedScale = 0.94,
    this.highlightColor,
    this.highlightRadius,
  });

  final Widget child;

  /// When false, no scale, fill, or haptic (mirrors the child's disabled state).
  final bool enabled;

  /// When false, scales without buzzing (the callback owns the haptic).
  final bool haptic;

  /// Scale while pressed. 0.94 reads as tactile without looking broken.
  final double pressedScale;

  /// Optional fill shown while pressed (e.g. calendar tiles over a
  /// transparent background, where scale alone doesn't read as a hit).
  /// Fades over 100ms (instant under Reduce Motion). Null = no fill.
  final Color? highlightColor;

  /// Corner radius of the fill. Match the child's shape.
  final BorderRadiusGeometry? highlightRadius;

  @override
  ConsumerState<PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends ConsumerState<PressScale> {
  bool _pressed = false;

  /// The pointer that owns the current press, and where it landed. Extra
  /// fingers must not restart it, and movement past the touch slop hands the
  /// gesture over to an enclosing scrollable.
  int? _pointer;
  Offset _downAt = Offset.zero;

  void _onDown(PointerDownEvent event) {
    if (_pointer != null) return;
    _pointer = event.pointer;
    _downAt = event.position;
    if (!widget.enabled) return;
    if (widget.haptic && ref.read(accessibilityProvider).hapticFeedback) {
      HapticFeedback.lightImpact();
    }
    setState(() => _pressed = true);
  }

  void _onMove(PointerMoveEvent event) {
    if (event.pointer != _pointer || !_pressed) return;
    if ((event.position - _downAt).distance <= kTouchSlop) return;
    // A scroll, not a tap: let go now instead of staying shrunk until lift.
    _pointer = null;
    setState(() => _pressed = false);
  }

  void _onUp(PointerUpEvent event) => _release(event.pointer);

  void _onCancel(PointerCancelEvent event) => _release(event.pointer);

  void _release(int pointer) {
    if (pointer != _pointer) return;
    _pointer = null;
    if (!_pressed) return;
    setState(() => _pressed = false);
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = AppTheme.reduceMotionOf(context);
    final pressDuration = AppTheme.animationDuration(
      context,
      const Duration(milliseconds: 100),
    );
    Widget content = widget.child;
    // Press fill above the child (negligible text wash at these alphas),
    // kept out of the scale transform's way by living inside it.
    if (widget.highlightColor != null) {
      content = Stack(
        children: [
          widget.child,
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedOpacity(
                opacity: _pressed && widget.enabled ? 1.0 : 0.0,
                duration: pressDuration,
                curve: Curves.easeOut,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: widget.highlightColor,
                    borderRadius: widget.highlightRadius ?? BorderRadius.zero,
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    }
    return AnimatedScale(
      scale: _pressed && !reduceMotion && widget.enabled
          ? widget.pressedScale
          : 1.0,
      duration: pressDuration,
      curve: Curves.easeOut,
      child: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: _onDown,
        onPointerMove: _onMove,
        onPointerUp: _onUp,
        onPointerCancel: _onCancel,
        child: content,
      ),
    );
  }
}
