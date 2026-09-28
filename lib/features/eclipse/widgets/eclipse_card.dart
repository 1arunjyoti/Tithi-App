import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../l10n/app_localizations.dart';
import '../../../core/anim/press_scale.dart';
import '../../../models/eclipse.dart';
import '../../../theme/app_theme.dart';
import 'eclipse_details_sheet.dart';

/// One eclipse in a glass card. Tap opens the details sheet.
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

    return RepaintBoundary(
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: AppTheme.glassmorphism(
          context: context,
          ref: ref,
          borderRadius: 16,
          border: Border.all(color: typeColor.withValues(alpha: 0.3)),
        ),
        child: Material(
        color: Colors.transparent,
        // Haptic only: pressedScale 1.0 disables the dip while keeping
        // the gated buzz (cards already stagger in; scale felt noisy).
        child: PressScale(
          pressedScale: 1.0,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => showEclipseDetailsSheet(context, eclipse),
          child: Padding(
            padding: const EdgeInsets.all(16),
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
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: typeColor.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        isHindi
                            ? eclipse.type.displayNameHi
                            : eclipse.type.displayName,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: typeColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const Spacer(),
                    // Days until
                    if (eclipse.daysUntil >= 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.1,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          eclipse.daysUntil == 0
                              ? l10n.today
                              : '${eclipse.daysUntil} ${l10n.days}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),

                // Date and time
                Row(
                  children: [
                    Icon(
                      Icons.calendar_today,
                      size: 16,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      DateFormat.yMMMEd().format(
                        eclipse.maxEclipseTime.toLocal(),
                      ),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.access_time,
                      size: 16,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${l10n.maxEclipse}: ${DateFormat.jm().format(eclipse.maxEclipseTime.toLocal())}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.7,
                        ),
                      ),
                    ),
                  ],
                ),

                // Visibility indicator
                if (eclipse.visibleAtLocation) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(
                        Icons.visibility,
                        size: 16,
                        color: AppTheme.success(
                          theme.brightness == Brightness.dark,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        l10n.visibleFromYourLocation,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppTheme.success(
                            theme.brightness == Brightness.dark,
                          ),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (eclipse.localMagnitude != null) ...[
                        const SizedBox(width: 8),
                        Text(
                          '(${(eclipse.localMagnitude! * 100).toStringAsFixed(0)}%)',
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
        ),
        ),
      ),
      ),
    );
}
}
