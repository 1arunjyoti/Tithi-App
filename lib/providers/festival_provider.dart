import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/festival.dart';

import '../services/festival_repository.dart';
import 'location_provider.dart';

/// Provider for the FestivalRepository
final festivalRepositoryProvider = Provider<FestivalRepository>((ref) {
  return FestivalRepository();
});

/// Provider that initialization of festival data
///
/// Holds seeding until the location permission flow resolves (see
/// [locationPermissionGateProvider]): granted → device coordinates,
/// denied/skipped/failed → default location. Downstream month batches
/// therefore compute once with the final coordinates instead of twice,
/// and seeding never contends with the first-launch permission flow.
final festivalInitProvider = FutureProvider<void>((ref) async {
  await ref.watch(locationPermissionGateProvider).future;
  final repository = ref.read(festivalRepositoryProvider);
  await repository.init();
});

/// Provider that loads and caches all festivals from Hive.
///
/// Subscribes to [festivalInitProvider]: on a fresh install the box starts
/// empty and seeding runs asynchronously AFTER the home screen builds. A
/// plain [ref.read] here would memoize that transient [] forever (nothing
/// ever rebuilds it — including the month batch, which then computes every
/// day with zero festivals), leaving home empty until the next launch.
/// Watching init rebuilds this provider the moment seeding completes, so
/// the first launch populates on its own.
final festivalProvider = Provider<List<Festival>>((ref) {
  final init = ref.watch(festivalInitProvider);
  final repository = ref.read(festivalRepositoryProvider);
  return init.when(
    data: (_) => repository.getAll(),
    // Seeding in flight: serve the in-memory list without touching Hive,
    // so the transient empty box is never cached as the final answer.
    loading: () => repository.peekCached(),
    // Seeding failed: legacy behavior — serve whatever the box holds.
    error: (_, _) => repository.getAll(),
  );
});

/// Provider that returns only major festivals
final majorFestivalsProvider = Provider<List<Festival>>((ref) {
  final festivals = ref.watch(festivalProvider);
  return festivals.where((f) => f.category == 'major').toList();
});

/// Provider that returns only recurring vrats
final vratProvider = Provider<List<Festival>>((ref) {
  final festivals = ref.watch(festivalProvider);
  return festivals.where((f) => f.category == 'vrat' || f.recurring).toList();
});
