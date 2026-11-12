import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../core/anim/press_scale.dart';
import '../theme/app_theme.dart';

/// One top-level destination in a [FloatingNavBar].
@immutable
class FloatingNavDestination {
  const FloatingNavDestination({required this.icon, required this.label});

  final IconData icon;

  /// Single short noun, always painted: the icon alone is reserved for the
  /// selected destination, so the label is what makes the other two readable.
  final String label;
}

/// Detached, Google-Photos-style navigation capsule that floats above the
/// content's bottom edge instead of occupying a `bottomNavigationBar` slot.
///
/// The destinations always paint their label; the selected one adds its icon
/// inside an accent-filled pill. The capsule itself is content-sized: as wide
/// as the destinations need (plus the edge insets) and no wider, clamped to
/// the space the host gives it so it never overflows. Presentation only: the
/// caller owns the index ([selectedIndex] / [onSelected]) and the tab bodies.
///
/// The capsule floats *over* the content: it does not reserve a strip of its
/// own, and nothing is laid out behind an opaque background. Scrolling content
/// therefore passes underneath it and reads through the blurred film. The host
/// still owes each scrollable [reserve] of extra bottom padding (as
/// `HomeShell` passes through `bottomContentInset`) so the last row can come
/// to rest above the pill instead of parking behind it.
///
/// Accessibility: the film comes from [AppTheme.floatingOverlayDecoration], so
/// High Contrast falls back to a solid fill with a strong border; every
/// transition runs through [AppTheme.animationDuration] so Reduce Motion
/// collapses it to one frame. Each destination is one semantics node that
/// owns its tap action (the painted label is excluded, so it is announced
/// once, as a button).
class FloatingNavBar extends StatelessWidget {
  const FloatingNavBar({
    super.key,
    required this.destinations,
    required this.selectedIndex,
    required this.onSelected,
    this.trailingAction,
    this.showTrailingAction = true,
  }) : assert(destinations.length > 1 && destinations.length < 5),
       assert(selectedIndex >= 0 && selectedIndex < destinations.length);

  final List<FloatingNavDestination> destinations;
  final int selectedIndex;

  /// Fires with the tapped destination's index. The host decides whether that
  /// means "switch tab" or "push a route".
  final ValueChanged<int> onSelected;

  /// Optional action that floats *outside* the capsule, on its right, sharing
  /// the bar's baseline (the "jump to today" button).
  ///
  /// It is a sibling of the film, not a segment of it: its own shape and fill
  /// read as a separate control, and it takes space from the capsule (whose
  /// labels shrink into what is left) rather than from the screen gutters.
  /// Null when the host has no such action; [showTrailingAction] is how the
  /// host hides a mounted one.
  final Widget? trailingAction;

  /// Whether [trailingAction] is painted. The slot collapses to zero width
  /// over one animation, so the capsule slides across instead of jumping when
  /// the action appears or disappears (see `_TrailingAction`).
  final bool showTrailingAction;

  /// Capsule height. The destinations are centred inside it and are inset by
  /// [_edgeInset] on the left and right.
  ///
  /// 56 is the slimmest the capsule goes without squeezing the pill: the pill
  /// is 44, so 6dp of film stays above and below it. Taller than this and the
  /// band around the pill reads as empty air rather than a background.
  static const double height = 56;

  /// The capsule's corner radius: a stadium, so the end curve is the same
  /// shape whatever [height] is tuned to.
  static const double _radius = height / 2;

  /// Horizontal inset between the capsule's edge and the first/last
  /// destination: breathing room at the capsule's rounded ends. The pill is
  /// itself a stadium and its cap is inscribed in the capsule's cap, so this is
  /// a visual gap, not a clipping guard.
  static const double _edgeInset = 8;

  /// Gap between the capsule and the screen edges. Matches the home cards'
  /// gutter so the pill's edges line up with the content above it.
  static const double margin = AppTheme.homeCardGutter;

  /// Vertical space the capsule owns above the system inset: the pill plus
  /// both its margins. See [FloatingNavBar] for how to apply it.
  static const double reserve = height + margin * 2;

  /// The painted capsule inside this widget's full-width box.
  ///
  /// The box spans the screen so the capsule can be centred, but only the
  /// capsule itself is as wide as the destinations need: measure this, not
  /// [FloatingNavBar], when asserting width.
  static const Key capsuleKey = Key('floating_nav_bar_capsule');

  /// Inner horizontal padding of a pill. Part of the width every destination
  /// asks for; the only part that gives way when the window is vanishingly
  /// narrow (see [_resolveSlots]).
  static const double _hPadding = 16;

  /// Icon drawn only by the selected destination, and the gap after it.
  static const double _iconExtent = 22;
  static const double _iconGap = 8;
  static const double _iconWidth = _iconExtent + _iconGap;

  /// Height of the accent pill inside the [height] capsule. The touch target
  /// is the whole capsule (see [_DestinationButton]), so the pill is free to be
  /// shorter than the 48dp minimum: it only has to hold the icon and the label.
  static const double _pillHeight = 44;

  /// The label typography, without a colour: the same style paints every
  /// destination and measures it, so the width the bar reserves and the width
  /// the text paints can never disagree.
  static TextStyle _labelStyle(BuildContext context) {
    final base = Theme.of(context).textTheme.labelLarge ?? const TextStyle();
    return base.copyWith(
      fontSize: 14,
      height: 1.1,
      fontWeight: FontWeight.w600,
    );
  }

  /// Width [label] paints at the current text scale.
  ///
  /// Measured once per label per [build] — not per layout pass — because the
  /// capsule's width changes on every frame of the trailing action's
  /// `AnimatedSize`, and a [TextPainter] per destination per frame is pure
  /// waste when only the space it is given has changed.
  static double _measureLabel(
    String label,
    TextStyle style,
    TextScaler textScaler,
    TextDirection textDirection,
  ) {
    final painter = TextPainter(
      text: TextSpan(text: label, style: style),
      textDirection: textDirection,
      textScaler: textScaler,
      maxLines: 1,
    )..layout();
    final width = painter.width;
    painter.dispose();
    return width;
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    final labelStyle = _labelStyle(context);
    final textScaler = MediaQuery.textScalerOf(context);
    final textDirection = Directionality.of(context);
    final labelWidths = <double>[
      for (final destination in destinations)
        _measureLabel(destination.label, labelStyle, textScaler, textDirection),
    ];

    return Padding(
      // The system view inset is applied here. `reserve` deliberately excludes
      // it: that value is only what hosts add as scroll padding.
      padding: EdgeInsets.fromLTRB(margin, 0, margin, margin + bottomInset),
      child: Center(
        // Content-sized: `Center` loosens the width the shell's `left/right: 0`
        // would otherwise pin, so the row can measure itself and stop at what
        // the destinations need on a wide window, while still being clamped to
        // `screen - 2 * margin` (where the capsule's resolver takes over).
        // `heightFactor: 1` keeps this widget only as tall as the capsule, so
        // the shell can still pin it with `bottom: 0`.
        heightFactor: 1,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Flexible, not a bare child: once the trailing action is present
            // the capsule has to know the width it has left, because its own
            // slots are resolved against exactly that.
            Flexible(
              child: _capsule(
                context,
                labelWidths: labelWidths,
                labelStyle: labelStyle,
              ),
            ),
            if (trailingAction != null)
              _TrailingAction(
                visible: showTrailingAction,
                child: trailingAction!,
              ),
          ],
        ),
      ),
    );
  }

  /// The translucent film: the bar proper, without the trailing action.
  Widget _capsule(
    BuildContext context, {
    required List<double> labelWidths,
    required TextStyle labelStyle,
  }) {
    final surface = _surface(
      context,
      labelWidths: labelWidths,
      labelStyle: labelStyle,
    );
    return ClipRRect(
      key: capsuleKey,
      borderRadius: BorderRadius.circular(_radius),
      // Real backdrop blur, not the app's painted "glass": this capsule is
      // an overlay, so whatever scrolls underneath has to stay readable
      // through it. High Contrast skips the blur and uses the solid fill
      // from [AppTheme.floatingOverlayDecoration] instead.
      child: AppTheme.floatingOverlayBlurs(context)
          ? BackdropFilter(filter: _blur, child: surface)
          : surface,
    );
  }

  static final ImageFilter _blur = ImageFilter.blur(sigmaX: 20, sigmaY: 20);

  Widget _surface(
    BuildContext context, {
    required List<double> labelWidths,
    required TextStyle labelStyle,
  }) {
    // Palette lookups once per build, not once per destination: they each hit
    // the theme and two of them branch on High Contrast.
    final scheme = Theme.of(context).colorScheme;
    final fill = AppTheme.festivalAccent(context);
    final ink = AppTheme.onFestivalAccent(context);
    final muted = scheme.onSurface.withValues(
      alpha: AppTheme.contrastAlpha(context, 0.66),
    );
    final duration = AppTheme.animationDuration(
      context,
      const Duration(milliseconds: 200),
    );

    return Material(
      // Transparent Material: gives the subtree a DefaultTextStyle and an ink
      // surface without painting anything.
      type: MaterialType.transparency,
      child: DecoratedBox(
        decoration: AppTheme.floatingOverlayDecoration(
          context,
          // Keep the painted fill's corners inside the clip, so the film's
          // shape comes from one number instead of two that can drift apart.
          borderRadius: _radius,
        ),
        child: SizedBox(
          height: height,
          // The only layout-dependent step: how the available width is split.
          // Everything it needs was measured in build, so a frame of the
          // trailing action's animation costs arithmetic, not text layout.
          child: LayoutBuilder(
            builder: (context, constraints) {
              final slots = _resolveSlots(
                labelWidths: labelWidths,
                maxWidth: constraints.maxWidth,
                active: selectedIndex,
              );
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: _edgeInset),
                child: Row(
                  // min: the row is as wide as its slots, and the capsule
                  // wraps the row. No `spaceBetween`/`spaceEvenly` — there is
                  // no leftover width to distribute, so the outer options sit
                  // on the edge inset and the gaps between options are their
                  // own hit padding.
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 0; i < destinations.length; i++)
                      _DestinationButton(
                        destination: destinations[i],
                        slot: slots[i],
                        selected: i == selectedIndex,
                        labelStyle: labelStyle,
                        fill: fill,
                        ink: ink,
                        muted: muted,
                        duration: duration,
                        onTap: () => onSelected(i),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  /// Width each destination is given inside the capsule.
  ///
  /// Explicit widths, not flex weights. A weighted [Row] divides whatever is
  /// left by weight, so a clamped bar could hand a destination less than its
  /// own fixed padding plus icon — the pill then overflowed at large text
  /// scales. Here the parts that cannot shrink are reserved first and only the
  /// label (which ellipsizes) absorbs the pressure. The last slot takes the
  /// rounding remainder so the widths sum to exactly the space available.
  List<_Slot> _resolveSlots({
    required List<double> labelWidths,
    required double maxWidth,
    required int active,
  }) {
    final count = labelWidths.length;
    final desired = <double>[
      for (var i = 0; i < count; i++)
        labelWidths[i] + _hPadding * 2 + (i == active ? _iconWidth : 0),
    ];
    final desiredTotal = desired.fold<double>(0, (sum, width) => sum + width);

    // Content-sized: every option gets exactly what it asked for, and the
    // capsule hugs the row (it is centred, not stretched).
    final available = maxWidth.isFinite
        ? math.max(0.0, maxWidth - _edgeInset * 2)
        : desiredTotal;
    if (desiredTotal <= available) {
      return [
        for (var i = 0; i < count; i++)
          _Slot(width: desired[i], showIcon: i == active, hPadding: _hPadding),
      ];
    }

    // Clamped. Reserve padding first, then the selected icon: the icon is an
    // addition to the label, so a bar too narrow for both drops it instead of
    // eating the label that identifies the destination.
    var showIcon = true;
    var fixedTotal = count * _hPadding * 2 + _iconWidth;
    if (fixedTotal > available) {
      showIcon = false;
      fixedTotal = count * _hPadding * 2;
    }

    if (fixedTotal > available) {
      // Not even the padding fits (a sub-100dp window). Split evenly and let
      // the padding shrink with the slot, which leaves the label half of a
      // slot it cannot do anything useful with anyway. No icon, no overflow.
      final each = available / count;
      final hPadding = math.min(_hPadding, each * 0.25);
      return [
        for (var i = 0; i < count; i++)
          _Slot(
            width: i == count - 1 ? available - each * (count - 1) : each,
            showIcon: false,
            hPadding: hPadding,
          ),
      ];
    }

    final labelTotal = labelWidths.fold<double>(0, (sum, width) => sum + width);
    final labelSpace = available - fixedTotal;
    final slots = <_Slot>[];
    var used = 0.0;
    for (var i = 0; i < count; i++) {
      final fixed = _hPadding * 2 + (showIcon && i == active ? _iconWidth : 0);
      final share = labelTotal > 0
          ? labelSpace * (labelWidths[i] / labelTotal)
          : labelSpace / count;
      final width = i == count - 1 ? available - used : fixed + share;
      used += width;
      slots.add(
        _Slot(
          width: width,
          showIcon: showIcon && i == active,
          hPadding: _hPadding,
        ),
      );
    }
    return slots;
  }
}

/// Layout decision for one destination: the space it owns, whether the pill
/// paints an icon, and how much inner padding is left for the label.
@immutable
class _Slot {
  const _Slot({
    required this.width,
    required this.showIcon,
    required this.hPadding,
  });

  final double width;
  final bool showIcon;
  final double hPadding;
}

class _TrailingAction extends StatelessWidget {
  const _TrailingAction({required this.visible, required this.child});

  final bool visible;
  final Widget child;

  /// Gap between the capsule and the action.
  static const double gap = 8;

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: AppTheme.animationDuration(
        context,
        const Duration(milliseconds: 220),
      ),
      curve: Curves.easeOutCubic,
      // Directional: the action is on the *end* side in both reading
      // directions, and it has to stay there when the shell is mirrored.
      alignment: AlignmentDirectional.centerStart,
      // The hidden state keeps the bar's height so only the width animates:
      // collapsing both axes would clip the round button from top and bottom
      // too, which reads as a squash instead of a slide.
      //
      // Staying mounted (rather than being dropped from the row) is what lets
      // the parent re-measure the capsule every frame, so the bar re-centres
      // smoothly and a clamped capsule's labels follow the change.
      child: visible
          ? Padding(
              padding: const EdgeInsetsDirectional.only(start: gap),
              child: child,
            )
          : const SizedBox(width: 0, height: FloatingNavBar.height),
    );
  }
}

class _DestinationButton extends StatelessWidget {
  const _DestinationButton({
    required this.destination,
    required this.slot,
    required this.selected,
    required this.labelStyle,
    required this.fill,
    required this.ink,
    required this.muted,
    required this.duration,
    required this.onTap,
  });

  final FloatingNavDestination destination;
  final _Slot slot;
  final bool selected;
  final TextStyle labelStyle;

  /// Accent fill and ink of the selected pill, and the muted label colour of
  /// the other destinations. Resolved by the bar once per build.
  final Color fill;
  final Color ink;
  final Color muted;

  /// Selection transition. Already Reduce-Motion aware.
  final Duration duration;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: slot.width,
      // The whole capsule height is the tap target; only the pill is 44 tall.
      // `SizedBox` only pins the width, so `Center` below expands to the row's
      // 56dp cross axis (the capsule's height).
      child: Semantics(
        button: true,
        selected: selected,
        label: destination.label,
        // The painted label is excluded (it is announced by this node, once),
        // which also drops the GestureDetector's own semantics node - so the
        // tap action has to be declared here or a screen reader cannot
        // activate the destination at all.
        onTap: onTap,
        excludeSemantics: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: PressScale(
            child: Center(
              child: AnimatedContainer(
                duration: duration,
                curve: Curves.easeOutCubic,
                height: FloatingNavBar._pillHeight,
                padding: EdgeInsets.symmetric(horizontal: slot.hPadding),
                decoration: BoxDecoration(
                  color: selected ? fill : Colors.transparent,
                  borderRadius: BorderRadius.circular(
                    FloatingNavBar._pillHeight / 2,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (slot.showIcon) ...[
                      Icon(
                        destination.icon,
                        size: FloatingNavBar._iconExtent,
                        color: ink,
                      ),
                      const SizedBox(width: FloatingNavBar._iconGap),
                    ],
                    // Flexible so a label that does not fit the width this
                    // destination was given ellipsizes instead of overflowing
                    // the capsule.
                    Flexible(
                      child: AnimatedDefaultTextStyle(
                        duration: duration,
                        curve: Curves.easeOutCubic,
                        style: labelStyle.copyWith(
                          color: selected ? ink : muted,
                        ),
                        child: Text(
                          destination.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
