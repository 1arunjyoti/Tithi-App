import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/async/keep_alive.dart';
import '../../../providers/calendar_provider.dart' as cp;
import '../../../providers/panchang_provider.dart';
import '../../../services/bengali_calendar_service.dart';
import '../../../services/hindu_calendar_service.dart';
import '../data/calendar_caches.dart';
import '../data/calendar_models.dart';
import '../domain/cell_builders.dart';

// Phase 3b: month cell providers extracted from widgets/calendar_widget.dart.
// Names and args are unchanged so existing watchers keep working; the widget
// re-exports this file.

// autoDispose: instances are per-month and the sync LRU
// (secondaryDayCache) already preserves labels across disposal, so the
// next visit re-renders instantly while fresh data resolves behind it.
final gregorianCalendarCellDataProvider = FutureProvider.autoDispose
    .family<
      Map<DateTime, CalendarCellData>,
      ({
        DateTime focusedMonth,
        cp.StartingDayOfWeek startOfWeek,
        cp.AppCalendarSystem primarySystem,
        cp.AppCalendarSystem secondarySystem,
        cp.TithiDisplayMode displayMode,
      })
    >((ref, args) async {
      final firstDayOfMonth = DateTime(
        args.focusedMonth.year,
        args.focusedMonth.month,
      );
      final lastDayOfMonth = DateTime(
        args.focusedMonth.year,
        args.focusedMonth.month + 1,
        0,
      );

      final int startOffset = args.startOfWeek == cp.StartingDayOfWeek.monday
          ? firstDayOfMonth.weekday - 1
          : firstDayOfMonth.weekday % 7;
      final int endOffset = args.startOfWeek == cp.StartingDayOfWeek.monday
          ? (7 - lastDayOfMonth.weekday) % 7
          : 6 - (lastDayOfMonth.weekday % 7);

      final startDate = firstDayOfMonth.subtract(Duration(days: startOffset));
      final endDate = lastDayOfMonth.add(Duration(days: endOffset));

      final dates = <DateTime>[];
      for (
        var date = startDate;
        !date.isAfter(endDate);
        date = date.add(const Duration(days: 1))
      ) {
        dates.add(DateTime(date.year, date.month, date.day));
      }

      return buildCalendarCellData(
        ref,
        dates,
        args.primarySystem,
        args.secondarySystem,
        args.displayMode,
        // Gregorian markers come from monthlyPanchangProvider; per-date
        // panchang fetches here only add FFI load during swipes.
        includeFestivals: false,
      );
    });

// autoDispose with a 5-minute keepAlive, mirroring monthlyPanchangProvider:
// swiping back/forth between the same lunar months stays warm for instant
// landing instead of recomputing. Each entry holds ~42 tiny cell records,
// so idle months are still released rather than retained for the session.
final adaptiveCalendarDataProvider = FutureProvider.autoDispose
    .family<
      AdaptiveCalendarData,
      ({
        DateTime focusedMonth,
        cp.StartingDayOfWeek startOfWeek,
        cp.AppCalendarSystem adaptiveSystem,
        cp.AppCalendarSystem primarySystem,
        cp.AppCalendarSystem secondarySystem,
        cp.TithiDisplayMode displayMode,
      })
    >((ref, args) async {
      ref.keepAliveFor(const Duration(minutes: 5));

      await ref.read(panchangInitProvider.future);

      DateTime startDate;
      DateTime nextMonthStart;

      if (args.adaptiveSystem == cp.AppCalendarSystem.bengali) {
        final service = ref.read(bengaliCalendarServiceProvider);
        final bDate = await service.calculateDate(args.focusedMonth);
        final monthIndex = service.bengaliMonths.indexOf(bDate.month);
        final year = bDate.year;
        startDate = await service.getMonthStart(year, monthIndex);

        var nextIndex = monthIndex + 1;
        var nextYear = year;
        if (nextIndex > 11) {
          nextIndex = 0;
          nextYear++;
        }
        nextMonthStart = await service.getMonthStart(nextYear, nextIndex);
      } else {
        // Exact-masa slicing: Adhika/Nija months are distinct masas and must
        // never share one grid. Index arithmetic (baseMasaName + monthIndex)
        // merges them (~59-day span) and skips Nija entirely.
        final service = ref.read(hinduCalendarServiceProvider);
        startDate = await service.monthStartContaining(args.focusedMonth);
        nextMonthStart = await service.nextMonthStartAfter(startDate);
      }

      final daysInMonth = nextMonthStart.difference(startDate).inDays;
      logCalNav(
        'slice ${args.adaptiveSystem} focused=${ymd(args.focusedMonth)} '
        'start=${ymd(startDate)} next=${ymd(nextMonthStart)} days=$daysInMonth',
      );
      final startWeekDay = startDate.weekday;
      final offset = args.startOfWeek == cp.StartingDayOfWeek.sunday
          ? startWeekDay % 7
          : startWeekDay - 1;

      final List<DateTime?> grid = [];
      for (int i = 0; i < offset; i++) {
        grid.add(null);
      }

      final visibleDates = <DateTime>[];
      for (int i = 0; i < daysInMonth; i++) {
        final date = DateTime(
          startDate.year,
          startDate.month,
          startDate.day + i,
        );
        grid.add(date);
        visibleDates.add(date);
      }

      // Complete the final week row only (mirrors TableCalendar with
      // sixWeekMonthsEnforced: false): lunar months render 4-6 rows so the
      // grid height follows the month instead of pinning to 6 rows.
      while (grid.length % 7 != 0) {
        grid.add(null);
      }

      final cellData = await buildCalendarCellData(
        ref,
        visibleDates,
        args.primarySystem,
        args.secondarySystem,
        args.displayMode,
      );

      return AdaptiveCalendarData(days: grid, cellData: cellData);
    });
