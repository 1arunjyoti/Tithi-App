import 'package:material_ui/material_ui.dart';

import '../../../theme/app_theme.dart';
import '../../../theme/app_metrics.dart';
import '../../../theme/app_typography.dart';

// Canonical icon/label/value row extracted from the former
// widgets/event_detail_sheet.dart monolith (_buildInfoRow). Positional parameters
// mirror the original method signature so existing call sites move
// unchanged.
//
// [dense] selects the compact eclipse-screen dialect (no vertical padding,
// value pushed right with a Spacer instead of Expanded): same information,
// tighter rows for data-dense screens.
Widget buildInfoRow(
  BuildContext context,
  IconData icon,
  String label,
  String value, {
  Widget? trailing,
  bool dense = false,
}) {
  if (dense) {
    return Row(
      children: [
        Icon(icon, size: AppIconSize.medium, color: context.colors.primary),
        const SizedBox(width: AppSpacing.s12),
        Text(
          '$label:',
          style: context.textTheme.bodyMedium?.copyWith(
            color: context.secondaryInk,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: context.textTheme.bodyMedium?.copyWith(
            fontWeight: AppTypography.semibold,
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: AppSpacing.s8),
          trailing,
        ],
      ],
    );
  }
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: AppSpacing.s8),
    child: Row(
      children: [
        Icon(icon, color: context.colors.primary, size: AppIconSize.large),
        const SizedBox(width: AppSpacing.s12),
        Text(
          '$label:',
          style: context.textTheme.bodyMedium?.copyWith(
            fontWeight: AppTypography.medium,
          ),
        ),
        const SizedBox(width: AppSpacing.s8),
        Expanded(
          child: Text(
            value,
            style: context.textTheme.bodyLarge?.copyWith(
              fontWeight: AppTypography.semibold,
            ),
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: AppSpacing.s8),
          trailing,
        ],
      ],
    ),
  );
}
