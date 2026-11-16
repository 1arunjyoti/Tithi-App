import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../l10n/app_localizations.dart';
import '../../../models/eclipse.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/app_metrics.dart';
import '../../../theme/app_typography.dart';
import '../../../widgets/app_card.dart';
import 'eclipse_details_sheet.dart';

/// One eclipse in a standard page card. Tap opens the details sheet.
class EclipseCard extends ConsumerWidget {
  const EclipseCard({super.key, required this.eclipse});

  final Eclipse eclipse;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final isHindi = Localizations.localeOf(context).languageCode == 'hi';

    // Use theme-based colors for eclipse types
    final typeColor = eclipse.type.isSolar
        ? theme.colorScheme.primary
        : theme.colorScheme.secondary;

    final typeName = isHindi
        ? eclipse.type.displayNameHi
        : eclipse.type.displayName;
    final dateText = DateFormat.yMMMEd().format(
      eclipse.maxEclipseTime.toLocal(),
    );
    final timeText =
        '${l10n.maxEclipse}: '
        '${DateFormat.jm().format(eclipse.maxEclipseTime.toLocal())}';
    final daysText = eclipse.daysUntil == 0
        ? l10n.today
        : '${eclipse.daysUntil} ${l10n.days}';
    final magnitudeText = eclipse.localMagnitude == null
        ? null
        : '${(eclipse.localMagnitude! * 100).toStringAsFixed(0)}%';

    // One composed label instead of the card's separate Text nodes (which
    // otherwise announce as five disconnected stops), matching the home
    // festival rows' convention. [AppCard] owns the semantics node and the
    // tap action; the visual text is excluded.
    final semanticsLabel = [
      typeName,
      if (eclipse.daysUntil >= 0) daysText,
      dateText,
      timeText,
      if (eclipse.visibleAtLocation) ...[
        l10n.visibleFromYourLocation,
        ?magnitudeText,
      ],
    ].join('. ');

    return RepaintBoundary(
      child: AppCard(
        // The type colour stays on the badge; the card keeps the neutral
        // hairline like every other page card (an accent edge is the
        // featured treatment, and not every eclipse is "featured").
        onTap: () => showEclipseDetailsSheet(context, eclipse),
        semanticLabel: semanticsLabel,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Type and date row
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Eclipse type badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.s10,
                    vertical: AppSpacing.s6,
                  ),
                  decoration: BoxDecoration(
                    color: typeColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(AppRadius.chip),
                  ),
                  child: Text(
                    typeName,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: typeColor,
                      fontWeight: AppTypography.bold,
                    ),
                  ),
                ),
                const Spacer(),
                // Days until
                if (eclipse.daysUntil >= 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.s8,
                      vertical: AppSpacing.s4,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppRadius.dense),
                    ),
                    child: Text(
                      daysText,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: AppTypography.medium,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.s12),

            // Date and time
            Row(
              children: [
                Icon(
                  Icons.calendar_today,
                  size: AppIconSize.small,
                  color: context.secondaryInk,
                ),
                const SizedBox(width: AppSpacing.s8),
                Text(
                  dateText,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: AppTypography.semibold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.s4),
            Row(
              children: [
                Icon(
                  Icons.access_time,
                  size: AppIconSize.small,
                  color: context.secondaryInk,
                ),
                const SizedBox(width: AppSpacing.s8),
                Text(
                  timeText,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: context.secondaryInk,
                  ),
                ),
              ],
            ),

            // Visibility indicator
            if (eclipse.visibleAtLocation) ...[
              const SizedBox(height: AppSpacing.s12),
              Row(
                children: [
                  Icon(
                    Icons.visibility,
                    size: AppIconSize.small,
                    color: AppTheme.success(
                      theme.brightness == Brightness.dark,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s8),
                  Text(
                    l10n.visibleFromYourLocation,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppTheme.success(
                        theme.brightness == Brightness.dark,
                      ),
                      fontWeight: AppTypography.medium,
                    ),
                  ),
                  if (magnitudeText != null) ...[
                    const SizedBox(width: AppSpacing.s8),
                    Text(
                      '($magnitudeText)',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppTheme.success(
                          theme.brightness == Brightness.dark,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
