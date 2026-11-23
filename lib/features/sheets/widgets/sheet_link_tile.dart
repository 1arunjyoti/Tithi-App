import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/feedback/app_haptics.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/app_metrics.dart';
import '../../../theme/app_typography.dart';
import 'sheet_surface_card.dart';

/// Tappable "go to the other sheet" row in the shared sheet kit.
///
/// Both detail sheets link to each other with the same affordance: a
/// surface card (same fill/radius as [SheetSurfaceCard]) holding an icon,
/// a bold label, an optional supporting line and a trailing chevron.
/// Keeping it here means tap target, semantics, haptics and high-contrast
/// behavior cannot drift between the two directions.
class SheetLinkTile extends ConsumerWidget {
  const SheetLinkTile({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.supporting,
    this.accent,
  });

  /// Leading glyph (contextual: calendar, celebration, …).
  final IconData icon;

  /// Bold action label, e.g. "View full panchang".
  final String label;

  /// Optional second line (typically the date the link opens).
  final String? supporting;

  /// Defaults to the theme primary; callers may pass the festival accent.
  final Color? accent;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ink = accent ?? context.colors.primary;
    final muted = context.secondaryInk;

    return Semantics(
      button: true,
      label: supporting == null ? label : '$label. $supporting',
      child: SheetSurfaceCard(
        padding: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              AppHaptics.tap(ref);
              onTap();
            },
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.s14),
              // The composed Semantics label above already carries both
              // lines; excluding the visible Texts avoids announcing them
              // twice.
              child: ExcludeSemantics(
                child: Row(
                  children: [
                    Icon(icon, size: AppIconSize.medium, color: ink),
                    const SizedBox(width: AppSpacing.s12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            label,
                            style: TextStyle(
                              fontSize: AppTypography.sizeBody,
                              fontWeight: AppTypography.bold,
                              color: context.colors.onSurface,
                            ),
                          ),
                          if (supporting != null) ...[
                            const SizedBox(height: AppSpacing.s2),
                            Text(
                              supporting!,
                              style: TextStyle(
                                fontSize: AppTypography.sizeCaption,
                                fontWeight: AppTypography.medium,
                                color: muted,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.s8),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: AppIconSize.medium,
                      color: ink,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
