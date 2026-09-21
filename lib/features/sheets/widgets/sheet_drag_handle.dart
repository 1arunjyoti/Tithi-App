import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';

// Canonical drag handle extracted from widgets/tithi_detail_sheet.dart
// (finalized design). The taller transparent zone makes the framework
// drag-to-dismiss target easier to grab; visuals unchanged (pill stays
// centered).
class SheetDragHandle extends StatelessWidget {
  const SheetDragHandle({super.key, required this.highContrast});

  final bool highContrast;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 32,
      alignment: Alignment.center,
      child: Container(
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: highContrast
              ? context.colors.onSurface.withValues(alpha: 0.35)
              : AppTheme.heroForeground(context).withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}
