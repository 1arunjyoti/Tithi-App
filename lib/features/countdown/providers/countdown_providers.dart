import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format/date_only.dart';
import '../../../models/festival.dart';
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
      final monthSystem = ref.watch(hinduMonthSystemProvider);
      // Occurrence-result cache: repeat loads (same month, location,
      // calendar system) skip the up-to-380-day forward scan.
      final targetDate = await findNextFestivalOccurrenceCached(
        service: service,
        festival: festival,
        startDate: today,
        latitude: coords.latitude,
        longitude: coords.longitude,
        monthSystem: monthSystem,
      );
      if (targetDate == null) return null;
      return FestivalCountdownTarget(
        id: id,
        title: _defaultCountdownTitles[id] ?? festival.name,
        festival: festival,
        date: targetDate,
        daysRemaining: targetDate.difference(today).inDays,
      );
    });

Future<List<FestivalCountdownTarget>> _loadCountdownTargets(
  Ref ref,
  List<String> ids,
) async {
  if (ids.isEmpty) return const [];

  final targets = await Future.wait(
    ids.map((id) => ref.watch(_festivalCountdownTargetProvider(id).future)),
  );

  return targets.nonNulls.toList()
    ..sort((a, b) => a.daysRemaining.compareTo(b.daysRemaining));
}

Festival? _findFestivalById(List<Festival> festivals, String id) {
  for (final festival in festivals) {
    if (festival.id == id) return festival;
  }

  final fallbackName = _defaultCountdownFallbackNames[id];
  if (fallbackName == null) return null;

  final normalizedExactName = fallbackName.toLowerCase();
  for (final festival in festivals) {
    if (festival.name.toLowerCase() == normalizedExactName) {
      return festival;
    }
  }

  return null;
}

