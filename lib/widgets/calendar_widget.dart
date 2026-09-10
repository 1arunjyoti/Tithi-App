import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:table_calendar/table_calendar.dart';
import '../l10n/app_localizations.dart';
import '../providers/calendar_provider.dart' as cp;
import '../providers/panchang_provider.dart';
import '../providers/festival_provider.dart';
import '../providers/accessibility_provider.dart';
import '../services/bengali_calendar_service.dart';
import '../services/hindu_calendar_service.dart';
import '../services/storage_service.dart';
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

// Sync LRU for festival indicator dots.
// Gregorian markers come from monthlyPanchangProvider, which is cold for the
// next month until it finishes heavy FFI work. Without a stale fallback the
// dots are missing during the swipe animation and pop in after landing.
// This cache is populated from every loaded month (current + precached
// neighbors) so the next month can show stale dots instantly.
final Map<DateTime, ({bool hasFestivals, bool isMajor})>
    _festivalDotCache = {};
const int _festivalDotCacheMax = 600;
final Set<String> _precachedFestivalMonthKeys = {};

DateTime _normalizeMonthKey(DateTime month) =>
    DateTime(month.year, month.month);

String _festivalMonthPrecacheKey(DateTime month) =>
    '${month.year}-${month.month}';

// Debug-only error log: release builds keep the silent-fallback behavior
// (stale cache / day number) so one bad FFI date never breaks the grid.
void _logCalError(String where, Object e) {
  if (kDebugMode) debugPrint('[calendar] $where: $e');
}

// Verbose navigation diagnostics (debug builds only): one line per month
// turn (intent → resolved target → sliced span → header text) with plain
// ymd dates — no extra FFI, only values already in hand. Used to diagnose
// Adhika/Nija boundary issues on-device; silent in release.
void _logCalNav(String message) {
  if (kDebugMode) debugPrint('[calnav] $message');
}

String _ymd(DateTime d) => '${d.year}-${d.month}-${d.day}';

// Bounded dedupe for precache keys. The sync LRU maps above are capped,
// but these Sets grew without bound (one entry per month × prefs combo
// ever visited). Cap at 120; oldest half is dropped on overflow.
bool _addBoundedPrecacheKey(Set<String> set, String key) {
  if (!set.add(key)) return false;
  const max = 120;
  if (set.length > max) {
    set.removeAll(set.take(set.length - max ~/ 2).toList());
  }
  return true;
}

// Guards _scheduleAdjacentPrecache: it is called from build, so without
// this every selection-change rebuild would queue another postFrame +
// 300ms delayed precache run. Only schedule when the request actually
// changed (month or calendar prefs).
String? _lastPrecacheRequest;

bool _claimPrecacheRequest(String request) {
  if (_lastPrecacheRequest == request) return false;
  _lastPrecacheRequest = request;
  return true;
}

// Re-entrancy guard for chevron navigation: the Hindu/Bengali paths await
// native calls, so a double-tap could interleave two month resolutions
// (wasted FFI, last-wins race). Gregorian taps are sync and unaffected.
bool _monthNavInFlight = false;

// Stale-data cache for the adaptive (Hindu/Bengali) grid. Family-arg changes
// create a FRESH provider instance, so Riverpod keeps no previous value —
// without this every month turn swaps the whole grid to a skeleton and back
// (the cell "flash"). Holding the last resolved grid renders the previous
// month instantly while the new one resolves, exactly like the Gregorian
// path's sync stale-label/dot caches. Scoped by system+displayMode so a
// Hindu grid is never shown as stale Bengali data.
_AdaptiveCalendarData? _lastAdaptiveData;
int? _lastAdaptiveSystemIndex;
int? _lastAdaptiveModeIndex;
// Key of [_lastAdaptiveData]. The AnimatedSwitcher below must keep showing
// the stale grid under its OLD key while the new month loads — keying stale
// content by the NEW month animates old cells as if they were new (the
// swipe "flash": current month slides/fades into itself, then pops to the
// real month). Single slide only once fresh data arrives.
String? _lastAdaptiveKey;

// Instant navigation targets for lunar months. Resolving the prev/next lunar
// month start needs FFI (calculateDate + getMonthStart), which used to block
// every swipe/chevron before the UI could respond. Precache (and successful
// FFI navigation) records targets keyed by the exact focused date, so repeat
// navigation is a sync map lookup. Forward-only entries: each is a true
// statement about the focused date's own lunar month regardless of whether
// the focused date is a month start.
/// Instant navigation targets for lunar months (see above). Keys carry the
/// [_adaptiveCacheCodeVersion] suffix, so entries computed by older logic —
/// including ones already sitting in this isolate across a hot reload, whose
/// static values survive — simply miss on lookup instead of misdirecting
/// navigation. Bump the version when resolution logic changes; old keys age
/// out through the cap below.
final Map<String, DateTime> _adaptiveNavTargets = {};
const int _adaptiveNavTargetsMax = 120;

String _versionedNavKey(String navKey) =>
    '${navKey}_v$_adaptiveCacheCodeVersion';

DateTime? _readAdaptiveNavTarget(String navKey) {
  return _adaptiveNavTargets[_versionedNavKey(navKey)];
}

void _storeAdaptiveNavTarget(String key, DateTime target) {
  _ensureAdaptiveCacheLoaded();
  if (_adaptiveNavTargets.length >= _adaptiveNavTargetsMax) {
    _adaptiveNavTargets.remove(_adaptiveNavTargets.keys.first);
  }
  _adaptiveNavTargets[_versionedNavKey(key)] = target;
  _scheduleAdaptiveCachePersist();
}

String _adaptiveNavKey(cp.AppCalendarSystem system, DateTime focusedMonth) =>
    '${system.index}_${focusedMonth.year}_${focusedMonth.month}_${focusedMonth.day}';

// Slide direction of the last adaptive month turn (+1 next, -1 previous),
// read by the grid's AnimatedSwitcher so swipes/chevrons slide correctly.
int _adaptiveSlideDirection = 1;

// ---- Persisted adaptive caches: instant months after app restart ----
// The nav-target map and secondary-label LRU above are memory-only, so the
// first swipe after every launch repaid full FFI. Both are deterministic per
// location (+displayMode for labels, baked into the key), so they persist in
// the settings box, invalidated by the cached-location signature. Festival
// dots are deliberately NOT persisted (festival data can change).
const _adaptiveCacheSigKey = 'adaptive_cache_sig';
const _adaptiveNavPersistKey = 'adaptive_nav_targets';
const _adaptiveLabelsPersistKey = 'adaptive_secondary_labels';

bool _adaptiveCacheLoaded = false;
Timer? _adaptiveCachePersistTimer;

/// Code version of the adaptive nav/label resolution logic. BUMP this
/// whenever the meaning of a persisted entry can change (slicing, neighbor
/// resolution, label derivation) — otherwise entries written by older logic
/// load as truth and send navigation to the wrong (or same) month. Part of
/// the persisted signature, so stale generations are ignored automatically.
/// v3: month boundaries resolved by masa transition instead of tithi-1
/// scans (Kshaya Pratipada has no tithi-1 day to find).
/// v4: new-moon instants wrap-interpolated + bisected (noon sampling put
/// same-day transit/new-moon coincidences on the wrong side).
const int _adaptiveCacheCodeVersion = 4;

String _adaptiveCacheSignature() {
  try {
    if (!Hive.isBoxOpen(StorageService.locationSettingsBoxName)) return '';
    final box = Hive.box(StorageService.locationSettingsBoxName);
    final lat = box.get('cached_lat', defaultValue: 28.6139);
    final lng = box.get('cached_lng', defaultValue: 77.2090);
    return '${lat}_${lng}_v$_adaptiveCacheCodeVersion';
  } catch (_) {
    return '';
  }
}

/// Adaptive month setter that ignores no-op targets. A stale/wrong cached
/// target equal to the viewed month would otherwise look like a frozen
/// calendar (state set to the same value → no rebuild, no feedback).
void _setAdaptiveMonth(WidgetRef ref, DateTime target, DateTime focusedMonth) {
  if (target.year == focusedMonth.year &&
      target.month == focusedMonth.month &&
      target.day == focusedMonth.day) {
    _logCalNav('nav settled: IGNORED self-target ${_ymd(target)}');
    return;
  }
  _logCalNav('nav settled: ${_ymd(focusedMonth)} -> ${_ymd(target)}');
  cp.setCalendarMonth(ref, target);
}

void _ensureAdaptiveCacheLoaded() {
  if (_adaptiveCacheLoaded) return;
  _adaptiveCacheLoaded = true;
  try {
    if (!Hive.isBoxOpen(StorageService.settingsBoxName)) return;
    final box = Hive.box(StorageService.settingsBoxName);
    final storedSig = box.get(_adaptiveCacheSigKey);
    if (storedSig is! String || storedSig != _adaptiveCacheSignature()) {
      return;
    }
    final nav = box.get(_adaptiveNavPersistKey);
    if (nav is Map) {
      for (final entry in nav.entries) {
        if (entry.key is String && entry.value is int) {
          _adaptiveNavTargets[entry.key as String] =
              DateTime.fromMillisecondsSinceEpoch(entry.value as int);
        }
      }
    }
    final labels = box.get(_adaptiveLabelsPersistKey);
    if (labels is Map) {
      for (final entry in labels.entries) {
        if (entry.key is String && entry.value is String) {
          _secondaryDayCache[entry.key as String] = entry.value as String;
        }
      }
    }
  } catch (_) {
    // Best-effort only; the memory caches stand alone.
  }
}

void _scheduleAdaptiveCachePersist() {
  // Debounced: a month turn stores ~30 labels; one write per turn, not one
  // per cell. Fire-and-forget puts; a failed write just means next launch
  // recomputes (correct, merely slower).
  _adaptiveCachePersistTimer?.cancel();
  _adaptiveCachePersistTimer = Timer(const Duration(seconds: 2), () {
    try {
      final sig = _adaptiveCacheSignature();
      if (sig.isEmpty || !Hive.isBoxOpen(StorageService.settingsBoxName)) {
        return;
      }
      final box = Hive.box(StorageService.settingsBoxName);
      unawaited(box.put(_adaptiveCacheSigKey, sig));
      unawaited(
        box.put(
          _adaptiveNavPersistKey,
          Map<String, int>.fromEntries(
            _adaptiveNavTargets.entries.map(
              (e) => MapEntry(e.key, e.value.millisecondsSinceEpoch),
            ),
          ),
        ),
      );
      unawaited(
        box.put(
          _adaptiveLabelsPersistKey,
          Map<String, String>.of(_secondaryDayCache),
        ),
      );
    } catch (_) {}
  });
}

void _storeFestivalDotsSync(Map<DateTime, PanchangData> monthData) {
  for (final entry in monthData.entries) {
    if (_festivalDotCache.length >= _festivalDotCacheMax) {
      final toRemove = _festivalDotCache.keys
          .take(_festivalDotCacheMax ~/ 5)
          .toList();
      for (final k in toRemove) {
        _festivalDotCache.remove(k);
      }
    }
    final panchang = entry.value;
    _festivalDotCache[entry.key] = (
      hasFestivals: panchang.hasFestivals,
      isMajor: panchang.majorFestivals.isNotEmpty,
    );
  }
}

({bool hasFestivals, bool isMajor})? _cachedFestivalDotSync(DateTime date) {
  return _festivalDotCache[
      DateTime(date.year, date.month, date.day)];
}

void _storeAdaptiveDotsSync(Map<DateTime, _CalendarCellData> cellData) {
  for (final entry in cellData.entries) {
    if (_festivalDotCache.length >= _festivalDotCacheMax) {
      final toRemove = _festivalDotCache.keys
          .take(_festivalDotCacheMax ~/ 5)
          .toList();
      for (final k in toRemove) {
        _festivalDotCache.remove(k);
      }
    }
    _festivalDotCache[entry.key] = (
      hasFestivals: entry.value.hasFestivals,
      isMajor: entry.value.hasMajorFestival,
    );
  }
}

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
  _ensureAdaptiveCacheLoaded();
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
  _ensureAdaptiveCacheLoaded();
  if (_secondaryDayCache.length >= _secondaryDayCacheMax) {
    final toRemove = _secondaryDayCache.keys
        .take(_secondaryDayCacheMax ~/ 5)
        .toList();
    for (final k in toRemove) {
      _secondaryDayCache.remove(k);
    }
  }
  _secondaryDayCache[_secondaryCacheKey(date, system, displayMode)] = value;
  _scheduleAdaptiveCachePersist();
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
      } catch (e) {
        _logCalError('hindu date $date', e);
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
      } catch (e) {
        _logCalError('bengali date $date', e);
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

  // Shared inputs for the festival-flag fast path below, hoisted out of the
  // per-cell closure so providers are read once per month, not ~42×.
  final flagService = includeFestivals ? ref.read(panchangServiceProvider) : null;
  final flagFestivals = includeFestivals ? ref.read(festivalProvider) : null;
  final flagMonthSystem = includeFestivals ? ref.watch(cp.hinduMonthSystemProvider) : null;
  final flagCoords = includeFestivals ? ref.watch(resolvedCoordinatesProvider) : null;
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
  final result = <DateTime, _CalendarCellData>{};
  Future<MapEntry<DateTime, _CalendarCellData>> computeCell(DateTime date) async {
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
    // Cheap path on purpose: computePanchangData WITHOUT the daytime
    // transition search (that bisection exists for the single-day detail
    // card; dots only need hasFestivals/majorFestivals, which the Hive
    // checkpoints + festival matching resolve identically). Same 5-point
    // tithi/masa cache as the monthly batch, so warm months are ~zero FFI.
    bool hasFestivals = false;
    bool hasMajorFestival = false;
    if (includeFestivals) {
      try {
        final panchang = await computePanchangData(
          normalizedDate: normalizedDate,
          service: flagService!,
          festivals: flagFestivals!,
          monthSystem: flagMonthSystem!,
          latitude: flagCoords!.latitude,
          longitude: flagCoords.longitude,
          cacheBox: flagCacheBox!,
        );
        hasFestivals = panchang.hasFestivals;
        hasMajorFestival = panchang.majorFestivals.isNotEmpty;
      } catch (e) {
        _logCalError('festival flag $normalizedDate', e);
      }
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
  }

  for (var i = 0; i < dates.length; i += batchSize) {
    final end =
        (i + batchSize) > dates.length ? dates.length : i + batchSize;
    final batch = dates.sublist(i, end);
    final entries = await Future.wait(batch.map(computeCell));
    for (final entry in entries) {
      result[entry.key] = entry.value;
    }
  }

  return result;
}

// autoDispose: instances are per-month and the sync LRU
// (_secondaryDayCache) already preserves labels across disposal, so the
// next visit re-renders instantly while fresh data resolves behind it.
final gregorianCalendarCellDataProvider =
    FutureProvider.autoDispose.family<
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

// autoDispose with a 5-minute keepAlive, mirroring monthlyPanchangProvider:
// swiping back/forth between the same lunar months stays warm for instant
// landing instead of recomputing. Each entry holds ~42 tiny cell records,
// so idle months are still released rather than retained for the session.
final adaptiveCalendarDataProvider =
    FutureProvider.autoDispose.family<
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
      final keepAliveLink = ref.keepAlive();
      final releaseTimer = Timer(
        const Duration(minutes: 5),
        keepAliveLink.close,
      );
      ref.onDispose(releaseTimer.cancel);

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
      _logCalNav(
        'slice ${args.adaptiveSystem} focused=${_ymd(args.focusedMonth)} '
        'start=${_ymd(startDate)} next=${_ymd(nextMonthStart)} days=$daysInMonth',
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

      final cellData = await _buildCalendarCellData(
        ref,
        visibleDates,
        args.primarySystem,
        args.secondarySystem,
        args.displayMode,
      );

      return _AdaptiveCalendarData(days: grid, cellData: cellData);
    });

/// Pre-computes neighbor months so sliding feels instant. Covers both the
/// secondary corner labels and (Gregorian path) the festival indicator dots
/// from monthlyPanchangProvider. Delayed well past the page animation,
/// sequential (next then previous) to avoid FFI bursts on the UI thread,
/// stale-guarded so rapid swipes don't pile up obsolete work, and never
/// throws into the UI.
void _scheduleAdjacentPrecache(
  WidgetRef ref,
  DateTime focusedMonth,
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

  // Called from build on every rebuild: only queue one precache run per
  // distinct month+prefs request instead of piling up a postFrame + delayed
  // future per selection tap.
  final requestKey =
      '$scheduledYear-$scheduledMonth-${startOfWeek.index}_${primarySystem.index}_${secondarySystem.index}_${displayMode.index}';
  if (!_claimPrecacheRequest(requestKey)) return;

  bool isStale() {
    // ref.read throws once the owning widget is unmounted — treat as stale
    // so pending precache work is dropped instead of crashing.
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
      // 300ms (was 800ms): starts right after the page animation settles
      // so fast swipers still hit a warm cache. Heavy work stays sequential
      // next-then-prev to avoid FFI bursts.
      Future.delayed(const Duration(milliseconds: 300), () async {
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
          _logCalError('precache $requestKey', e);
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
    _normalizeMonthKey(DateTime(focusedMonth.year, focusedMonth.month + 1)),
    _normalizeMonthKey(DateTime(focusedMonth.year, focusedMonth.month - 1)),
  ];
  final needsSecondaryLabels =
      secondarySystem != cp.AppCalendarSystem.none;
  for (final month in neighbors) {
    if (isStale()) return;
    // Festival dots: always needed, independent of secondary labels.
    // Warms the Hive tithi/masa cache and fills _festivalDotCache so the
    // next month shows stale dots instantly instead of popping in.
    final festivalKey = _festivalMonthPrecacheKey(month);
    if (_addBoundedPrecacheKey(_precachedFestivalMonthKeys, festivalKey)) {
      try {
        final monthData = await ref.read(
          monthlyPanchangProvider(month).future,
        );
        _storeFestivalDotsSync(monthData);
      } catch (e) {
        _precachedFestivalMonthKeys.remove(festivalKey);
        _logCalError('precache festivals $festivalKey', e);
      }
    }
    if (isStale()) return;
    // Secondary corner labels: only when a secondary system is shown.
    if (!needsSecondaryLabels) continue;
    final key = _monthPrecacheKey(
      month,
      startOfWeek,
      primarySystem,
      secondarySystem,
      displayMode,
    );
    if (!_addBoundedPrecacheKey(_precachedMonthKeys, key)) continue;
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
      _precachedMonthKeys.remove(key);
      _logCalError('precache labels $key', e);
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
    _logCalError('precache adaptive targets', e);
    return;
  }

  // Record instant-navigation targets for this exact focused date:
  // targets are ordered [prev, next] on both paths.
  if (targets.length == 2) {
    final base = _adaptiveNavKey(primarySystem, focusedMonth);
    _storeAdaptiveNavTarget('${base}_-1', targets[0]);
    _storeAdaptiveNavTarget('${base}_+1', targets[1]);
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
    if (!_addBoundedPrecacheKey(_precachedMonthKeys, key)) continue;
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
      _precachedMonthKeys.remove(key);
      _logCalError('precache adaptive $key', e);
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

    final monthKey = _normalizeMonthKey(heavyMonth);
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
              _storeFestivalDotsSync(data);
              return data;
            },
            loading: () => <DateTime, PanchangData>{},
            error: (_, _) => <DateTime, PanchangData>{},
          );

    final gregorianCellDataAsync = isAdaptive
        ? const AsyncValue<Map<DateTime, _CalendarCellData>>.loading()
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
        : const AsyncValue<_AdaptiveCalendarData>.loading();
    final adaptiveKey = _adaptiveNavKey(primarySystem, focusedMonth);
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
    final adaptiveDisplay = adaptiveFresh ?? (reuseStale ? _lastAdaptiveData : null);
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
        startOfWeek,
        primarySystem,
        secondarySystem,
        displayMode,
      );
    }

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

          if (isAdaptive)
            // Adaptive grid has no internal PageView, so swipe is handled here.
            // Stale-first: the previous month stays mounted under its OLD key
            // while fresh data resolves (no animation), then slides once to
            // the new month — the same stale-then-single-transition pattern
            // as the Gregorian path's sync stale-label caches. No skeleton
            // flash by default.
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
                          begin: Offset(
                            0.35 * _adaptiveSlideDirection,
                            0,
                          ),
                          end: Offset.zero,
                        ).animate(
                          CurvedAnimation(
                            parent: animation,
                            curve: Curves.easeOutCubic,
                          ),
                        );
                    return SlideTransition(
                      position: slide,
                      child: child,
                    );
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
              child: TableCalendar(
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
                availableGestures: AvailableGestures.horizontalSwipe,
                startingDayOfWeek: startOfWeek == cp.StartingDayOfWeek.sunday
                    ? StartingDayOfWeek.sunday
                    : StartingDayOfWeek.monday,
                selectedDayPredicate: (day) => isSameDay(day, selectedDate),
                onDaySelected: (selected, focused) {
                  if (ref.read(accessibilityProvider).hapticFeedback) {
                    HapticFeedback.lightImpact();
                  }
                  ref.read(cp.selectedDateProvider.notifier).setDate(selected);
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
                  // separately on this path (see _navigateTo*Month).
                  if (ref.read(accessibilityProvider).hapticFeedback) {
                    HapticFeedback.lightImpact();
                  }
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
                      isToday: isSameDay(date, today),
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
              ),
        ],
      ),
    );
  }

  /// 5-row skeleton for cold start (the most common lunar-month shape);
  /// month turns reuse the stale grid instead, and row counts of 4-6 settle
  /// naturally like the Gregorian path.
  Widget _buildAdaptiveSkeleton(BuildContext context, {Key? key}) {
    return Column(
      key: key,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            for (var i = 0; i < 7; i++)
              Expanded(
                child: Center(
                  child: Text(
                    _getWeekdayName(i, cp.StartingDayOfWeek.sunday),
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
    _AdaptiveCalendarData adaptiveData,
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

            final isSelected = isSameDay(date, selectedDate);
            final isToday = isSameDay(date, today);

            final normalizedDate = DateTime(date.year, date.month, date.day);
            final cellData = adaptiveData.cellData[normalizedDate];
            // Festival info is embedded in cellData (from adaptive provider)
            // which uses the correct lunar date range — no Gregorian mismatch.
            // Fall back to stale dots while the next lunar month is loading.
            final staleDot = cellData == null
                ? _cachedFestivalDotSync(normalizedDate)
                : null;
            final hasFestivals =
                cellData?.hasFestivals ?? staleDot?.hasFestivals ?? false;
            final hasMajorFestival = cellData?.hasMajorFestival ??
                staleDot?.isMajor ??
                false;

            return GestureDetector(
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
              onPrimary: Colors.white,
              surface: Theme.of(context).scaffoldBackgroundColor,
            ),
          ),
          child: child!,
        );
      },
    );

    if (selectedDate != null) {
      cp.setCalendarMonth(
        ref,
        DateTime(selectedDate.year, focusedMonth.month),
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
    if (_monthNavInFlight) return;
    _monthNavInFlight = true;
    // Load persisted nav targets before the cache-hit lookup below, so the
    // first swipe after a restart can already move instantly.
    _ensureAdaptiveCacheLoaded();
    _logCalNav('nav prev intent: focused=${_ymd(focusedMonth)} system=$primarySystem');
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
        _adaptiveSlideDirection = -1;
        final navKey = '${_adaptiveNavKey(primarySystem, focusedMonth)}_-1';
        final cached = _readAdaptiveNavTarget(navKey);
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
          _storeAdaptiveNavTarget(navKey, newDate);
          _setAdaptiveMonth(ref, newDate, focusedMonth);
        }
      } else if (primarySystem == cp.AppCalendarSystem.hindu) {
        // Navigate by Hindu Lunar Month — same instant-on-hit pattern.
        // Exact-masa step back: index arithmetic would skip Nija months.
        _adaptiveSlideDirection = -1;
        final navKey = '${_adaptiveNavKey(primarySystem, focusedMonth)}_-1';
        final cached = _readAdaptiveNavTarget(navKey);
        if (cached != null) {
          _setAdaptiveMonth(ref, cached, focusedMonth);
        } else {
          final service = ref.read(hinduCalendarServiceProvider);
          await ref.read(panchangInitProvider.future);
          final newDate = await service.prevMasaStartFrom(focusedMonth);
          _storeAdaptiveNavTarget(navKey, newDate);
          _setAdaptiveMonth(ref, newDate, focusedMonth);
        }
      } else {
        cp.setCalendarMonth(
          ref,
          DateTime(focusedMonth.year, focusedMonth.month - 1),
        );
      }
    } catch (e) {
      _logCalError('navigate previous month', e);
    } finally {
      _monthNavInFlight = false;
    }
  }

  /// Navigate to the next month based on the calendar system.
  /// Same re-entrancy guard as [_navigateToPreviousMonth].
  void _navigateToNextMonth(
    WidgetRef ref,
    DateTime focusedMonth,
    cp.AppCalendarSystem primarySystem,
  ) async {
    if (_monthNavInFlight) return;
    _monthNavInFlight = true;
    // Load persisted nav targets before the cache-hit lookup below, so the
    // first swipe after a restart can already move instantly.
    _ensureAdaptiveCacheLoaded();
    _logCalNav('nav next intent: focused=${_ymd(focusedMonth)} system=$primarySystem');
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
        _adaptiveSlideDirection = 1;
        final navKey = '${_adaptiveNavKey(primarySystem, focusedMonth)}_+1';
        final cached = _readAdaptiveNavTarget(navKey);
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
          _storeAdaptiveNavTarget(navKey, newDate);
          _setAdaptiveMonth(ref, newDate, focusedMonth);
        }
      } else if (primarySystem == cp.AppCalendarSystem.hindu) {
        // Exact-masa step forward: lands on Nija months instead of skipping
        // them like index arithmetic did.
        _adaptiveSlideDirection = 1;
        final navKey = '${_adaptiveNavKey(primarySystem, focusedMonth)}_+1';
        final cached = _readAdaptiveNavTarget(navKey);
        if (cached != null) {
          _setAdaptiveMonth(ref, cached, focusedMonth);
        } else {
          final service = ref.read(hinduCalendarServiceProvider);
          await ref.read(panchangInitProvider.future);
          final newDate = await service.nextMasaStartFrom(focusedMonth);
          _storeAdaptiveNavTarget(navKey, newDate);
          _setAdaptiveMonth(ref, newDate, focusedMonth);
        }
      } else {
        cp.setCalendarMonth(
          ref,
          DateTime(focusedMonth.year, focusedMonth.month + 1),
        );
      }
    } catch (e) {
      _logCalError('navigate next month', e);
    } finally {
      _monthNavInFlight = false;
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
    Map<DateTime, PanchangData> monthlyPanchang,
  ) {
    final normalizedDate = DateTime(date.year, date.month, date.day);
    final panchang = monthlyPanchang[normalizedDate];

    if (panchang != null) {
      if (!panchang.hasFestivals) return null;
      return _buildFestivalDot(context, panchang.majorFestivals.isNotEmpty);
    }

    final stale = _cachedFestivalDotSync(normalizedDate);
    if (stale == null || !stale.hasFestivals) return null;
    return _buildFestivalDot(context, stale.isMajor);
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

// Sync LRU for calendar headers (Gregorian primary + Hindu/Bengali secondary
// range needs 2 FFI calls). Without a stale fallback the header shows bare
// Gregorian text during the swipe then flips once FFI resolves — perceived
// as lag. Populated from every loaded month so the next swipe shows stale
// text instantly while fresh data resolves behind it.
final Map<String, _HeaderData> _headerDataCache = {};
const int _headerDataCacheMax = 120;

String _headerCacheKey(
  DateTime date,
  cp.AppCalendarSystem primary,
  cp.AppCalendarSystem secondary,
  HinduYearEra yearEra,
  HinduMonthSystem monthSystem, [
  DateTime? selectedDate,
]) {
  final selectedKey = selectedDate == null
      ? 'range'
      : '${selectedDate.year}-${selectedDate.month}-${selectedDate.day}';
  return '${date.year}-${date.month}_${primary.index}_${secondary.index}_${yearEra.index}_${monthSystem.index}_$selectedKey';
}

_HeaderData? _cachedHeaderSync(
  DateTime date,
  cp.AppCalendarSystem primary,
  cp.AppCalendarSystem secondary,
  HinduYearEra yearEra,
  HinduMonthSystem monthSystem, [
  DateTime? selectedDate,
]) {
  return _headerDataCache[
      _headerCacheKey(date, primary, secondary, yearEra, monthSystem, selectedDate)];
}

void _storeHeaderSync(
  DateTime date,
  cp.AppCalendarSystem primary,
  cp.AppCalendarSystem secondary,
  HinduYearEra yearEra,
  HinduMonthSystem monthSystem,
  _HeaderData value, [
  DateTime? selectedDate,
]) {
  if (_headerDataCache.length >= _headerDataCacheMax) {
    final toRemove =
        _headerDataCache.keys.take(_headerDataCacheMax ~/ 5).toList();
    for (final k in toRemove) {
      _headerDataCache.remove(k);
    }
  }
  _headerDataCache[
      _headerCacheKey(
        date,
        primary,
        secondary,
        yearEra,
        monthSystem,
        selectedDate,
      )] = value;
}

// autoDispose: one tiny _HeaderData per visited month; the sync LRU
// (_headerDataCache) preserves headers across disposal, so the next visit
// renders stale text instantly while fresh data resolves behind it.
final calendarHeaderDataProvider =
    FutureProvider.autoDispose<_HeaderData>((ref) async {
  final date = ref.watch(cp.focusedMonthProvider);
  final primary = ref.watch(cp.primaryCalendarSystemProvider);
  final secondary = ref.watch(cp.secondaryCalendarSystemProvider);
  final hinduYearEra = ref.watch(cp.hinduYearEraProvider);
  final hinduMonthSystem = ref.watch(cp.hinduMonthSystemProvider);
  // Tapping a date tile narrows the secondary range label to that date's
  // single month; the tap state (not the default-selected today) drives a
  // header refresh, so the two-month range stays the default. Subscribed
  // only when the secondary header actually is a traditional range —
  // otherwise tile taps would pointlessly recompute this header (up to 2
  // FFI calls for a Hindu/Bengali primary label).
  final tapNarrowsSecondary =
      primary == cp.AppCalendarSystem.gregorian &&
      (secondary == cp.AppCalendarSystem.hindu ||
          secondary == cp.AppCalendarSystem.bengali);
  final tappedDate = tapNarrowsSecondary
      ? ref.watch(cp.tappedCalendarDateProvider)
      : null;
  final tappedInMonth =
      tappedDate != null &&
          tappedDate.year == date.year &&
          tappedDate.month == date.month
      ? DateTime(tappedDate.year, tappedDate.month, tappedDate.day)
      : null;

  final data = await _buildCalendarHeaderData(
    ref,
    date,
    primary,
    secondary,
    hinduYearEra,
    hinduMonthSystem,
    selectedDate: tappedInMonth,
  );
  // Feed the stale-header LRU so the next swipe shows text instantly
  // instead of falling back to bare Gregorian and flipping.
  _storeHeaderSync(
    date,
    primary,
    secondary,
    hinduYearEra,
    hinduMonthSystem,
    data,
    tappedInMonth,
  );
  return data;
});

Future<_HeaderData> _buildCalendarHeaderData(
  Ref ref,
  DateTime date,
  cp.AppCalendarSystem primary,
  cp.AppCalendarSystem secondary,
  HinduYearEra hinduYearEra,
  HinduMonthSystem hinduMonthSystem, {
  DateTime? selectedDate,
}) async {
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
      selectedDate: selectedDate,
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

  _logCalNav(
    'header date=${_ymd(date)} primary=$primary secondary=$secondary '
    '-> "$primaryText" / "$secondaryText"',
  );
  return _HeaderData(primaryText: primaryText, secondaryText: secondaryText);
}

Future<String?> _getTraditionalMonthRangeForCalendar(
  Ref ref,
  DateTime date,
  cp.AppCalendarSystem system,
  HinduYearEra hinduYearEra,
  HinduMonthSystem hinduMonthSystem, {
  DateTime? selectedDate,
}) async {
  if (system != cp.AppCalendarSystem.bengali &&
      system != cp.AppCalendarSystem.hindu) {
    return null;
  }

  try {
    // Tapped date in the focused month: narrow the range to that date's
    // single month with the year (e.g. "Shravana 1948" instead of
    // "Shravana - Bhadrapada 1948").
    if (selectedDate != null) {
      if (system == cp.AppCalendarSystem.bengali) {
        final service = ref.read(bengaliCalendarServiceProvider);
        await ref.read(panchangInitProvider.future);
        final selectedBDate = await service.calculateDate(selectedDate);
        return '${selectedBDate.month} ${selectedBDate.year}';
      } else {
        final service = ref.read(hinduCalendarServiceProvider);
        await ref.read(panchangInitProvider.future);
        final selectedHDate = await service.calculateDate(selectedDate);
        final year = hinduYearEra == HinduYearEra.vikramSamvat
            ? selectedHDate.vsYear
            : selectedHDate.shakaYear;
        final masa = displayMasaName(
          selectedHDate.masa,
          selectedHDate.paksha,
          hinduMonthSystem,
        ).replaceAll('_', ' ');
        return '$masa $year';
      }
    }

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
      ).replaceAll('_', ' ');
      endMonth = displayMasaName(
        endHDate.masa,
        endHDate.paksha,
        hinduMonthSystem,
      ).replaceAll('_', ' ');

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
  } catch (e) {
    _logCalError('traditional month range', e);
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
      // Exact-masa range: the containing month only, so an Adhika month no
      // longer stretches the range across both Adhika and Nija.
      final service = ref.read(hinduCalendarServiceProvider);
      await ref.read(panchangInitProvider.future);

      startDate = await service.monthStartContaining(date);
      endDate = await service.nextMonthStartAfter(startDate);
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
  } catch (e) {
    _logCalError('gregorian month range', e);
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
      } catch (e) {
        _logCalError('bengali header', e);
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
      } catch (e) {
        _logCalError('hindu header', e);
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
    final primary = ref.watch(cp.primaryCalendarSystemProvider);
    final secondary = ref.watch(cp.secondaryCalendarSystemProvider);
    final hinduYearEra = ref.watch(cp.hinduYearEraProvider);
    final hinduMonthSystem = ref.watch(cp.hinduMonthSystemProvider);
    // Mirrors the provider's gating: subscribe to taps only when the
    // secondary header has a tap-narrowed variant, so the key lookup stays
    // meaningful and taps skip this widget otherwise.
    final tappedDate =
        primary == cp.AppCalendarSystem.gregorian &&
            (secondary == cp.AppCalendarSystem.hindu ||
                secondary == cp.AppCalendarSystem.bengali)
        ? ref.watch(cp.tappedCalendarDateProvider)
        : null;
    final tappedInMonth =
        tappedDate != null &&
            tappedDate.year == focusedMonth.year &&
            tappedDate.month == focusedMonth.month
        ? DateTime(tappedDate.year, tappedDate.month, tappedDate.day)
        : null;
    final headerDataAsync = ref.watch(calendarHeaderDataProvider);
    // Stale header first so swipes never show bare Gregorian then flip;
    // fresh async data replaces it once FFI resolves. On a date tap the
    // tap-keyed entry misses until fresh data lands, so fall back to
    // the range entry (previous text) rather than bare Gregorian.
    final headerData =
        headerDataAsync.valueOrNull ??
        _cachedHeaderSync(
          focusedMonth,
          primary,
          secondary,
          hinduYearEra,
          hinduMonthSystem,
          tappedInMonth,
        ) ??
        _cachedHeaderSync(
          focusedMonth,
          primary,
          secondary,
          hinduYearEra,
          hinduMonthSystem,
        ) ??
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
