import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../core/format/date_only.dart';
import '../models/festival.dart';
import '../models/panchang_data.dart';
import '../providers/accessibility_provider.dart';
import '../providers/calendar_provider.dart';
import '../providers/festival_provider.dart';
import '../screens/all_festivals_screen.dart';
import '../core/navigation/app_routes.dart';
import '../theme/app_theme.dart';
import '../features/event_list/providers/event_providers.dart';
import '../features/sheets/sheet_launcher.dart';
import 'festival_row_tile.dart';

export '../features/event_list/providers/event_providers.dart'
    show
        UpcomingFestival,
        upcomingFestivalWindowDays,
        upcomingFestivalMaxRows,
        upcomingFestivalsProvider;

/// Home "Festivals & Events" card (redesign): one glass card holding the
/// selected day + next 3 days' festivals — selected day first, upcoming
/// after — with a "View all N festivals" button pushing [AllFestivalsScreen].
class EventListWidget extends ConsumerWidget {
  const EventListWidget({super.key});

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
      duration: AppTheme.animationDuration(
        context,
        const Duration(milliseconds: 250),
      ),
      curve: Curves.easeInOutCubic,
      child: Container(
        width: double.infinity,
        // Tighter bottom edge: the "View all" button already carries 10px
        // of vertical padding, so 6px here balances the 16px top padding
        // instead of stacking dead space below the button.
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
        decoration: AppTheme.glassmorphism(context: context, ref: ref),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              AppLocalizations.of(context)?.festivalsAndEvents ??
                  'Festivals & Events',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w700,
                color: context.colors.onSurface,
              ),
            ),
            const SizedBox(height: 2),
            // Range hint: the rows below cover the selected day plus the
            // next 3 days (see upcomingFestivalWindowDays), not the whole
            // calendar.
            Text(
              _rangeHint(selectedDate, ref.watch(todayDateProvider)),
              style: context.textTheme.labelSmall?.copyWith(
                color: context.colors.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 12),
            upcomingAsync.when(
              // Date taps reload for the new window; the old rows stay put
              // underneath instead of flashing a skeleton (same pattern as
              // the countdown screen's skipLoadingOnReload).
              skipLoadingOnReload: true,
              data: (items) => _buildRows(context, ref, items, selectedDate),
              loading: () => _buildLoadingSkeleton(context),
              error: (error, _) => _buildErrorBody(context, error),
            ),
            const SizedBox(height: 4),
            _ViewAllButton(totalCount: totalCount),
          ],
        ),
      ),
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
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Icon(
              Icons.event_available_rounded,
              size: 20,
              color: context.colors.onSurface.withValues(alpha: 0.4),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                AppLocalizations.of(context)?.noFestivalsInNextThreeDays ??
                    'No festivals in the next 3 days',
                style: TextStyle(
                  fontSize: 13.5,
                  color: context.colors.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ),
          ],
        ),
      );
    }
    final shown = items.take(upcomingFestivalMaxRows).toList();
    final hidden = items.skip(shown.length).toList();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < shown.length; i++) ...[
          if (i > 0) const SizedBox(height: 10),
          // No per-row entrance: the card's own skeleton → content fade
          // already covers loading, and a row stagger on the home screen
          // delayed the first visible festival after every date tap.
          FestivalRowTile(
            festival: shown[i].festival,
            date: shown[i].date,
            panchang: shown[i].panchang,
            daysAway: shown[i].daysAway,
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
          const SizedBox(height: 10),
          _OverflowLine(hidden: hidden),
        ],
      ],
    );
  }

  Widget _buildLoadingSkeleton(BuildContext context) {
    final placeholder = context.colors.onSurface.withValues(alpha: 0.06);
    Widget row() {
      return Container(
        height: 76,
        decoration: BoxDecoration(
          color: placeholder,
          borderRadius: BorderRadius.circular(16),
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [row(), const SizedBox(height: 10), row()],
    );
  }

  Widget _buildErrorBody(BuildContext context, Object error) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        AppLocalizations.of(context)?.couldNotLoadFestivalsWithError(
              error.toString(),
            ) ??
            'Could not load festivals: $error',
        style: TextStyle(
          fontSize: 13.5,
          color: context.colors.onSurface.withValues(alpha: 0.6),
        ),
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
    final label = hidden.length == 1 ? '+1 more: $names' : '+${hidden.length} more: $names';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      child: Text(
        label,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 13.5,
          fontWeight: FontWeight.w700,
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
  const _ViewAllButton({required this.totalCount});

  final int totalCount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gold = AppTheme.festivalAccent(context);
    final l10n = AppLocalizations.of(context);
    final label = totalCount > 0
        ? (l10n?.viewAllFestivalsCount(totalCount) ?? 'View all $totalCount festivals')
        : (l10n?.viewAllFestivals ?? 'View all festivals');
    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            if (ref.read(accessibilityProvider).hapticFeedback) {
              HapticFeedback.lightImpact();
            }
            // Fade through (not shared-X slide): the pop back to home
            // fades instead of sliding out over the home card.
            AppRoutes.pushFadeThrough(context, const AllFestivalsScreen());
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: gold,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(Icons.chevron_right_rounded, size: 20, color: gold),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
