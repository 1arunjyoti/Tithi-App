import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';

// Canonical hero-style sun pill extracted from
// widgets/tithi_detail_sheet.dart (_SheetChip, finalized design): same
// treatment as the home hero chips — hero-foreground ink on the gradient,
// primary tint in high contrast.
class SheetChip extends StatelessWidget {
  const SheetChip({
    super.key,
    required this.icon,
    required this.text,
    required this.highContrast,
  });

  final IconData icon;
  final String text;
  final bool highContrast;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
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
          Icon(
            icon,
            size: 14,
            color: highContrast
                ? context.colors.primary
                : AppTheme.heroForeground(context),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12,
                color: highContrast
                    ? context.colors.onSurface
                    : AppTheme.heroForeground(context),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
