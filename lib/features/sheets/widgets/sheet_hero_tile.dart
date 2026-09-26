import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';

// Canonical 46pt hero icon tile shared by the tithi detail sheet (moon
// tile) and the festival event sheet (festival icon tile): 14pt radius,
// hero-chip fill/border (primary tint in high contrast), centered [child].
class SheetHeroTile extends StatelessWidget {
  const SheetHeroTile({
    super.key,
    required this.highContrast,
    required this.child,
  });

  final bool highContrast;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: highContrast
            ? context.colors.primary.withValues(alpha: 0.1)
            : AppTheme.heroChipBackground(context),
        border: Border.all(
          color: highContrast
              ? context.colors.primary.withValues(alpha: 0.2)
              : AppTheme.heroChipBorder(context),
        ),
      ),
      alignment: Alignment.center,
      child: child,
    );
  }
}
