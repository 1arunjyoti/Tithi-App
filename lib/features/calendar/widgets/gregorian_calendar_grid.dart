import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../../core/feedback/app_haptics.dart';
import '../../../models/panchang_data.dart';
import '../../../providers/calendar_provider.dart' as cp;
import '../../../theme/app_metrics.dart';
import '../../../theme/app_motion.dart';
import '../../../theme/app_theme.dart';
import '../data/calendar_caches.dart';
import '../data/calendar_models.dart';
import 'calendar_cell.dart';
import 'calendar_festival_bar.dart';
import 'calendar_weekday_row.dart';

/// Gregorian path: TableCalendar owns the horizontal swipe via its internal
/// PageView. No outer GestureDetector here — a competing drag handler makes
/// the page stick/jitter mid-swipe.
class GregorianCalendarGrid extends ConsumerWidget {
  const GregorianCalendarGrid({
    super.key,
    required this.focusedMonth,
    required this.startOfWeek,
    required this.secondarySystem,
    required this.displayMode,
    required this.selectedDate,
    required this.today,
    required this.cellDataAsync,
    required this.monthlyPanchang,
  });

  final DateTime focusedMonth;
  final cp.StartingDayOfWeek startOfWeek;
  final cp.AppCalendarSystem secondarySystem;
  final cp.TithiDisplayMode displayMode;
  final DateTime selectedDate;
  final DateTime today;
  final AsyncValue<Map<DateTime, CalendarCellData>> cellDataAsync;
  final Map<DateTime, PanchangData> monthlyPanchang;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return RepaintBoundary(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CalendarWeekdayRow(startOfWeek: startOfWeek),
          const SizedBox(height: AppSpacing.s4),
          LayoutBuilder(
            builder: (context, constraints) {
              return CalendarWeekendStripes(
                startOfWeek: startOfWeek,
                child: TableCalendar(
                  // Square cells: row height matches the column width.
                  rowHeight: constraints.maxWidth / 7,
                  firstDay: DateTime(1976),
                  lastDay: DateTime(2076, 12, 31),
                  focusedDay: focusedMonth,
                  // Short, eased page animation: the default 300ms easeInOut
                  // feels sluggish while heavy providers resolve underneath.
                  // Reduce Motion jumps instantly between months.
                  pageAnimationDuration: AppMotion.of(
                    context,
                    AppMotion.emphasized,
                  ),
                  pageAnimationCurve: AppMotion.standardCurve,
                  availableGestures: AvailableGestures.horizontalSwipe,
                  startingDayOfWeek: startOfWeek == cp.StartingDayOfWeek.sunday
                      ? StartingDayOfWeek.sunday
                      : StartingDayOfWeek.monday,
                  selectedDayPredicate: (day) => isSameDay(day, selectedDate),
                  onDaySelected: (selected, focused) {
                    // Haptic + press scale owned by PressScale
                    // inside CalendarCell (no double-buzz).
                    ref
                        .read(cp.selectedDateProvider.notifier)
                        .setDate(selected);
                    // Avoid notifying focusedMonth (and re-resolving all month
                    // providers) when the tap didn't actually change months.
                    final current = ref.read(cp.focusedMonthProvider);
                    if (current.year != focused.year ||
                        current.month != focused.month) {
                      // Day taps have no page animation to protect: settle
                      // heavy data immediately so dots/labels don't lag.
                      cp.setCalendarMonth(ref, focused);
                    }
                    // Active tile tap (set after setCalendarMonth, which clears
                    // tap state as month navigation): narrows the secondary
                    // header to this date's single month.
                    ref.read(cp.tappedCalendarDateProvider.notifier).state =
                        DateTime(selected.year, selected.month, selected.day);
                  },
                  onPageChanged: (focusedDay) {
                    // Single haptic for Gregorian page turns (swipe or
                    // chevron-driven animation). Chevron taps don't buzz
                    // separately on this path (see navigateTo*Month).
                    AppHaptics.tap(ref);
                    // Instant: header + page position flip at mid-screen cross.
                    ref
                        .read(cp.focusedMonthProvider.notifier)
                        .setFocusedMonth(focusedDay);
                    // Swiping months ends the explicit tile-tap state: the
                    // secondary header returns to its default two-month range.
                    ref.read(cp.tappedCalendarDateProvider.notifier).state =
                        null;
                    // Deferred: heavy FFI follows after the page animation
                    // settles, so it never blocks settle frames.
                    ref
                        .read(cp.heavyFocusedMonthProvider.notifier)
                        .scheduleDebounced(focusedDay);
                  },
                  headerVisible: false, // Hide default header
                  calendarBuilders: CalendarBuilders(
                    defaultBuilder: (context, date, _) {
                      final normalizedDate = DateTime(
                        date.year,
                        date.month,
                        date.day,
                      );
                      final cellData = cellDataAsync.maybeWhen(
                        data: (data) => data[normalizedDate],
                        orElse: () => null,
                      );
                      return CalendarCell(
                        date: date,
                        isSelected: false,
                        isToday: false,
                        primaryText: cellData?.primary ?? date.day.toString(),
                        secondaryText:
                            cellData?.secondary ??
                            cachedSecondarySync(
                              normalizedDate,
                              secondarySystem,
                              displayMode,
                            ),
                      );
                    },
                    selectedBuilder: (context, date, _) {
                      final normalizedDate = DateTime(
                        date.year,
                        date.month,
                        date.day,
                      );
                      final cellData = cellDataAsync.maybeWhen(
                        data: (data) => data[normalizedDate],
                        orElse: () => null,
                      );
                      return CalendarCell(
                        date: date,
                        isSelected: true,
                        isToday: isSameDay(date, today),
                        primaryText: cellData?.primary ?? date.day.toString(),
                        secondaryText:
                            cellData?.secondary ??
                            cachedSecondarySync(
                              normalizedDate,
                              secondarySystem,
                              displayMode,
                            ),
                      );
                    },
                    todayBuilder: (context, date, _) {
                      final normalizedDate = DateTime(
                        date.year,
                        date.month,
                        date.day,
                      );
                      final cellData = cellDataAsync.maybeWhen(
                        data: (data) => data[normalizedDate],
                        orElse: () => null,
                      );
                      return CalendarCell(
                        date: date,
                        isSelected: false,
                        isToday: true,
                        primaryText: cellData?.primary ?? date.day.toString(),
                        secondaryText:
                            cellData?.secondary ??
                            cachedSecondarySync(
                              normalizedDate,
                              secondarySystem,
                              displayMode,
                            ),
                      );
                    },
                    outsideBuilder: (context, date, _) {
                      final normalizedDate = DateTime(
                        date.year,
                        date.month,
                        date.day,
                      );
                      final cellData = cellDataAsync.maybeWhen(
                        data: (data) => data[normalizedDate],
                        orElse: () => null,
                      );
                      return CalendarCell(
                        date: date,
                        isSelected: isSameDay(date, selectedDate),
                        isToday: isSameDay(date, today),
                        isOutside: true,
                        primaryText: cellData?.primary ?? date.day.toString(),
                        secondaryText:
                            cellData?.secondary ??
                            cachedSecondarySync(
                              normalizedDate,
                              secondarySystem,
                              displayMode,
                            ),
                      );
                    },
                    markerBuilder: (context, date, events) {
                      return buildFestivalMarkerFromCache(
                        context,
                        date,
                        monthlyPanchang,
                        isSelected: isSameDay(date, selectedDate),
                        isToday: isSameDay(date, today),
                      );
                    },
                  ),
                  calendarStyle: CalendarStyle(
                    // Styles handled by custom builders, but keeping basics for fallback
                    outsideTextStyle: TextStyle(color: context.faintInk),
                  ),
                  // Weekday labels render in the shared row above.
                  daysOfWeekVisible: false,
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
