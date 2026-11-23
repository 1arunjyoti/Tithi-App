import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart' show isSameDay;

import '../../../providers/calendar_provider.dart' as cp;
import '../../../theme/app_metrics.dart';
import '../../../theme/app_motion.dart';
import '../../../widgets/skeleton.dart';
import '../data/adaptive_grid_state.dart';
import '../data/calendar_caches.dart';
import '../data/calendar_models.dart';
import '../domain/month_navigation.dart';
import '../domain/month_navigation_controller.dart';
import 'calendar_cell.dart';
import 'calendar_festival_bar.dart';
import 'calendar_weekday_row.dart';

/// Swipe + stale-first transition wrapper for the adaptive (Hindu/Bengali)
/// month grid. The grid has no internal PageView, so the horizontal drag is
/// handled here; the previous month stays mounted under its OLD key while the
/// next one resolves, then slides once to the new month.
class AdaptiveCalendarPane extends ConsumerWidget {
  const AdaptiveCalendarPane({
    super.key,
    required this.display,
    required this.isLoading,
    required this.focusedMonth,
    required this.startOfWeek,
    required this.primarySystem,
    required this.secondarySystem,
    required this.displayMode,
    required this.selectedDate,
    required this.today,
  });

  final AdaptiveGridDisplay? display;
  final bool isLoading;
  final DateTime focusedMonth;
  final cp.StartingDayOfWeek startOfWeek;
  final cp.AppCalendarSystem primarySystem;
  final cp.AppCalendarSystem secondarySystem;
  final cp.TithiDisplayMode displayMode;
  final DateTime selectedDate;
  final DateTime today;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      // Opaque (not deferToChild): null-day blanks, the weekday
      // header and grid gaps paint nothing hittable, so swipes
      // starting there never reached this detector while
      // Gregorian's full-bleed PageView always responds. Same
      // remedy the date cells below already carry. Vertical
      // scrolling and tile taps are unaffected (the arena
      // decides by direction; taps don't move).
      behavior: HitTestBehavior.opaque,
      onHorizontalDragStart: (_) => adaptiveSwipeDx = 0,
      onHorizontalDragUpdate: (details) {
        adaptiveSwipeDx += details.delta.dx;
      },
      onHorizontalDragEnd: (details) {
        // Fling OR slow drag past the slop (see
        // adaptiveSwipeDirection): Gregorian parity.
        final direction = adaptiveSwipeDirection(
          velocity: details.primaryVelocity ?? 0,
          distance: adaptiveSwipeDx,
        );
        adaptiveSwipeDx = 0;
        if (direction > 0) {
          navigateToNextMonth(ref, focusedMonth, primarySystem);
        } else if (direction < 0) {
          navigateToPreviousMonth(ref, focusedMonth, primarySystem);
        }
      },
      child: RepaintBoundary(
        child: AnimatedSwitcher(
          duration: AppMotion.of(context, AppMotion.emphasized),
          // Outgoing drops instantly: AnimatedSwitcher reuses this
          // Tween reversed for the exit, which would slide the old
          // grid back over the incoming one (wrong side) while
          // keeping 84 cells + opacity mounted — the raster spike
          // (~20ms) and ghost flash seen in profile captures.
          reverseDuration: Duration.zero,
          transitionBuilder: (child, animation) {
            // Slide-only (no fade): fade forces an opacity +
            // glassmorphism blur recomposite every frame and ghosts
            // old cells over new ones. Slide-only mirrors the
            // Gregorian TableCalendar page turn without overlap.
            final slide =
                Tween<Offset>(
                  begin: Offset(0.35 * adaptiveSlideDirection, 0),
                  end: Offset.zero,
                ).animate(
                  CurvedAnimation(
                    parent: animation,
                    curve: AppMotion.standardCurve,
                  ),
                );
            return SlideTransition(position: slide, child: child);
          },
          child: display != null
              ? AdaptiveCalendarGrid(
                  // Stale keeps the previous month's key (static hold,
                  // no animation); fresh takes the new month's key so
                  // the switcher slides exactly once old -> new.
                  key: ValueKey(display!.key),
                  startOfWeek: startOfWeek,
                  data: display!.data,
                  secondarySystem: secondarySystem,
                  displayMode: displayMode,
                  selectedDate: selectedDate,
                  today: today,
                )
              : isLoading
              // Same 6-row skeleton height as the loaded grid: keeps
              // layout stable instead of swapping a 300px spinner
              // for a taller/shorter grid (the main "jump" culprit).
              // Only on cold start — never between months.
              ? AdaptiveCalendarSkeleton(
                  key: const ValueKey('adaptive_skeleton'),
                  startOfWeek: startOfWeek,
                )
              : const SizedBox.shrink(),
        ),
      ),
    );
  }
}

/// 5-row skeleton for cold start (the most common lunar-month shape);
/// month turns reuse the stale grid instead, and row counts of 4-6 settle
/// naturally like the Gregorian path.
class AdaptiveCalendarSkeleton extends StatelessWidget {
  const AdaptiveCalendarSkeleton({super.key, required this.startOfWeek});

  final cp.StartingDayOfWeek startOfWeek;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        CalendarWeekdayRow(startOfWeek: startOfWeek),
        const SizedBox(height: AppSpacing.s4),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
          ),
          // 5 rows: the most common lunar-month shape (see grid padding).
          itemCount: 35,
          itemBuilder: (context, index) => const Padding(
            padding: EdgeInsets.all(AppSpacing.s4),
            child: SkeletonBox(radius: AppRadius.chip),
          ),
        ),
      ],
    );
  }
}

/// Adaptive month grid with weekday headers and weekend striping.
class AdaptiveCalendarGrid extends ConsumerWidget {
  const AdaptiveCalendarGrid({
    super.key,
    required this.startOfWeek,
    required this.data,
    required this.secondarySystem,
    required this.displayMode,
    required this.selectedDate,
    required this.today,
  });

  final cp.StartingDayOfWeek startOfWeek;
  final AdaptiveCalendarData data;
  final cp.AppCalendarSystem secondarySystem;
  final cp.TithiDisplayMode displayMode;
  // Hoisted by the caller: watching selectedDate or calling DateTime.now()
  // inside itemBuilder would re-subscribe/re-evaluate per cell (42×).
  final DateTime selectedDate;
  final DateTime today;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Feed the stale-dot LRU so a later Gregorian view (or a fast
    // back-navigation) can render dots instantly.
    _storeAdaptiveCellDots(data.cellData);
    final days = data.days;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Weekday Headers (shared styling with the Gregorian path).
        CalendarWeekdayRow(startOfWeek: startOfWeek),
        const SizedBox(height: AppSpacing.s4),
        // Grid with weekend striping.
        CalendarWeekendStripes(
          startOfWeek: startOfWeek,
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
            ),
            itemCount: days.length,
            itemBuilder: (context, index) {
              final date = days[index];
              if (date == null) return const SizedBox();

              final isSelected = isSameDay(date, selectedDate);
              final isToday = isSameDay(date, today);

              final normalizedDate = DateTime(date.year, date.month, date.day);
              final cellData = data.cellData[normalizedDate];
              // Festival info is embedded in cellData (from adaptive provider)
              // which uses the correct lunar date range — no Gregorian mismatch.
              // Fall back to stale dots while the next lunar month is loading.
              final staleDot = cellData == null
                  ? cachedFestivalDotSync(normalizedDate)
                  : null;
              final hasFestivals =
                  cellData?.hasFestivals ?? staleDot?.hasFestivals ?? false;
              final hasMajorFestival =
                  cellData?.hasMajorFestival ?? staleDot?.isMajor ?? false;

              return GestureDetector(
                // Unlike TableCalendar's Gregorian tiles, this custom grid
                // has transparent cell backgrounds for most unselected days.
                // The default `deferToChild` hit-testing then recognizes a
                // tap only on the painted text/marker, making taps in the
                // rest of the visible square feel intermittent. Claim the
                // complete GridView slot so every date cell has the same
                // target area and response as the Gregorian calendar.
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  // Haptic + press scale owned by PressScale inside
                  // CalendarCell (no double-buzz).
                  ref.read(cp.selectedDateProvider.notifier).setDate(date);
                  // Active tile tap: narrows the secondary header to this
                  // date's single month with the year.
                  ref.read(cp.tappedCalendarDateProvider.notifier).state =
                      DateTime(date.year, date.month, date.day);
                },
                child: Stack(
                  children: [
                    CalendarCell(
                      date: date,
                      isSelected: isSelected,
                      isToday: isToday,
                      primaryText: cellData?.primary ?? date.day.toString(),
                      secondaryText:
                          cellData?.secondary ??
                          cachedSecondarySync(
                            normalizedDate,
                            secondarySystem,
                            displayMode,
                          ),
                    ),
                    if (hasFestivals)
                      CalendarFestivalBar(
                        isMajor: hasMajorFestival,
                        isSelected: isSelected,
                        isToday: isToday,
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// Adapter: the shared dot cache stores plain records; the grid works with
// CalendarCellData.
void _storeAdaptiveCellDots(Map<DateTime, CalendarCellData> cellData) {
  storeAdaptiveDotsSync(
    cellData.map(
      (date, cell) => MapEntry(date, (
        hasFestivals: cell.hasFestivals,
        isMajor: cell.hasMajorFestival,
      )),
    ),
  );
}
