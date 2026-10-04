import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format/date_only.dart';
import '../../../models/festival.dart';
import '../../../models/hindu_month_system.dart';
import '../../../services/storage_service.dart';
import '../../../providers/calendar_provider.dart';
import '../../../providers/festival_provider.dart';
import '../../../providers/panchang_provider.dart';
import '../../panchang/domain/occurrence_cache.dart';

const _defaultCountdownIds = [
  'shashthi_durga_puja',
  'holi',
  'diwali',
  'dussehra',
];

const _defaultCountdownTitles = {
  'shashthi_durga_puja': 'Durga Puja',
  'holi': 'Holi',
  'diwali': 'Diwali',
  'dussehra': 'Dussehra (Vijayadashami)',
};

const _defaultCountdownFallbackNames = {
  'shashthi_durga_puja': 'Durga Puja- Shashthi',
  'holi': 'Holi',
  'diwali': 'Diwali',
  'dussehra': 'Dussehra / Vijayadashami',
};

class FestivalCountdownTarget {
  const FestivalCountdownTarget({
    required this.id,
    required this.title,
    required this.festival,
    required this.date,
    required this.daysRemaining,
  });

  final String id;
  final String title;
  final Festival festival;
  final DateTime date;
  final int daysRemaining;

  bool get isToday => daysRemaining == 0;
  bool get isTomorrow => daysRemaining == 1;
}

class FestivalCountdownPreferences {
  const FestivalCountdownPreferences({
    required this.countdownIds,
    required this.homeCountdownIds,
  });

  final List<String> countdownIds;
  final Set<String> homeCountdownIds;

  bool isPinnedToHome(String id) => homeCountdownIds.contains(id);

  FestivalCountdownPreferences copyWith({
    List<String>? countdownIds,
    Set<String>? homeCountdownIds,
  }) {
    return FestivalCountdownPreferences(
      countdownIds: countdownIds ?? this.countdownIds,
      homeCountdownIds: homeCountdownIds ?? this.homeCountdownIds,
    );
  }
}

class FestivalCountdownPreferencesNotifier
    extends Notifier<FestivalCountdownPreferences> {
  static const _countdownIdsKey = 'festival_countdown_ids';
  static const _homeCountdownIdsKey = 'festival_countdown_home_ids';

  @override
  FestivalCountdownPreferences build() {
    final box = StorageService().getSettingsBox();
    final countdownIds = _readStringList(
      box.get(_countdownIdsKey),
      defaultValue: _defaultCountdownIds,
    );
    final homeCountdownIds = _readStringList(
      box.get(_homeCountdownIdsKey),
      defaultValue: _defaultCountdownIds,
    ).where(countdownIds.contains).toSet();

    return FestivalCountdownPreferences(
      countdownIds: countdownIds,
      homeCountdownIds: homeCountdownIds,
    );
  }

  Future<bool> addFestival(String festivalId, {bool pinToHome = false}) async {
    if (festivalId.isEmpty) return false;

    if (state.countdownIds.contains(festivalId)) {
      if (pinToHome && !state.homeCountdownIds.contains(festivalId)) {
        await setHomePinned(festivalId, isPinned: true);
      }
      return false;
    }

    final countdownIds = [...state.countdownIds, festivalId];
    final homeCountdownIds = {...state.homeCountdownIds};
    if (pinToHome) {
      homeCountdownIds.add(festivalId);
    }

    await _save(
      state.copyWith(
        countdownIds: countdownIds,
        homeCountdownIds: homeCountdownIds,
      ),
    );
    return true;
  }

  Future<void> removeFestival(String festivalId) async {
    final countdownIds = state.countdownIds
        .where((id) => id != festivalId)
        .toList();
    final homeCountdownIds = {...state.homeCountdownIds}..remove(festivalId);
    await _save(
      state.copyWith(
        countdownIds: countdownIds,
        homeCountdownIds: homeCountdownIds,
      ),
    );
  }

  Future<void> setHomePinned(
    String festivalId, {
    required bool isPinned,
  }) async {
    if (!state.countdownIds.contains(festivalId)) return;

    final homeCountdownIds = {...state.homeCountdownIds};
    if (isPinned) {
      homeCountdownIds.add(festivalId);
    } else {
      homeCountdownIds.remove(festivalId);
    }

    await _save(state.copyWith(homeCountdownIds: homeCountdownIds));
  }

  Future<void> toggleHomePinned(String festivalId) async {
    await setHomePinned(
      festivalId,
      isPinned: !state.homeCountdownIds.contains(festivalId),
    );
  }

  Future<void> _save(FestivalCountdownPreferences preferences) async {
    final box = StorageService().getSettingsBox();
    await box.put(_countdownIdsKey, preferences.countdownIds);
    await box.put(_homeCountdownIdsKey, preferences.homeCountdownIds.toList());
    state = preferences;
  }

  List<String> _readStringList(
    Object? value, {
    required List<String> defaultValue,
  }) {
    if (value is! List) return List<String>.of(defaultValue);

    final seen = <String>{};
    final result = <String>[];
    for (final item in value) {
      if (item is String && item.isNotEmpty && seen.add(item)) {
        result.add(item);
      }
    }

    return result;
  }
}

final festivalCountdownPreferencesProvider =
    NotifierProvider<
      FestivalCountdownPreferencesNotifier,
      FestivalCountdownPreferences
    >(FestivalCountdownPreferencesNotifier.new);

final allFestivalCountdownTargetsProvider =
    FutureProvider.autoDispose<List<FestivalCountdownTarget>>((ref) async {
      ref.keepAlive();

      final preferences = ref.watch(festivalCountdownPreferencesProvider);
      return _loadCountdownTargets(ref, preferences.countdownIds);
    });

final homeFestivalCountdownTargetsProvider =
    FutureProvider.autoDispose<List<FestivalCountdownTarget>>((ref) async {
      ref.keepAlive();

      final preferences = ref.watch(festivalCountdownPreferencesProvider);
      final homeIds = preferences.countdownIds
          .where(preferences.homeCountdownIds.contains)
          .toList();
      return _loadCountdownTargets(ref, homeIds);
    });

final _festivalCountdownTargetProvider = FutureProvider.autoDispose
    .family<FestivalCountdownTarget?, String>((ref, id) async {
      await ref.watch(panchangInitProvider.future);
      await ref.watch(festivalInitProvider.future);

      final festivals = ref.read(festivalProvider);
      final festival = _findFestivalById(festivals, id);
      if (festival == null) return null;

      final today = dateOnly(ref.watch(todayDateProvider));
      final coords = ref.watch(resolvedCoordinatesProvider);
      final service = ref.read(panchangServiceProvider);
      // Dates are ALWAYS Amanta-based: festival rules are stored in Amanta
      // and both scanners match with HinduMonthSystem.amanta hardcoded — the
      // display system only affects masa labels, never occurrence dates.
      // Do NOT watch hinduMonthSystemProvider here: switching Amanta↔Purnimant
      // must not re-run every 420-day scan (loading shimmer for zero new
      // information). Pass the fixed basis the matching actually uses.
      // Occurrence-result cache: repeat loads (same month, location) skip
      // the up-to-420-day forward scan.
      // One bad rule/FFI failure must not fail the whole countdown list
      // (see _loadCountdownTargets isolation below): resolve dateless.
      late final DateTime? targetDate;
      try {
        targetDate = await findNextFestivalOccurrenceCached(
          service: service,
          festival: festival,
          startDate: today,
          latitude: coords.latitude,
          longitude: coords.longitude,
          monthSystem: HinduMonthSystem.amanta,
        );
      } catch (e) {
        debugPrint('Countdown resolve failed for $id: $e');
        return null;
      }
      if (targetDate == null) return null;
      return FestivalCountdownTarget(
        id: id,
        title: _defaultCountdownTitles[id] ?? festival.name,
        festival: festival,
        date: targetDate,
        // Calendar-day diff (DST-safe): local-midnight .difference().inDays
        // truncates 23/25h DST days and can report 0 for a 1-day span.
        daysRemaining: calendarDaysBetween(today, targetDate),
      );
    });

Future<List<FestivalCountdownTarget>> _loadCountdownTargets(
  Ref ref,
  List<String> ids, {
  int batchSize = 8,
}) async {
  if (ids.isEmpty) return const [];

  // Per-ID isolation: one throwing festival (FFI failure, bad rule) resolves
  // dateless instead of failing the whole list (Future.wait would throw and
  // hide every other countdown behind a full-screen error/empty card).
  Future<FestivalCountdownTarget?> safeTarget(String id) async {
    try {
      return await ref.watch(_festivalCountdownTargetProvider(id).future);
    } catch (e) {
      debugPrint('Countdown target failed for $id: $e');
      return null;
    }
  }

  // Small parallel batches (same size as resolveDatedFestivals): each scan is
  // up to ~420 days × 3-4 FFI calls, so awaiting all IDs at once stampedes
  // the FFI bridge and janks the UI thread. Batched keeps throughput while
  // bounding concurrency.
  final out = <FestivalCountdownTarget>[];
  for (var i = 0; i < ids.length; i += batchSize) {
    final end = (i + batchSize).clamp(0, ids.length);
    final batch = await Future.wait(ids.sublist(i, end).map(safeTarget));
    out.addAll(batch.nonNulls);
  }

  return out
    // Name breaks same-day ties so shared dates never reorder across
    // rebuilds (list jumping); id keeps identical names stable.
    ..sort((a, b) {
      final byDate = a.daysRemaining.compareTo(b.daysRemaining);
      if (byDate != 0) return byDate;
      final byName = a.festival.name.compareTo(b.festival.name);
      if (byName != 0) return byName;
      return a.id.compareTo(b.id);
    });
}

Festival? _findFestivalById(List<Festival> festivals, String id) {
  for (final festival in festivals) {
    if (festival.id == id) return festival;
  }

  final fallbackName = _defaultCountdownFallbackNames[id];
  if (fallbackName == null) return null;

  // Hardened fallback for the bundled default IDs: the dataset's display
  // names drift over time (punctuation, spacing), so an exact match is
  // brittle — a rename silently emptied a default countdown. Match in
  // stages: exact (case-insensitive) → normalized alphanumeric → token
  // overlap (every fallback token present in the candidate name).
  Festival? normalizedHit;
  normalizedHit ??= _matchNormalized(festivals, fallbackName);
  normalizedHit ??= _matchTokenOverlap(festivals, fallbackName);
  if (normalizedHit != null) {
    debugPrint('Countdown fallback: "$id" resolved via name match '
        '("${normalizedHit.name}"). Consider updating the id map.');
  }
  return normalizedHit;
}

/// Lowercase alphanumeric only: punctuation/spacing-insensitive compare.
String _normalizeName(String name) =>
    name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

Festival? _matchNormalized(List<Festival> festivals, String fallbackName) {
  final exact = fallbackName.toLowerCase();
  for (final festival in festivals) {
    if (festival.name.toLowerCase() == exact) return festival;
  }
  final normalized = _normalizeName(fallbackName);
  if (normalized.isEmpty) return null;
  for (final festival in festivals) {
    if (_normalizeName(festival.name) == normalized) return festival;
  }
  return null;
}

Festival? _matchTokenOverlap(List<Festival> festivals, String fallbackName) {
  final tokens = fallbackName
      .toLowerCase()
      .split(RegExp(r'[^a-z0-9]+'))
      .where((t) => t.isNotEmpty)
      .toSet();
  if (tokens.isEmpty) return null;
  // Every candidate containing all tokens qualifies; prefer the closest
  // name (shortest normalized form) over bare list order, so 'Holi' wins
  // over 'Holi Milan'-style siblings instead of whichever seeded first.
  Festival? best;
  var bestLength = 1 << 30;
  for (final festival in festivals) {
    final haystack = '${festival.name} ${festival.nameHindi ?? ''}'
        .toLowerCase();
    if (!tokens.every(haystack.contains)) continue;
    final length = _normalizeName(festival.name).length;
    if (length < bestLength) {
      best = festival;
      bestLength = length;
    }
  }
  return best;
}

