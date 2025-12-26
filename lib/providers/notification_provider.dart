import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../services/notification_service.dart';

/// Provider for NotificationService singleton
final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});

/// Provider that tracks if notification service is initialized
final notificationInitProvider = FutureProvider<void>((ref) async {
  final service = ref.read(notificationServiceProvider);
  await service.init();
});

/// Provider for notification enabled state
final notificationEnabledProvider = StateProvider<bool>((ref) => false);

/// Provider for notification time (hour, minute)
final notificationTimeProvider = StateProvider<({int hour, int minute})>(
  (ref) => (hour: 8, minute: 0),
);

/// Provider to load actual notification state from storage
final loadNotificationStateProvider = FutureProvider<void>((ref) async {
  await ref.watch(notificationInitProvider.future);
  final service = ref.read(notificationServiceProvider);

  final enabled = await service.isEnabled();
  ref.read(notificationEnabledProvider.notifier).state = enabled;

  final time = await service.getNotificationTime();
  ref.read(notificationTimeProvider.notifier).state = time;
});
