import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/anim/press_scale.dart';
import '../theme/app_theme.dart';
import '../theme/app_metrics.dart';

/// The one page-level card surface.
///
/// Every standalone card on a page (home cards, eclipse cards, festival rows'
/// containers, list cards) should be an [AppCard] so fill, edge, radius,
/// padding, ripple and semantics cannot drift between screens. The pieces it
/// owns:
///
/// - surface + edge via [AppTheme.cardDecoration] (neutral hairline by
///   default; [accent] opts into the featured edge),
/// - [radius] shared by the surface *and* the [InkWell], so the ripple can
///   never be a different shape than the card,
/// - optional [onTap] with the app's press treatment (haptic, no dip unless
///   [pressedScale] is changed),
/// - optional [semanticLabel], which collapses the card's text into one
///   announcement and hands the tap action to the [InkWell] - the same
///   convention the festival rows use.
///
/// Spacing is parent-owned: pass [margin] only when the card must be inset
/// from a parent that the list cannot pad (e.g. home cards inside a
/// `SliverList`); otherwise let the list space cards by [AppTheme.cardGap].
class AppCard extends ConsumerWidget {
  const AppCard({
    super.key,
    required this.child,
    this.radius = AppTheme.cardRadius,
    this.padding = const EdgeInsets.all(AppSpacing.s16),
    this.margin,
    this.accent,
    this.onTap,
    this.semanticLabel,
    this.semanticHint,
    this.pressedScale = 1.0,
    this.clipBehavior = Clip.none,
  });

  final Widget child;

  /// Corner radius. Use [AppTheme.cardRadius] for a page card and
  /// [AppTheme.cardRadiusCompact] for a tile nested in one.
  final double radius;

  /// Inner padding around [child]. Pass `EdgeInsets.zero` for cards whose
  /// child manages its own padding.
  final EdgeInsetsGeometry padding;

  /// Outer margin. Leave null inside a list that spaces cards itself.
  final EdgeInsetsGeometry? margin;

  /// Featured edge colour. Null keeps the neutral hairline.
  final Color? accent;

  /// Makes the whole card tappable; adds ripple + haptic and the button
  /// semantics role.
  final VoidCallback? onTap;

  /// One-line accessibility label for the whole card. When set, the card's
  /// visual text is excluded from semantics and only this label is read.
  final String? semanticLabel;

  final String? semanticHint;

  /// Press dip. Defaults to 1.0 (haptic only), matching the home cards.
  final double pressedScale;

  final Clip clipBehavior;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final borderRadius = BorderRadius.circular(radius);
    Widget content = padding == EdgeInsets.zero
        ? child
        : Padding(padding: padding, child: child);

    if (onTap != null) {
      content = Material(
        color: Colors.transparent,
        borderRadius: borderRadius,
        child: PressScale(
          pressedScale: pressedScale,
          child: InkWell(
            borderRadius: borderRadius,
            onTap: onTap,
            // The composed label replaces the visual text; without one the
            // card keeps its children's semantics (and their reading order).
            child: semanticLabel == null
                ? content
                : ExcludeSemantics(child: content),
          ),
        ),
      );
    }

    final card = Container(
      margin: margin,
      clipBehavior: clipBehavior,
      decoration: AppTheme.cardDecoration(
        context,
        ref: ref,
        radius: radius,
        accent: accent,
      ),
      child: content,
    );

    if (semanticLabel == null) return card;

    return Semantics(
      button: onTap != null,
      label: semanticLabel,
      hint: semanticHint,
      child: card,
    );
  }
}
