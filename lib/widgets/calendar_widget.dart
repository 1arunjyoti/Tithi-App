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
import '../utils/tithi_localization.dart';
import '../features/calendar/data/calendar_caches.dart';
import '../features/calendar/data/calendar_models.dart';
import '../features/calendar/domain/month_navigation.dart';
import '../features/calendar/domain/header_builders.dart'
    show cachedHeaderSync, formatGregorianHeader;
import '../features/calendar/providers/cell_providers.dart';
import '../features/calendar/providers/header_provider.dart';

export '../features/calendar/data/calendar_models.dart'
    show CalendarCellData, AdaptiveCalendarData, HeaderData, MonthRangeParts;
export '../features/calendar/providers/cell_providers.dart'
    show
        gregorianCalendarCellDataProvider,
        adaptiveCalendarDataProvider;
export '../features/calendar/providers/header_provider.dart'
    show calendarHeaderDataProvider;
export '../features/calendar/domain/header_builders.dart'
    show cachedHeaderSync, formatGregorianHeader;


// Adapter: the shared dot cache stores plain records; the grid works with
// CalendarCellData.
void _storeAdaptiveDotsSync(Map<DateTime, CalendarCellData> cellData) {
  storeAdaptiveDotsSync(
    cellData.map(
      (date, cell) => MapEntry(
        date,
        (hasFestivals: cell.hasFestivals, isMajor: cell.hasMajorFestival),
      ),
    ),
  );
}







// Stale-data cache for the adaptive (Hindu/Bengali) grid. Family-arg changes
// create a FRESH provider instance, so Riverpod keeps no previous value —
// without this every month turn swaps the whole grid to a skeleton and back
// (the cell "flash"). Holding the last resolved grid renders the previous
// month instantly while the new one resolves, exactly like the Gregorian
// path's sync stale-label/dot caches. Scoped by system+displayMode so a
// Hindu grid is never shown as stale Bengali data.
AdaptiveCalendarData? _lastAdaptiveData;
int? _lastAdaptiveSystemIndex;
int? _lastAdaptiveModeIndex;
// Key of [_lastAdaptiveData]. The AnimatedSwitcher below must keep showing
// the stale grid under its OLD key while the new month loads — keying stale
// content by the NEW month animates old cells as if they were new (the
// swipe "flash": current month slides/fades into itself, then pops to the
// real month). Single slide only once fresh data arrives.
String? _lastAdaptiveKey;


/// Adaptive month setter that ignores no-op targets. A stale/wrong cached
/// target equal to the viewed month would otherwise look like a frozen
/// calendar (state set to the same value → no rebuild, no feedback).
void _setAdaptiveMonth(WidgetRef ref, DateTime target, DateTime focusedMonth) {
  if (target.year == focusedMonth.year &&
      target.month == focusedMonth.month &&
      target.day == focusedMonth.day) {
    logCalNav('nav settled: IGNORED self-target ${ymd(target)}');
    return;
  }
  logCalNav('nav settled: ${ymd(focusedMonth)} -> ${ymd(target)}');
  cp.setCalendarMonth(ref, target);
}










/// Pre-computes neighbor months so sliding feels instant. Covers both the
/// secondary corner labels and (Gregorian path) the festival indicator dots
/// from monthlyPanchangProvider. It starts only after the calendar has been
/// idle, is cancelled by a date tap, is sequential (next then previous) to
/// avoid FFI bursts on the UI thread, and never throws into the UI.
void _scheduleAdjacentPrecache(
  WidgetRef ref,
  DateTime focusedMonth,
  DateTime selectedDate,
  cp.StartingDayOfWeek startOfWeek,
  cp.AppCalendarSystem primarySystem,
  cp.AppCalendarSystem secondarySystem,
  cp.TithiDisplayMode displayMode,
) {
  final isAdaptive =
      primarySystem == cp.AppCalendarSystem.bengali ||
      primarySystem == cp.AppCalendarSystem.hindu;
  final scheduledYear = focusedMonth.year;
  final scheduledMonth = focusedMonth.month;
  final scheduledSelectedDate = DateTime(
    selectedDate.year,
    selectedDate.month,
    selectedDate.day,
  );

  // Called from build on every rebuild: only queue one precache run per
  // distinct month+prefs+selection request instead of piling up a postFrame
  // + delayed future per rebuild. A new selection gets its own idle timer;
  // the earlier request observes the changed date and exits.
  final requestKey =
      '$scheduledYear-$scheduledMonth-${ymd(scheduledSelectedDate)}_${startOfWeek.index}_${primarySystem.index}_${secondarySystem.index}_${displayMode.index}';
  if (!claimPrecacheRequest(requestKey)) return;

  bool isStale() {
    // ref.read throws once the owning widget is unmounted — treat as stale
    // so pending precache work is dropped instead of crashing.
    try {
      final current = ref.read(cp.focusedMonthProvider);
      return current.year != scheduledYear ||
          current.month != scheduledMonth ||
          !isSameCalendarDay(
            ref.read(cp.selectedDateProvider),
            scheduledSelectedDate,
          ) ||
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
      // Give a newly selected date time to paint and resolve its lightweight
      // details before yielding the native ephemeris thread to background
      // neighbor work. A new tap invalidates this request through isStale.
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
        } catch (e) {
          // Precache is best-effort only.
          logCalError('precache $requestKey', e);
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
  // Keys are month-normalized (day=1) so they hit the same provider
  // instance the calendar watches after onPageChanged, regardless of which
  // day TableCalendar reports as the new focusedDay.
  final neighbors = [
    normalizeMonthKey(DateTime(focusedMonth.year, focusedMonth.month + 1)),
    normalizeMonthKey(DateTime(focusedMonth.year, focusedMonth.month - 1)),
  ];
  final needsSecondaryLabels = secondarySystem != cp.AppCalendarSystem.none;
  for (final month in neighbors) {
    if (isStale()) return;
    // Festival dots: always needed, independent of secondary labels.
    // Warms the Hive tithi/masa cache and fills festivalDotCache so the
    // next month shows stale dots instantly instead of popping in.
    final festivalKey = festivalMonthPrecacheKey(month);
    if (addBoundedPrecacheKey(precachedFestivalMonthKeys, festivalKey)) {
      try {
        final monthData = await ref.read(monthlyPanchangProvider(month).future);
        storeFestivalDotsSync(monthData);
      } catch (e) {
        precachedFestivalMonthKeys.remove(festivalKey);
        logCalError('precache festivals $festivalKey', e);
      }
    }
    if (isStale()) return;
    // Secondary corner labels: only when a secondary system is shown.
    if (!needsSecondaryLabels) continue;
    final key = monthPrecacheKey(
      month,
      startOfWeek,
      primarySystem,
      secondarySystem,
      displayMode,
    );
    if (!addBoundedPrecacheKey(precachedMonthKeys, key)) continue;
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
    } catch (e) {
      precachedMonthKeys.remove(key);
      logCalError('precache labels $key', e);
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
      // Exact-masa neighbors: index arithmetic skips Nija months, so resolve
      // through the containing month's boundaries instead.
      final service = ref.read(hinduCalendarServiceProvider);
      final currentStart = await service.monthStartContaining(focusedMonth);
      targets.add(await service.prevMonthStartBefore(currentStart));
      targets.add(await service.nextMonthStartAfter(currentStart));
    }
  } catch (e) {
    logCalError('precache adaptive targets', e);
    return;
  }

  // Record instant-navigation targets for this exact focused date:
  // targets are ordered [prev, next] on both paths.
  if (targets.length == 2) {
    final base = adaptiveNavKey(primarySystem, focusedMonth);
    storeAdaptiveNavTarget('${base}_-1', targets[0]);
    storeAdaptiveNavTarget('${base}_+1', targets[1]);
  }

  for (final target in targets) {
    if (isStale()) return;
    final key = monthPrecacheKey(
      target,
      startOfWeek,
      primarySystem,
      secondarySystem,
      displayMode,
    );
    if (!addBoundedPrecacheKey(precachedMonthKeys, key)) continue;
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
    } catch (e) {
      precachedMonthKeys.remove(key);
      logCalError('precache adaptive $key', e);
    }
  }
}

/// Calendar widget using TableCalendar with Tithi markers
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

    // Adaptive month data, resolved stale-first below: the previous month's
    // grid stays on screen while the new one computes (family-arg changes
    // create fresh provider instances, so .valueOrNull is the only bridge).
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
    final adaptiveKey = adaptiveNavKey(primarySystem, focusedMonth);
    final adaptiveFresh = adaptiveAsync.valueOrNull;
    if (adaptiveFresh != null) {
      _lastAdaptiveData = adaptiveFresh;
      _lastAdaptiveSystemIndex = primarySystem.index;
      _lastAdaptiveModeIndex = displayMode.index;
      _lastAdaptiveKey = adaptiveKey;
    }
    final reuseStale =
        _lastAdaptiveData != null &&
        _lastAdaptiveSystemIndex == primarySystem.index &&
        _lastAdaptiveModeIndex == displayMode.index;
    final adaptiveDisplay =
        adaptiveFresh ?? (reuseStale ? _lastAdaptiveData : null);
    final adaptiveSettled = adaptiveFresh != null;
    // While the new month loads, keep the stale grid under its OLD key so
    // the AnimatedSwitcher holds it static (no transition). Only fresh data
    // takes the NEW key, producing a single slide old -> new instead of the
    // double-transition flash (old slides into itself, then pops to new).
    final displayKey = adaptiveFresh != null
        ? adaptiveKey
        : (reuseStale ? (_lastAdaptiveKey ?? adaptiveKey) : adaptiveKey);

    // Best-effort precache of neighbor months (secondary labels + festival dots).
    // Only after the current month settled: firing neighbor FFI while the
    // current month is still computing contends for the same native thread
    // and janks the initial paint / landing frame.
    final currentSettled = isAdaptive
        ? adaptiveSettled
        : (monthlyPanchangAsync.hasValue || gregorianCellDataAsync.hasValue);
    if (currentSettled) {
      _scheduleAdjacentPrecache(
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
      duration: AppTheme.animationDuration(
        context,
        const Duration(milliseconds: 250),
      ),
      curve: Curves.easeInOutCubic,
      child: Container(
        // Horizontal gutters only (shared AppTheme.homeCardGutter so left and
        // right match every other home card): vertical spacing between home
        // cards is owned by the home column's uniform SizedBox gaps, so a
        // vertical margin here would double up around this card alone.
        margin: const EdgeInsets.symmetric(horizontal: AppTheme.homeCardGutter),
        decoration: AppTheme.glassmorphism(context: context, ref: ref),
        // Card padding per the redesign (18 top, 14 sides/bottom) keeps the
        // grid and stripes clear of the rounded card corners.
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 18, 14, 14),
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

              if (isAdaptive)
                // Adaptive grid has no internal PageView, so swipe is handled here.
                // Stale-first: the previous month stays mounted under its OLD key
                // while fresh data resolves (no animation), then slides once to
                // the new month — the same stale-then-single-transition pattern
                // as the Gregorian path's sync stale-label caches. No skeleton
                // flash by default.
                GestureDetector(
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
                      _navigateToNextMonth(ref, focusedMonth, primarySystem);
                    } else if (direction < 0) {
                      _navigateToPreviousMonth(
                        ref,
                        focusedMonth,
                        primarySystem,
                      );
                    }
                  },
                  child: RepaintBoundary(
                    child: AnimatedSwitcher(
                      duration: AppTheme.animationDuration(
                        context,
                        const Duration(milliseconds: 250),
                      ),
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
                                curve: Curves.easeOutCubic,
                              ),
                            );
                        return SlideTransition(position: slide, child: child);
                      },
                      child: adaptiveDisplay != null
                          ? _buildAdaptiveGrid(
                              context,
                              ref,
                              startOfWeek,
                              adaptiveDisplay,
                              secondarySystem,
                              displayMode,
                              selectedDate,
                              today,
                              // Stale keeps the previous month's key (static hold,
                              // no animation); fresh takes the new month's key so
                              // the switcher slides exactly once old -> new.
                              key: ValueKey(displayKey),
                            )
                          : adaptiveAsync.isLoading
                          // Same 6-row skeleton height as the loaded grid: keeps
                          // layout stable instead of swapping a 300px spinner
                          // for a taller/shorter grid (the main "jump" culprit).
                          // Only on cold start — never between months.
                          ? _buildAdaptiveSkeleton(
                              context,
                              startOfWeek,
                              key: const ValueKey('adaptive_skeleton'),
                            )
                          : const SizedBox.shrink(),
                    ),
                  ),
                )
              else
                // Gregorian path: TableCalendar owns the horizontal swipe via its
                // internal PageView. No outer GestureDetector here — a competing
                // drag handler makes the page stick/jitter mid-swipe.
                RepaintBoundary(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _WeekdayHeaderRow(startOfWeek: startOfWeek),
                      const SizedBox(height: 4),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          return _WeekendStripes(
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
                              pageAnimationDuration: AppTheme.animationDuration(
                                context,
                                const Duration(milliseconds: 250),
                              ),
                              pageAnimationCurve: Curves.easeOutCubic,
                              availableGestures:
                                  AvailableGestures.horizontalSwipe,
                              startingDayOfWeek:
                                  startOfWeek == cp.StartingDayOfWeek.sunday
                                  ? StartingDayOfWeek.sunday
                                  : StartingDayOfWeek.monday,
                              selectedDayPredicate: (day) =>
                                  isSameDay(day, selectedDate),
                              onDaySelected: (selected, focused) {
                                if (ref
                                    .read(accessibilityProvider)
                                    .hapticFeedback) {
                                  HapticFeedback.lightImpact();
                                }
                                ref
                                    .read(cp.selectedDateProvider.notifier)
                                    .setDate(selected);
                                // Avoid notifying focusedMonth (and re-resolving all month
                                // providers) when the tap didn't actually change months.
                                final current = ref.read(
                                  cp.focusedMonthProvider,
                                );
                                if (current.year != focused.year ||
                                    current.month != focused.month) {
                                  // Day taps have no page animation to protect: settle
                                  // heavy data immediately so dots/labels don't lag.
                                  cp.setCalendarMonth(ref, focused);
                                }
                                // Active tile tap (set after setCalendarMonth, which clears
                                // tap state as month navigation): narrows the secondary
                                // header to this date's single month.
                                ref
                                    .read(
                                      cp.tappedCalendarDateProvider.notifier,
                                    )
                                    .state = DateTime(
                                  selected.year,
                                  selected.month,
                                  selected.day,
                                );
                              },
                              onPageChanged: (focusedDay) {
                                // Single haptic for Gregorian page turns (swipe or
                                // chevron-driven animation). Chevron taps don't buzz
                                // separately on this path (see _navigateTo*Month).
                                if (ref
                                    .read(accessibilityProvider)
                                    .hapticFeedback) {
                                  HapticFeedback.lightImpact();
                                }
                                // Instant: header + page position flip at mid-screen cross.
                                ref
                                    .read(cp.focusedMonthProvider.notifier)
                                    .setFocusedMonth(focusedDay);
                                // Swiping months ends the explicit tile-tap state: the
                                // secondary header returns to its default two-month range.
                                ref
                                        .read(
                                          cp
                                              .tappedCalendarDateProvider
                                              .notifier,
                                        )
                                        .state =
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
                                  final cellData = gregorianCellDataAsync
                                      .maybeWhen(
                                        data: (data) => data[normalizedDate],
                                        orElse: () => null,
                                      );
                                  return _CalendarCell(
                                    date: date,
                                    isSelected: false,
                                    isToday: false,
                                    primaryText:
                                        cellData?.primary ??
                                        date.day.toString(),
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
                                  final cellData = gregorianCellDataAsync
                                      .maybeWhen(
                                        data: (data) => data[normalizedDate],
                                        orElse: () => null,
                                      );
                                  return _CalendarCell(
                                    date: date,
                                    isSelected: true,
                                    isToday: isSameDay(date, today),
                                    primaryText:
                                        cellData?.primary ??
                                        date.day.toString(),
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
                                  final cellData = gregorianCellDataAsync
                                      .maybeWhen(
                                        data: (data) => data[normalizedDate],
                                        orElse: () => null,
                                      );
                                  return _CalendarCell(
                                    date: date,
                                    isSelected: false,
                                    isToday: true,
                                    primaryText:
                                        cellData?.primary ??
                                        date.day.toString(),
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
                                  final cellData = gregorianCellDataAsync
                                      .maybeWhen(
                                        data: (data) => data[normalizedDate],
                                        orElse: () => null,
                                      );
                                  return _CalendarCell(
                                    date: date,
                                    isSelected: isSameDay(date, selectedDate),
                                    isToday: isSameDay(date, today),
                                    isOutside: true,
                                    primaryText:
                                        cellData?.primary ??
                                        date.day.toString(),
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
                                  return _buildFestivalMarkerFromCache(
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
                                outsideTextStyle: TextStyle(
                                  color: context.colors.onSurface.withValues(
                                    alpha: 0.35,
                                  ),
                                ),
                              ),
                              // Weekday labels render in the shared row above.
                              daysOfWeekVisible: false,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// 5-row skeleton for cold start (the most common lunar-month shape);
  /// month turns reuse the stale grid instead, and row counts of 4-6 settle
  /// naturally like the Gregorian path.
  Widget _buildAdaptiveSkeleton(
    BuildContext context,
    cp.StartingDayOfWeek startOfWeek, {
    Key? key,
  }) {
    return Column(
      key: key,
      children: [
        _WeekdayHeaderRow(startOfWeek: startOfWeek),
        const SizedBox(height: 4),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
          ),
          // 5 rows: the most common lunar-month shape (see grid padding).
          itemCount: 35,
          itemBuilder: (context, index) => Container(
            margin: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: context.colors.onSurface.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAdaptiveGrid(
    BuildContext context,
    WidgetRef ref,
    cp.StartingDayOfWeek startOfWeek,
    AdaptiveCalendarData adaptiveData,
    cp.AppCalendarSystem secondarySystem,
    cp.TithiDisplayMode displayMode,
    // Hoisted by the caller: watching selectedDate or calling DateTime.now()
    // inside itemBuilder would re-subscribe/re-evaluate per cell (42×).
    DateTime selectedDate,
    DateTime today, {
    Key? key,
  }) {
    // Feed the stale-dot LRU so a later Gregorian view (or a fast
    // back-navigation) can render dots instantly.
    _storeAdaptiveDotsSync(adaptiveData.cellData);
    final days = adaptiveData.days;
    return Column(
      key: key,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Weekday Headers (shared styling with the Gregorian path).
        _WeekdayHeaderRow(startOfWeek: startOfWeek),
        const SizedBox(height: 4),
        // Grid with weekend striping.
        _WeekendStripes(
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
              final cellData = adaptiveData.cellData[normalizedDate];
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
                  if (ref.read(accessibilityProvider).hapticFeedback) {
                    HapticFeedback.lightImpact();
                  }
                  ref.read(cp.selectedDateProvider.notifier).setDate(date);
                  // Active tile tap: narrows the secondary header to this
                  // date's single month with the year.
                  ref.read(cp.tappedCalendarDateProvider.notifier).state =
                      DateTime(date.year, date.month, date.day);
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
                          cachedSecondarySync(
                            normalizedDate,
                            secondarySystem,
                            displayMode,
                          ),
                    ),
                    if (hasFestivals)
                      _buildFestivalBar(
                        context,
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

  /// Show year picker dialog for quick navigation
  /// Supports Gregorian, Hindu (Vikram Samvat/Shaka), and Bengali calendar years
  void _showYearPicker(
    BuildContext context,
    WidgetRef ref,
    DateTime focusedMonth,
  ) async {
    if (ref.read(accessibilityProvider).hapticFeedback) {
      await HapticFeedback.lightImpact();
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
              onPrimary: Theme.of(context).colorScheme.onPrimary,
              surface: Theme.of(context).scaffoldBackgroundColor,
            ),
          ),
          child: child!,
        );
      },
    );

    if (selectedDate != null) {
      cp.setCalendarMonth(ref, DateTime(selectedDate.year, focusedMonth.month));
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

    if (!context.mounted) return;
    final l10n = AppLocalizations.of(context);
    if (yearEra == HinduYearEra.vikramSamvat) {
      minYear = 1976 + 57; // 2033 VS
      maxYear = 2076 + 57; // 2133 VS
      eraName = l10n?.vikramSamvat ?? 'Vikram Samvat';
    } else {
      minYear = 1976 - 78; // 1898 Shaka
      maxYear = 2076 - 78; // 1998 Shaka
      eraName = l10n?.shakaEra ?? 'Shaka Era';
    }

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
      cp.setCalendarMonth(ref, newDate);
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
      AppLocalizations.of(context)?.bengaliEra ?? 'Bengali Era',
    );

    if (selectedYear == null) return;
    if (!context.mounted) return;

    // Step 2: Select Month (Bengali script names for the Bengali UI locale,
    // transliterated names otherwise — same rule as the header labels).
    final useBnMonths =
        Localizations.localeOf(context).languageCode == 'bn';
    final selectedMonthIndex = await _showBengaliMonthPickerDialog(
      context,
      ref,
      useBnMonths ? service.bengaliMonthsBn : service.bengaliMonths,
      selectedYear == currentYear ? currentMonthIndex : 0,
      selectedYear,
    );

    if (selectedMonthIndex != null) {
      // Get the Gregorian date for the selected Bengali month
      final newDate = await service.getMonthStart(
        selectedYear,
        selectedMonthIndex,
      );
      cp.setCalendarMonth(ref, newDate);
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
          final materialL10n = MaterialLocalizations.of(context);
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
                          AppLocalizations.of(context)?.selectYear ??
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
                                  HapticFeedback.lightImpact();
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
                                  localizeDigits(
                                    '$year',
                                    Localizations.localeOf(
                                      context,
                                    ).languageCode,
                                  ),
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
      '${localizeDigits('$selectedYear', Localizations.localeOf(context).languageCode)} $eraName',
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
    final l10n = AppLocalizations.of(context);
    final localeCode = Localizations.localeOf(context).languageCode;
    return _showAdaptiveMonthPickerDialog(
      context,
      ref,
      months,
      currentMonthIndex,
      localizeDigits(
        l10n?.bengaliEraYear(selectedYear) ?? '$selectedYear বঙ্গাব্দ',
        localeCode,
      ),
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
                                HapticFeedback.lightImpact();
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

  /// Navigate to the previous month based on the calendar system.
  /// Guarded against double-taps: the lunar paths await native calls, so
  /// overlapping invocations would interleave two month resolutions.
  void _navigateToPreviousMonth(
    WidgetRef ref,
    DateTime focusedMonth,
    cp.AppCalendarSystem primarySystem,
  ) async {
    if (monthNavInFlight) return;
    monthNavInFlight = true;
    // Load persisted nav targets before the cache-hit lookup below, so the
    // first swipe after a restart can already move instantly.
    ensureAdaptiveCacheLoaded();
    logCalNav(
      'nav prev intent: focused=${ymd(focusedMonth)} system=$primarySystem',
    );
    try {
      // Buzz here only for Hindu/Bengali (no page view, no onPageChanged).
      // Gregorian chevrons buzz via onPageChanged's page-turn animation.
      if (primarySystem != cp.AppCalendarSystem.gregorian &&
          ref.read(accessibilityProvider).hapticFeedback) {
        await HapticFeedback.lightImpact();
      }

      if (primarySystem == cp.AppCalendarSystem.bengali) {
        // Navigate by Bengali Month — instant on cache hit (no FFI before
        // the UI responds), FFI fallback records the target for next time.
        adaptiveSlideDirection = -1;
        final navKey = '${adaptiveNavKey(primarySystem, focusedMonth)}_-1';
        final cached = readAdaptiveNavTarget(navKey);
        if (cached != null) {
          _setAdaptiveMonth(ref, cached, focusedMonth);
        } else {
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
          storeAdaptiveNavTarget(navKey, newDate);
          _setAdaptiveMonth(ref, newDate, focusedMonth);
        }
      } else if (primarySystem == cp.AppCalendarSystem.hindu) {
        // Navigate by Hindu Lunar Month — same instant-on-hit pattern.
        // Exact-masa step back: index arithmetic would skip Nija months.
        adaptiveSlideDirection = -1;
        final navKey = '${adaptiveNavKey(primarySystem, focusedMonth)}_-1';
        final cached = readAdaptiveNavTarget(navKey);
        if (cached != null) {
          _setAdaptiveMonth(ref, cached, focusedMonth);
        } else {
          final service = ref.read(hinduCalendarServiceProvider);
          await ref.read(panchangInitProvider.future);
          final newDate = await service.prevMasaStartFrom(focusedMonth);
          storeAdaptiveNavTarget(navKey, newDate);
          _setAdaptiveMonth(ref, newDate, focusedMonth);
        }
      } else {
        cp.setCalendarMonth(
          ref,
          DateTime(focusedMonth.year, focusedMonth.month - 1),
        );
      }
    } catch (e) {
      logCalError('navigate previous month', e);
    } finally {
      monthNavInFlight = false;
    }
  }

  /// Navigate to the next month based on the calendar system.
  /// Same re-entrancy guard as [_navigateToPreviousMonth].
  void _navigateToNextMonth(
    WidgetRef ref,
    DateTime focusedMonth,
    cp.AppCalendarSystem primarySystem,
  ) async {
    if (monthNavInFlight) return;
    monthNavInFlight = true;
    // Load persisted nav targets before the cache-hit lookup below, so the
    // first swipe after a restart can already move instantly.
    ensureAdaptiveCacheLoaded();
    logCalNav(
      'nav next intent: focused=${ymd(focusedMonth)} system=$primarySystem',
    );
    try {
      // Same split as _navigateToPreviousMonth: Gregorian buzzes once via
      // onPageChanged; Hindu/Bengali buzz here.
      if (primarySystem != cp.AppCalendarSystem.gregorian &&
          ref.read(accessibilityProvider).hapticFeedback) {
        await HapticFeedback.lightImpact();
      }

      if (primarySystem == cp.AppCalendarSystem.bengali) {
        // Navigate by Bengali Month — instant on cache hit (no FFI before
        // the UI responds), FFI fallback records the target for next time.
        adaptiveSlideDirection = 1;
        final navKey = '${adaptiveNavKey(primarySystem, focusedMonth)}_+1';
        final cached = readAdaptiveNavTarget(navKey);
        if (cached != null) {
          _setAdaptiveMonth(ref, cached, focusedMonth);
        } else {
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
          storeAdaptiveNavTarget(navKey, newDate);
          _setAdaptiveMonth(ref, newDate, focusedMonth);
        }
      } else if (primarySystem == cp.AppCalendarSystem.hindu) {
        // Exact-masa step forward: lands on Nija months instead of skipping
        // them like index arithmetic did.
        adaptiveSlideDirection = 1;
        final navKey = '${adaptiveNavKey(primarySystem, focusedMonth)}_+1';
        final cached = readAdaptiveNavTarget(navKey);
        if (cached != null) {
          _setAdaptiveMonth(ref, cached, focusedMonth);
        } else {
          final service = ref.read(hinduCalendarServiceProvider);
          await ref.read(panchangInitProvider.future);
          final newDate = await service.nextMasaStartFrom(focusedMonth);
          storeAdaptiveNavTarget(navKey, newDate);
          _setAdaptiveMonth(ref, newDate, focusedMonth);
        }
      } else {
        cp.setCalendarMonth(
          ref,
          DateTime(focusedMonth.year, focusedMonth.month + 1),
        );
      }
    } catch (e) {
      logCalError('navigate next month', e);
    } finally {
      monthNavInFlight = false;
    }
  }

  /// Optimized festival marker using pre-loaded monthly panchang cache
  /// Used by the Gregorian TableCalendar path.
  /// Falls back to the sync stale-dot LRU when [monthlyPanchang] doesn't
  /// contain [date] yet (during swipe animation, or while the next month's
  /// provider is still loading) so dots don't pop in late.
  Widget? _buildFestivalMarkerFromCache(
    BuildContext context,
    DateTime date,
    Map<DateTime, PanchangData> monthlyPanchang, {
    required bool isSelected,
    required bool isToday,
  }) {
    final normalizedDate = DateTime(date.year, date.month, date.day);
    final panchang = monthlyPanchang[normalizedDate];

    if (panchang != null) {
      if (!panchang.hasFestivals) return null;
      return _buildFestivalBar(
        context,
        isMajor: panchang.majorFestivals.isNotEmpty,
        isSelected: isSelected,
        isToday: isToday,
      );
    }

    final stale = cachedFestivalDotSync(normalizedDate);
    if (stale == null || !stale.hasFestivals) return null;
    return _buildFestivalBar(
      context,
      isMajor: stale.isMajor,
      isSelected: isSelected,
      isToday: isToday,
    );
  }

  /// Festival pill-bar marker (redesign): a 12x3 rounded bar instead of a
  /// dot. Color follows tile state — moon-fill on selected, ring color on
  /// today, accent bar otherwise (minor festivals dimmed). Takes pre-resolved
  /// flags so callers never mismatch date ranges.
  Widget _buildFestivalBar(
    BuildContext context, {
    required bool isMajor,
    required bool isSelected,
    required bool isToday,
  }) {
    final highContrast = AppTheme.highContrastOf(context);
    Color color;
    if (isSelected) {
      color = highContrast
          ? context.colors.onPrimary
          : AppTheme.heroMoonFill(context);
    } else if (isToday) {
      color = highContrast
          ? context.colors.primary
          : AppTheme.calendarTodayRing(context);
    } else {
      color = AppTheme.calendarFestivalBar(context);
      if (!isMajor) color = color.withValues(alpha: 0.45);
    }
    return Positioned(
      bottom: 5,
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          width: 12,
          height: 3,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(99),
          ),
        ),
      ),
    );
  }
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
    final primary = ref.watch(cp.primaryCalendarSystemProvider);
    final secondary = ref.watch(cp.secondaryCalendarSystemProvider);
    final hinduYearEra = ref.watch(cp.hinduYearEraProvider);
    final hinduMonthSystem = ref.watch(cp.hinduMonthSystemProvider);
    // Mirrors the provider's gating: subscribe to taps whenever the
    // secondary header has a tap-narrowed (range -> single) variant, so the
    // key lookup stays meaningful and taps skip this widget otherwise.
    final tapNarrowsSecondary =
        (primary == cp.AppCalendarSystem.gregorian &&
            (secondary == cp.AppCalendarSystem.hindu ||
                secondary == cp.AppCalendarSystem.bengali)) ||
        ((primary == cp.AppCalendarSystem.hindu ||
                primary == cp.AppCalendarSystem.bengali) &&
            secondary != cp.AppCalendarSystem.none &&
            secondary != primary);
    final tappedDate = tapNarrowsSecondary
        ? ref.watch(cp.tappedCalendarDateProvider)
        : null;
    // Gregorian compares by year-month; lunar spans straddle Gregorian
    // months, so pass the tap through and let the range builder validate
    // containment (out-of-span taps show the range).
    final tappedInMonth = tappedDate == null
        ? null
        : (primary == cp.AppCalendarSystem.gregorian
              ? (tappedDate.year == focusedMonth.year &&
                        tappedDate.month == focusedMonth.month
                    ? DateTime(
                        tappedDate.year,
                        tappedDate.month,
                        tappedDate.day,
                      )
                    : null)
              : DateTime(tappedDate.year, tappedDate.month, tappedDate.day));
    final headerDataAsync = ref.watch(calendarHeaderDataProvider);
    final localeCode = Localizations.localeOf(context).languageCode;
    // Stale header first so swipes never show bare Gregorian then flip;
    // fresh async data replaces it once FFI resolves. On a date tap the
    // tap-keyed entry misses until fresh data lands, so fall back to
    // the range entry (previous text) rather than bare Gregorian.
    final headerData =
        headerDataAsync.valueOrNull ??
        cachedHeaderSync(
          focusedMonth,
          primary,
          secondary,
          hinduYearEra,
          hinduMonthSystem,
          locale: localeCode,
          selectedDate: tappedInMonth,
        ) ??
        cachedHeaderSync(
          focusedMonth,
          primary,
          secondary,
          hinduYearEra,
          hinduMonthSystem,
          locale: localeCode,
        ) ??
        HeaderData(
          primaryText: localizeDigits(
            formatGregorianHeader(
              focusedMonth,
              AppLocalizations.of(context),
            ),
            localeCode,
          ),
        );    final materialL10n = MaterialLocalizations.of(context);

    final highContrast = AppTheme.highContrastOf(context);
    final onSurface = context.colors.onSurface;
    final dim = onSurface.withValues(alpha: 0.6);

    Widget navButton({
      required IconData icon,
      required String tooltip,
      required VoidCallback onTap,
    }) {
      // Haptics stay in the navigate methods (per-path: page-turn buzz on
      // Gregorian, explicit buzz on Hindu/Bengali) — not here, to avoid
      // double feedback.
      return Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Tooltip(
            message: tooltip,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: onSurface.withValues(alpha: highContrast ? 0.25 : 0.1),
                ),
              ),
              alignment: Alignment.center,
              child: Icon(icon, size: 16, color: onSurface),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          navButton(
            icon: Icons.chevron_left,
            tooltip: materialL10n.previousPageTooltip,
            onTap: onLeftChevronTap,
          ),
          Expanded(
            child: GestureDetector(
              onTap: onYearTap,
              behavior: HitTestBehavior.opaque,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(
                        child: Text(
                          headerData.primaryText,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.2,
                            color: onSurface,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.expand_more, size: 14, color: dim),
                    ],
                  ),
                  if (headerData.secondaryAccent != null) ...[
                    const SizedBox(height: 1),
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: headerData.secondaryAccent,
                            style: TextStyle(
                              fontSize: 11,
                              letterSpacing: 0.2,
                              fontWeight: FontWeight.w600,
                              color: context.colors.primary,
                            ),
                          ),
                          if (headerData.secondaryDim != null &&
                              headerData.secondaryDim!.isNotEmpty)
                            TextSpan(
                              text: ' · ${headerData.secondaryDim}',
                              style: TextStyle(fontSize: 11, color: dim),
                            ),
                        ],
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ),
          navButton(
            icon: Icons.chevron_right,
            tooltip: materialL10n.nextPageTooltip,
            onTap: onRightChevronTap,
          ),
        ],
      ),
    );
  }
}

/// Weekday header row shared by the Gregorian and adaptive grids: 3-letter
/// uppercase labels with weekend columns in the accent color. Order follows
/// [startOfWeek] to match the grid columns below. Labels come from
/// AppLocalizations so Hindi/Bengali/Sanskrit show their own weekday names.
class _WeekdayHeaderRow extends StatelessWidget {
  const _WeekdayHeaderRow({required this.startOfWeek});

  final cp.StartingDayOfWeek startOfWeek;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // Sunday-first and Monday-first orders of the localized short names
    // (English fallbacks for contexts without localizations, e.g. tests).
    List<String> ordered(bool mondayFirst) {
      final days = [
        l10n?.weekdaySundayShort ?? 'SUN',
        l10n?.weekdayMondayShort ?? 'MON',
        l10n?.weekdayTuesdayShort ?? 'TUE',
        l10n?.weekdayWednesdayShort ?? 'WED',
        l10n?.weekdayThursdayShort ?? 'THU',
        l10n?.weekdayFridayShort ?? 'FRI',
        l10n?.weekdaySaturdayShort ?? 'SAT',
      ];
      return mondayFirst ? [...days.sublist(1), days[0]] : days;
    }

    final labels = ordered(startOfWeek == cp.StartingDayOfWeek.monday);
    // Weekend columns depend on the week start (Sun/Sat at 0+6 or 5+6).
    bool isWeekend(int index) => startOfWeek == cp.StartingDayOfWeek.monday
        ? index >= 5
        : (index == 0 || index == 6);
    return Row(
      children: [
        for (var i = 0; i < 7; i++)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text(
                labels[i],
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.6,
                  color: isWeekend(i)
                      ? context.colors.primary
                      : context.colors.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Weekend column tint behind a 7-column grid (redesign weekend striping).
/// Runs are contiguous weekend-column ranges so Monday-start weekends render
/// as one stripe. Both children grids use equal full-width columns, so
/// sevenths geometry always lines up.
class _WeekendStripes extends StatelessWidget {
  const _WeekendStripes({required this.startOfWeek, required this.child});

  final cp.StartingDayOfWeek startOfWeek;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final runs = startOfWeek == cp.StartingDayOfWeek.monday
        ? const [
            [5, 6],
          ]
        : const [
            [0, 0],
            [6, 6],
          ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final column = constraints.maxWidth / 7;
        return Stack(
          children: [
            for (final run in runs)
              Positioned(
                top: 0,
                bottom: 0,
                left: column * run[0],
                width: column * (run[1] - run[0] + 1),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppTheme.calendarWeekendStripe(context),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            child,
          ],
        );
      },
    );
  }
}

class _CalendarCell extends StatelessWidget {
  final DateTime date;
  final bool isSelected;
  final bool isToday;
  final String primaryText;
  final String? secondaryText;
  final bool isOutside;

  const _CalendarCell({
    required this.date,
    required this.isSelected,
    required this.isToday,
    this.primaryText = '',
    this.secondaryText,
    this.isOutside = false,
  });

  @override
  Widget build(BuildContext context) {
    // The app propagates the accessibility high-contrast setting into
    // MediaQuery, so no provider watch is needed here.
    final highContrast = AppTheme.highContrastOf(context);
    // Locale digits for the day/tithi numbers: Latin in every locale stays
    // Latin, Bengali renders Bengali digits. Applied at render time (not in
    // the providers) so the sync label caches stay locale-independent.
    final locale = Localizations.localeOf(context).languageCode;
    final resolvedPrimary = localizeDigits(
      primaryText.isEmpty ? date.day.toString() : primaryText,
      locale,
    );

    final scheme = context.colors;
    // Selected wins over today (spec .today.sel).
    BoxDecoration? decoration;
    Color textColor = scheme.onSurface;
    FontWeight weight = FontWeight.w500;
    Matrix4? transform;

    if (isSelected) {
      decoration = BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: AppTheme.calendarSelectedGradient(context),
        ),
        border: highContrast
            ? Border.all(
                color: scheme.onSurface.withValues(alpha: 0.6),
                width: 1.5,
              )
            : null,
        // Soft glow only: the previous hard spread-3 "card ring" used
        // cardTheme.color, which mismatches the glassmorphism card behind
        // the grid, so it read as a halo while the 1.08 scale still bled
        // over neighbors. The tile margin below provides the real gutter.
        boxShadow: highContrast
            ? null
            : [
                BoxShadow(
                  color: AppTheme.heroGlow(context),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
      );
      textColor = AppTheme.calendarSelectedForeground(context);
      weight = FontWeight.w600;
      transform = Matrix4.identity()..scaleByDouble(1.08, 1.08, 1.0, 1.0);
    } else if (isToday) {
      decoration = BoxDecoration(
        color: AppTheme.calendarTodayBackground(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.calendarTodayRing(context),
          width: 1.5,
        ),
      );
      textColor = AppTheme.calendarTodayForeground(context);
      weight = FontWeight.w600;
    }

    // Outside-month days render muted (spec `.d.muted`: dim at 35%) unless
    // they carry the selected/today emphasis.
    if (isOutside && !isSelected && !isToday) {
      textColor = scheme.onSurface.withValues(alpha: 0.35);
    }

    final secondaryColor = isSelected
        ? AppTheme.calendarSelectedForeground(context).withValues(alpha: 0.7)
        : isToday
        ? AppTheme.calendarTodayForeground(context).withValues(alpha: 0.7)
        : scheme.onSurface.withValues(alpha: isOutside ? 0.35 : 0.5);

    // 2px gutter on every tile: adjacent squares no longer touch, so the
    // selected tile's 1.08 scale (~2px overflow on a ~50px cell) just fills
    // its own gutter instead of covering the neighbor's today-ring. The
    // weekend stripe shows through the gutters, as in the spec grid.
    return Container(
      margin: const EdgeInsets.all(2),
      decoration: decoration,
      transform: transform,
      transformAlignment: Alignment.center,
      // NOTE: no clipBehavior here — Container asserts
      // (decoration != null || clipBehavior == Clip.none), and plain day
      // tiles have no decoration. The children (centered number + corner
      // label) never reach the rounded corners, so no clip is needed.
      child: Stack(
        children: [
          Center(
            child: Text(
              resolvedPrimary,
              style: TextStyle(
                color: textColor,
                fontSize: 14,
                fontWeight: weight,
              ),
            ),
          ),
          if (secondaryText != null)
            Positioned(
              top: 4,
              left: 6,
              child: Text(
                localizeDigits(secondaryText!, locale),
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
