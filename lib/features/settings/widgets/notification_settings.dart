import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import '../../../providers/notification_provider.dart';
import '../../../core/feedback/app_messages.dart';
import '../../../l10n/app_localizations.dart';
import '../../../theme/app_theme.dart';
import '../../../services/notification_service.dart' show FestivalReminderTiming;
import '../../../widgets/settings_widgets.dart';

class NotificationSettings extends ConsumerWidget {
  const NotificationSettings({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    // Load notification state
    ref.watch(loadNotificationStateProvider);

    final notificationService = ref.read(notificationServiceProvider);
    final notifTime = ref.watch(notificationTimeProvider);
    final isEnabled = ref.watch(notificationEnabledProvider);

    return Column(
      children: [
        SettingsSwitchTile(
          icon: Icons.notifications_active_rounded,
          title: l10n?.dailyNotifications ?? 'Daily Notifications',
          subtitle: isEnabled
              ? (l10n?.notificationScheduled ?? 'Scheduled daily')
              : (l10n?.getNotifiedTithiDaily ??
                    'Get notified about Tithi daily'),
          value: isEnabled,
          onChanged: (val) async {
            if (val) {
              final granted = await notificationService.requestPermission();
              if (!granted) {
                if (context.mounted) {
                  showAppMessage(
                    context,
                    l10n?.notificationPermissionDenied ??
                        'Notification permission denied. Please enable it in system settings.',
                    kind: AppMessageKind.error,
                    action: SnackBarAction(
                      label: l10n?.openSettings ?? 'Open Settings',
                      onPressed: () {
                        Geolocator.openAppSettings();
                      },
                    ),
                  );
                }
                return;
              }
            }
            // Optimistic update so the switch responds instantly. The loader
            // invalidation in `finally` re-syncs from storage afterwards.
            ref.read(notificationEnabledProvider.notifier).setEnabled(val);
            try {
              await notificationService.setEnabled(val);
            } catch (e) {
              debugPrint('Failed to set daily notifications to $val: $e');
              // Revert so the switch reflects the real (unchanged) state.
              ref.read(notificationEnabledProvider.notifier).setEnabled(!val);
              if (context.mounted) {
                showAppMessage(
                  context,
                  l10n?.notificationToggleFailed(val ? 'on' : 'off', e.toString()) ??
                      'Could not turn notifications ${val ? 'on' : 'off'} ($e). Please try again.',
                  kind: AppMessageKind.error,
                  // Enable failures are commonly the OS-level gate
                  // (_assertSystemNotificationsAllowed), so offer the fix.
                  action: val
                      ? SnackBarAction(
                          label: l10n?.openSettings ?? 'Open Settings',
                          onPressed: () {
                            Geolocator.openAppSettings();
                          },
                        )
                      : null,
                );
              }
            } finally {
              ref.invalidate(loadNotificationStateProvider);
            }
          },
        ),
        const SettingsDivider(),
        // Daily Shloka Toggle (independent of the daily master switch,
        // so users can opt into shloka-only notifications).
        SettingsSwitchTile(
          icon: Icons.menu_book_rounded,
          title: l10n?.dailyShloka ?? 'Daily Shloka',
          subtitle: l10n?.dailyShlokaSubtitle ?? 'Get a daily spiritual verse',
          value: ref.watch(shlokaNotificationEnabledProvider),
          onChanged: (val) async {
            if (val) {
              final granted = await notificationService.requestPermission();
              if (!granted) {
                if (context.mounted) {
                  showAppMessage(
                    context,
                    l10n?.notificationPermissionDenied ??
                        'Notification permission denied. Please enable it in system settings.',
                    kind: AppMessageKind.error,
                  );
                }
                return;
              }
            }
            ref
                .read(shlokaNotificationEnabledProvider.notifier)
                .setEnabled(val);
            try {
              await notificationService.setShlokaEnabled(val);
            } catch (e) {
              debugPrint('Failed to set shloka notifications to $val: $e');
              ref
                  .read(shlokaNotificationEnabledProvider.notifier)
                  .setEnabled(!val);
              if (context.mounted) {
                showAppMessage(
                  context,
                  l10n?.dailyShlokaToggleFailed(val ? 'on' : 'off', e.toString()) ??
                      'Could not turn Daily Shloka ${val ? 'on' : 'off'} ($e). Please try again.',
                  kind: AppMessageKind.error,
                );
              }
            } finally {
              ref.invalidate(loadNotificationStateProvider);
            }
          },
        ),
        const SettingsDivider(),
        // Festival Reminders Toggle (independent of daily master switch,
        // so users can opt into festival-only notifications).
        SettingsSwitchTile(
          icon: Icons.celebration_rounded,
          title: l10n?.festivalReminders ?? 'Festival Reminders',
          subtitle: l10n?.festivalRemindersSubtitle ??
              'Notify only for festivals, on the day or before',
          value: ref.watch(festivalNotificationEnabledProvider),
          onChanged: (val) async {
            if (val) {
              final granted = await notificationService.requestPermission();
              if (!granted) {
                if (context.mounted) {
                  showAppMessage(
                    context,
                    l10n?.notificationPermissionDenied ??
                        'Notification permission denied. Please enable it in system settings.',
                    kind: AppMessageKind.error,
                  );
                }
                return;
              }
            }
            ref
                .read(festivalNotificationEnabledProvider.notifier)
                .setEnabled(val);
            try {
              await notificationService.setFestivalEnabled(val);
            } catch (e) {
              debugPrint('Failed to set festival notifications to $val: $e');
              ref
                  .read(festivalNotificationEnabledProvider.notifier)
                  .setEnabled(!val);
              if (context.mounted) {
                showAppMessage(
                  context,
                  l10n?.festivalRemindersToggleFailed(val ? 'on' : 'off', e.toString()) ??
                      'Could not turn Festival Reminders ${val ? 'on' : 'off'} ($e). Please try again.',
                  kind: AppMessageKind.error,
                );
              }
            } finally {
              ref.invalidate(loadNotificationStateProvider);
            }
          },
        ),
        if (ref.watch(festivalNotificationEnabledProvider)) ...[
          const SettingsDivider(),
          SettingsActionTile(
            icon: Icons.schedule_rounded,
            title: l10n?.festivalReminderTime ?? 'Festival Reminder Time',
            trailing: Text(
              _festivalTimingLabel(ref.watch(festivalTimingProvider), l10n),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.end,
              style: context.textTheme.bodyMedium?.copyWith(
                color: context.colors.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
            onTap: () => _showFestivalTimingPicker(context, ref),
          ),
        ],
        // Shared by daily, shloka, and festival reminders — shown whenever
        // any of them is on, so single-type users can still change it.
        if (isEnabled ||
            ref.watch(shlokaNotificationEnabledProvider) ||
            ref.watch(festivalNotificationEnabledProvider)) ...[
          const SettingsDivider(),
          SettingsActionTile(
            icon: Icons.access_time_rounded,
            title: l10n?.notificationTime ?? 'Notification Time',
            trailing: Text(
              _formatTime(
                TimeOfDay(hour: notifTime.hour, minute: notifTime.minute),
                context,
              ),
              style: context.textTheme.bodyMedium?.copyWith(
                color: context.colors.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
            onTap: () async {
              final time = await showTimePicker(
                context: context,
                initialTime: TimeOfDay(
                  hour: notifTime.hour,
                  minute: notifTime.minute,
                ),
                builder: (context, child) {
                  return Theme(
                    data: context.theme.copyWith(
                      timePickerTheme: TimePickerThemeData(
                        backgroundColor: context.colors.surface,
                        hourMinuteTextColor: context.colors.primary,
                        dayPeriodTextColor: context.colors.onSurface,
                        dialHandColor: context.colors.primary,
                        dialBackgroundColor: context.colors.onSurface
                            .withValues(alpha: 0.1),
                      ),
                    ),
                    child: child!,
                  );
                },
              );

              if (time != null) {
                try {
                  await notificationService.setNotificationTime(
                    time.hour,
                    time.minute,
                  );
                } catch (e) {
                  debugPrint('Failed to set notification time: $e');
                  if (context.mounted) {
                    showAppMessage(
                      context,
                      l10n?.notificationTimeUpdateFailed(e.toString()) ??
                          'Could not update notification time ($e). Please try again.',
                      kind: AppMessageKind.error,
                    );
                  }
                } finally {
                  ref.invalidate(loadNotificationStateProvider);
                }
              }
            },
          ),
        ],
      ],
    );
  }

  String _festivalTimingLabel(int timing, [AppLocalizations? l10n]) {
    if (timing == FestivalReminderTiming.dayBefore.index) {
      return l10n?.festivalReminderDayBefore ?? 'Day before';
    }
    if (timing == FestivalReminderTiming.both.index) {
      return l10n?.festivalReminderBoth ?? 'Both';
    }
    return l10n?.festivalReminderOnDay ?? 'On the day';
  }

  Future<void> _showFestivalTimingPicker(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final l10n = AppLocalizations.of(context);
    final current = ref.read(festivalTimingProvider);
    final notificationService = ref.read(notificationServiceProvider);

    await SettingsBottomSheet.show(
      context: context,
      title: l10n?.festivalReminderTime ?? 'Festival Reminder Time',
      children: FestivalReminderTiming.values.map((timing) {
        final label = _festivalTimingLabel(timing.index, l10n);
        return SettingsPickerItem(
          title: label,
          isSelected: timing.index == current,
          onTap: () async {
            ref.read(festivalTimingProvider.notifier).setTiming(timing.index);
            try {
              await notificationService.setFestivalTiming(timing.index);
            } catch (e) {
              debugPrint('Failed to set festival timing: $e');
              ref.read(festivalTimingProvider.notifier).setTiming(current);
              if (context.mounted) {
                showAppMessage(
                  context,
                  l10n?.reminderTimeUpdateFailed(e.toString()) ??
                      'Could not update reminder time ($e). Please try again.',
                  kind: AppMessageKind.error,
                );
              }
            } finally {
              ref.invalidate(loadNotificationStateProvider);
            }
            if (context.mounted) Navigator.pop(context);
          },
        );
      }).toList(),
    );
  }

  String _formatTime(TimeOfDay time, BuildContext context) {
    final localizations = MaterialLocalizations.of(context);
    return localizations.formatTimeOfDay(time);
  }
}

