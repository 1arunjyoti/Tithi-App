import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/sankalpa.dart';
import '../services/sankalpa_service.dart';
import '../services/notification_service.dart';
import 'notification_provider.dart';

final sankalpaServiceProvider = Provider<SankalpaService>((ref) {
  return SankalpaService();
});

final sankalpaListProvider = NotifierProvider<SankalpaListNotifier, List<Sankalpa>>(
  SankalpaListNotifier.new,
);

class SankalpaListNotifier extends Notifier<List<Sankalpa>> {
  late final SankalpaService _service;
  late final NotificationService _notificationService;

  @override
  List<Sankalpa> build() {
    _service = ref.watch(sankalpaServiceProvider);
    _notificationService = ref.read(notificationServiceProvider);
    _loadSankalpas();
    return const [];
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
