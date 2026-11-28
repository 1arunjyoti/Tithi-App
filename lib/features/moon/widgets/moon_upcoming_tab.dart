import 'package:material_ui/material_ui.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../l10n/app_localizations.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/app_metrics.dart';
import '../../../theme/app_typography.dart';
import '../../../widgets/state_views.dart';

/// Chronological list of upcoming Purnima or Amavasya instants.
class MoonUpcomingTab extends ConsumerWidget {
  const MoonUpcomingTab({
    super.key,
    required this.provider,
    required this.emptyMessage,
    required this.isDark,
  });

  final FutureProvider<List<DateTime>> provider;
  final String emptyMessage;
  final bool isDark;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final datesAsync = ref.watch(provider);
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return datesAsync.when(
      data: (dates) {
        if (dates.isEmpty) {
          return EmptyState(
            icon: Icons.calendar_month_outlined,
            title: emptyMessage,
          );
        }
        return ListView.separated(
          padding: EdgeInsets.fromLTRB(
            AppTheme.pageGutter,
            0,
            AppTheme.pageGutter,
            AppSpacing.s8 + AppTheme.navigationBarInset(context),
          ),
          itemCount: dates.length,
          separatorBuilder: (_, _) => const SizedBox(height: AppTheme.cardGap),
          itemBuilder: (context, index) {
            final date = dates[index];
            final daysUntil = date.difference(DateTime.now()).inDays;
            return Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.s16,
                vertical: AppSpacing.s12,
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppTheme.cardRadiusCompact),
                color: isDark
                    ? AppTheme.spaceStar.withValues(alpha: 0.05)
                    : AppTheme.spaceStar.withValues(alpha: 0.6),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          DateFormat.yMMMMEEEEd().format(date),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurface,
                            fontWeight: AppTypography.semibold,
                          ),
                        ),
                        Text(
                          DateFormat.jm().format(date),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.72,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.s12,
                      vertical: AppSpacing.s6,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppRadius.tile),
                      color:
                          (isDark
                                  ? AppTheme.moonGlowDark
                                  : AppTheme.moonGlowLight)
                              .withValues(alpha: 0.3),
                    ),
                    child: Text(
                      daysUntil == 0
                          ? l10n.today
                          : daysUntil == 1
                          ? l10n.tomorrow
                          : l10n.daysFromNow(daysUntil),
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: AppTypography.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
      loading: () => const Center(child: M3EProgressIndicator.circular()),
      error: (error, _) {
        debugPrint('Moon phase dates failed: $error');
        return ErrorState(
          message: l10n.unexpectedErrorOccurred,
          onRetry: () => ref.invalidate(provider),
        );
      },
    );
  }
}
