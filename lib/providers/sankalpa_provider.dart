import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../models/sankalpa.dart';
import '../services/sankalpa_service.dart';
import '../services/notification_service.dart';

final sankalpaServiceProvider = Provider<SankalpaService>((ref) {
  return SankalpaService();
});

final sankalpaListProvider =
    StateNotifierProvider<SankalpaListNotifier, List<Sankalpa>>((ref) {
      final service = ref.watch(sankalpaServiceProvider);
      return SankalpaListNotifier(service, ref);
    });

class SankalpaListNotifier extends StateNotifier<List<Sankalpa>> {
  final SankalpaService _service;
  final Ref _ref;

  SankalpaListNotifier(this._service, this._ref) : super([]) {
    _loadSankalpas();
  }

  Future<void> _loadSankalpas() async {
    // Ensure service is initialized (it might be lazy, so safe to call init)
    await _service.init();
    state = _service.getAllSankalpas();
  }

  Future<void> addSankalpa(Sankalpa sankalpa) async {
    await _service.addSankalpa(sankalpa);

    // Schedule notification
    // We assume NotificationService is global or we can get it via simple instance if not provided
    // Ideally we should use a provider for NotificationService too, but the existing codebase
    // seems to use it as a singleton-ish service or just instances.
    // Let's create a new instance or assume one exists.
    // Actually, let's just use the service class directly if it's stateless or init-safe.
    // The NotificationService requires init.
    // Let's fix this properly in a real app, but for now:
    final notificationService = NotificationService();
    await notificationService.init(); // Ensure init
    await notificationService.scheduleSankalpaReminder(sankalpa);

    await _loadSankalpas();
  }

  Future<void> deleteSankalpa(String id) async {
    // Cancel notification
    final notificationService = NotificationService();
    await notificationService.init();
    await notificationService.cancelSankalpaReminder(id);

    await _service.deleteSankalpa(id);
    await _loadSankalpas();
  }

  Future<void> toggleCompletion(String id) async {
    await _service.toggleCompletion(id);
    await _loadSankalpas();

    // If completed, maybe cancel notification?
    // If uncompleted, reschedule?
    final sankalpa = state.firstWhere((s) => s.id == id);
    final notificationService = NotificationService();
    await notificationService.init();

    if (sankalpa.isCompleted) {
      await notificationService.cancelSankalpaReminder(id);
    } else {
      await notificationService.scheduleSankalpaReminder(sankalpa);
    }
  }

  Future<void> markDailyProgress(String id) async {
    await _service.markDailyCompletion(id, DateTime.now());
    await _loadSankalpas();
  }
}
