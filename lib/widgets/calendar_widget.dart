import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';
import '../providers/calendar_provider.dart' as cp;
import '../providers/panchang_provider.dart';
import '../providers/accessibility_provider.dart';
import '../services/bengali_calendar_service.dart';
import '../services/hindu_calendar_service.dart';
import '../theme/app_theme.dart';

/// Calendar widget using TableCalendar with Tithi markers
class CalendarWidget extends ConsumerWidget {
  const CalendarWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedDate = ref.watch(cp.selectedDateProvider);
    final focusedMonth = ref.watch(cp.focusedMonthProvider);
    final startOfWeek = ref.watch(cp.startOfWeekProvider);
    final primarySystem = ref.watch(cp.primaryCalendarSystemProvider);

    return Container(
      margin: const EdgeInsets.all(12),
      decoration: AppTheme.glassmorphism(
        context: context,
        opacity: 0.1,
        ref: ref,
      ),
      child: Column(
        children: [
          // Custom Header
          _CalendarHeader(
            focusedMonth: focusedMonth,
            onLeftChevronTap: () async {
              if (ref.read(accessibilityProvider).hapticFeedback) {
                HapticFeedback.selectionClick();
              }
              if (primarySystem == cp.AppCalendarSystem.bengali) {
                // Navigate by Bengali Month
                final service = ref.read(bengaliCalendarServiceProvider);
                await ref.read(panchangInitProvider.future);
                // Get current Bengali Date
                final bDate = await service.calculateDate(focusedMonth);
                final bIndex = service.bengaliMonths.indexOf(bDate.month);
                // Prev month
                var newIndex = bIndex - 1;
                var newYear = bDate.year;
                if (newIndex < 0) {
                  newIndex = 11;
                  newYear--;
                }
                final newDate = await service.getMonthStart(newYear, newIndex);
                ref.read(cp.focusedMonthProvider.notifier).state = newDate;
              } else if (primarySystem == cp.AppCalendarSystem.hindu) {
                // Navigate by Hindu Lunar Month
                final service = ref.read(hinduCalendarServiceProvider);
                await ref.read(panchangInitProvider.future);
                final hDate = await service.calculateDate(focusedMonth);
                // Current index
                final hIndex = service.hinduMonths.indexOf(hDate.masa);
                // Prev
                var newIndex = hIndex - 1;
                var newYear = hDate.year;
                if (newIndex < 0) {
                  newIndex = 11;
                  newYear--;
                }
                // getMonthStart takes index 0..11
                final newDate = await service.getMonthStart(newYear, newIndex);
                ref.read(cp.focusedMonthProvider.notifier).state = newDate;
              } else {
                ref.read(cp.focusedMonthProvider.notifier).state = DateTime(
                  focusedMonth.year,
                  focusedMonth.month - 1,
                );
              }
            },
            onRightChevronTap: () async {
              if (ref.read(accessibilityProvider).hapticFeedback) {
                HapticFeedback.selectionClick();
              }
              if (primarySystem == cp.AppCalendarSystem.bengali) {
                // Navigate by Bengali Month
                final service = ref.read(bengaliCalendarServiceProvider);
                await ref.read(panchangInitProvider.future);
                final bDate = await service.calculateDate(focusedMonth);
                final bIndex = service.bengaliMonths.indexOf(bDate.month);
                // Next month
                var newIndex = bIndex + 1;
                var newYear = bDate.year;
                if (newIndex > 11) {
                  newIndex = 0;
                  newYear++;
                }
                final newDate = await service.getMonthStart(newYear, newIndex);
                ref.read(cp.focusedMonthProvider.notifier).state = newDate;
              } else if (primarySystem == cp.AppCalendarSystem.hindu) {
                final service = ref.read(hinduCalendarServiceProvider);
                await ref.read(panchangInitProvider.future);
                final hDate = await service.calculateDate(focusedMonth);
                final hIndex = service.hinduMonths.indexOf(hDate.masa);
                // Next
                var newIndex = hIndex + 1;
                var newYear = hDate.year;
                if (newIndex > 11) {
                  newIndex = 0;
                  newYear++;
                }
                final newDate = await service.getMonthStart(newYear, newIndex);
                ref.read(cp.focusedMonthProvider.notifier).state = newDate;
              } else {
                ref.read(cp.focusedMonthProvider.notifier).state = DateTime(
                  focusedMonth.year,
                  focusedMonth.month + 1,
                );
              }
            },
          ),

          if (primarySystem == cp.AppCalendarSystem.bengali ||
              primarySystem == cp.AppCalendarSystem.hindu)
            _buildAdaptiveGrid(
              context,
              ref,
              focusedMonth,
              startOfWeek,
              primarySystem,
            )
          else
            TableCalendar(
              firstDay: DateTime(2020, 1, 1),
              lastDay: DateTime(2030, 12, 31),
              focusedDay: focusedMonth,
              startingDayOfWeek: startOfWeek == cp.StartingDayOfWeek.sunday
                  ? StartingDayOfWeek.sunday
                  : StartingDayOfWeek.monday,
              selectedDayPredicate: (day) => isSameDay(day, selectedDate),
              onDaySelected: (selected, focused) {
                if (ref.read(accessibilityProvider).hapticFeedback) {
                  HapticFeedback.selectionClick();
                }
                ref.read(cp.selectedDateProvider.notifier).state = selected;
                ref.read(cp.focusedMonthProvider.notifier).state = focused;
              },
              onPageChanged: (focusedDay) {
                ref.read(cp.focusedMonthProvider.notifier).state = focusedDay;
              },
              calendarFormat: CalendarFormat.month,
              headerVisible: false, // Hide default header
              calendarBuilders: CalendarBuilders(
                defaultBuilder: (context, date, _) {
                  return _CalendarCell(
                    date: date,
                    isSelected: false,
                    isToday: false,
                  );
                },
                selectedBuilder: (context, date, _) {
                  return _CalendarCell(
                    date: date,
                    isSelected: true,
                    isToday: isSameDay(date, DateTime.now()),
                  );
                },
                todayBuilder: (context, date, _) {
                  return _CalendarCell(
                    date: date,
                    isSelected: false,
                    isToday: true,
                  );
                },
                markerBuilder: (context, date, events) {
                  return _buildFestivalMarker(context, ref, date);
                },
              ),
              calendarStyle: CalendarStyle(
                // Styles handled by custom builders, but keeping basics for fallback
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
            ),
        ],
      ),
    );
  }

  Widget _buildAdaptiveGrid(
    BuildContext context,
    WidgetRef ref,
    DateTime focusedMonth,
    cp.StartingDayOfWeek startOfWeek,
    cp.AppCalendarSystem system,
  ) {
    return FutureBuilder<List<DateTime?>>(
      future: _getAdaptiveMonthDays(ref, focusedMonth, system),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox(
            height: 300,
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final days = snapshot.data!;

        return Column(
          children: [
            // Weekday Headers
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                for (var i = 0; i < 7; i++)
                  Expanded(
                    child: Center(
                      child: Text(
                        _getWeekdayName(i, startOfWeek),
                        style: TextStyle(
                          color: context.colors.onSurface.withValues(
                            alpha: 0.7,
                          ),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            // Grid
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
              ),
              itemCount: days.length,
              itemBuilder: (context, index) {
                final date = days[index];
                if (date == null) return const SizedBox();

                final isSelected = isSameDay(
                  date,
                  ref.watch(cp.selectedDateProvider),
                );
                final isToday = isSameDay(date, DateTime.now());

                return GestureDetector(
                  onTap: () {
                    if (ref.read(accessibilityProvider).hapticFeedback) {
                      HapticFeedback.selectionClick();
                    }
                    ref.read(cp.selectedDateProvider.notifier).state = date;
                  },
                  child: Stack(
                    children: [
                      _CalendarCell(
                        date: date,
                        isSelected: isSelected,
                        isToday: isToday,
                      ),
                      if (ref
                          .watch(panchangForDateProvider(date))
                          .maybeWhen(
                            data: (p) => p.hasFestivals,
                            orElse: () => false,
                          ))
                        _buildFestivalMarker(context, ref, date) ??
                            const SizedBox(),
                    ],
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }

  String _getWeekdayName(int index, cp.StartingDayOfWeek startOfWeek) {
    // 0 = Sun or Mon depending on start
    final days = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    if (startOfWeek == cp.StartingDayOfWeek.monday) {
      final d = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return d[index];
    }
    return days[index];
  }

  Future<List<DateTime?>> _getAdaptiveMonthDays(
    WidgetRef ref,
    DateTime focused,
    cp.AppCalendarSystem system,
  ) async {
    await ref.read(panchangInitProvider.future);

    DateTime startDate;
    DateTime nextMonthStart;

    if (system == cp.AppCalendarSystem.bengali) {
      final service = ref.read(bengaliCalendarServiceProvider);
      final bDate = await service.calculateDate(focused);
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
    } else if (system == cp.AppCalendarSystem.hindu) {
      final service = ref.read(hinduCalendarServiceProvider);
      final hDate = await service.calculateDate(focused);
      final monthIndex = service.hinduMonths.indexOf(hDate.masa);
      final year = hDate.year;
      startDate = await service.getMonthStart(year, monthIndex);

      var nextIndex = monthIndex + 1;
      var nextYear = year;
      if (nextIndex > 11) {
        nextIndex = 0;
        nextYear++;
      }
      nextMonthStart = await service.getMonthStart(nextYear, nextIndex);
    } else {
      return [];
    }

    final daysInMonth = nextMonthStart.difference(startDate).inDays;
    final startWeekDay = startDate.weekday; // 1-7

    int offset = 0;
    final startOfWeek = ref.read(cp.startOfWeekProvider);
    if (startOfWeek == cp.StartingDayOfWeek.sunday) {
      offset = startWeekDay % 7;
    } else {
      offset = startWeekDay - 1;
    }

    final List<DateTime?> grid = [];
    for (int i = 0; i < offset; i++) grid.add(null);

    for (int i = 0; i < daysInMonth; i++) {
      grid.add(startDate.add(Duration(days: i)));
    }

    return grid;
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
          left: 0,
          right: 0,
          child: Center(
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
          ),
        );
      },
      loading: () => null,
      error: (_, _) => null,
    );
  }
}

class _CalendarHeader extends ConsumerWidget {
  final DateTime focusedMonth;
  final VoidCallback onLeftChevronTap;
  final VoidCallback onRightChevronTap;

  const _CalendarHeader({
    required this.focusedMonth,
    required this.onLeftChevronTap,
    required this.onRightChevronTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final primarySystem = ref.watch(cp.primaryCalendarSystemProvider);
    final secondarySystem = ref.watch(cp.secondaryCalendarSystemProvider);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: Icon(Icons.chevron_left, color: context.colors.primary),
            onPressed: onLeftChevronTap,
          ),
          Expanded(
            child: FutureBuilder<String>(
              future: _getCombinedHeaderText(
                ref,
                focusedMonth,
                primarySystem,
                secondarySystem,
              ),
              initialData: _formatGregorian(focusedMonth),
              builder: (context, snapshot) {
                return FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    snapshot.data ?? '',
                    style: context.textTheme.headlineMedium!.copyWith(
                      fontSize: 18,
                    ),
                  ),
                );
              },
            ),
          ),
          IconButton(
            icon: Icon(Icons.chevron_right, color: context.colors.primary),
            onPressed: onRightChevronTap,
          ),
        ],
      ),
    );
  }

  Future<String> _getCombinedHeaderText(
    WidgetRef ref,
    DateTime date,
    cp.AppCalendarSystem primary,
    cp.AppCalendarSystem secondary,
  ) async {
    final primaryText = await _getSystemHeaderText(ref, date, primary);

    if (secondary != cp.AppCalendarSystem.none && secondary != primary) {
      final secondaryText = await _getSystemHeaderText(ref, date, secondary);
      return '$primaryText ($secondaryText)';
    }

    return primaryText;
  }

  Future<String> _getSystemHeaderText(
    WidgetRef ref,
    DateTime date,
    cp.AppCalendarSystem system,
  ) async {
    // final midMonth = DateTime(date.year, date.month, 15); // Unused now

    switch (system) {
      case cp.AppCalendarSystem.bengali:
        try {
          final service = ref.read(bengaliCalendarServiceProvider);
          await ref.read(panchangInitProvider.future);
          // Use the date directly. focusedMonth is usually 1st of Bengali month or a valid day.
          // Calculating midMonth (Gregorian 15th) causes off-by-one month error
          // if Bengali month starts after 15th (e.g. Poush starts Dec 16).
          final bDate = await service.calculateDate(date);
          return '${bDate.month} ${bDate.year}';
        } catch (_) {
          return _formatGregorian(date);
        }

      case cp.AppCalendarSystem.hindu:
        try {
          final service = ref.read(hinduCalendarServiceProvider);
          await ref.read(panchangInitProvider.future);
          final hDate = await service.calculateDate(date);
          return '${hDate.masa} ${hDate.year}';
        } catch (_) {
          return _formatGregorian(date);
        }

      case cp.AppCalendarSystem.gregorian:
      default:
        return _formatGregorian(date);
    }
  }

  String _formatGregorian(DateTime date) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${months[date.month - 1]} ${date.year}';
  }
}

class _CalendarCell extends ConsumerWidget {
  final DateTime date;
  final bool isSelected;
  final bool isToday;

  const _CalendarCell({
    required this.date,
    required this.isSelected,
    required this.isToday,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final primarySystem = ref.watch(cp.primaryCalendarSystemProvider);
    final secondarySystem = ref.watch(cp.secondaryCalendarSystemProvider);

    return FutureBuilder<({String primary, String? secondary})>(
      future: _getDates(ref, date, primarySystem, secondarySystem),
      initialData: (
        primary: date.day.toString(),
        secondary: null,
      ), // Optimistic update
      builder: (context, snapshot) {
        final data =
            snapshot.data ?? (primary: date.day.toString(), secondary: null);

        // Determine colors based on state
        final textColor = isSelected
            ? Colors.white
            : isToday
            ? context.colors.primary
            : context.colors.onSurface;

        final secondaryColor = isSelected
            ? Colors.white.withValues(alpha: 0.7)
            : isToday
            ? context.colors.primary.withValues(alpha: 0.7)
            : context.colors.onSurface.withValues(alpha: 0.5);

        final bgColor = isSelected
            ? context.colors.primary
            : isToday
            ? context.colors.primary.withValues(alpha: 0.2)
            : Colors.transparent;

        return Container(
          margin: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: bgColor,
            shape: isSelected || isToday ? BoxShape.circle : BoxShape.rectangle,
            borderRadius: isSelected || isToday
                ? null
                : BorderRadius.circular(8),
          ),
          child: Stack(
            children: [
              // Primary Date (Center, Large)
              Center(
                child: Text(
                  data.primary,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 16,
                    fontWeight: isSelected || isToday
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
              ),

              // Secondary Date (Top Left, Small)
              if (data.secondary != null)
                Positioned(
                  top: 4,
                  left: 6,
                  child: Text(
                    data.secondary!,
                    style: TextStyle(
                      color: secondaryColor,
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Future<({String primary, String? secondary})> _getDates(
    WidgetRef ref,
    DateTime date,
    cp.AppCalendarSystem primary,
    cp.AppCalendarSystem secondary,
  ) async {
    final pDate = await _getCalendarDate(ref, date, primary);
    String? sDate;

    if (secondary != cp.AppCalendarSystem.none && secondary != primary) {
      sDate = await _getCalendarDate(ref, date, secondary);
    }

    return (primary: pDate, secondary: sDate);
  }

  Future<String> _getCalendarDate(
    WidgetRef ref,
    DateTime date,
    cp.AppCalendarSystem system,
  ) async {
    switch (system) {
      case cp.AppCalendarSystem.gregorian:
        return date.day.toString();
      case cp.AppCalendarSystem.hindu:
        try {
          final service = ref.read(hinduCalendarServiceProvider);
          await ref.read(panchangInitProvider.future);
          final hDate = await service.calculateDate(date);
          return hDate.tithi.toString();
        } catch (e) {
          return '?';
        }
      case cp.AppCalendarSystem.bengali:
        try {
          final service = ref.read(bengaliCalendarServiceProvider);
          // Wait for init just in case
          await ref.read(panchangInitProvider.future);
          final bengaliDate = await service.calculateDate(date);
          return bengaliDate.day.toString();
        } catch (e) {
          return '?';
        }
      case cp.AppCalendarSystem.none:
        return '';
    }
  }
}
