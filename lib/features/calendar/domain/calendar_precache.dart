import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/calendar_provider.dart' as cp;
import '../../../providers/festival_provider.dart';
import '../../../providers/location_provider.dart';
import '../../../providers/panchang_provider.dart';
import '../../../services/bengali_calendar_service.dart';
import '../../../services/hindu_calendar_service.dart';
import '../data/calendar_caches.dart';
import '../providers/cell_providers.dart';

// Phase 4a: neighbor-month precache extracted from the former calendar_widget.dart monolith.
// Best-effort background work that warms the next/previous month so a swipe
// lands instantly instead of showing a skeleton.

/// Reads a precache provider's future, retrying once if the instance was
/// disposed mid-load.
///
/// `ref.read(p.future)` alone subscribes to nothing, so a neighbor-month
/// instance nobody watches can be dropped while loading (`Bad state: ...
/// was disposed during loading state` — seen on first launch when the
/// location grant flips coordinates mid-precache). The retry rebuilds the
/// instance fresh; anything else rethrows immediately so real failures keep
/// the existing log-and-retry-later behavior at the call sites. Retries are
/// rare (normal precaches never hit this) and bounded to one, so an
/// expensive month batch can never spin.
Future<T> _readWarmed<T>(
  WidgetRef ref,
  ProviderListenable<Future<T>> providerFuture,
) async {
  try {
    return await ref.read(providerFuture);
  } on StateError catch (e) {
    if (!e.message.contains('disposed during loading')) rethrow;
    return await ref.read(providerFuture);
  }
}

/// Pre-computes neighbor months so sliding feels instant. Covers both the
/// secondary corner labels and (Gregorian path) the festival indicator dots
/// from monthlyPanchangProvider. It starts only after the calendar has been
/// idle, is cancelled by a date tap, is sequential (next then previous) to
/// avoid FFI bursts on the UI thread, and never throws into the UI.
void scheduleAdjacentPrecache(
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
  // Settle the inputs whose mid-load flip drops the warmed instance
  // (the first-launch location grant flips coordinates): warm against
  // stable deps instead of racing them. All resolved post-launch, so this
  // is instant in steady state; a failure here just skips the best-effort
  // pass — the visible month's own load surfaces real errors.
  try {
    await ref.read(panchangInitProvider.future);
    await ref.read(festivalInitProvider.future);
    await ref.read(currentLocationProvider.future);
  } catch (_) {
    return;
  }
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
        final monthData = await _readWarmed(
          ref,
          monthlyPanchangProvider(month).future,
        );
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
      await _readWarmed(
        ref,
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
  // Same settle-first contract as the Gregorian path above: don't warm
  // neighbor grids while init/location can still flip underneath them.
  try {
    await ref.read(festivalInitProvider.future);
    await ref.read(currentLocationProvider.future);
  } catch (_) {
    return;
  }

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
      await _readWarmed(
        ref,
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
