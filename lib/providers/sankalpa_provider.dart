import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../models/sankalpa.dart';
import '../services/sankalpa_service.dart';
import '../services/notification_service.dart';
import 'notification_provider.dart';

final sankalpaServiceProvider = Provider<SankalpaService>((ref) {
  return SankalpaService();
});

final sankalpaListProvider =
    StateNotifierProvider<SankalpaListNotifier, List<Sankalpa>>((ref) {
      final service = ref.watch(sankalpaServiceProvider);
      final notificationService = ref.read(notificationServiceProvider);
      return SankalpaListNotifier(service, notificationService);
    });

class SankalpaListNotifier extends StateNotifier<List<Sankalpa>> {
  final SankalpaService _service;
  final NotificationService _notificationService;

  SankalpaListNotifier(this._service, this._notificationService) : super([]) {
    _loadSankalpas();
  }

  Future<void> _loadSankalpas() async {
    // Ensure service is initialized (it might be lazy, so safe to call init)
    await _service.init();
    state = _service.getAllSankalpas();
  }

  Future<void> addSankalpa(Sankalpa sankalpa) async {
    await _service.addSankalpa(sankalpa);

    // Use the shared notification service instance
    await _notificationService.scheduleSankalpaReminder(sankalpa);

    await _loadSankalpas();
  }

  Future<void> deleteSankalpa(String id) async {
    // Cancel notification using shared instance
    await _notificationService.cancelSankalpaReminder(id);

    await _service.deleteSankalpa(id);
    await _loadSankalpas();
  }

  Future<void> toggleCompletion(String id) async {
    await _service.toggleCompletion(id);
    await _loadSankalpas();

    // If completed, cancel notification; if uncompleted, reschedule
    final sankalpa = state.firstWhere((s) => s.id == id);

    if (sankalpa.isCompleted) {
      await _notificationService.cancelSankalpaReminder(id);
    } else {
      await _notificationService.scheduleSankalpaReminder(sankalpa);
    }
  }

  Future<void> markDailyProgress(String id) async {
    await _service.markDailyCompletion(id, DateTime.now());
    await _loadSankalpas();
  }
}
