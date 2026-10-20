import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/accessibility_provider.dart';
import '../../../theme/app_theme.dart';
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
    final muted = context.colors.onSurface.withValues(alpha: 0.7);

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
              if (ref.read(accessibilityProvider).hapticFeedback) {
                HapticFeedback.lightImpact();
              }
              onTap();
            },
            child: Padding(
              padding: const EdgeInsets.all(14),
              // The composed Semantics label above already carries both
              // lines; excluding the visible Texts avoids announcing them
              // twice.
              child: ExcludeSemantics(
                child: Row(
                  children: [
                    Icon(icon, size: 20, color: ink),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            label,
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w700,
                              color: context.colors.onSurface,
                            ),
                          ),
                          if (supporting != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              supporting!,
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w500,
                                color: muted,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(Icons.chevron_right_rounded, size: 20, color: ink),
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
