import 'package:flutter/foundation.dart';
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
    try {
      // Ensure service is initialized (it might be lazy, so safe to call init)
      await _service.init();
      state = _service.getAllSankalpas();
    } catch (e, stack) {
      // SMELL-12: surface the error via Flutter's error reporting instead of
      // swallowing it silently.  Consumers keep the previous state ([] on
      // first load) unchanged so the UI doesn't crash.
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: e,
          stack: stack,
          library: 'SankalpaListNotifier',
          context: ErrorDescription('loading sankalpas from storage'),
        ),
      );
    }
  }

  /// Ensures the shared NotificationService is initialized before use.
  /// Sankalpa screens can run without Settings ever being opened (which is
  /// what normally triggers notificationInitProvider), and every schedule /
  /// cancel call throws "not initialized" otherwise.
  Future<void> _ensureNotificationsReady() async {
    await ref.read(notificationInitProvider.future);
  }

  /// Schedules a reminder without ever breaking sankalpa CRUD: notification
  /// failures are reported but the sankalpa itself is already saved.
  Future<void> _scheduleReminderQuietly(Sankalpa sankalpa) async {
    try {
      await _ensureNotificationsReady();
      await _notificationService.scheduleSankalpaReminder(sankalpa);
    } catch (e, stack) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: e,
          stack: stack,
          library: 'SankalpaListNotifier',
          context: ErrorDescription('scheduling sankalpa reminder'),
        ),
      );
    }
  }

  Future<void> _cancelReminderQuietly(String id) async {
    try {
      await _ensureNotificationsReady();
      await _notificationService.cancelSankalpaReminder(id);
    } catch (e, stack) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: e,
          stack: stack,
          library: 'SankalpaListNotifier',
          context: ErrorDescription('cancelling sankalpa reminder'),
        ),
      );
    }
  }

  Future<void> addSankalpa(Sankalpa sankalpa) async {
    await _service.addSankalpa(sankalpa);

    // Use the shared notification service instance
    await _scheduleReminderQuietly(sankalpa);

    await _loadSankalpas();
  }

  Future<void> deleteSankalpa(String id) async {
    // Cancel notification using shared instance
    await _cancelReminderQuietly(id);

    await _service.deleteSankalpa(id);
    await _loadSankalpas();
  }

  Future<void> toggleCompletion(String id) async {
    await _service.toggleCompletion(id);
    await _loadSankalpas();

    // If completed, cancel notification; if uncompleted, reschedule
    final sankalpa = state.firstWhere((s) => s.id == id);

    if (sankalpa.isCompleted) {
      await _cancelReminderQuietly(id);
    } else {
      await _scheduleReminderQuietly(sankalpa);
    }
  }

  Future<void> markDailyProgress(String id) async {
    await _service.markDailyCompletion(id, DateTime.now());
    await _loadSankalpas();
  }
}
