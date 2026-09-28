import 'dart:async';

import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// One-shot staggered entrance for list rows: fade + 12px rise.
///
/// Wrap each row: `StaggerEntrance(index: i, child: FestivalRowTile(...))`.
/// Row `i` waits `i × [delayPerIndex]` then glides in over [duration].
/// Transform-only (opacity + translate) so list extents — and
/// `ScrollablePositionedList.jumpTo` targets — never shift mid-animation.
///
/// * Entrance runs once per mounted element. Parent rebuilds (date taps,
///   search filter) reuse the same element positions, so they show
///   instantly instead of replaying. Only genuinely new mounts animate.
/// * Past [maxStaggered] the child returns as-is: a 100-row list pays for
///   ~8 timers, not 100.
/// * Reduce Motion (app setting + OS, see [AppTheme.reduceMotionOf]) shows
///   instantly with no timer and no opacity layer.
/// * After the tween completes the widget returns [child] directly, dropping
///   the opacity/transform layers so fast scrolls stay cheap.
class StaggerEntrance extends StatefulWidget {
  const StaggerEntrance({
    super.key,
    required this.index,
    required this.child,
    this.maxStaggered = 8,
    this.delayPerIndex = const Duration(milliseconds: 60),
    this.duration = const Duration(milliseconds: 280),
    this.slideOffset = 12.0,
  });

  final int index;
  final Widget child;

  /// Rows at or past this index appear instantly (perf cap).
  final int maxStaggered;

  /// Stagger step per row. Total delay is `index × delayPerIndex`.
  final Duration delayPerIndex;

  /// Fade/rise duration once the row starts.
  final Duration duration;

  /// Vertical rise distance in logical pixels.
  final double slideOffset;

  @override
  State<StaggerEntrance> createState() => _StaggerEntranceState();
}

class _StaggerEntranceState extends State<StaggerEntrance> {
  Timer? _timer;
  bool _started = false;
  bool _completed = false;
  bool _bypass = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Decide once per mount (context is available here, not in initState).
    if (_started || _completed || _timer != null) return;
    if (widget.index >= widget.maxStaggered ||
        AppTheme.reduceMotionOf(context)) {
      _bypass = true;
      _started = true;
      _completed = true;
      return;
    }
    final delay = widget.delayPerIndex * widget.index;
    if (delay == Duration.zero) {
      _started = true;
    } else {
      _timer = Timer(delay, () {
        if (!mounted) return;
        setState(() => _started = true);
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_bypass || _completed) return widget.child;
    if (!_started) {
      // Reserve full layout while invisible: no shift when rows appear.
      return Opacity(
        opacity: 0,
        child: Transform.translate(
          offset: Offset(0, widget.slideOffset),
          child: widget.child,
        ),
      );
    }
    return TweenAnimationBuilder<double>(
      duration: AppTheme.animationDuration(context, widget.duration),
      curve: Curves.easeOutCubic,
      tween: Tween<double>(begin: 0, end: 1),
      onEnd: () {
        if (mounted && !_completed) setState(() => _completed = true);
      },
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, widget.slideOffset * (1 - t)),
          child: child,
        ),
      ),
      child: widget.child,
    );
  }
}
