import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';

// Canonical icon/label/value row extracted from
// widgets/event_detail_sheet.dart (_buildInfoRow). Positional parameters
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
        Icon(icon, size: 20, color: context.colors.primary),
        const SizedBox(width: 12),
        Text(
          '$label:',
          style: context.textTheme.bodyMedium?.copyWith(
            color: context.colors.onSurface.withValues(alpha: 0.6),
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: context.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: 8), trailing],
      ],
    );
  }
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      children: [
        Icon(icon, color: context.colors.primary, size: 22),
        const SizedBox(width: 12),
        Text(
          '$label:',
          style: context.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: context.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: 8), trailing],
      ],
    ),
  );
}
