import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';

// Canonical hero-style sun pill extracted from
// widgets/tithi_detail_sheet.dart (_SheetChip, finalized design): same
// treatment as the home hero chips — hero-foreground ink on the gradient,
// primary tint in high contrast.
//
// [onSurface] swaps the gradient inks for the sheet-body treatment (the
// same card fill as the sheet's timing cards + primary icon), for callers
// that place chip rows *below* the hero header, on the scaffold surface.
//
// [centerContent] centers the icon + label group inside the pill, for
// chips stretched to a grid cell (the tithi sheet's anchor row) so the
// pair does not hug the left edge with dead space on the right.
class SheetChip extends StatelessWidget {
  const SheetChip({
    super.key,
    required this.icon,
    required this.text,
    required this.highContrast,
    this.onSurface = false,
    this.centerContent = false,
  });

  final IconData icon;
  final String text;
  final bool highContrast;
  final bool onSurface;
  final bool centerContent;

  @override
  Widget build(BuildContext context) {
    final Color textColor;
    final Color iconColor;
    final Color background;
    final Color borderColor;
    if (onSurface) {
      textColor = context.colors.onSurface;
      iconColor = context.colors.primary;
      // Same fill as the sheet's cards (timings, nakshatra, yoga/karana,
      // auspicious, inauspicious), so the chips read as the same surface
      // family; the hairline keeps the pill defined on the scaffold.
      background =
          Theme.of(context).cardTheme.color ?? context.colors.surface;
      borderColor = AppTheme.sheetHairline(
        context,
        highContrast: highContrast,
      );
    } else {
      final ink = highContrast
          ? context.colors.primary
          : AppTheme.heroForeground(context);
      textColor = highContrast ? context.colors.onSurface : ink;
      iconColor = ink;
      background = highContrast
          ? context.colors.primary.withValues(alpha: 0.1)
          : AppTheme.heroChipBackground(context);
      borderColor = highContrast
          ? context.colors.primary.withValues(alpha: 0.2)
          : AppTheme.heroChipBorder(context);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: centerContent
            ? MainAxisAlignment.center
            : MainAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: iconColor),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              textAlign: centerContent ? TextAlign.center : null,
              style: TextStyle(
                fontSize: 12,
                color: textColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
