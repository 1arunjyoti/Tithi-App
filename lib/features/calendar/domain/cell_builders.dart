import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/panchang_data.dart';
import '../../../providers/calendar_provider.dart' as cp;
import '../../../providers/festival_provider.dart';
import '../../../providers/panchang_provider.dart';
import '../../../services/bengali_calendar_service.dart';
import '../../../services/festival_matching_pipeline.dart';
import '../../../services/hindu_calendar_service.dart';
import '../data/calendar_caches.dart';
import '../data/calendar_models.dart';

// Phase 3b: cell builders extracted from widgets/calendar_widget.dart.
// Pure domain logic parameterized by [Ref]; no widget lifecycle.

// Single date label for [system] (primary or secondary corner label).
Future<String> calendarDateForSystem(
  Ref ref,
  DateTime date,
  cp.AppCalendarSystem system,
  cp.TithiDisplayMode displayMode,
) async {
  switch (system) {
    case cp.AppCalendarSystem.gregorian:
      return date.day.toString();
    case cp.AppCalendarSystem.hindu:
      final cached = cachedSecondarySync(date, system, displayMode);
      if (cached != null) return cached;
      try {
        final service = ref.read(hinduCalendarServiceProvider);
        final hDate = await service.calculateDate(date);
        final result = displayMode == cp.TithiDisplayMode.continuous30
            ? hDate.fullTithi.toString()
            : hDate.tithi.toString();
        storeSecondarySync(date, system, displayMode, result);
        return result;
      } catch (e) {
        logCalError('hindu date $date', e);
        return date.day.toString();
      }
    case cp.AppCalendarSystem.bengali:
      final cached = cachedSecondarySync(date, system, displayMode);
      if (cached != null) return cached;
      try {
        final service = ref.read(bengaliCalendarServiceProvider);
        final bengaliDate = await service.calculateDate(date);
        final result = bengaliDate.day.toString();
        storeSecondarySync(date, system, displayMode, result);
        return result;
      } catch (e) {
        logCalError('bengali date $date', e);
        return date.day.toString();
      }
    case cp.AppCalendarSystem.none:
      return '';
  }
}

Future<Map<DateTime, CalendarCellData>> buildCalendarCellData(
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

  // Shared inputs for the festival-flag fast path below, hoisted out of the
  // per-cell closure so providers are read once per month, not ~42x.
  final flagService = includeFestivals
      ? ref.read(panchangServiceProvider)
      : null;
  final flagFestivals = includeFestivals ? ref.read(festivalProvider) : null;
  final flagMonthSystem = includeFestivals
      ? ref.watch(cp.hinduMonthSystemProvider)
      : null;
  final flagCoords = includeFestivals
      ? ref.watch(resolvedCoordinatesProvider)
      : null;
  final flagCacheBox = includeFestivals
      ? await preparePanchangCacheBox(
          flagCoords!.latitude,
          flagCoords.longitude,
        )
      : null;

  // Batched to avoid a ~42-wide FFI burst on cold months: Hindu secondary
  // labels need 2 native calls each (tithi + masa), so firing all at once
  // contends for the same native thread and janks the landing frame.
  // 8-at-a-time matches monthlyPanchangProvider and keeps precache effective.
  const batchSize = 8;
  final result = <DateTime, CalendarCellData>{};

  // Festival flags through the shared pipeline (NOT per-cell): compute the
  // padded range once, trim Vriddhi runs once, then read booleans per cell.
  // Padding ±4 days keeps Vriddhi runs straddling the grid edge correct and
  // covers the selected day plus the next three dates used by EventList.
  // That lets a Hindu/Bengali tile tap reuse these records rather than start
  // an additional Gregorian-month batch. Only grid dates are displayed.
  // Same 5-point tithi/masa cache as the monthly batch, so warm months are
  // ~zero FFI. Reading flags from an unfiltered per-cell compute instead
  // would let dots disagree with the detail sheets on trimmed days.
  Map<DateTime, PanchangData> filteredFlags = const {};
  if (includeFestivals && dates.isNotEmpty) {
    final padStart = dates.first.subtract(const Duration(days: 4));
    final padEnd = dates.last.add(const Duration(days: 4));
    final padDates = <DateTime>[];
    for (
      var d = padStart;
      !d.isAfter(padEnd);
      d = d.add(const Duration(days: 1))
    ) {
      padDates.add(DateTime(d.year, d.month, d.day));
    }
    final flagData = <DateTime, PanchangData>{};
    Future<void> computeFlag(DateTime normalizedDate) async {
      try {
        // Cheap path on purpose: computePanchangData WITHOUT the daytime
        // transition search (that bisection exists for the single-day detail
        // card; dots only need hasFestivals/majorFestivals). Individual
        // failures leave that day dotless rather than failing the month.
        flagData[normalizedDate] = await computePanchangData(
          normalizedDate: normalizedDate,
          service: flagService!,
          festivals: flagFestivals!,
          monthSystem: flagMonthSystem!,
          latitude: flagCoords!.latitude,
          longitude: flagCoords.longitude,
          cacheBox: flagCacheBox!,
        );
      } catch (e) {
        logCalError('festival flag $normalizedDate', e);
      }
    }

    for (var i = 0; i < padDates.length; i += batchSize) {
      final end = (i + batchSize) > padDates.length
          ? padDates.length
          : i + batchSize;
      await Future.wait(padDates.sublist(i, end).map(computeFlag));
      await yieldToEventLoop();
    }
    filteredFlags = applyVriddhiFilter(flagData);
    // Preserve the full day records, not only the dot booleans. The
    // selected-date provider consumes this bridge to avoid recomputing a
    // whole Gregorian month after a Hindu/Bengali date-cell tap.
    for (final entry in filteredFlags.entries) {
      storePanchangUiSync(entry.key, entry.value);
    }
  }

  Future<MapEntry<DateTime, CalendarCellData>> computeCell(
    DateTime date,
  ) async {
    final normalizedDate = DateTime(date.year, date.month, date.day);
    final pDate = await calendarDateForSystem(
      ref,
      normalizedDate,
      primary,
      displayMode,
    );
    String? sDate;
    if (secondary != cp.AppCalendarSystem.none && secondary != primary) {
      sDate = await calendarDateForSystem(
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
    // Flags read from the pipeline-filtered precompute above — dots agree
    // with detail sheets by construction (trimmed entries leave no dot).
    bool hasFestivals = false;
    bool hasMajorFestival = false;
    if (includeFestivals) {
      final flagged = filteredFlags[normalizedDate];
      hasFestivals = flagged?.hasFestivals ?? false;
      hasMajorFestival = flagged?.majorFestivals.isNotEmpty ?? false;
    }

    return MapEntry(
      normalizedDate,
      CalendarCellData(
        primary: pDate,
        secondary: sDate,
        hasFestivals: hasFestivals,
        hasMajorFestival: hasMajorFestival,
      ),
    );
  }

  for (var i = 0; i < dates.length; i += batchSize) {
    final end = (i + batchSize) > dates.length ? dates.length : i + batchSize;
    final batch = dates.sublist(i, end);
    final entries = await Future.wait(batch.map(computeCell));
    for (final entry in entries) {
      result[entry.key] = entry.value;
    }
    await yieldToEventLoop();
  }

  return result;
}
