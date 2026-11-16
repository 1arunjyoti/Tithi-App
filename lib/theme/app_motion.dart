import 'package:flutter/material.dart';

import 'app_theme.dart';

/// The app's motion vocabulary: named durations and curves.
///
/// Durations had drifted into 100/150/160/180/200/220/250/260/280/300ms with
/// no names, so a reviewer could not tell a deliberate 220 from a 200 typo.
/// Named by *job*, not by number - pick the token that matches what is moving:
///
/// - [press]: press feedback (press scale, press fill).
/// - [chrome]: chrome nudges (keyboard padding, inline hints).
/// - [subtle]: compact content swap inside a frame that keeps its size.
/// - [standard]: the default for implicit animations and toggles.
/// - [resize]: geometry changes (AnimatedSize, drawer capsule).
/// - [emphasized]: content entering or leaving (cards, rows, tab layers).
/// - [entrance]: one-shot list entrance before the stagger settles.
/// - [scroll]: programmatic scroll settle (jump to today, reveal top).
/// - [page]: page push.
/// - [staggerStep]: per-item stagger cadence.
///
/// Always gate a token with [of] (or [AppTheme.animationDuration] directly):
/// it collapses to 1ms when Reduce Motion / the OS `disableAnimations` flag is
/// on. Raw `Duration(milliseconds:)` in an implicit animation silently ignores
/// that setting.
abstract final class AppMotion {
  /// 100ms - press feedback (press scale, press fill).
  static const Duration press = Duration(milliseconds: 100);

  /// 150ms - chrome nudges (keyboard padding, inline hints).
  static const Duration chrome = Duration(milliseconds: 150);

  /// 180ms - compact content swap inside a fixed frame.
  static const Duration subtle = Duration(milliseconds: 180);

  /// 200ms - the default for implicit animations and toggles.
  static const Duration standard = Duration(milliseconds: 200);

  /// 220ms - geometry changes (AnimatedSize, drawer capsule).
  static const Duration resize = Duration(milliseconds: 220);

  /// 250ms - content entering or leaving (cards, rows, tab layers).
  static const Duration emphasized = Duration(milliseconds: 250);

  /// 280ms - one-shot list entrance before the stagger settles.
  static const Duration entrance = Duration(milliseconds: 280);

  /// 260ms - programmatic scroll settle.
  static const Duration scroll = Duration(milliseconds: 260);

  /// 300ms - page push.
  static const Duration page = Duration(milliseconds: 300);

  /// 60ms - per-item stagger cadence.
  static const Duration staggerStep = Duration(milliseconds: 60);

  /// Ease-out for things that appear or move in.
  static const Curve standardCurve = Curves.easeOutCubic;

  /// Ease-in-out for resizes and cross-fades where both ends are visible.
  static const Curve emphasizedCurve = Curves.easeInOutCubic;

  /// Ease-in for the reverse half of a push/pop.
  static const Curve exitCurve = Curves.easeInCubic;

  /// [token], collapsed to 1ms when Reduce Motion is on.
  static Duration of(BuildContext context, Duration token) =>
      AppTheme.animationDuration(context, token);
}
