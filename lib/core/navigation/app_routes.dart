import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// Central navigation motion for the app (Material Motion, hand-rolled).
///
/// Replaces raw `MaterialPageRoute` pushes so every screen transition shares
/// one duration/easing + Reduce Motion story:
///
/// * [pushFadeThrough] — peer-level screens (drawer destinations). Fade +
///   slight scale, outgoing fades first so pages never ghost over each other.
/// * [pushSharedX] — hierarchical drill (list → detail, settings → picker,
///   card → full screen). Slide along X + fade; outgoing parallaxes away.
///
/// Both respect [AppTheme.reduceMotionOf] (app setting + OS
/// `disableAnimations`, propagated in `main.dart`):
/// durations collapse to 1ms and the transition builder returns [child]
/// directly. `Duration.zero` is never used (see [AppTheme.animationDuration]).
///
/// Hero flights (e.g. `moon_icon`) keep working: these are regular
/// [ModalRoute]s, so the Navigator's HeroController animates shared tags.
class AppRoutes {
  const AppRoutes._();

  static const Duration _forwardDuration = Duration(milliseconds: 300);
  static const Duration _reverseDuration = Duration(milliseconds: 250);
  static const Duration _instant = Duration(milliseconds: 1);

  /// Peer-level transition: drawer → Moon / Countdown / Settings / About …
  static Future<T?> pushFadeThrough<T>(
    BuildContext context,
    Widget page, {
    String? name,
  }) {
    return Navigator.of(
      context,
    ).push<T>(fadeThroughRoute<T>(page, name: name, context: context));
  }

  /// Hierarchical transition: View All → list, card → Moon, gear → picker …
  static Future<T?> pushSharedX<T>(
    BuildContext context,
    Widget page, {
    String? name,
  }) {
    return Navigator.of(
      context,
    ).push<T>(sharedXRoute<T>(page, name: name, context: context));
  }

  /// Route version when the caller already holds a Navigator.
  static Route<T> fadeThroughRoute<T>(
    Widget page, {
    String? name,
    BuildContext? context,
  }) {
    final reduceMotion =
        context != null && AppTheme.reduceMotionOf(context);
    return PageRouteBuilder<T>(
      settings: RouteSettings(name: name ?? page.runtimeType.toString()),
      transitionDuration: reduceMotion ? _instant : _forwardDuration,
      reverseTransitionDuration: reduceMotion ? _instant : _reverseDuration,
      pageBuilder: (_, _, _) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        if (AppTheme.reduceMotionOf(context)) return child;
        // Staged fade-through: outgoing leaves (0.0–0.4), incoming
        // arrives (0.3–1.0) with a 0.92 → 1.0 scale. No overlap ghost.
        final incomingOpacity = CurvedAnimation(
          parent: animation,
          curve: const Interval(0.3, 1.0, curve: Curves.easeOutCubic),
          reverseCurve: Curves.easeInCubic,
        );
        final incomingScale = Tween<double>(begin: 0.92, end: 1.0).animate(
          CurvedAnimation(
            parent: animation,
            curve: const Interval(0.3, 1.0, curve: Curves.easeOutCubic),
            reverseCurve: Curves.easeInCubic,
          ),
        );
        final outgoingOpacity = Tween<double>(begin: 1.0, end: 0.0).animate(
          CurvedAnimation(
            parent: secondaryAnimation,
            curve: const Interval(0.0, 0.4, curve: Curves.easeOut),
          ),
        );
        final outgoingScale = Tween<double>(begin: 1.0, end: 0.92).animate(
          CurvedAnimation(
            parent: secondaryAnimation,
            curve: const Interval(0.0, 0.4, curve: Curves.easeOut),
          ),
        );
        return FadeTransition(
          opacity: outgoingOpacity,
          child: ScaleTransition(
            scale: outgoingScale,
            child: FadeTransition(
              opacity: incomingOpacity,
              child: ScaleTransition(scale: incomingScale, child: child),
            ),
          ),
        );
      },
    );
  }

  /// Route version when the caller already holds a Navigator.
  static Route<T> sharedXRoute<T>(
    Widget page, {
    String? name,
    BuildContext? context,
  }) {
    final reduceMotion =
        context != null && AppTheme.reduceMotionOf(context);
    return PageRouteBuilder<T>(
      settings: RouteSettings(name: name ?? page.runtimeType.toString()),
      transitionDuration: reduceMotion ? _instant : _forwardDuration,
      reverseTransitionDuration: reduceMotion ? _instant : _reverseDuration,
      pageBuilder: (_, _, _) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        if (AppTheme.reduceMotionOf(context)) return child;
        final primary = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        final secondary = CurvedAnimation(
          parent: secondaryAnimation,
          curve: Curves.easeOutCubic,
        );
        // Incoming: slide 8% → settled + fade. Outgoing (when covered):
        // parallax 6% back + dim. Pop reverses symmetrically.
        return FadeTransition(
          opacity: Tween<double>(begin: 1.0, end: 0.0).animate(secondary),
          child: SlideTransition(
            position: Tween<Offset>(
              begin: Offset.zero,
              end: const Offset(-0.06, 0),
            ).animate(secondary),
            child: FadeTransition(
              opacity: primary,
              child: SlideTransition(
                position:
                    Tween<Offset>(
                      begin: const Offset(0.08, 0),
                      end: Offset.zero,
                    ).animate(primary),
                child: child,
              ),
            ),
          ),
        );
      },
    );
  }
}
