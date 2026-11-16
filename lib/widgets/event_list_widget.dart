import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../core/format/date_only.dart';
import '../models/festival.dart';
import '../models/panchang_data.dart';
import '../core/feedback/app_haptics.dart';
import '../providers/calendar_provider.dart';
import '../providers/festival_provider.dart';
import '../core/navigation/home_tab.dart';
import '../screens/all_festivals_screen.dart';
import '../core/navigation/app_routes.dart';
import '../theme/app_theme.dart';
import '../theme/app_metrics.dart';
import '../theme/app_motion.dart';
import '../theme/app_typography.dart';
import '../features/event_list/providers/event_providers.dart';
import '../features/sheets/sheet_launcher.dart';
import 'festival_row_tile.dart';
import 'app_card.dart';
import 'inset_row_divider.dart';
import 'skeleton.dart';
import 'state_views.dart';

export '../features/event_list/providers/event_providers.dart'
    show
        UpcomingFestival,
        upcomingFestivalWindowDays,
        upcomingFestivalMaxRows,
        upcomingFestivalsProvider;

/// Home "Festivals & Events" card (redesign): one glass card holding the
/// selected day + next 3 days' festivals — selected day first, upcoming
/// after — with a "View all N festivals" button opening [AllFestivalsScreen].
class EventListWidget extends ConsumerWidget {
  const EventListWidget({super.key, this.onSelectTab});

  /// Selects the mounted Festivals tab when the card lives inside
  /// [HomeShell]. Null keeps the standalone pushed-screen behavior.
  final ValueChanged<HomeTab>? onSelectTab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final upcomingAsync = ref.watch(upcomingFestivalsProvider);
    final totalCount = ref.watch(festivalProvider).length;
    // One selection watch for the card: the range hint and the row
    // highlight both key off it, and the provider above already depends on
    // it, so this adds no extra rebuild.
    final selectedDate = ref.watch(selectedDateProvider);

    return AnimatedSize(
      alignment: Alignment.topCenter,
      duration: AppMotion.of(context, AppMotion.emphasized),
      curve: AppMotion.emphasizedCurve,
      child: AppCard(
        // Tighter bottom edge: the "View all" button already carries 10px
        // of vertical padding, so 6px here balances the 16px top padding
        // instead of stacking dead space below the button.
        //
        // Side padding is the heading gutter minus
        // [AppTheme.homeCardRowInset]: rows carry that inset inside their
        // own wash/highlight, so their content still lines up with the
        // heading while the today wash and press highlight get left/right
        // breathing room instead of hugging the tile and chevron.
        padding: const EdgeInsets.fromLTRB(
          AppTheme.homeCardRowPadding,
          AppSpacing.s16,
          AppTheme.homeCardRowPadding,
          AppSpacing.s6,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _headingInset(
              Text(
                AppLocalizations.of(context)?.festivalsAndEvents ??
                    'Festivals & Events',
                style: AppTypography.display(
                  fontSize: AppTypography.sizeHeading,
                  fontWeight: AppTypography.bold,
                  height: 1.3,
                  color: context.colors.onSurface,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.s2),
            // Range hint: the rows below cover the selected day plus the
            // next 3 days (see upcomingFestivalWindowDays), not the whole
            // calendar.
            _headingInset(
              Text(
                _rangeHint(selectedDate, ref.watch(todayDateProvider)),
                style: context.textTheme.labelSmall?.copyWith(
                  color: context.secondaryInk,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.s12),
            upcomingAsync.when(
              // Date taps reload for the new window; the old rows stay put
              // underneath instead of flashing a skeleton (same pattern as
              // the countdown screen's skipLoadingOnReload).
              skipLoadingOnReload: true,
              data: (items) => _buildRows(context, ref, items, selectedDate),
              loading: () => _buildLoadingSkeleton(context),
              error: (error, _) => _buildErrorBody(context, ref, error),
            ),
            const SizedBox(height: AppSpacing.s4),
            // Same inset as the rows, so the button's ripple keeps the
            // card's side rim.
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.homeCardRowInset,
              ),
              child: _ViewAllButton(
                totalCount: totalCount,
                onSelectTab: onSelectTab,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Card text on the 16dp heading gutter (the card's own side padding plus
  /// the row inset).
  Widget _headingInset(Widget child) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.homeCardRowInset,
      ),
      child: child,
    );
  }

  /// Coverage hint under the title: the rows span the selected day plus
  /// the next 3 days. Names "Today" when the selection is today so the
  /// default view reads naturally; browsed dates say "Selected day".
  String _rangeHint(DateTime selectedDate, DateTime today) {
    if (isSameDay(selectedDate, today)) return 'Today + next 3 days';
    return 'Selected day + next 3 days';
  }

  Widget _buildRows(
    BuildContext context,
    WidgetRef ref,
    List<UpcomingFestival> items,
    DateTime selectedDate,
  ) {
    if (items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.s8,
          horizontal: AppTheme.homeCardRowInset,
        ),
        child: EmptyState(
          icon: Icons.event_available_rounded,
          title:
              AppLocalizations.of(context)?.noFestivalsInNextThreeDays ??
              'No festivals in the next 3 days',
          variant: StateViewVariant.inline,
        ),
      );
    }
    final shown = items.take(upcomingFestivalMaxRows).toList();
    final hidden = items.skip(shown.length).toList();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < shown.length; i++) ...[
          // Rows are flush on the card: no per-row box, just a hairline
          // divider between them (none after the last row).
          if (i > 0)
            const InsetRowDivider(
              leadingInset:
                  FestivalRowTile.textColumnInset + AppTheme.homeCardRowInset,
            ),
          // No per-row entrance: the card's own skeleton → content fade
          // already covers loading, and a row stagger on the home screen
          // delayed the first visible festival after every date tap.
          FestivalRowTile(
            festival: shown[i].festival,
            date: shown[i].date,
            panchang: shown[i].panchang,
            daysAway: shown[i].daysAway,
            flush: true,
            horizontalPadding: AppTheme.homeCardRowInset,
            isSelectedDay: isSameDay(shown[i].date, selectedDate),
            onTap: () => _showFestivalDetail(
              context,
              ref,
              shown[i].festival,
              shown[i].panchang,
            ),
          ),
        ],
        // Truncation used to be silent: beyond the row cap the glance
        // failed without saying what was cut. Name the hidden festivals
        // inline (tap goes to the full list, same as View all below).
        if (hidden.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.s10),
          _OverflowLine(hidden: hidden),
        ],
      ],
    );
  }

  Widget _buildLoadingSkeleton(BuildContext context) {
    return const SkeletonList(count: 2);
  }

  Widget _buildErrorBody(BuildContext context, WidgetRef ref, Object error) {
    // The exception belongs in the log, not in a card: users cannot act on
    // "Exception: ..." and localised copy is the only thing they can read.
    debugPrint('Festival load failed: $error');
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: AppSpacing.s8,
        horizontal: AppTheme.homeCardRowInset,
      ),
      child: ErrorState(
        message:
            AppLocalizations.of(context)?.couldNotLoadFestivals ??
            'Could not load festivals. Please try again.',
        onRetry: () => ref.invalidate(upcomingFestivalsProvider),
        variant: StateViewVariant.inline,
      ),
    );
  }

  void _showFestivalDetail(
    BuildContext context,
    WidgetRef ref,
    Festival festival,
    PanchangData panchang,
  ) {
    showEventDetailSheet(context, festival: festival, panchang: panchang);
  }
}

/// Inline overflow line naming the festivals cut by the home row cap, so a
/// busy window never fails silently. Display only — the View all button
/// right below it owns navigation to the full list.
class _OverflowLine extends StatelessWidget {
  const _OverflowLine({required this.hidden});

  final List<UpcomingFestival> hidden;

  @override
  Widget build(BuildContext context) {
    final gold = AppTheme.festivalAccent(context);
    final names = hidden.map((e) => e.festival.name).join(' • ');
    final label = hidden.length == 1
        ? '+1 more: $names'
        : '+${hidden.length} more: $names';
    return Padding(
      // Card side padding already moved out by `homeCardRowInset`, so keep
      // the overflow line on the same 4dp step past the row content it had
      // before (heading gutter 16 + 4).
      padding: const EdgeInsets.symmetric(
        vertical: AppSpacing.s6,
        horizontal: AppSpacing.s16,
      ),
      child: Text(
        label,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: AppTypography.sizeDetail,
          fontWeight: AppTypography.bold,
          color: gold,
        ),
      ),
    );
  }
}

/// Gold "View all N festivals ›" button pinning the card's bottom edge.
/// Always visible — even with an empty window — since the full list lives
/// behind it.
class _ViewAllButton extends ConsumerWidget {
  const _ViewAllButton({required this.totalCount, this.onSelectTab});

  final int totalCount;
  final ValueChanged<HomeTab>? onSelectTab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gold = AppTheme.festivalAccent(context);
    final l10n = AppLocalizations.of(context);
    final label = totalCount > 0
        ? (l10n?.viewAllFestivalsCount(totalCount) ??
              'View all $totalCount festivals')
        : (l10n?.viewAllFestivals ?? 'View all festivals');
    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.dense),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.dense),
          onTap: () {
            AppHaptics.tap(ref);
            final select = onSelectTab;
            if (select != null) {
              select(HomeTab.festivals);
            } else {
              AppRoutes.pushFadeThrough(context, const AllFestivalsScreen());
            }
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.s10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: AppTypography.sizeProse,
                    fontWeight: AppTypography.bold,
                    color: gold,
                  ),
                ),
                const SizedBox(width: AppSpacing.s4),
                Icon(
                  Icons.chevron_right_rounded,
                  size: AppIconSize.medium,
                  color: gold,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
