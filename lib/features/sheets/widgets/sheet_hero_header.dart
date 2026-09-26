import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';
import 'sheet_drag_handle.dart';

// Canonical hero-gradient sheet header shared by the tithi detail sheet
// and the festival event sheet: same gradient/ink treatment as
// [AppTheme.heroSheetHeaderDecoration] (flush top-32 radius, glow backdrop),
// with the shared drag handle on top and the caller-supplied [child]
// (date line + title row + chips) below it.
class SheetHeroHeader extends StatelessWidget {
  const SheetHeroHeader({
    super.key,
    required this.highContrast,
    required this.child,
  });

  final bool highContrast;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: AppTheme.heroSheetHeaderDecoration(
        context,
        highContrast: highContrast,
      ),
      child: Stack(
        children: [
          if (!highContrast)
            Positioned.fill(
              child: Container(
                decoration: AppTheme.heroGlowBackdrop(context),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Drag handle (a downward drag here overscrolls the scroll
                // view at offset zero and dismisses via EdgeDismiss above).
                SheetDragHandle(highContrast: highContrast),
                child,
              ],
            ),
          ),
        ],
      ),
    );
  }
}
