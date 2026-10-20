import 'package:flutter/material.dart';

import '../../../core/anim/press_scale.dart';
import '../../../theme/app_theme.dart';

// Pill chip shared by the hero's transition / sunrise / sunset / city rows.
// Moved verbatim from widgets/paksha_hero_card.dart (_HeroChip).
//
// Bold hero-foreground ink on the gradient (brown on light Shukla, white
// on dark); theme primary on surface in high-contrast mode. [highlight]
// renders a middle segment (e.g. the next tithi name) in the themed accent
// color: hero accent on the gradient, primary in high-contrast mode.
class HeroChip extends StatelessWidget {
  const HeroChip({
    super.key,
    required this.icon,
    required this.text,
    this.highlight,
    this.suffix,
    this.inlineIcon = false,
    this.wrap = false,
    this.fontWeight,
    this.fontSize,
    this.onTap,
    this.hint,
    required this.highContrast,
  });

  final IconData icon;
  final String text;
  final String? highlight;
  final String? suffix;

  /// When true the icon renders inline after [text] (e.g. between the label
  /// and the highlighted tithi) instead of leading the chip.
  final bool inlineIcon;

  /// When true the label wraps onto multiple lines instead of ellipsizing.
  ///
  /// Default single-line ellipsis suits narrow, capped chips (the header's
  /// location pill). Transition chips share their column with the festival
  /// artwork and can run long ("Next tithi: Chaturdashi at 11:02 PM"), so they
  /// opt in and wrap rather than truncate.
  final bool wrap;

  /// Overrides the label weight (base and highlight alike). Defaults to bold
  /// on the gradient, medium in high-contrast mode.
  final FontWeight? fontWeight;

  /// Overrides the label size. Defaults to 12.
  final double? fontSize;

  /// Makes the chip a button. The tap wins over an enclosing card's ink well,
  /// so a tappable pill inside a tappable hero opens its own destination.
  final VoidCallback? onTap;

  /// Screen-reader hint for [onTap] (what the chip opens). Ignored when the
  /// chip is not tappable.
  final String? hint;
  final bool highContrast;

  @override
  Widget build(BuildContext context) {
    final accent = highContrast
        ? context.colors.primary
        : AppTheme.heroAccent(context);
    final baseColor = highContrast
        ? context.colors.onSurface
        : AppTheme.heroForeground(context);
    final iconColor = highContrast ? accent : AppTheme.heroForeground(context);
    final weight =
        fontWeight ?? (highContrast ? FontWeight.w500 : FontWeight.bold);

    final pill = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: highContrast
            ? context.colors.primary.withValues(alpha: 0.1)
            : AppTheme.heroChipBackground(context),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: highContrast
              ? context.colors.primary.withValues(alpha: 0.2)
              : AppTheme.heroChipBorder(context),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!inlineIcon) Icon(icon, size: 14, color: iconColor),
          if (!inlineIcon) const SizedBox(width: 6),
          Flexible(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: text),
                  if (inlineIcon)
                    WidgetSpan(
                      alignment: PlaceholderAlignment.middle,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Icon(icon, size: 14, color: iconColor),
                      ),
                    ),
                  if (highlight != null)
                    TextSpan(
                      text: highlight,
                      style: TextStyle(color: accent, fontWeight: weight),
                    ),
                  if (suffix != null) TextSpan(text: suffix),
                ],
              ),
              style: TextStyle(
                fontSize: fontSize ?? 12,
                color: baseColor,
                fontWeight: weight,
              ),
              overflow: wrap ? TextOverflow.clip : TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );

    final onTap = this.onTap;
    if (onTap == null) return pill;

    // Listener-based PressScale (no arena entry) + its own GestureDetector:
    // the pill's tap wins the arena over the enclosing card's InkWell, so a
    // location pill inside a tappable hero opens the picker instead of the
    // detail sheet. Press fill rides above the pill, so the translucent chip
    // background doesn't swallow it.
    return Semantics(
      // Own node: without it the hint/button flag would merge into the
      // enclosing hero card's node (which is also a button).
      container: true,
      button: true,
      hint: hint,
      child: PressScale(
        highlightColor: highContrast
            ? context.colors.primary.withValues(alpha: 0.12)
            : Colors.white.withValues(alpha: 0.18),
        highlightRadius: BorderRadius.circular(999),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: pill,
        ),
      ),
    );
  }
}
