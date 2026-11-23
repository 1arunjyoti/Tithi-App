import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/feedback/app_haptics.dart';
import '../../../providers/calendar_provider.dart' as cp;
import '../../../providers/panchang_provider.dart';
import '../../../services/bengali_calendar_service.dart';
import '../../../services/hindu_calendar_service.dart';
import '../data/calendar_caches.dart';

// Phase 4b: month navigation extracted from the former calendar_widget.dart monolith.
// Keeps the Gregorian / Hindu / Bengali branching and the instant-on-cache-hit
// lunar navigation contract out of the render layer.

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

/// Navigate to the previous month based on the calendar system.
/// Guarded against double-taps: the lunar paths await native calls, so
/// overlapping invocations would interleave two month resolutions.
void navigateToPreviousMonth(
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
    if (primarySystem != cp.AppCalendarSystem.gregorian) {
      AppHaptics.tap(ref);
    }

    if (primarySystem == cp.AppCalendarSystem.bengali) {
      // Navigate by Bengali Month - instant on cache hit (no FFI before
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
/// Same re-entrancy guard as [navigateToPreviousMonth].
void navigateToNextMonth(
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
    // Same split as navigateToPreviousMonth: Gregorian buzzes once via
    // onPageChanged; Hindu/Bengali buzz here.
    if (primarySystem != cp.AppCalendarSystem.gregorian) {
      AppHaptics.tap(ref);
    }

    if (primarySystem == cp.AppCalendarSystem.bengali) {
      // Navigate by Bengali Month - instant on cache hit (no FFI before
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
