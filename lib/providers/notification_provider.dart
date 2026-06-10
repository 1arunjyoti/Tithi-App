import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/notification_service.dart';

/// Provider for NotificationService instance
final notificationServiceProvider = Provider<NotificationService>((ref) {
  final service = NotificationService();
  ref.onDispose(() {
    unawaited(service.dispose());
  });
  return service;
});

/// Provider that tracks if notification service is initialized
final notificationInitProvider = FutureProvider<void>((ref) async {
  final service = ref.read(notificationServiceProvider);
  await service.init();
});

/// Provider for notification enabled state
class NotificationEnabledNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void setEnabled(bool enabled) {
    state = enabled;
  }
}

final notificationEnabledProvider =
    NotifierProvider<NotificationEnabledNotifier, bool>(
      NotificationEnabledNotifier.new,
    );

/// Provider for Shloka notification enabled state (default false, synced from storage)
class ShlokaNotificationEnabledNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void setEnabled(bool enabled) {
    state = enabled;
  }
}

final shlokaNotificationEnabledProvider =
    NotifierProvider<ShlokaNotificationEnabledNotifier, bool>(
      ShlokaNotificationEnabledNotifier.new,
    );

/// Provider for notification time (hour, minute)
class NotificationTimeNotifier extends Notifier<({int hour, int minute})> {
  @override
  ({int hour, int minute}) build() => (hour: 8, minute: 0);

  void setTime(({int hour, int minute}) time) {
    state = time;
  }
}

final notificationTimeProvider =
    NotifierProvider<NotificationTimeNotifier, ({int hour, int minute})>(
      NotificationTimeNotifier.new,
    );

/// Provider to load actual notification state from storage
final loadNotificationStateProvider = FutureProvider<void>((ref) async {
  await ref.watch(notificationInitProvider.future);
  final service = ref.read(notificationServiceProvider);

  final enabled = await service.isEnabled();
  ref.read(notificationEnabledProvider.notifier).setEnabled(enabled);

  final shlokaEnabled = await service.isShlokaEnabled();
  ref
      .read(shlokaNotificationEnabledProvider.notifier)
      .setEnabled(shlokaEnabled);

  final time = await service.getNotificationTime();
  ref.read(notificationTimeProvider.notifier).setTime(time);
});
