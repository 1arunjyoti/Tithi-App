import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/festival.dart';

import '../services/festival_repository.dart';

/// Provider for the FestivalRepository
final festivalRepositoryProvider = Provider<FestivalRepository>((ref) {
  return FestivalRepository();
});

/// Provider that initialization of festival data
final festivalInitProvider = FutureProvider<void>((ref) async {
  final repository = ref.read(festivalRepositoryProvider);
  await repository.init();
});

/// Provider that loads and caches all festivals from Hive
final festivalProvider = Provider<List<Festival>>((ref) {
  // Ensure init is called before accessing this, usually done in main or splash
  // But for safety in UI, we might want to watch the init provider or just return empty if not ready.
  // Ideally, the app should await init before showing main screen.
  final repository = ref.read(festivalRepositoryProvider);
  return repository.getAll();
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
