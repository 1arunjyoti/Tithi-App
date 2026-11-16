import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';
import '../../../theme/app_metrics.dart';
import '../../../theme/app_typography.dart';

// Canonical gray explainer card shared by the tithi detail sheet (udaya
// explanation) and the festival event sheet (timing note): dim info icon
// + 12.5pt dim text on a 5%-alpha onSurface fill, 12pt radius.
class SheetExplainerCard extends StatelessWidget {
  const SheetExplainerCard({super.key, required this.text, this.icon});

  final String text;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final highContrast = AppTheme.highContrastOf(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.s12),
      decoration: BoxDecoration(
        color: context.colors.onSurface.withValues(
          alpha: highContrast ? 0.1 : 0.05,
        ),
        borderRadius: BorderRadius.circular(AppRadius.dense),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon ?? Icons.info_outline,
            size: AppIconSize.dense,
            color: context.hintInk,
          ),
          const SizedBox(width: AppSpacing.s8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: AppTypography.sizeCaption,
                color: context.secondaryInk,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
