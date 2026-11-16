import 'package:material_ui/material_ui.dart';
import 'package:intl/intl.dart';

import '../../../l10n/app_localizations.dart';
import '../../../models/eclipse.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/app_metrics.dart';
import '../../../theme/app_typography.dart';
import '../../../widgets/app_divider.dart';
import '../../../features/sheets/widgets/info_row.dart';

/// Presents the eclipse details bottom sheet.
void showEclipseDetailsSheet(BuildContext context, Eclipse eclipse) {
  final theme = Theme.of(context);
  final l10n = AppLocalizations.of(context)!;
  final isHindi = Localizations.localeOf(context).languageCode == 'hi';

  showModalBottomSheet(
    context: context,
    sheetAnimationStyle: AppTheme.sheetAnimationStyleOf(context),
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) => Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppRadius.card),
        ),
      ),
      padding: const EdgeInsets.all(AppSpacing.s24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(AppRadius.micro),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.s24),

          // Title
          Row(
            children: [
              Text(
                eclipse.type.icon,
                style: const TextStyle(fontSize: AppTypography.sizeHero),
              ),
              const SizedBox(width: AppSpacing.s12),
              Expanded(
                child: Text(
                  isHindi
                      ? eclipse.type.displayNameHi
                      : eclipse.type.displayName,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: AppTypography.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s24),

          // Date and time
          buildInfoRow(
            context,
            Icons.calendar_today,
            l10n.date,
            DateFormat.yMMMMEEEEd().format(eclipse.maxEclipseTime.toLocal()),
            dense: true,
          ),
          const SizedBox(height: AppSpacing.s12),
          buildInfoRow(
            context,
            Icons.access_time,
            l10n.maxEclipse,
            DateFormat.jms().format(eclipse.maxEclipseTime.toLocal()),
            dense: true,
          ),

          // Phase times
          if (eclipse.partialStart != null) ...[
            const SizedBox(height: AppSpacing.s12),
            buildInfoRow(
              context,
              Icons.play_arrow,
              l10n.partialBegins,
              DateFormat.jm().format(eclipse.partialStart!.toLocal()),
              dense: true,
            ),
          ],
          if (eclipse.totalStart != null) ...[
            const SizedBox(height: AppSpacing.s12),
            buildInfoRow(
              context,
              Icons.brightness_7,
              l10n.totalityBegins,
              DateFormat.jm().format(eclipse.totalStart!.toLocal()),
              dense: true,
            ),
          ],
          if (eclipse.totalEnd != null) ...[
            const SizedBox(height: AppSpacing.s12),
            buildInfoRow(
              context,
              Icons.brightness_5,
              l10n.totalityEnds,
              DateFormat.jm().format(eclipse.totalEnd!.toLocal()),
              dense: true,
            ),
          ],
          if (eclipse.partialEnd != null) ...[
            const SizedBox(height: AppSpacing.s12),
            buildInfoRow(
              context,
              Icons.stop,
              l10n.partialEnds,
              DateFormat.jm().format(eclipse.partialEnd!.toLocal()),
              dense: true,
            ),
          ],

          // Duration
          if (eclipse.totalDuration != null) ...[
            const SizedBox(height: AppSpacing.s16),
            const AppDivider(),
            const SizedBox(height: AppSpacing.s16),
            buildInfoRow(
              context,
              Icons.timer,
              l10n.duration,
              _formatDuration(eclipse.totalDuration!),
              dense: true,
            ),
          ],

          // Visibility
          const SizedBox(height: AppSpacing.s16),
          const AppDivider(),
          const SizedBox(height: AppSpacing.s16),
          Row(
            children: [
              Icon(
                eclipse.visibleAtLocation
                    ? Icons.visibility
                    : Icons.visibility_off,
                color: eclipse.visibleAtLocation
                    ? AppTheme.success(theme.brightness == Brightness.dark)
                    : context.hintInk,
              ),
              const SizedBox(width: AppSpacing.s12),
              Expanded(
                child: Text(
                  eclipse.visibleAtLocation
                      ? l10n.visibleFromYourLocation
                      : l10n.notVisibleFromYourLocation,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: eclipse.visibleAtLocation
                        ? AppTheme.success(theme.brightness == Brightness.dark)
                        : context.hintInk,
                    fontWeight: AppTypography.medium,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.s24),
        ],
      ),
    ),
  );
}

String _formatDuration(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes % 60;

  if (hours > 0) {
    return '${hours}h ${minutes}m';
  }
  return '${minutes}m';
}
