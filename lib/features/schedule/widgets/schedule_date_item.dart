import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../models/panchang_data.dart';
import '../../../providers/calendar_provider.dart' as cp;
import '../../../theme/app_metrics.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/app_typography.dart';
import '../../../utils/tithi_localization.dart';
import '../domain/schedule_date_column.dart';
import '../providers/schedule_providers.dart';
import 'schedule_day_content.dart';

/// One day row in the schedule view: the date column on the left, a divider,
/// then the day's panchang summary / sun times / festival cards.
///
/// Owns the per-day async states, so a slow day never blanks its neighbours.
class ScheduleDateItem extends ConsumerWidget {
  const ScheduleDateItem({
    super.key,
    required this.date,
    required this.isToday,
  });

  final DateTime date;
  final bool isToday;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dateDataAsync = ref.watch(scheduleDateDataProvider(date));

    return dateDataAsync.when(
      data: (dateData) => _buildDateRow(context, dateData),
      loading: () => _buildLoadingRow(context),
      error: (error, _) => _buildErrorRow(context, error),
    );
  }

  Widget _buildDateRow(BuildContext context, ScheduleDateData dateData) {
    final panchang = dateData.panchang;
    // Cached formatters via the shared helper: constructing three
    // DateFormats per row per build janks scrolling (dozens of rows), and
    // the helper also honors the UI locale (these were English-only).
    final locale = Localizations.localeOf(context).languageCode;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.s8),
      decoration: isToday
          ? BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.tile),
              border: Border.all(
                color: context.colors.primary.withValues(alpha: 0.5),
                width: 2,
              ),
            )
          : null,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date Column (Left side)
            _DateColumn(
              gregorianMonth: formatLocalizedDate(
                date,
                'MMM',
                locale,
              ).toUpperCase(),
              gregorianDay: formatLocalizedDate(date, 'd', locale),
              weekday: formatLocalizedDate(date, 'EEE', locale),
              panchang: panchang,
              bengaliDate: dateData.bengaliDate,
              hinduDate: dateData.hinduDate,
              isToday: isToday,
            ),

            // Vertical divider
            Container(
              width: 1,
              color: context.colors.onSurface.withValues(alpha: 0.1),
              margin: const EdgeInsets.symmetric(vertical: AppSpacing.s8),
            ),

            // Events Column (Right side)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.s12),
                child: ScheduleDayContent(panchang: panchang),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingRow(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.s8),
      padding: const EdgeInsets.all(AppSpacing.s16),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: context.colors.onSurface.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppRadius.chip),
            ),
          ),
          const SizedBox(width: AppSpacing.s16),
          Expanded(
            child: Container(
              height: 40,
              decoration: BoxDecoration(
                color: context.colors.onSurface.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppRadius.chip),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorRow(BuildContext context, Object error) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.s8),
      padding: const EdgeInsets.all(AppSpacing.s16),
      child: Text(
        'Error: $error',
        style: TextStyle(color: context.colors.error),
      ),
    );
  }
}

/// Left-hand date column: primary month stem, big day numeral, weekday and an
/// optional secondary-calendar chip.
///
/// The whole system resolution lives in [ScheduleDateColumnView.resolve]; this
/// widget only watches the settings and renders the result.
class _DateColumn extends ConsumerWidget {
  const _DateColumn({
    required this.gregorianMonth,
    required this.gregorianDay,
    required this.weekday,
    required this.panchang,
    required this.bengaliDate,
    required this.hinduDate,
    required this.isToday,
  });

  final String gregorianMonth;
  final String gregorianDay;
  final String weekday;
  final PanchangData panchang;
  final ({int day, String month, int year})? bengaliDate;
  final HinduDateData? hinduDate;
  final bool isToday;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final view = ScheduleDateColumnView.resolve(
      primarySystem: ref.watch(cp.primaryCalendarSystemProvider),
      secondarySystem: ref.watch(cp.secondaryCalendarSystemProvider),
      // Display settings for the panchang-data fallback below (Amanta values
      // converted at render; Shukla days are identical in both systems).
      monthSystem: ref.watch(cp.hinduMonthSystemProvider),
      tithiMode: ref.watch(cp.tithiDisplayModeProvider),
      panchang: panchang,
      gregorianMonth: gregorianMonth,
      gregorianDay: gregorianDay,
      bengaliDate: bengaliDate,
      hinduDate: hinduDate,
    );

    return Container(
      width: view.hasSecondary ? 75 : 60,
      padding: const EdgeInsets.symmetric(
        vertical: AppSpacing.s12,
        horizontal: AppSpacing.s8,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            view.month,
            style: context.textTheme.labelSmall?.copyWith(
              color: isToday ? context.colors.primary : context.secondaryInk,
              fontWeight: AppTypography.semibold,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: AppSpacing.s2),
          Text(
            view.day,
            style: context.textTheme.headlineMedium?.copyWith(
              color: isToday
                  ? context.colors.primary
                  : context.colors.onSurface,
              fontWeight: AppTypography.bold,
              fontSize: AppTypography.sizeDisplay,
            ),
          ),
          const SizedBox(height: AppSpacing.s2),
          Text(
            weekday,
            style: context.textTheme.labelSmall?.copyWith(
              color: isToday ? context.colors.primary : context.hintInk,
            ),
          ),
          // Secondary calendar info
          if (view.secondary case final secondary?) ...[
            const SizedBox(height: AppSpacing.s4),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.s4,
                vertical: AppSpacing.s2,
              ),
              decoration: BoxDecoration(
                color: context.colors.secondary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppRadius.small),
              ),
              child: Text(
                secondary,
                style: context.textTheme.labelSmall?.copyWith(
                  color: context.colors.secondary,
                  fontSize: AppTypography.sizeMicro,
                  fontWeight: AppTypography.medium,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
