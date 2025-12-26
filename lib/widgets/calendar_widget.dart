import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';
import '../providers/calendar_provider.dart';
import '../providers/panchang_provider.dart';
import '../theme/app_theme.dart';

/// Calendar widget using TableCalendar with Tithi markers
class CalendarWidget extends ConsumerWidget {
  const CalendarWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedDate = ref.watch(selectedDateProvider);
    final focusedMonth = ref.watch(focusedMonthProvider);

    return Container(
      margin: const EdgeInsets.all(12),
      decoration: AppTheme.glassmorphism(context: context, opacity: 0.15),
      child: TableCalendar(
        firstDay: DateTime(2020, 1, 1),
        lastDay: DateTime(2030, 12, 31),
        focusedDay: focusedMonth,
        selectedDayPredicate: (day) => isSameDay(day, selectedDate),
        onDaySelected: (selected, focused) {
          ref.read(selectedDateProvider.notifier).state = selected;
          ref.read(focusedMonthProvider.notifier).state = focused;
        },
        onPageChanged: (focusedDay) {
          ref.read(focusedMonthProvider.notifier).state = focusedDay;
        },
        calendarFormat: CalendarFormat.month,
        headerStyle: HeaderStyle(
          formatButtonVisible: false,
          titleCentered: true,
          titleTextStyle: context.textTheme.headlineMedium!.copyWith(
            fontSize: 18,
          ),
          leftChevronIcon: Icon(
            Icons.chevron_left,
            color: context.colors.primary,
          ),
          rightChevronIcon: Icon(
            Icons.chevron_right,
            color: context.colors.primary,
          ),
        ),
        calendarStyle: CalendarStyle(
          // Today styling
          todayDecoration: BoxDecoration(
            color: context.colors.primary.withValues(alpha: 0.3),
            shape: BoxShape.circle,
          ),
          todayTextStyle: TextStyle(
            color: context.colors.onSurface,
            fontWeight: FontWeight.bold,
          ),
          // Selected day styling
          selectedDecoration: BoxDecoration(
            color: context.colors.primary,
            shape: BoxShape.circle,
          ),
          selectedTextStyle: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
          // Default day styling
          defaultTextStyle: TextStyle(color: context.colors.onSurface),
          weekendTextStyle: TextStyle(
            color: context.colors.primary.withValues(alpha: 0.8),
          ),
          outsideTextStyle: TextStyle(
            color: context.colors.onSurface.withValues(alpha: 0.4),
          ),
        ),
        daysOfWeekStyle: DaysOfWeekStyle(
          weekdayStyle: TextStyle(
            color: context.colors.onSurface.withValues(alpha: 0.7),
            fontWeight: FontWeight.w600,
          ),
          weekendStyle: TextStyle(
            color: context.colors.primary.withValues(alpha: 0.8),
            fontWeight: FontWeight.w600,
          ),
        ),
        calendarBuilders: CalendarBuilders(
          markerBuilder: (context, date, events) {
            return _buildFestivalMarker(context, ref, date);
          },
        ),
      ),
    );
  }

  Widget? _buildFestivalMarker(
    BuildContext context,
    WidgetRef ref,
    DateTime date,
  ) {
    final panchangAsync = ref.watch(panchangForDateProvider(date));

    return panchangAsync.when(
      data: (panchang) {
        if (!panchang.hasFestivals) return null;

        // Show dot marker for festivals
        return Positioned(
          bottom: 1,
          child: Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: panchang.majorFestivals.isNotEmpty
                  ? context.colors.primary
                  : context.colors.secondary,
              shape: BoxShape.circle,
            ),
          ),
        );
      },
      loading: () => null,
      error: (_, _) => null,
    );
  }
}
