import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

import '../../../core/location/cached_location.dart';
import '../../../models/panchang_data.dart';
import '../../../providers/calendar_provider.dart' as cp;
import '../../../services/storage_service.dart';

// Phase 3a: calendar sync caches extracted from widgets/calendar_widget.dart.
// These file-level LRUs let cells show stale labels/dots instantly while the
// next month's FutureProvider is still doing FFI. Owned here (data layer) so
// they are testable and independent of widget lifecycle; the widget imports
// and calls them instead of defining its own globals.

// Sync LRU for secondary corner labels (top-left of each date cell).
final Map<String, String> secondaryDayCache = {};
const int secondaryDayCacheMax = 600;
final Set<String> precachedMonthKeys = {};

// Sync LRU for festival indicator dots.
final Map<DateTime, ({bool hasFestivals, bool isMajor})> festivalDotCache = {};
const int festivalDotCacheMax = 600;
final Set<String> precachedFestivalMonthKeys = {};

DateTime normalizeMonthKey(DateTime month) =>
    DateTime(month.year, month.month);

String festivalMonthPrecacheKey(DateTime month) =>
    '${month.year}-${month.month}';

// Debug-only error log: release builds keep the silent-fallback behavior
// (stale cache / day number) so one bad FFI date never breaks the grid.
void logCalError(String where, Object e) {
  if (kDebugMode) debugPrint('[calendar] $where: $e');
}

// Verbose navigation diagnostics (debug builds only).
void logCalNav(String message) {
  if (kDebugMode) debugPrint('[calnav] $message');
}

String ymd(DateTime d) => '${d.year}-${d.month}-${d.day}';

bool isSameCalendarDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

// Yields one event-loop turn so gestures and frames interleave with long
// FFI batches. Plain `await` chains on already-complete futures only hop
// microtasks, which starve touch input for the whole burst.
Future<void> yieldToEventLoop() => Future<void>.delayed(Duration.zero);

// Bounded dedupe for precache keys. The sync LRU maps above are capped,
// but these Sets grew without bound (one entry per month × prefs combo
// ever visited). Cap at 120; oldest half is dropped on overflow.
bool addBoundedPrecacheKey(Set<String> set, String key) {
  if (!set.add(key)) return false;
  const max = 120;
  if (set.length > max) {
    set.removeAll(set.take(set.length - max ~/ 2).toList());
  }
  return true;
}

// Guards _scheduleAdjacentPrecache: it is called from build, so without
// this every selection-change rebuild would queue another postFrame +
// 300ms delayed precache run.
String? lastPrecacheRequest;

bool claimPrecacheRequest(String request) {
  if (lastPrecacheRequest == request) return false;
  lastPrecacheRequest = request;
  return true;
}

// Re-entrancy guard for chevron navigation: the Hindu/Bengali paths await
// native calls, so a double-tap could interleave two month resolutions
// (wasted FFI, last-wins race). Gregorian taps are sync and unaffected.
bool monthNavInFlight = false;

// Accumulated horizontal drag distance (logical px) for the current
// adaptive-grid swipe gesture. Reset on drag start/end; consulted together
// with release velocity by [adaptiveSwipeDirection] so slow drags turn the
// month exactly like Gregorian's position-based page view does.
double adaptiveSwipeDx = 0.0;

// Instant navigation targets for lunar months. Resolving the prev/next lunar
// month start needs FFI, which used to block every swipe/chevron before the
// UI could respond. Precache (and successful FFI navigation) records targets
// keyed by the exact focused date, so repeat navigation is a sync lookup.
final Map<String, DateTime> adaptiveNavTargets = {};
const int adaptiveNavTargetsMax = 120;

// Slide direction of the last adaptive month turn (+1 next, -1 previous),
// read by the grid's AnimatedSwitcher so swipes/chevrons slide correctly.
int adaptiveSlideDirection = 1;

// ---- Persisted adaptive caches: instant months after app restart ----
const adaptiveCacheSigKey = 'adaptive_cache_sig';
const adaptiveNavPersistKey = 'adaptive_nav_targets';
const adaptiveLabelsPersistKey = 'adaptive_secondary_labels';

bool adaptiveCacheLoaded = false;
Timer? adaptiveCachePersistTimer;

/// Code version of the adaptive nav/label resolution logic. BUMP this
/// whenever the meaning of a persisted entry can change — otherwise entries
/// written by older logic load as truth and misdirect navigation.
const int adaptiveCacheCodeVersion = 4;

String versionedNavKey(String navKey) =>
    '${navKey}_v$adaptiveCacheCodeVersion';

DateTime? readAdaptiveNavTarget(String navKey) {
  return adaptiveNavTargets[versionedNavKey(navKey)];
}

void storeAdaptiveNavTarget(String key, DateTime target) {
  ensureAdaptiveCacheLoaded();
  if (adaptiveNavTargets.length >= adaptiveNavTargetsMax) {
    adaptiveNavTargets.remove(adaptiveNavTargets.keys.first);
  }
  adaptiveNavTargets[versionedNavKey(key)] = target;
  scheduleAdaptiveCachePersist();
}

String adaptiveNavKey(cp.AppCalendarSystem system, DateTime focusedMonth) =>
    '${system.index}_${focusedMonth.year}_${focusedMonth.month}_${focusedMonth.day}';

String adaptiveCacheSignature() {
  try {
    if (!Hive.isBoxOpen(StorageService.locationSettingsBoxName)) return '';
    final box = Hive.box(StorageService.locationSettingsBoxName);
    final coords = readCachedLatLng(box);
    return '${coords.latitude}_${coords.longitude}_v$adaptiveCacheCodeVersion';
  } catch (_) {
    return '';
  }
}

void ensureAdaptiveCacheLoaded() {
  if (adaptiveCacheLoaded) return;
  adaptiveCacheLoaded = true;
  try {
    if (!Hive.isBoxOpen(StorageService.settingsBoxName)) return;
    final box = Hive.box(StorageService.settingsBoxName);
    final storedSig = box.get(adaptiveCacheSigKey);
    if (storedSig is! String || storedSig != adaptiveCacheSignature()) {
      return;
    }
    final nav = box.get(adaptiveNavPersistKey);
    if (nav is Map) {
      for (final entry in nav.entries) {
        if (entry.key is String && entry.value is int) {
          adaptiveNavTargets[entry.key as String] =
              DateTime.fromMillisecondsSinceEpoch(entry.value as int);
        }
      }
    }
    final labels = box.get(adaptiveLabelsPersistKey);
    if (labels is Map) {
      for (final entry in labels.entries) {
        if (entry.key is String && entry.value is String) {
          secondaryDayCache[entry.key as String] = entry.value as String;
        }
      }
    }
  } catch (_) {
    // Best-effort only; the memory caches stand alone.
  }
}

void scheduleAdaptiveCachePersist() {
  // Debounced: a month turn stores ~30 labels; one write per turn, not one
  // per cell. Fire-and-forget puts; a failed write just means next launch
  // recomputes (correct, merely slower).
  adaptiveCachePersistTimer?.cancel();
  adaptiveCachePersistTimer = Timer(const Duration(seconds: 2), () {
    try {
      final sig = adaptiveCacheSignature();
      if (sig.isEmpty || !Hive.isBoxOpen(StorageService.settingsBoxName)) {
        return;
      }
      final box = Hive.box(StorageService.settingsBoxName);
      unawaited(box.put(adaptiveCacheSigKey, sig));
      unawaited(
        box.put(
          adaptiveNavPersistKey,
          Map<String, int>.fromEntries(
            adaptiveNavTargets.entries.map(
              (e) => MapEntry(e.key, e.value.millisecondsSinceEpoch),
            ),
          ),
        ),
      );
      unawaited(
        box.put(
          adaptiveLabelsPersistKey,
          Map<String, String>.of(secondaryDayCache),
        ),
      );
    } catch (_) {}
  });
}

void storeFestivalDotsSync(Map<DateTime, PanchangData> monthData) {
  for (final entry in monthData.entries) {
    if (festivalDotCache.length >= festivalDotCacheMax) {
      final toRemove = festivalDotCache.keys
          .take(festivalDotCacheMax ~/ 5)
          .toList();
      for (final k in toRemove) {
        festivalDotCache.remove(k);
      }
    }
    final panchang = entry.value;
    festivalDotCache[entry.key] = (
      hasFestivals: panchang.hasFestivals,
      isMajor: panchang.majorFestivals.isNotEmpty,
    );
  }
}

({bool hasFestivals, bool isMajor})? cachedFestivalDotSync(DateTime date) {
  return festivalDotCache[DateTime(date.year, date.month, date.day)];
}

void storeAdaptiveDotsSync(
  Map<DateTime, ({bool hasFestivals, bool isMajor})> cellData,
) {
  for (final entry in cellData.entries) {
    if (festivalDotCache.length >= festivalDotCacheMax) {
      final toRemove = festivalDotCache.keys
          .take(festivalDotCacheMax ~/ 5)
          .toList();
      for (final k in toRemove) {
        festivalDotCache.remove(k);
      }
    }
    festivalDotCache[entry.key] = entry.value;
  }
}

String secondaryCacheKey(
  DateTime date,
  cp.AppCalendarSystem system,
  cp.TithiDisplayMode displayMode,
) {
  return '${date.year}-${date.month}-${date.day}_${system.index}_${displayMode.index}';
}

String? cachedSecondarySync(
  DateTime date,
  cp.AppCalendarSystem system,
  cp.TithiDisplayMode displayMode,
) {
  if (system == cp.AppCalendarSystem.none ||
      system == cp.AppCalendarSystem.gregorian) {
    return null;
  }
  ensureAdaptiveCacheLoaded();
  return secondaryDayCache[secondaryCacheKey(date, system, displayMode)];
}

void storeSecondarySync(
  DateTime date,
  cp.AppCalendarSystem system,
  cp.TithiDisplayMode displayMode,
  String value,
) {
  if (system == cp.AppCalendarSystem.none ||
      system == cp.AppCalendarSystem.gregorian) {
    return;
  }
  ensureAdaptiveCacheLoaded();
  if (secondaryDayCache.length >= secondaryDayCacheMax) {
    final toRemove = secondaryDayCache.keys
        .take(secondaryDayCacheMax ~/ 5)
        .toList();
    for (final k in toRemove) {
      secondaryDayCache.remove(k);
    }
  }
  secondaryDayCache[secondaryCacheKey(date, system, displayMode)] = value;
  scheduleAdaptiveCachePersist();
}

String monthPrecacheKey(
  DateTime month,
  cp.StartingDayOfWeek startOfWeek,
  cp.AppCalendarSystem primary,
  cp.AppCalendarSystem secondary,
  cp.TithiDisplayMode displayMode,
) {
  return '${month.year}-${month.month}-${month.day}_${startOfWeek.index}_${primary.index}_${secondary.index}_${displayMode.index}';
}
