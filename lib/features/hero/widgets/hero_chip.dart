import 'package:flutter/material.dart';

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
    this.fontWeight,
    this.fontSize,
    required this.highContrast,
  });

  final IconData icon;
  final String text;
  final String? highlight;
  final String? suffix;

  /// When true the icon renders inline after [text] (e.g. between the label
  /// and the highlighted tithi) instead of leading the chip.
  final bool inlineIcon;

  /// Overrides the label weight (base and highlight alike). Defaults to bold
  /// on the gradient, medium in high-contrast mode.
  final FontWeight? fontWeight;

  /// Overrides the label size. Defaults to 12.
  final double? fontSize;
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

    return Container(
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
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
