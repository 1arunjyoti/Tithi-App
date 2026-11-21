import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/panchang_data.dart';
import '../../../providers/calendar_provider.dart' as cp;
import '../../../providers/panchang_provider.dart';
import '../../../theme/app_metrics.dart';
import '../../../theme/app_motion.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/app_card.dart';
import '../data/adaptive_grid_state.dart';
import '../data/calendar_caches.dart';
import '../data/calendar_models.dart';
import '../domain/calendar_precache.dart';
import '../domain/month_navigation_controller.dart';
import '../providers/cell_providers.dart';
import 'adaptive_calendar_grid.dart';
import 'calendar_header.dart';
import 'calendar_year_picker.dart';
import 'gregorian_calendar_grid.dart';

/// Calendar widget using TableCalendar with Tithi markers.
class CalendarWidget extends ConsumerWidget {
  const CalendarWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedDate = ref.watch(cp.selectedDateProvider);
    // Hoisted: previously DateTime.now() was evaluated per cell (~42× per
    // build, plus once per marker), pinning "today" mid-build instead.
    final today = DateTime.now();
    final focusedMonth = ref.watch(cp.focusedMonthProvider);
    final startOfWeek = ref.watch(cp.startOfWeekProvider);
    final primarySystem = ref.watch(cp.primaryCalendarSystemProvider);
    final secondarySystem = ref.watch(cp.secondaryCalendarSystemProvider);
    final displayMode = ref.watch(cp.tithiDisplayModeProvider);

    // Heavy data follows heavyMonthProvider, which trails focusedMonth by
    // ~220ms after swipes so FFI never runs during the page animation.
    // focusedMonth itself (TableCalendar position + header) updates instantly
    // at mid-screen cross, keeping the header flip cheap and in sync.
    final heavyMonth = ref.watch(cp.heavyFocusedMonthProvider);
    // Pre-load entire month's panchang data to eliminate N+1 query pattern.
    // Month-normalized key: monthlyPanchangProvider ignores the day for its
    // range, so normalizing guarantees the precached next/prev months hit
    // the same provider instance after onPageChanged (TableCalendar may
    // report any day as the new focusedDay).
    final isAdaptive =
        primarySystem == cp.AppCalendarSystem.bengali ||
        primarySystem == cp.AppCalendarSystem.hindu;

    final monthKey = normalizeMonthKey(heavyMonth);
    // Gregorian-only data: on the adaptive path these two providers burn a
    // full extra month of FFI (~30 dates × native calls each) whose results
    // the lunar grid never reads. Skipping them removes ~2/3 of the work per
    // month turn. Placeholder loading values keep the types non-nullable.
    final monthlyPanchangAsync = isAdaptive
        ? const AsyncValue<Map<DateTime, PanchangData>>.loading()
        : ref.watch(monthlyPanchangProvider(monthKey));
    final monthlyPanchang = isAdaptive
        ? const <DateTime, PanchangData>{}
        : monthlyPanchangAsync.when(
            data: (data) {
              // Feed the stale-dot LRU so the next month can render instantly
              // while its own provider is still loading.
              storeFestivalDotsSync(data);
              return data;
            },
            loading: () => <DateTime, PanchangData>{},
            error: (_, _) => <DateTime, PanchangData>{},
          );

    final gregorianCellDataAsync = isAdaptive
        ? const AsyncValue<Map<DateTime, CalendarCellData>>.loading()
        : ref.watch(
            gregorianCalendarCellDataProvider((
              // Month-normalized so precached neighbors hit the same instance.
              focusedMonth: monthKey,
              startOfWeek: startOfWeek,
              primarySystem: primarySystem,
              secondarySystem: secondarySystem,
              displayMode: displayMode,
            )),
          );

    // Adaptive month data, resolved stale-first: the previous month's grid
    // stays on screen while the new one computes (family-arg changes create
    // fresh provider instances, so .valueOrNull is the only bridge).
    final adaptiveAsync = isAdaptive
        ? ref.watch(
            adaptiveCalendarDataProvider((
              focusedMonth: focusedMonth,
              startOfWeek: startOfWeek,
              adaptiveSystem: primarySystem,
              primarySystem: primarySystem,
              secondarySystem: secondarySystem,
              displayMode: displayMode,
            )),
          )
        : const AsyncValue<AdaptiveCalendarData>.loading();
    final adaptiveDisplay = resolveAdaptiveGridDisplay(
      fresh: adaptiveAsync.valueOrNull,
      freshKey: adaptiveNavKey(primarySystem, focusedMonth),
      system: primarySystem,
      mode: displayMode,
    );
    final adaptiveSettled = adaptiveAsync.valueOrNull != null;

    // Best-effort precache of neighbor months (secondary labels + festival
    // dots). Only after the current month settled: firing neighbor FFI while
    // the current month is still computing contends for the same native
    // thread and janks the initial paint / landing frame.
    final currentSettled = isAdaptive
        ? adaptiveSettled
        : (monthlyPanchangAsync.hasValue || gregorianCellDataAsync.hasValue);
    if (currentSettled) {
      scheduleAdjacentPrecache(
        ref,
        focusedMonth,
        selectedDate,
        startOfWeek,
        primarySystem,
        secondarySystem,
        displayMode,
      );
    }

    // AnimatedSize: month turns can change the grid between 4–6 week rows
    // (and the adaptive path swaps grids), which used to snap the card —
    // and everything below it — in one frame. Top-aligned so the header
    // stays pinned while the bottom edge glides. Slow-start curve so the
    // edge never kicks on the first frames.
    return AnimatedSize(
      alignment: Alignment.topCenter,
      duration: AppMotion.of(context, AppMotion.emphasized),
      curve: AppMotion.emphasizedCurve,
      child: AppCard(
        // Horizontal gutters only ([AppTheme.pageGutter] so left and right
        // match every other page card): vertical spacing between home cards
        // is owned by the home column's uniform gaps, so a vertical margin
        // here would double up around this card alone.
        margin: const EdgeInsets.symmetric(horizontal: AppTheme.pageGutter),
        padding: EdgeInsets.zero,
        // Card padding per the redesign (18 top, 14 sides/bottom) keeps the
        // grid and stripes clear of the rounded card corners.
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.s14,
            AppSpacing.s18,
            AppSpacing.s14,
            AppSpacing.s14,
          ),
          child: Column(
            children: [
              CalendarHeader(
                focusedMonth: focusedMonth,
                onLeftChevronTap: () =>
                    navigateToPreviousMonth(ref, focusedMonth, primarySystem),
                onRightChevronTap: () =>
                    navigateToNextMonth(ref, focusedMonth, primarySystem),
                onYearTap: () =>
                    showCalendarYearPicker(context, ref, focusedMonth),
              ),
              if (isAdaptive)
                // Adaptive grid has no internal PageView, so swipe is handled
                // by the pane. Stale-first: the previous month stays mounted
                // under its OLD key while fresh data resolves (no animation),
                // then slides once to the new month.
                AdaptiveCalendarPane(
                  display: adaptiveDisplay,
                  isLoading: adaptiveAsync.isLoading,
                  focusedMonth: focusedMonth,
                  startOfWeek: startOfWeek,
                  primarySystem: primarySystem,
                  secondarySystem: secondarySystem,
                  displayMode: displayMode,
                  selectedDate: selectedDate,
                  today: today,
                )
              else
                // Gregorian path: TableCalendar owns the horizontal swipe via
                // its internal PageView.
                GregorianCalendarGrid(
                  focusedMonth: focusedMonth,
                  startOfWeek: startOfWeek,
                  secondarySystem: secondarySystem,
                  displayMode: displayMode,
                  selectedDate: selectedDate,
                  today: today,
                  cellDataAsync: gregorianCellDataAsync,
                  monthlyPanchang: monthlyPanchang,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
