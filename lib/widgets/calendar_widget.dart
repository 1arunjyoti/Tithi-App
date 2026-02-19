import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';
import '../providers/calendar_provider.dart' as cp;
import '../providers/panchang_provider.dart';
import '../providers/accessibility_provider.dart';
import '../services/bengali_calendar_service.dart';
import '../services/hindu_calendar_service.dart';
import '../models/hindu_month_system.dart';
import '../models/panchang_data.dart';
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

    // Pre-load entire month's panchang data to eliminate N+1 query pattern
    final monthlyPanchangAsync = ref.watch(
      monthlyPanchangProvider(focusedMonth),
    );
    final monthlyPanchang = monthlyPanchangAsync.when(
      data: (data) => data,
      loading: () => <DateTime, PanchangData>{},
      error: (_, _) => <DateTime, PanchangData>{},
    );

    return Container(
      margin: const EdgeInsets.all(12),
      decoration: AppTheme.glassmorphism(context: context, ref: ref),
      child: GestureDetector(
        onHorizontalDragEnd: (details) {
          // Swipe left = next month, swipe right = previous month
          if (details.primaryVelocity != null) {
            if (details.primaryVelocity! < -300) {
              // Swipe left - next month
              _navigateToNextMonth(ref, focusedMonth, primarySystem);
            } else if (details.primaryVelocity! > 300) {
              // Swipe right - previous month
              _navigateToPreviousMonth(ref, focusedMonth, primarySystem);
            }
          }
        },
        child: Column(
          children: [
            // Custom Header
            _CalendarHeader(
              focusedMonth: focusedMonth,
              onLeftChevronTap: () =>
                  _navigateToPreviousMonth(ref, focusedMonth, primarySystem),
              onRightChevronTap: () =>
                  _navigateToNextMonth(ref, focusedMonth, primarySystem),
              onYearTap: () => _showYearPicker(context, ref, focusedMonth),
            ),

            if (primarySystem == cp.AppCalendarSystem.bengali ||
                primarySystem == cp.AppCalendarSystem.hindu)
              _buildAdaptiveGrid(
                context,
                ref,
                focusedMonth,
                startOfWeek,
                primarySystem,
                monthlyPanchang,
              )
            else
              TableCalendar(
                firstDay: DateTime(1976),
                lastDay: DateTime(2076, 12, 31),
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
                    return _buildFestivalMarkerFromCache(
                      context,
                      date,
                      monthlyPanchang,
                    );
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
      ),
    );
  }

  Widget _buildAdaptiveGrid(
    BuildContext context,
    WidgetRef ref,
    DateTime focusedMonth,
    cp.StartingDayOfWeek startOfWeek,
    cp.AppCalendarSystem system,
    Map<DateTime, PanchangData> monthlyPanchang,
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

                // Use pre-loaded panchang data from cache
                final normalizedDate = DateTime(
                  date.year,
                  date.month,
                  date.day,
                );
                final panchang = monthlyPanchang[normalizedDate];
                final hasFestivals = panchang?.hasFestivals ?? false;

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
                      if (hasFestivals)
                        _buildFestivalMarkerFromCache(
                              context,
                              date,
                              monthlyPanchang,
                            ) ??
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
      final year = hDate.vsYear;
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
    for (int i = 0; i < offset; i++) {
      grid.add(null);
    }

    for (int i = 0; i < daysInMonth; i++) {
      grid.add(startDate.add(Duration(days: i)));
    }

    return grid;
  }

  /// Show year picker dialog for quick navigation
  /// Supports Gregorian, Hindu (Vikram Samvat/Shaka), and Bengali calendar years
  void _showYearPicker(
    BuildContext context,
    WidgetRef ref,
    DateTime focusedMonth,
  ) async {
    if (ref.read(accessibilityProvider).hapticFeedback) {
      await HapticFeedback.selectionClick();
    }

    final primarySystem = ref.read(cp.primaryCalendarSystemProvider);

    if (primarySystem == cp.AppCalendarSystem.hindu) {
      await _showHinduYearPicker(context, ref, focusedMonth);
    } else if (primarySystem == cp.AppCalendarSystem.bengali) {
      await _showBengaliYearPicker(context, ref, focusedMonth);
    } else {
      await _showGregorianYearPicker(context, ref, focusedMonth);
    }
  }

  /// Gregorian year picker using native Flutter dialog
  Future<void> _showGregorianYearPicker(
    BuildContext context,
    WidgetRef ref,
    DateTime focusedMonth,
  ) async {
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: focusedMonth,
      firstDate: DateTime(1976),
      lastDate: DateTime(2076, 12, 31),
      initialDatePickerMode: DatePickerMode.year,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: context.colors.primary,
              onPrimary: Colors.white,
              surface: Theme.of(context).scaffoldBackgroundColor,
            ),
          ),
          child: child!,
        );
      },
    );

    if (selectedDate != null) {
      ref.read(cp.focusedMonthProvider.notifier).state = DateTime(
        selectedDate.year,
        focusedMonth.month,
      );
    }
  }

  /// Hindu calendar year picker (Vikram Samvat or Shaka Era) with month selection
  Future<void> _showHinduYearPicker(
    BuildContext context,
    WidgetRef ref,
    DateTime focusedMonth,
  ) async {
    final yearEra = ref.read(cp.hinduYearEraProvider);
    final service = ref.read(hinduCalendarServiceProvider);
    await ref.read(panchangInitProvider.future);

    // Get current Hindu year for the focused month
    final hDate = await service.calculateDate(focusedMonth);
    final currentYear = yearEra == HinduYearEra.vikramSamvat
        ? hDate.vsYear
        : hDate.shakaYear;
    final currentMonthIndex = service.hinduMonths.indexOf(hDate.masa);

    // Calculate era years for 1976 and 2076 (matching Gregorian range)
    int minYear;
    int maxYear;
    String eraName;

    if (yearEra == HinduYearEra.vikramSamvat) {
      minYear = 1976 + 57; // 2033 VS
      maxYear = 2076 + 57; // 2133 VS
      eraName = 'Vikram Samvat';
    } else {
      minYear = 1976 - 78; // 1898 Shaka
      maxYear = 2076 - 78; // 1998 Shaka
      eraName = 'Shaka Era';
    }

    if (!context.mounted) return;

    // Step 1: Select Year
    final selectedYear = await _showCustomYearPickerDialog(
      context,
      ref,
      currentYear,
      minYear,
      maxYear,
      eraName,
    );

    if (selectedYear == null) return;
    if (!context.mounted) return;

    // Step 2: Select Month
    final selectedMonthIndex = await _showHinduMonthPickerDialog(
      context,
      ref,
      service.hinduMonths,
      selectedYear == currentYear ? currentMonthIndex : 0,
      selectedYear,
      eraName,
    );

    if (selectedMonthIndex != null) {
      // Calculate the year difference
      final yearDiff = selectedYear - currentYear;
      final targetVsYear = hDate.vsYear + yearDiff;

      // Get the Gregorian date for the selected Hindu month
      final newDate = await service.getMonthStart(
        targetVsYear,
        selectedMonthIndex,
      );
      ref.read(cp.focusedMonthProvider.notifier).state = newDate;
    }
  }

  /// Bengali calendar year picker with month selection
  Future<void> _showBengaliYearPicker(
    BuildContext context,
    WidgetRef ref,
    DateTime focusedMonth,
  ) async {
    final service = ref.read(bengaliCalendarServiceProvider);
    await ref.read(panchangInitProvider.future);

    // Get current Bengali year for the focused month
    final bDate = await service.calculateDate(focusedMonth);
    final currentYear = bDate.year;
    final currentMonthIndex = service.bengaliMonths.indexOf(bDate.month);

    // Calculate Bengali years for 1976 and 2076 (matching Gregorian range)
    // Bengali Era = Gregorian - 594 (approximately, Bengali new year in mid-April)
    const minYear = 1976 - 594; // 1382 BE
    const maxYear = 2076 - 594; // 1482 BE

    if (!context.mounted) return;

    // Step 1: Select Year
    final selectedYear = await _showCustomYearPickerDialog(
      context,
      ref,
      currentYear,
      minYear,
      maxYear,
      'Bengali Era',
    );

    if (selectedYear == null) return;
    if (!context.mounted) return;

    // Step 2: Select Month
    final selectedMonthIndex = await _showBengaliMonthPickerDialog(
      context,
      ref,
      service.bengaliMonths,
      selectedYear == currentYear ? currentMonthIndex : 0,
      selectedYear,
    );

    if (selectedMonthIndex != null) {
      // Get the Gregorian date for the selected Bengali month
      final newDate = await service.getMonthStart(
        selectedYear,
        selectedMonthIndex,
      );
      ref.read(cp.focusedMonthProvider.notifier).state = newDate;
    }
  }

  /// Custom year picker dialog matching Flutter's native Material 3 year picker design
  Future<int?> _showCustomYearPickerDialog(
    BuildContext context,
    WidgetRef ref,
    int currentYear,
    int minYear,
    int maxYear,
    String eraName,
  ) async {
    final years = List.generate(maxYear - minYear + 1, (i) => minYear + i);
    final initialIndex = years.indexOf(currentYear);
    final scrollController = ScrollController(
      initialScrollOffset: ((initialIndex ~/ 3) * 52.0).clamp(
        0,
        double.infinity,
      ),
    );

    return showDialog<int>(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 328, maxHeight: 496),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header matching Material 3 date picker style
                Container(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Select year',
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(
                              color: context.colors.onSurface.withValues(
                                alpha: 0.6,
                              ),
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        eraName,
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w400),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                // Year grid
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    child: GridView.builder(
                      controller: scrollController,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            childAspectRatio: 2.0,
                            crossAxisSpacing: 8,
                            mainAxisSpacing: 8,
                          ),
                      itemCount: years.length,
                      itemBuilder: (context, index) {
                        final year = years[index];
                        final isSelected = year == currentYear;
                        return Material(
                          color: isSelected
                              ? context.colors.primary
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(20),
                          child: InkWell(
                            onTap: () {
                              if (ref
                                  .read(accessibilityProvider)
                                  .hapticFeedback) {
                                HapticFeedback.selectionClick();
                              }
                              Navigator.of(dialogContext).pop(year);
                            },
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                                border: isSelected
                                    ? null
                                    : Border.all(
                                        color: context.colors.outline
                                            .withValues(alpha: 0.3),
                                      ),
                              ),
                              child: Text(
                                '$year',
                                style: TextStyle(
                                  color: isSelected
                                      ? context.colors.onPrimary
                                      : context.colors.onSurface,
                                  fontWeight: isSelected
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                // Action buttons
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(dialogContext).pop(),
                        child: Text(
                          'Cancel',
                          style: TextStyle(color: context.colors.primary),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Hindu month picker dialog matching Material 3 design
  Future<int?> _showHinduMonthPickerDialog(
    BuildContext context,
    WidgetRef ref,
    List<String> months,
    int currentMonthIndex,
    int selectedYear,
    String eraName,
  ) async {
    return showDialog<int>(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 328, maxHeight: 440),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Select month',
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(
                              color: context.colors.onSurface.withValues(
                                alpha: 0.6,
                              ),
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$selectedYear $eraName',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w400),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                // Month grid
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    child: GridView.builder(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            childAspectRatio: 2.0,
                            crossAxisSpacing: 8,
                            mainAxisSpacing: 8,
                          ),
                      itemCount: months.length,
                      itemBuilder: (context, index) {
                        final month = months[index];
                        final isSelected = index == currentMonthIndex;
                        return Material(
                          color: isSelected
                              ? context.colors.primary
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(20),
                          child: InkWell(
                            onTap: () {
                              if (ref
                                  .read(accessibilityProvider)
                                  .hapticFeedback) {
                                HapticFeedback.selectionClick();
                              }
                              Navigator.of(dialogContext).pop(index);
                            },
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                                border: isSelected
                                    ? null
                                    : Border.all(
                                        color: context.colors.outline
                                            .withValues(alpha: 0.3),
                                      ),
                              ),
                              child: Text(
                                month,
                                style: TextStyle(
                                  color: isSelected
                                      ? context.colors.onPrimary
                                      : context.colors.onSurface,
                                  fontWeight: isSelected
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                  fontSize: 13,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                // Action buttons
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(dialogContext).pop(),
                        child: Text(
                          'Cancel',
                          style: TextStyle(color: context.colors.primary),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Bengali month picker dialog matching Material 3 design
  Future<int?> _showBengaliMonthPickerDialog(
    BuildContext context,
    WidgetRef ref,
    List<String> months,
    int currentMonthIndex,
    int selectedYear,
  ) async {
    return showDialog<int>(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 328, maxHeight: 440),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Select month',
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(
                              color: context.colors.onSurface.withValues(
                                alpha: 0.6,
                              ),
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$selectedYear বঙ্গাব্দ',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w400),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                // Month grid
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    child: GridView.builder(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            childAspectRatio: 2.0,
                            crossAxisSpacing: 8,
                            mainAxisSpacing: 8,
                          ),
                      itemCount: months.length,
                      itemBuilder: (context, index) {
                        final month = months[index];
                        final isSelected = index == currentMonthIndex;
                        return Material(
                          color: isSelected
                              ? context.colors.primary
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(20),
                          child: InkWell(
                            onTap: () {
                              if (ref
                                  .read(accessibilityProvider)
                                  .hapticFeedback) {
                                HapticFeedback.selectionClick();
                              }
                              Navigator.of(dialogContext).pop(index);
                            },
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                                border: isSelected
                                    ? null
                                    : Border.all(
                                        color: context.colors.outline
                                            .withValues(alpha: 0.3),
                                      ),
                              ),
                              child: Text(
                                month,
                                style: TextStyle(
                                  color: isSelected
                                      ? context.colors.onPrimary
                                      : context.colors.onSurface,
                                  fontWeight: isSelected
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                  fontSize: 13,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                // Action buttons
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(dialogContext).pop(),
                        child: Text(
                          'Cancel',
                          style: TextStyle(color: context.colors.primary),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Navigate to the previous month based on the calendar system
  void _navigateToPreviousMonth(
    WidgetRef ref,
    DateTime focusedMonth,
    cp.AppCalendarSystem primarySystem,
  ) async {
    if (ref.read(accessibilityProvider).hapticFeedback) {
      await HapticFeedback.selectionClick();
    }

    if (primarySystem == cp.AppCalendarSystem.bengali) {
      // Navigate by Bengali Month
      final service = ref.read(bengaliCalendarServiceProvider);
      await ref.read(panchangInitProvider.future);
      final bDate = await service.calculateDate(focusedMonth);
      final bIndex = service.bengaliMonths.indexOf(bDate.month);
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
      final hIndex = service.hinduMonths.indexOf(hDate.masa);
      var newIndex = hIndex - 1;
      var newYear = hDate.vsYear;
      if (newIndex < 0) {
        newIndex = 11;
        newYear--;
      }
      final newDate = await service.getMonthStart(newYear, newIndex);
      ref.read(cp.focusedMonthProvider.notifier).state = newDate;
    } else {
      ref.read(cp.focusedMonthProvider.notifier).state = DateTime(
        focusedMonth.year,
        focusedMonth.month - 1,
      );
    }
  }

  /// Navigate to the next month based on the calendar system
  void _navigateToNextMonth(
    WidgetRef ref,
    DateTime focusedMonth,
    cp.AppCalendarSystem primarySystem,
  ) async {
    if (ref.read(accessibilityProvider).hapticFeedback) {
      await HapticFeedback.selectionClick();
    }

    if (primarySystem == cp.AppCalendarSystem.bengali) {
      // Navigate by Bengali Month
      final service = ref.read(bengaliCalendarServiceProvider);
      await ref.read(panchangInitProvider.future);
      final bDate = await service.calculateDate(focusedMonth);
      final bIndex = service.bengaliMonths.indexOf(bDate.month);
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
      var newIndex = hIndex + 1;
      var newYear = hDate.vsYear;
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
  }

  /// Optimized festival marker using pre-loaded monthly panchang cache
  Widget? _buildFestivalMarkerFromCache(
    BuildContext context,
    DateTime date,
    Map<DateTime, PanchangData> monthlyPanchang,
  ) {
    final normalizedDate = DateTime(date.year, date.month, date.day);
    final panchang = monthlyPanchang[normalizedDate];

    if (panchang == null || !panchang.hasFestivals) return null;

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
  }
}

/// Data class to hold header information for the calendar
class _HeaderData {
  final String primaryText;
  final String? secondaryText;

  _HeaderData({required this.primaryText, this.secondaryText});
}

class _CalendarHeader extends ConsumerWidget {
  final DateTime focusedMonth;
  final VoidCallback onLeftChevronTap;
  final VoidCallback onRightChevronTap;
  final VoidCallback onYearTap;

  const _CalendarHeader({
    required this.focusedMonth,
    required this.onLeftChevronTap,
    required this.onRightChevronTap,
    required this.onYearTap,
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
            child: GestureDetector(
              onTap: onYearTap,
              child: FutureBuilder<_HeaderData>(
                future: _getHeaderData(
                  ref,
                  focusedMonth,
                  primarySystem,
                  secondarySystem,
                ),
                initialData: _HeaderData(
                  primaryText: _formatGregorian(focusedMonth),
                ),
                builder: (context, snapshot) {
                  final data =
                      snapshot.data ??
                      _HeaderData(primaryText: _formatGregorian(focusedMonth));
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Column with primary and secondary text
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Row 1: Primary calendar date
                          Text(
                            data.primaryText,
                            style: context.textTheme.headlineMedium!.copyWith(
                              fontSize: 18,
                            ),
                          ),
                          // Row 2: Secondary calendar info
                          if (data.secondaryText != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              data.secondaryText!,
                              style: context.textTheme.bodySmall!.copyWith(
                                color: context.colors.onSurface.withValues(
                                  alpha: 0.7,
                                ),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ],
                      ),
                      // Dropdown icon outside the column for proper alignment
                      Icon(
                        Icons.arrow_drop_down,
                        size: 20,
                        color: context.colors.primary,
                      ),
                    ],
                  );
                },
              ),
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

  /// Data class for header display with primary and secondary text
  Future<_HeaderData> _getHeaderData(
    WidgetRef ref,
    DateTime date,
    cp.AppCalendarSystem primary,
    cp.AppCalendarSystem secondary,
  ) async {
    String primaryText;
    String? secondaryText;

    // Get the primary header text
    primaryText = await _getSystemHeaderText(ref, date, primary);

    if (primary == cp.AppCalendarSystem.gregorian) {
      // For Gregorian primary, show month range from secondary (Bengali/Hindu) calendar
      final monthRange = await _getTraditionalMonthRange(ref, date, secondary);
      if (monthRange != null) {
        secondaryText = monthRange;
      }
    } else if ((primary == cp.AppCalendarSystem.hindu ||
            primary == cp.AppCalendarSystem.bengali) &&
        secondary == cp.AppCalendarSystem.gregorian) {
      // For Hindu/Bengali primary with Gregorian secondary, show Gregorian month range
      final monthRange = await _getGregorianMonthRange(ref, date, primary);
      if (monthRange != null) {
        secondaryText = monthRange;
      }
    } else if (secondary != cp.AppCalendarSystem.none && secondary != primary) {
      // For other cases, show secondary calendar info
      secondaryText = await _getSystemHeaderText(ref, date, secondary);
    }

    return _HeaderData(primaryText: primaryText, secondaryText: secondaryText);
  }

  /// Gets the range of traditional (Bengali/Hindu) months that span the given Gregorian month
  Future<String?> _getTraditionalMonthRange(
    WidgetRef ref,
    DateTime date,
    cp.AppCalendarSystem system,
  ) async {
    if (system != cp.AppCalendarSystem.bengali &&
        system != cp.AppCalendarSystem.hindu) {
      return null;
    }

    try {
      // Get start and end of Gregorian month
      final startOfMonth = DateTime(date.year, date.month);
      final endOfMonth = DateTime(date.year, date.month + 1, 0); // Last day

      String startMonth;
      String endMonth;
      int startYear;
      int endYear;

      if (system == cp.AppCalendarSystem.bengali) {
        final service = ref.read(bengaliCalendarServiceProvider);
        await ref.read(panchangInitProvider.future);

        final startBDate = await service.calculateDate(startOfMonth);
        final endBDate = await service.calculateDate(endOfMonth);

        startMonth = startBDate.month;
        endMonth = endBDate.month;
        startYear = startBDate.year;
        endYear = endBDate.year;

        if (startMonth == endMonth && startYear == endYear) {
          return '$startMonth $startYear';
        } else if (startYear == endYear) {
          return '$startMonth - $endMonth $startYear';
        } else {
          return '$startMonth $startYear - $endMonth $endYear';
        }
      } else if (system == cp.AppCalendarSystem.hindu) {
        final service = ref.read(hinduCalendarServiceProvider);
        await ref.read(panchangInitProvider.future);

        final startHDate = await service.calculateDate(startOfMonth);
        final endHDate = await service.calculateDate(endOfMonth);

        startMonth = startHDate.masa;
        endMonth = endHDate.masa;

        // Use year era preference for display
        final yearEra = ref.read(cp.hinduYearEraProvider);
        startYear = yearEra == HinduYearEra.vikramSamvat
            ? startHDate.vsYear
            : startHDate.shakaYear;
        endYear = yearEra == HinduYearEra.vikramSamvat
            ? endHDate.vsYear
            : endHDate.shakaYear;

        if (startMonth == endMonth && startYear == endYear) {
          return '$startMonth $startYear';
        } else if (startYear == endYear) {
          return '$startMonth - $endMonth $startYear';
        } else {
          return '$startMonth $startYear - $endMonth $endYear';
        }
      }
    } catch (_) {
      return null;
    }

    return null;
  }

  /// Gets the range of Gregorian months that span the given Hindu/Bengali month
  Future<String?> _getGregorianMonthRange(
    WidgetRef ref,
    DateTime date,
    cp.AppCalendarSystem primarySystem,
  ) async {
    if (primarySystem != cp.AppCalendarSystem.bengali &&
        primarySystem != cp.AppCalendarSystem.hindu) {
      return null;
    }

    try {
      const gregorianMonths = [
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

      DateTime startDate;
      DateTime endDate;

      if (primarySystem == cp.AppCalendarSystem.bengali) {
        final service = ref.read(bengaliCalendarServiceProvider);
        await ref.read(panchangInitProvider.future);

        // Get current Bengali month info from the focused date
        final bDate = await service.calculateDate(date);
        final monthIndex = service.bengaliMonths.indexOf(bDate.month);
        final year = bDate.year;

        // Get start of current Bengali month
        startDate = await service.getMonthStart(year, monthIndex);

        // Get start of next Bengali month (end of current)
        var nextIndex = monthIndex + 1;
        var nextYear = year;
        if (nextIndex > 11) {
          nextIndex = 0;
          nextYear++;
        }
        endDate = await service.getMonthStart(nextYear, nextIndex);
        endDate = endDate.subtract(
          const Duration(days: 1),
        ); // Last day of current
      } else {
        // Hindu calendar
        final service = ref.read(hinduCalendarServiceProvider);
        await ref.read(panchangInitProvider.future);

        // Get current Hindu month info from the focused date
        final hDate = await service.calculateDate(date);
        final monthIndex = service.hinduMonths.indexOf(hDate.masa);
        final year = hDate.vsYear;

        // Get start of current Hindu month
        startDate = await service.getMonthStart(year, monthIndex);

        // Get start of next Hindu month (end of current)
        var nextIndex = monthIndex + 1;
        var nextYear = year;
        if (nextIndex > 11) {
          nextIndex = 0;
          nextYear++;
        }
        endDate = await service.getMonthStart(nextYear, nextIndex);
        endDate = endDate.subtract(
          const Duration(days: 1),
        ); // Last day of current
      }

      final startMonth = gregorianMonths[startDate.month - 1];
      final endMonth = gregorianMonths[endDate.month - 1];
      final startYear = startDate.year;
      final endYear = endDate.year;

      if (startMonth == endMonth && startYear == endYear) {
        return '$startMonth $startYear';
      } else if (startYear == endYear) {
        return '$startMonth - $endMonth $startYear';
      } else {
        return '$startMonth $startYear - $endMonth $endYear';
      }
    } catch (_) {
      return null;
    }
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
          // Use year era preference for display
          final yearEra = ref.read(cp.hinduYearEraProvider);
          final displayYear = yearEra == HinduYearEra.vikramSamvat
              ? hDate.vsYear
              : hDate.shakaYear;
          return '${hDate.masa} $displayYear';
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
          final displayMode = ref.read(cp.tithiDisplayModeProvider);
          if (displayMode == cp.TithiDisplayMode.continuous30) {
            return hDate.fullTithi.toString();
          }
          return hDate.tithi.toString();
        } catch (e) {
          return date.day.toString();
        }
      case cp.AppCalendarSystem.bengali:
        try {
          final service = ref.read(bengaliCalendarServiceProvider);
          await ref.read(panchangInitProvider.future);
          final bengaliDate = await service.calculateDate(date);
          return bengaliDate.day.toString();
        } catch (e) {
          return date.day.toString();
        }
      case cp.AppCalendarSystem.none:
        return '';
    }
  }
}
