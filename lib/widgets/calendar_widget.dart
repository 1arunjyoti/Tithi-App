import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';
import '../l10n/app_localizations.dart';
import '../providers/calendar_provider.dart' as cp;
import '../providers/panchang_provider.dart';
import '../providers/accessibility_provider.dart';
import '../services/bengali_calendar_service.dart';
import '../services/hindu_calendar_service.dart';
import '../models/hindu_month_system.dart';
import '../models/panchang_data.dart';
import '../theme/app_theme.dart';

class _CalendarCellData {
  final String primary;
  final String? secondary;
  final bool hasFestivals;
  final bool hasMajorFestival;

  const _CalendarCellData({
    required this.primary,
    this.secondary,
    this.hasFestivals = false,
    this.hasMajorFestival = false,
  });
}

class _AdaptiveCalendarData {
  final List<DateTime?> days;
  final Map<DateTime, _CalendarCellData> cellData;

  const _AdaptiveCalendarData({required this.days, required this.cellData});
}

// Sync LRU for secondary corner labels (top-left of each date cell).
// Lets cells show a stale secondary instantly while the next month's
// FutureProvider is still loading, and makes neighbor precache pay off
// even when adaptive month keys differ by a few days.
final Map<String, String> _secondaryDayCache = {};
const int _secondaryDayCacheMax = 600;
final Set<String> _precachedMonthKeys = {};

String _secondaryCacheKey(
  DateTime date,
  cp.AppCalendarSystem system,
  cp.TithiDisplayMode displayMode,
) {
  return '${date.year}-${date.month}-${date.day}_${system.index}_${displayMode.index}';
}

String? _cachedSecondarySync(
  DateTime date,
  cp.AppCalendarSystem system,
  cp.TithiDisplayMode displayMode,
) {
  if (system == cp.AppCalendarSystem.none ||
      system == cp.AppCalendarSystem.gregorian) {
    return null;
  }
  return _secondaryDayCache[_secondaryCacheKey(date, system, displayMode)];
}

void _storeSecondarySync(
  DateTime date,
  cp.AppCalendarSystem system,
  cp.TithiDisplayMode displayMode,
  String value,
) {
  if (system == cp.AppCalendarSystem.none ||
      system == cp.AppCalendarSystem.gregorian) {
    return;
  }
  if (_secondaryDayCache.length >= _secondaryDayCacheMax) {
    final toRemove = _secondaryDayCache.keys
        .take(_secondaryDayCacheMax ~/ 5)
        .toList();
    for (final k in toRemove) {
      _secondaryDayCache.remove(k);
    }
  }
  _secondaryDayCache[_secondaryCacheKey(date, system, displayMode)] = value;
}

String _monthPrecacheKey(
  DateTime month,
  cp.StartingDayOfWeek startOfWeek,
  cp.AppCalendarSystem primary,
  cp.AppCalendarSystem secondary,
  cp.TithiDisplayMode displayMode,
) {
  return '${month.year}-${month.month}-${month.day}_${startOfWeek.index}_${primary.index}_${secondary.index}_${displayMode.index}';
}

Future<String> _calendarDateForSystem(
  Ref ref,
  DateTime date,
  cp.AppCalendarSystem system,
  cp.TithiDisplayMode displayMode,
) async {
  switch (system) {
    case cp.AppCalendarSystem.gregorian:
      return date.day.toString();
    case cp.AppCalendarSystem.hindu:
      final cached = _cachedSecondarySync(date, system, displayMode);
      if (cached != null) return cached;
      try {
        final service = ref.read(hinduCalendarServiceProvider);
        final hDate = await service.calculateDate(date);
        final result = displayMode == cp.TithiDisplayMode.continuous30
            ? hDate.fullTithi.toString()
            : hDate.tithi.toString();
        _storeSecondarySync(date, system, displayMode, result);
        return result;
      } catch (_) {
        return date.day.toString();
      }
    case cp.AppCalendarSystem.bengali:
      final cached = _cachedSecondarySync(date, system, displayMode);
      if (cached != null) return cached;
      try {
        final service = ref.read(bengaliCalendarServiceProvider);
        final bengaliDate = await service.calculateDate(date);
        final result = bengaliDate.day.toString();
        _storeSecondarySync(date, system, displayMode, result);
        return result;
      } catch (_) {
        return date.day.toString();
      }
    case cp.AppCalendarSystem.none:
      return '';
  }
}

Future<Map<DateTime, _CalendarCellData>> _buildCalendarCellData(
  Ref ref,
  List<DateTime> dates,
  cp.AppCalendarSystem primary,
  cp.AppCalendarSystem secondary,
  cp.TithiDisplayMode displayMode, {
  bool includeFestivals = true,
}) async {
  final needsHinduInit =
      primary == cp.AppCalendarSystem.hindu ||
      secondary == cp.AppCalendarSystem.hindu ||
      primary == cp.AppCalendarSystem.bengali ||
      secondary == cp.AppCalendarSystem.bengali;
  if (needsHinduInit) {
    await ref.read(panchangInitProvider.future);
  }

  // PERF-2: Compute all dates in parallel instead of sequentially.
  final entries = await Future.wait(dates.map((date) async {
    final normalizedDate = DateTime(date.year, date.month, date.day);
    final pDate = await _calendarDateForSystem(
      ref,
      normalizedDate,
      primary,
      displayMode,
    );
    String? sDate;
    if (secondary != cp.AppCalendarSystem.none && secondary != primary) {
      sDate = await _calendarDateForSystem(
        ref,
        normalizedDate,
        secondary,
        displayMode,
      );
    }

    // Fetch festival info for this date so the adaptive grid has it.
    // Skipped on the Gregorian path: markers there come from
    // monthlyPanchangProvider, so per-date panchang fetches would only
    // burn FFI cycles during the swipe animation.
    bool hasFestivals = false;
    bool hasMajorFestival = false;
    if (includeFestivals) {
      try {
        final panchang = await ref.read(
          panchangForDateProvider(normalizedDate).future,
        );
        hasFestivals = panchang.hasFestivals;
        hasMajorFestival = panchang.majorFestivals.isNotEmpty;
      } catch (_) {}
    }

    return MapEntry(
      normalizedDate,
      _CalendarCellData(
        primary: pDate,
        secondary: sDate,
        hasFestivals: hasFestivals,
        hasMajorFestival: hasMajorFestival,
      ),
    );
  }));

  return Map.fromEntries(entries);
}

final gregorianCalendarCellDataProvider =
    FutureProvider.family<
      Map<DateTime, _CalendarCellData>,
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

      return _buildCalendarCellData(
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

final adaptiveCalendarDataProvider =
    FutureProvider.family<
      _AdaptiveCalendarData,
      ({
        DateTime focusedMonth,
        cp.StartingDayOfWeek startOfWeek,
        cp.AppCalendarSystem adaptiveSystem,
        cp.AppCalendarSystem primarySystem,
        cp.AppCalendarSystem secondarySystem,
        cp.TithiDisplayMode displayMode,
      })
    >((ref, args) async {
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
        final service = ref.read(hinduCalendarServiceProvider);
        final hDate = await service.calculateDate(args.focusedMonth);
        final monthIndex = service.hinduMonths.indexOf(
          service.baseMasaName(hDate.masa),
        );
        final year = hDate.vsYear;
        startDate = await service.getMonthStart(year, monthIndex);

        var nextIndex = monthIndex + 1;
        var nextYear = year;
        if (nextIndex > 11) {
          nextIndex = 0;
          nextYear++;
        }
        nextMonthStart = await service.getMonthStart(nextYear, nextIndex);
      }

      final daysInMonth = nextMonthStart.difference(startDate).inDays;
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

      final cellData = await _buildCalendarCellData(
        ref,
        visibleDates,
        args.primarySystem,
        args.secondarySystem,
        args.displayMode,
      );

      return _AdaptiveCalendarData(days: grid, cellData: cellData);
    });

/// Pre-computes secondary corner labels for adjacent months so sliding
/// feels instant. Delayed well past the page animation, sequential (next
/// then previous) to avoid FFI bursts on the UI thread, stale-guarded so
/// rapid swipes don't pile up obsolete work, and never throws into the UI.
void _scheduleAdjacentPrecache(
  WidgetRef ref,
  DateTime focusedMonth,
  cp.StartingDayOfWeek startOfWeek,
  cp.AppCalendarSystem primarySystem,
  cp.AppCalendarSystem secondarySystem,
  cp.TithiDisplayMode displayMode,
) {
  // No corner labels to precompute when secondary is off.
  if (secondarySystem == cp.AppCalendarSystem.none) return;

  final isAdaptive =
      primarySystem == cp.AppCalendarSystem.bengali ||
      primarySystem == cp.AppCalendarSystem.hindu;
  final scheduledYear = focusedMonth.year;
  final scheduledMonth = focusedMonth.month;

  bool isStale() {
    try {
      final current = ref.read(cp.focusedMonthProvider);
      return current.year != scheduledYear ||
          current.month != scheduledMonth ||
          ref.read(cp.primaryCalendarSystemProvider) != primarySystem ||
          ref.read(cp.secondaryCalendarSystemProvider) != secondarySystem ||
          ref.read(cp.tithiDisplayModeProvider) != displayMode ||
          ref.read(cp.startOfWeekProvider) != startOfWeek;
    } catch (_) {
      return true;
    }
  }

  WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(
      Future.delayed(const Duration(milliseconds: 800), () async {
        try {
          if (isStale()) return;
          if (isAdaptive) {
            await _precacheAdaptiveNeighbors(
              ref,
              focusedMonth,
              startOfWeek,
              primarySystem,
              secondarySystem,
              displayMode,
              isStale,
            );
          } else {
            await _precacheGregorianNeighbors(
              ref,
              focusedMonth,
              startOfWeek,
              primarySystem,
              secondarySystem,
              displayMode,
              isStale,
            );
          }
        } catch (_) {
          // Precache is best-effort only.
        }
      }),
    );
  });
}

Future<void> _precacheGregorianNeighbors(
  WidgetRef ref,
  DateTime focusedMonth,
  cp.StartingDayOfWeek startOfWeek,
  cp.AppCalendarSystem primarySystem,
  cp.AppCalendarSystem secondarySystem,
  cp.TithiDisplayMode displayMode,
  bool Function() isStale,
) async {
  // Next month first (more likely swipe direction), then previous.
  final neighbors = [
    DateTime(focusedMonth.year, focusedMonth.month + 1),
    DateTime(focusedMonth.year, focusedMonth.month - 1),
  ];
  for (final month in neighbors) {
    if (isStale()) return;
    final key = _monthPrecacheKey(
      month,
      startOfWeek,
      primarySystem,
      secondarySystem,
      displayMode,
    );
    if (!_precachedMonthKeys.add(key)) continue;
    try {
      await ref.read(
        gregorianCalendarCellDataProvider((
          focusedMonth: month,
          startOfWeek: startOfWeek,
          primarySystem: primarySystem,
          secondarySystem: secondarySystem,
          displayMode: displayMode,
        )).future,
      );
    } catch (_) {
      _precachedMonthKeys.remove(key);
    }
  }
}

/// Resolves the exact prev/next lunar month starts (same logic as chevron
/// navigation) and precaches those exact provider keys so the next swipe hits.
Future<void> _precacheAdaptiveNeighbors(
  WidgetRef ref,
  DateTime focusedMonth,
  cp.StartingDayOfWeek startOfWeek,
  cp.AppCalendarSystem primarySystem,
  cp.AppCalendarSystem secondarySystem,
  cp.TithiDisplayMode displayMode,
  bool Function() isStale,
) async {
  await ref.read(panchangInitProvider.future);

  final targets = <DateTime>[];
  try {
    if (primarySystem == cp.AppCalendarSystem.bengali) {
      final service = ref.read(bengaliCalendarServiceProvider);
      final bDate = await service.calculateDate(focusedMonth);
      final bIndex = service.bengaliMonths.indexOf(bDate.month);
      if (bIndex < 0) return;
      for (final delta in [-1, 1]) {
        var idx = bIndex + delta;
        var year = bDate.year;
        if (idx < 0) {
          idx = 11;
          year--;
        } else if (idx > 11) {
          idx = 0;
          year++;
        }
        targets.add(await service.getMonthStart(year, idx));
      }
    } else if (primarySystem == cp.AppCalendarSystem.hindu) {
      final service = ref.read(hinduCalendarServiceProvider);
      final hDate = await service.calculateDate(focusedMonth);
      final hIndex = service.hinduMonths.indexOf(
        service.baseMasaName(hDate.masa),
      );
      if (hIndex < 0) return;
      for (final delta in [-1, 1]) {
        var idx = hIndex + delta;
        var year = hDate.vsYear;
        if (idx < 0) {
          idx = 11;
          year--;
        } else if (idx > 11) {
          idx = 0;
          year++;
        }
        targets.add(await service.getMonthStart(year, idx));
      }
    }
  } catch (_) {
    return;
  }

  for (final target in targets) {
    if (isStale()) return;
    final key = _monthPrecacheKey(
      target,
      startOfWeek,
      primarySystem,
      secondarySystem,
      displayMode,
    );
    if (!_precachedMonthKeys.add(key)) continue;
    try {
      await ref.read(
        adaptiveCalendarDataProvider((
          focusedMonth: target,
          startOfWeek: startOfWeek,
          adaptiveSystem: primarySystem,
          primarySystem: primarySystem,
          secondarySystem: secondarySystem,
          displayMode: displayMode,
        )).future,
      );
    } catch (_) {
      _precachedMonthKeys.remove(key);
    }
  }
}

/// Calendar widget using TableCalendar with Tithi markers
class CalendarWidget extends ConsumerWidget {
  const CalendarWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedDate = ref.watch(cp.selectedDateProvider);
    final focusedMonth = ref.watch(cp.focusedMonthProvider);
    final startOfWeek = ref.watch(cp.startOfWeekProvider);
    final primarySystem = ref.watch(cp.primaryCalendarSystemProvider);
    final secondarySystem = ref.watch(cp.secondaryCalendarSystemProvider);
    final displayMode = ref.watch(cp.tithiDisplayModeProvider);

    // Pre-load entire month's panchang data to eliminate N+1 query pattern
    final monthlyPanchangAsync = ref.watch(
      monthlyPanchangProvider(focusedMonth),
    );
    final monthlyPanchang = monthlyPanchangAsync.when(
      data: (data) => data,
      loading: () => <DateTime, PanchangData>{},
      error: (_, _) => <DateTime, PanchangData>{},
    );

    final gregorianCellDataAsync = ref.watch(
      gregorianCalendarCellDataProvider((
        focusedMonth: focusedMonth,
        startOfWeek: startOfWeek,
        primarySystem: primarySystem,
        secondarySystem: secondarySystem,
        displayMode: displayMode,
      )),
    );

    // Best-effort precache of neighbor months' secondary corner labels.
    _scheduleAdjacentPrecache(
      ref,
      focusedMonth,
      startOfWeek,
      primarySystem,
      secondarySystem,
      displayMode,
    );

    return Container(
      margin: const EdgeInsets.all(12),
      decoration: AppTheme.glassmorphism(context: context, ref: ref),
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
            // Adaptive grid has no internal PageView, so swipe is handled here.
            GestureDetector(
              onHorizontalDragEnd: (details) {
                if (details.primaryVelocity != null) {
                  if (details.primaryVelocity! < -300) {
                    _navigateToNextMonth(ref, focusedMonth, primarySystem);
                  } else if (details.primaryVelocity! > 300) {
                    _navigateToPreviousMonth(ref, focusedMonth, primarySystem);
                  }
                }
              },
              child: ref
                  .watch(
                    adaptiveCalendarDataProvider((
                      focusedMonth: focusedMonth,
                      startOfWeek: startOfWeek,
                      adaptiveSystem: primarySystem,
                      primarySystem: primarySystem,
                      secondarySystem: secondarySystem,
                      displayMode: displayMode,
                    )),
                  )
                  .when(
                    data: (adaptiveData) => _buildAdaptiveGrid(
                      context,
                      ref,
                      startOfWeek,
                      monthlyPanchang,
                      adaptiveData,
                      secondarySystem,
                      displayMode,
                    ),
                    loading: () => const SizedBox(
                      height: 300,
                      child: Center(child: CircularProgressIndicator()),
                    ),
                    error: (_, _) => const SizedBox.shrink(),
                  ),
            )
          else
            // Gregorian path: TableCalendar owns the horizontal swipe via its
            // internal PageView. No outer GestureDetector here — a competing
            // drag handler makes the page stick/jitter mid-swipe.
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
                  ref.read(cp.selectedDateProvider.notifier).setDate(selected);
                  ref
                      .read(cp.focusedMonthProvider.notifier)
                      .setFocusedMonth(focused);
                },
                onPageChanged: (focusedDay) {
                  ref
                      .read(cp.focusedMonthProvider.notifier)
                      .setFocusedMonth(focusedDay);
                },
                headerVisible: false, // Hide default header
                calendarBuilders: CalendarBuilders(
                  defaultBuilder: (context, date, _) {
                    final normalizedDate = DateTime(
                      date.year,
                      date.month,
                      date.day,
                    );
                    final cellData = gregorianCellDataAsync.maybeWhen(
                      data: (data) => data[normalizedDate],
                      orElse: () => null,
                    );
                    return _CalendarCell(
                      date: date,
                      isSelected: false,
                      isToday: false,
                      primaryText: cellData?.primary ?? date.day.toString(),
                      secondaryText:
                          cellData?.secondary ??
                          _cachedSecondarySync(
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
                    final cellData = gregorianCellDataAsync.maybeWhen(
                      data: (data) => data[normalizedDate],
                      orElse: () => null,
                    );
                    return _CalendarCell(
                      date: date,
                      isSelected: true,
                      isToday: isSameDay(date, DateTime.now()),
                      primaryText: cellData?.primary ?? date.day.toString(),
                      secondaryText:
                          cellData?.secondary ??
                          _cachedSecondarySync(
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
                    final cellData = gregorianCellDataAsync.maybeWhen(
                      data: (data) => data[normalizedDate],
                      orElse: () => null,
                    );
                    return _CalendarCell(
                      date: date,
                      isSelected: false,
                      isToday: true,
                      primaryText: cellData?.primary ?? date.day.toString(),
                      secondaryText:
                          cellData?.secondary ??
                          _cachedSecondarySync(
                            normalizedDate,
                            secondarySystem,
                            displayMode,
                          ),
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
    );
  }

  Widget _buildAdaptiveGrid(
    BuildContext context,
    WidgetRef ref,
    cp.StartingDayOfWeek startOfWeek,
    Map<DateTime, PanchangData> monthlyPanchang,
    _AdaptiveCalendarData adaptiveData,
    cp.AppCalendarSystem secondarySystem,
    cp.TithiDisplayMode displayMode,
  ) {
    final days = adaptiveData.days;
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
                      color: context.colors.onSurface.withValues(alpha: 0.7),
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

            final normalizedDate = DateTime(date.year, date.month, date.day);
            final cellData = adaptiveData.cellData[normalizedDate];
            // Festival info is embedded in cellData (from adaptive provider)
            // which uses the correct lunar date range — no Gregorian mismatch.
            final hasFestivals = cellData?.hasFestivals ?? false;
            final hasMajorFestival = cellData?.hasMajorFestival ?? false;

            return GestureDetector(
              onTap: () {
                if (ref.read(accessibilityProvider).hapticFeedback) {
                  HapticFeedback.selectionClick();
                }
                ref.read(cp.selectedDateProvider.notifier).setDate(date);
              },
              child: Stack(
                children: [
                  _CalendarCell(
                    date: date,
                    isSelected: isSelected,
                    isToday: isToday,
                    primaryText: cellData?.primary ?? date.day.toString(),
                    secondaryText:
                        cellData?.secondary ??
                        _cachedSecondarySync(
                          normalizedDate,
                          secondarySystem,
                          displayMode,
                        ),
                  ),
                  if (hasFestivals)
                    _buildFestivalDot(context, hasMajorFestival),
                ],
              ),
            );
          },
        ),
      ],
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
    if (!context.mounted) return;

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
      ref
          .read(cp.focusedMonthProvider.notifier)
          .setFocusedMonth(DateTime(selectedDate.year, focusedMonth.month));
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
    final currentMonthIndex = service.hinduMonths.indexOf(
      service.baseMasaName(hDate.masa),
    );

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
      ref.read(cp.focusedMonthProvider.notifier).setFocusedMonth(newDate);
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
      ref.read(cp.focusedMonthProvider.notifier).setFocusedMonth(newDate);
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

    try {
      return await showDialog<int>(
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
    } finally {
      scrollController.dispose();
    }
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
    return _showAdaptiveMonthPickerDialog(
      context,
      ref,
      months,
      currentMonthIndex,
      '$selectedYear $eraName',
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
    return _showAdaptiveMonthPickerDialog(
      context,
      ref,
      months,
      currentMonthIndex,
      '$selectedYear বঙ্গাব্দ',
    );
  }

  Future<int?> _showAdaptiveMonthPickerDialog(
    BuildContext context,
    WidgetRef ref,
    List<String> months,
    int currentMonthIndex,
    String yearLabel,
  ) async {
    return showDialog<int>(
      context: context,
      builder: (dialogContext) {
        final materialL10n = MaterialLocalizations.of(context);
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
                        AppLocalizations.of(context)!.selectMonth,
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(
                              color: context.colors.onSurface.withValues(
                                alpha: 0.6,
                              ),
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        yearLabel,
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
                          materialL10n.cancelButtonLabel,
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
      ref.read(cp.focusedMonthProvider.notifier).setFocusedMonth(newDate);
    } else if (primarySystem == cp.AppCalendarSystem.hindu) {
      // Navigate by Hindu Lunar Month
      final service = ref.read(hinduCalendarServiceProvider);
      await ref.read(panchangInitProvider.future);
      final hDate = await service.calculateDate(focusedMonth);
      final hIndex = service.hinduMonths.indexOf(
        service.baseMasaName(hDate.masa),
      );
      var newIndex = hIndex - 1;
      var newYear = hDate.vsYear;
      if (newIndex < 0) {
        newIndex = 11;
        newYear--;
      }
      final newDate = await service.getMonthStart(newYear, newIndex);
      ref.read(cp.focusedMonthProvider.notifier).setFocusedMonth(newDate);
    } else {
      ref
          .read(cp.focusedMonthProvider.notifier)
          .setFocusedMonth(DateTime(focusedMonth.year, focusedMonth.month - 1));
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
      ref.read(cp.focusedMonthProvider.notifier).setFocusedMonth(newDate);
    } else if (primarySystem == cp.AppCalendarSystem.hindu) {
      final service = ref.read(hinduCalendarServiceProvider);
      await ref.read(panchangInitProvider.future);
      final hDate = await service.calculateDate(focusedMonth);
      final hIndex = service.hinduMonths.indexOf(
        service.baseMasaName(hDate.masa),
      );
      var newIndex = hIndex + 1;
      var newYear = hDate.vsYear;
      if (newIndex > 11) {
        newIndex = 0;
        newYear++;
      }
      final newDate = await service.getMonthStart(newYear, newIndex);
      ref.read(cp.focusedMonthProvider.notifier).setFocusedMonth(newDate);
    } else {
      ref
          .read(cp.focusedMonthProvider.notifier)
          .setFocusedMonth(DateTime(focusedMonth.year, focusedMonth.month + 1));
    }
  }

  /// Optimized festival marker using pre-loaded monthly panchang cache
  /// Used by the Gregorian TableCalendar path.
  Widget? _buildFestivalMarkerFromCache(
    BuildContext context,
    DateTime date,
    Map<DateTime, PanchangData> monthlyPanchang,
  ) {
    final normalizedDate = DateTime(date.year, date.month, date.day);
    final panchang = monthlyPanchang[normalizedDate];

    if (panchang == null || !panchang.hasFestivals) return null;

    return _buildFestivalDot(context, panchang.majorFestivals.isNotEmpty);
  }

  /// Festival dot marker for use in the adaptive (Hindu/Bengali) grid.
  /// Takes pre-resolved flags from cellData so no Gregorian date-range mismatch.
  Widget _buildFestivalDot(BuildContext context, bool isMajor) {
    return Positioned(
      bottom: 1,
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: isMajor ? context.colors.primary : context.colors.secondary,
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

final calendarHeaderDataProvider = FutureProvider<_HeaderData>((ref) async {
  final date = ref.watch(cp.focusedMonthProvider);
  final primary = ref.watch(cp.primaryCalendarSystemProvider);
  final secondary = ref.watch(cp.secondaryCalendarSystemProvider);
  final hinduYearEra = ref.watch(cp.hinduYearEraProvider);
  final hinduMonthSystem = ref.watch(cp.hinduMonthSystemProvider);

  return _buildCalendarHeaderData(
    ref,
    date,
    primary,
    secondary,
    hinduYearEra,
    hinduMonthSystem,
  );
});

Future<_HeaderData> _buildCalendarHeaderData(
  Ref ref,
  DateTime date,
  cp.AppCalendarSystem primary,
  cp.AppCalendarSystem secondary,
  HinduYearEra hinduYearEra,
  HinduMonthSystem hinduMonthSystem,
) async {
  String primaryText;
  String? secondaryText;

  primaryText = await _getSystemHeaderTextForCalendar(
    ref,
    date,
    primary,
    hinduYearEra,
    hinduMonthSystem,
  );

  if (primary == cp.AppCalendarSystem.gregorian) {
    final monthRange = await _getTraditionalMonthRangeForCalendar(
      ref,
      date,
      secondary,
      hinduYearEra,
      hinduMonthSystem,
    );
    if (monthRange != null) {
      secondaryText = monthRange;
    }
  } else if ((primary == cp.AppCalendarSystem.hindu ||
          primary == cp.AppCalendarSystem.bengali) &&
      secondary == cp.AppCalendarSystem.gregorian) {
    final monthRange = await _getGregorianMonthRangeForCalendar(
      ref,
      date,
      primary,
    );
    if (monthRange != null) {
      secondaryText = monthRange;
    }
  } else if (secondary != cp.AppCalendarSystem.none && secondary != primary) {
    secondaryText = await _getSystemHeaderTextForCalendar(
      ref,
      date,
      secondary,
      hinduYearEra,
      hinduMonthSystem,
    );
  }

  return _HeaderData(primaryText: primaryText, secondaryText: secondaryText);
}

Future<String?> _getTraditionalMonthRangeForCalendar(
  Ref ref,
  DateTime date,
  cp.AppCalendarSystem system,
  HinduYearEra hinduYearEra,
  HinduMonthSystem hinduMonthSystem,
) async {
  if (system != cp.AppCalendarSystem.bengali &&
      system != cp.AppCalendarSystem.hindu) {
    return null;
  }

  try {
    final startOfMonth = DateTime(date.year, date.month);
    final endOfMonth = DateTime(date.year, date.month + 1, 0);

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
    } else {
      final service = ref.read(hinduCalendarServiceProvider);
      await ref.read(panchangInitProvider.future);

      final startHDate = await service.calculateDate(startOfMonth);
      final endHDate = await service.calculateDate(endOfMonth);

      startMonth = displayMasaName(
        startHDate.masa,
        startHDate.paksha,
        hinduMonthSystem,
      );
      endMonth = displayMasaName(
        endHDate.masa,
        endHDate.paksha,
        hinduMonthSystem,
      );

      startYear = hinduYearEra == HinduYearEra.vikramSamvat
          ? startHDate.vsYear
          : startHDate.shakaYear;
      endYear = hinduYearEra == HinduYearEra.vikramSamvat
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
}

Future<String?> _getGregorianMonthRangeForCalendar(
  Ref ref,
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

      final bDate = await service.calculateDate(date);
      final monthIndex = service.bengaliMonths.indexOf(bDate.month);
      final year = bDate.year;

      startDate = await service.getMonthStart(year, monthIndex);

      var nextIndex = monthIndex + 1;
      var nextYear = year;
      if (nextIndex > 11) {
        nextIndex = 0;
        nextYear++;
      }
      endDate = await service.getMonthStart(nextYear, nextIndex);
      endDate = endDate.subtract(const Duration(days: 1));
    } else {
      final service = ref.read(hinduCalendarServiceProvider);
      await ref.read(panchangInitProvider.future);

      final hDate = await service.calculateDate(date);
      final monthIndex = service.hinduMonths.indexOf(
        service.baseMasaName(hDate.masa),
      );
      final year = hDate.vsYear;

      startDate = await service.getMonthStart(year, monthIndex);

      var nextIndex = monthIndex + 1;
      var nextYear = year;
      if (nextIndex > 11) {
        nextIndex = 0;
        nextYear++;
      }
      endDate = await service.getMonthStart(nextYear, nextIndex);
      endDate = endDate.subtract(const Duration(days: 1));
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

Future<String> _getSystemHeaderTextForCalendar(
  Ref ref,
  DateTime date,
  cp.AppCalendarSystem system,
  HinduYearEra hinduYearEra,
  HinduMonthSystem hinduMonthSystem,
) async {
  switch (system) {
    case cp.AppCalendarSystem.bengali:
      try {
        final service = ref.read(bengaliCalendarServiceProvider);
        await ref.read(panchangInitProvider.future);
        final bDate = await service.calculateDate(date);
        return '${bDate.month} ${bDate.year}';
      } catch (_) {
        return _formatGregorianHeader(date);
      }

    case cp.AppCalendarSystem.hindu:
      try {
        final service = ref.read(hinduCalendarServiceProvider);
        await ref.read(panchangInitProvider.future);
        final hDate = await service.calculateDate(date);
        final displayYear = hinduYearEra == HinduYearEra.vikramSamvat
            ? hDate.vsYear
            : hDate.shakaYear;
        final displayMasa = displayMasaName(
          hDate.masa,
          hDate.paksha,
          hinduMonthSystem,
        ).replaceAll('_', ' ');
        return '$displayMasa $displayYear';
      } catch (_) {
        return _formatGregorianHeader(date);
      }

    case cp.AppCalendarSystem.gregorian:
    default:
      return _formatGregorianHeader(date);
  }
}

String _formatGregorianHeader(DateTime date) {
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
    final headerDataAsync = ref.watch(calendarHeaderDataProvider);
    final headerData = headerDataAsync.valueOrNull ??
        _HeaderData(primaryText: _formatGregorianHeader(focusedMonth));
    final materialL10n = MaterialLocalizations.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: Icon(Icons.chevron_left, color: context.colors.primary),
            tooltip: materialL10n.previousPageTooltip,
            onPressed: onLeftChevronTap,
          ),
          Expanded(
            child: GestureDetector(
              onTap: onYearTap,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        headerData.primaryText,
                        style: context.textTheme.headlineMedium!.copyWith(
                          fontSize: 18,
                        ),
                      ),
                      if (headerData.secondaryText != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          headerData.secondaryText!,
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
                  Icon(
                    Icons.arrow_drop_down,
                    size: 20,
                    color: context.colors.primary,
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            icon: Icon(Icons.chevron_right, color: context.colors.primary),
            tooltip: materialL10n.nextPageTooltip,
            onPressed: onRightChevronTap,
          ),
        ],
      ),
    );
  }
}

class _CalendarCell extends StatelessWidget {
  final DateTime date;
  final bool isSelected;
  final bool isToday;
  final String primaryText;
  final String? secondaryText;

  const _CalendarCell({
    required this.date,
    required this.isSelected,
    required this.isToday,
    this.primaryText = '',
    this.secondaryText,
  });

  @override
  Widget build(BuildContext context) {
    final resolvedPrimary = primaryText.isEmpty
        ? date.day.toString()
        : primaryText;

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
        borderRadius: isSelected || isToday ? null : BorderRadius.circular(8),
      ),
      child: Stack(
        children: [
          Center(
            child: Text(
              resolvedPrimary,
              style: TextStyle(
                color: textColor,
                fontSize: 16,
                fontWeight: isSelected || isToday
                    ? FontWeight.bold
                    : FontWeight.normal,
              ),
            ),
          ),
          if (secondaryText != null)
            Positioned(
              top: 4,
              left: 6,
              child: Text(
                secondaryText!,
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
  }
}
