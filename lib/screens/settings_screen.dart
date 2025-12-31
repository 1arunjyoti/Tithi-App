import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../providers/calendar_provider.dart';
import '../providers/location_provider.dart';
import '../providers/notification_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/locale_provider.dart';
import '../l10n/app_localizations.dart';
import '../theme/app_theme.dart';
import 'privacy_policy_screen.dart';
import '../providers/accessibility_provider.dart';
import '../screens/location_picker_screen.dart';
import '../models/hindu_month_system.dart';
import '../widgets/settings_widgets.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(l10n?.settings ?? 'Settings'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: context.colors.surface.withValues(alpha: 0.5),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.arrow_back_rounded),
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          // Background Gradient - Wrapped in RepaintBoundary
          Positioned.fill(
            child: RepaintBoundary(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors:
                        context.theme.scaffoldBackgroundColor == Colors.black
                        ? [Colors.black, Colors.black]
                        : context.isDark
                        ? [const Color(0xFF10002B), const Color(0xFF240046)]
                        : [
                            const Color(0xFFFFFDF7),
                            const Color(0xFFFFECB3).withValues(alpha: 0.2),
                          ],
                  ),
                ),
              ),
            ),
          ),

          SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                SettingsSectionHeader(l10n?.appearance ?? 'APPEARANCE'),
                _buildThemeSection(context),

                const SizedBox(height: 32),

                SettingsSectionHeader(l10n?.preferences ?? 'PREFERENCES'),
                SettingsGroupCard(
                  children: [
                    const _NotificationSettings(),
                    const SettingsDivider(),
                    const _LocationSettings(),
                    const SettingsDivider(),
                    const _HomeLocationSetting(),
                    const SettingsDivider(),
                    const _LanguageSetting(),
                  ],
                ),

                const SizedBox(height: 32),

                SettingsSectionHeader(l10n?.calendar ?? 'CALENDAR'),
                SettingsGroupCard(
                  children: [
                    const _StartOfWeekSetting(),
                    const SettingsDivider(),
                    const _PrimaryViewSetting(),
                    const SettingsDivider(),
                    const _PrimaryCalendarSetting(),
                    const SettingsDivider(),
                    const _SecondaryCalendarSetting(),
                    const SettingsDivider(),
                    const _HinduMonthSystemSetting(),
                    const SettingsDivider(),
                    const _HinduYearEraSetting(),
                  ],
                ),

                const SizedBox(height: 32),

                SettingsSectionHeader(l10n?.accessibility ?? 'ACCESSIBILITY'),
                const _AccessibilitySettings(),

                const SizedBox(height: 32),

                SettingsSectionHeader(l10n?.dataStorage ?? 'DATA & STORAGE'),
                SettingsGroupCard(
                  children: [
                    Consumer(
                      builder: (context, ref, _) {
                        return SettingsActionTile(
                          icon: Icons.cleaning_services_rounded,
                          title:
                              l10n?.clearLocationCache ??
                              'Clear Location Cache',
                          onTap: () async {
                            final scaffold = ScaffoldMessenger.of(context);
                            await ref
                                .read(locationServiceProvider)
                                .clearCache();
                            ref.invalidate(currentLocationProvider);
                            scaffold.showSnackBar(
                              SnackBar(
                                content: Text(
                                  l10n?.locationCacheCleared ??
                                      'Location cache cleared',
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                    const SettingsDivider(),
                    Consumer(
                      builder: (context, ref, _) {
                        return SettingsActionTile(
                          icon: Icons.restore_rounded,
                          title: l10n?.resetAppSettings ?? 'Reset App Settings',
                          trailing: const Text(
                            'Using default',
                            style: TextStyle(color: Colors.transparent),
                          ), // Just spacer
                          onTap: () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (c) => AlertDialog(
                                title: Text(
                                  l10n?.resetSettingsTitle ?? 'Reset Settings?',
                                ),
                                content: Text(
                                  l10n?.resetSettingsMessage ??
                                      'This will reset all your preferences and data to default. This cannot be undone.',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(c, false),
                                    child: Text(l10n?.cancel ?? 'Cancel'),
                                  ),
                                  TextButton(
                                    onPressed: () => Navigator.pop(c, true),
                                    child: Text(
                                      l10n?.reset ?? 'Reset',
                                      style: const TextStyle(color: Colors.red),
                                    ),
                                  ),
                                ],
                              ),
                            );

                            if (confirm == true) {
                              final box = Hive.box('settings');
                              await box.clear();
                              await ref
                                  .read(locationServiceProvider)
                                  .setLocationEnabled(false);

                              // Reset providers
                              ref.invalidate(startOfWeekProvider);
                              ref.invalidate(primaryEventViewProvider);
                              ref.invalidate(themeOverrideProvider);

                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      l10n?.appResetComplete ??
                                          'App reset complete',
                                    ),
                                  ),
                                );
                              }
                            }
                          },
                        );
                      },
                    ),
                  ],
                ),

                const SizedBox(height: 32),

                SettingsSectionHeader(l10n?.about ?? 'ABOUT'),
                SettingsGroupCard(
                  children: [
                    SettingsActionTile(
                      icon: Icons.privacy_tip_rounded,
                      title: l10n?.privacyPolicy ?? 'Privacy Policy',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const PrivacyPolicyScreen(),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 32),
                Center(
                  child: Text(
                    l10n?.madeWithLove ?? 'Made with ❤️ for Sanatan Dharma',
                    style: context.textTheme.labelSmall?.copyWith(
                      color: context.colors.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThemeSection(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) {
        final currentOverride = ref.watch(themeOverrideProvider);
        final autoMode = currentOverride == null;

        return Container(
          decoration: AppTheme.glassmorphism(
            context: context,
            opacity: 0.1,
            borderRadius: 24,
            ref: ref,
          ),
          padding: const EdgeInsets.all(16),
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.spaceEvenly,
            children: [
              ThemeOptionButton(
                label: 'Auto',
                icon: Icons.brightness_auto_rounded,
                isSelected: autoMode,
                onTap: () =>
                    ref.read(themeOverrideProvider.notifier).setOverride(null),
              ),
              ThemeOptionButton(
                label: 'Shukla',
                icon: Icons.light_mode_rounded,
                isSelected: currentOverride == 'Shukla',
                onTap: () => ref
                    .read(themeOverrideProvider.notifier)
                    .setOverride('Shukla'),
              ),
              ThemeOptionButton(
                label: 'Dark',
                icon: Icons.contrast,
                isSelected: currentOverride == 'PureDark',
                onTap: () => ref
                    .read(themeOverrideProvider.notifier)
                    .setOverride('PureDark'),
              ),
              ThemeOptionButton(
                label: 'Krishna',
                icon: Icons.bubble_chart,
                isSelected: currentOverride == 'Krishna',
                onTap: () => ref
                    .read(themeOverrideProvider.notifier)
                    .setOverride('Krishna'),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _NotificationSettings extends ConsumerWidget {
  const _NotificationSettings();

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
              if (!granted) return;
            }
            await notificationService.setEnabled(val);
            ref.invalidate(loadNotificationStateProvider);
            ref.invalidate(loadNotificationStateProvider);
          },
        ),
        if (isEnabled) ...[
          const SettingsDivider(),
          // Daily Shloka Toggle
          SettingsSwitchTile(
            icon: Icons.menu_book_rounded,
            title: 'Daily Shloka',
            subtitle: 'Get a daily spiritual verse',
            value: ref.watch(shlokaNotificationEnabledProvider),
            onChanged: (val) async {
              await notificationService.setShlokaEnabled(val);
              ref.invalidate(loadNotificationStateProvider);
            },
          ),
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
                await notificationService.setNotificationTime(
                  time.hour,
                  time.minute,
                );
                ref.invalidate(loadNotificationStateProvider);
              }
            },
          ),
        ],
      ],
    );
  }

  String _formatTime(TimeOfDay time, BuildContext context) {
    final localizations = MaterialLocalizations.of(context);
    return localizations.formatTimeOfDay(time);
  }
}

class _LocationSettings extends ConsumerWidget {
  const _LocationSettings();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final locationAsync = ref.watch(currentLocationProvider);
    final locationService = ref.read(locationServiceProvider);

    return FutureBuilder<bool>(
      future: locationService.isLocationEnabled(),
      builder: (context, snapshot) {
        final isEnabled = snapshot.data ?? false;
        return SettingsSwitchTile(
          icon: Icons.location_on_rounded,
          title: l10n?.autoLocation ?? 'Auto Location',
          subtitle: locationAsync.when(
            data: (loc) {
              final cityName = loc?.cityName;
              if (cityName != null) {
                return l10n?.usingLocation(cityName) ?? 'Using: $cityName';
              }
              return l10n?.useGpsForTithi ??
                  'Use GPS for precise Tithi calculation';
            },
            loading: () => l10n?.fetchingLocation ?? 'Fetching location...',
            error: (_, _) =>
                l10n?.locationUnavailable ?? 'Location unavailable',
          ),
          value: isEnabled,
          onChanged: (val) async {
            await locationService.setLocationEnabled(val);
            if (val) {
              final permission = await Geolocator.checkPermission();
              if (permission == LocationPermission.denied) {
                await Geolocator.requestPermission();
              }
            }
            ref.invalidate(currentLocationProvider);
          },
        );
      },
    );
  }
}

class _HomeLocationSetting extends ConsumerWidget {
  const _HomeLocationSetting();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final homeLocation = ref.watch(homeLocationProvider);

    return SettingsActionTile(
      icon: Icons.home_rounded,
      title: l10n?.homeLocation ?? 'Home Location',
      trailing: SizedBox(
        width: 120,
        child: Text(
          homeLocation?.cityName ?? (l10n?.notSet ?? 'Not set'),
          textAlign: TextAlign.end,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: context.textTheme.labelSmall?.copyWith(
            color: context.colors.onSurface.withValues(alpha: 0.6),
          ),
        ),
      ),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const LocationPickerScreen()),
        );
      },
    );
  }
}

class _LanguageSetting extends ConsumerWidget {
  const _LanguageSetting();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentLocale = ref.watch(localeProvider);
    final l10n = AppLocalizations.of(context);
    final currentName = currentLocale == null
        ? l10n?.systemDefault ?? 'System Default'
        : findSupportedLocale(currentLocale)?.nativeName ??
              currentLocale.languageCode;

    return SettingsActionTile(
      icon: Icons.language_rounded,
      title: l10n?.language ?? 'Language',
      trailing: Text(
        currentName,
        style: context.textTheme.bodyMedium?.copyWith(
          color: context.colors.primary,
          fontWeight: FontWeight.bold,
        ),
      ),
      onTap: () => _showLanguagePicker(context, ref),
    );
  }

  Future<void> _showLanguagePicker(BuildContext context, WidgetRef ref) async {
    final currentLocale = ref.read(localeProvider);
    final l10n = AppLocalizations.of(context);

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: context.colors.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l10n?.selectLanguage ?? 'Select Language',
                style: context.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: context.colors.onSurface,
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                title: Text(l10n?.systemDefault ?? 'System Default'),
                trailing: currentLocale == null
                    ? Icon(
                        Icons.check_circle_rounded,
                        color: context.colors.primary,
                      )
                    : null,
                onTap: () async {
                  await ref.read(localeProvider.notifier).clearLocale();
                  if (context.mounted) Navigator.pop(context);
                },
              ),
              const Divider(),
              ...supportedLocales.map((supported) {
                final isSelected =
                    supported.locale.languageCode ==
                    currentLocale?.languageCode;
                return ListTile(
                  title: Text(supported.nativeName),
                  subtitle: Text(supported.name),
                  trailing: isSelected
                      ? Icon(
                          Icons.check_circle_rounded,
                          color: context.colors.primary,
                        )
                      : null,
                  onTap: () async {
                    await ref
                        .read(localeProvider.notifier)
                        .setLocale(supported.locale);
                    if (context.mounted) Navigator.pop(context);
                  },
                );
              }),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }
}

class _StartOfWeekSetting extends ConsumerWidget {
  const _StartOfWeekSetting();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final startOfWeek = ref.watch(startOfWeekProvider);
    final l10n = AppLocalizations.of(context);
    return SettingsActionTile(
      icon: Icons.calendar_today_rounded,
      title: l10n?.startOfWeek ?? 'Start of Week',
      trailing: Text(
        startOfWeek == StartingDayOfWeek.sunday
            ? (l10n?.sunday ?? 'Sunday')
            : (l10n?.monday ?? 'Monday'),
        style: context.textTheme.bodyMedium?.copyWith(
          color: context.colors.primary,
          fontWeight: FontWeight.bold,
        ),
      ),
      onTap: () async {
        final newValue = startOfWeek == StartingDayOfWeek.sunday
            ? StartingDayOfWeek.monday
            : StartingDayOfWeek.sunday;
        await ref.read(startOfWeekProvider.notifier).setStartOfWeek(newValue);
      },
    );
  }
}

class _PrimaryViewSetting extends ConsumerWidget {
  const _PrimaryViewSetting();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final primaryView = ref.watch(primaryEventViewProvider);
    final l10n = AppLocalizations.of(context);
    return SettingsActionTile(
      icon: Icons.view_agenda_rounded,
      title: l10n?.primaryView ?? 'Primary View',
      trailing: Text(
        primaryView == PrimaryEventView.tithi
            ? (l10n?.tithi ?? 'Tithi')
            : primaryView == PrimaryEventView.festival
            ? (l10n?.festival ?? 'Festival')
            : (l10n?.moon ?? 'Moon'),
        style: context.textTheme.bodyMedium?.copyWith(
          color: context.colors.primary,
          fontWeight: FontWeight.bold,
        ),
      ),
      onTap: () {
        final nextIndex =
            (primaryView.index + 1) % PrimaryEventView.values.length;
        ref
            .read(primaryEventViewProvider.notifier)
            .setPrimaryView(PrimaryEventView.values[nextIndex]);
      },
    );
  }
}

class _PrimaryCalendarSetting extends ConsumerWidget {
  const _PrimaryCalendarSetting();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final primarySystem = ref.watch(primaryCalendarSystemProvider);
    final l10n = AppLocalizations.of(context);
    return SettingsActionTile(
      icon: Icons.event_note_rounded,
      title: l10n?.primaryCalendar ?? 'Primary Calendar',
      trailing: Text(
        primarySystem.label,
        style: context.textTheme.bodyMedium?.copyWith(
          color: context.colors.primary,
          fontWeight: FontWeight.bold,
        ),
      ),
      onTap: () => _showCalendarSystemPicker(context, ref, isPrimary: true),
    );
  }
}

class _SecondaryCalendarSetting extends ConsumerWidget {
  const _SecondaryCalendarSetting();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final secondarySystem = ref.watch(secondaryCalendarSystemProvider);
    final l10n = AppLocalizations.of(context);
    return SettingsActionTile(
      icon: Icons.event_available_rounded,
      title: l10n?.secondaryCalendar ?? 'Secondary Calendar',
      trailing: Text(
        secondarySystem.label,
        style: context.textTheme.bodyMedium?.copyWith(
          color: context.colors.primary,
          fontWeight: FontWeight.bold,
        ),
      ),
      onTap: () => _showCalendarSystemPicker(context, ref, isPrimary: false),
    );
  }
}

class _HinduMonthSystemSetting extends ConsumerWidget {
  const _HinduMonthSystemSetting();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final monthSystem = ref.watch(hinduMonthSystemProvider);
    return SettingsActionTile(
      icon: Icons.date_range_rounded,
      title: 'Hindu Month System',
      trailing: Text(
        monthSystem.label,
        style: context.textTheme.bodyMedium?.copyWith(
          color: context.colors.primary,
          fontWeight: FontWeight.bold,
        ),
      ),
      onTap: () => _showHinduMonthSystemPicker(context, ref),
    );
  }

  Future<void> _showHinduMonthSystemPicker(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final currentSystem = ref.read(hinduMonthSystemProvider);

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: context.colors.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Hindu Month System',
                style: context.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: context.colors.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  'Choose how months are named during Krishna Paksha',
                  textAlign: TextAlign.center,
                  style: context.textTheme.bodySmall?.copyWith(
                    color: context.colors.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              ...HinduMonthSystem.values.map((system) {
                final isSelected = system == currentSystem;
                return ListTile(
                  title: Text(
                    system.label,
                    style: TextStyle(
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                      color: isSelected
                          ? context.colors.primary
                          : context.colors.onSurface,
                    ),
                  ),
                  subtitle: Text(
                    system.description,
                    style: context.textTheme.bodySmall?.copyWith(
                      color: context.colors.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                  trailing: isSelected
                      ? Icon(
                          Icons.check_circle_rounded,
                          color: context.colors.primary,
                        )
                      : null,
                  onTap: () async {
                    await ref
                        .read(hinduMonthSystemProvider.notifier)
                        .setSystem(system);
                    if (context.mounted) Navigator.pop(context);
                  },
                );
              }),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }
}

class _HinduYearEraSetting extends ConsumerWidget {
  const _HinduYearEraSetting();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final yearEra = ref.watch(hinduYearEraProvider);
    return SettingsActionTile(
      icon: Icons.calendar_month_rounded,
      title: 'Hindu Year Era',
      trailing: Text(
        yearEra.shortLabel,
        style: context.textTheme.bodyMedium?.copyWith(
          color: context.colors.primary,
          fontWeight: FontWeight.bold,
        ),
      ),
      onTap: () => _showHinduYearEraPicker(context, ref),
    );
  }

  Future<void> _showHinduYearEraPicker(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final currentEra = ref.read(hinduYearEraProvider);

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: context.colors.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Hindu Year Era',
                style: context.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: context.colors.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  'Choose the calendar era for year display',
                  textAlign: TextAlign.center,
                  style: context.textTheme.bodySmall?.copyWith(
                    color: context.colors.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              ...HinduYearEra.values.map((era) {
                final isSelected = era == currentEra;
                return ListTile(
                  title: Text(
                    era.label,
                    style: TextStyle(
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                      color: isSelected
                          ? context.colors.primary
                          : context.colors.onSurface,
                    ),
                  ),
                  subtitle: Text(
                    era.description,
                    style: context.textTheme.bodySmall?.copyWith(
                      color: context.colors.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                  trailing: isSelected
                      ? Icon(
                          Icons.check_circle_rounded,
                          color: context.colors.primary,
                        )
                      : null,
                  onTap: () async {
                    await ref.read(hinduYearEraProvider.notifier).setEra(era);
                    if (context.mounted) Navigator.pop(context);
                  },
                );
              }),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }
}

class _AccessibilitySettings extends ConsumerWidget {
  const _AccessibilitySettings();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final accessibility = ref.watch(accessibilityProvider);
    final notifier = ref.read(accessibilityProvider.notifier);

    return SettingsGroupCard(
      children: [
        SettingsSwitchTile(
          icon: Icons.motion_photos_off_outlined,
          title: l10n?.reduceMotion ?? 'Reduce Motion',
          subtitle: l10n?.disableAnimations ?? 'Disable animations & effects',
          value: accessibility.reduceMotion,
          onChanged: notifier.toggleReduceMotion,
        ),
        const SettingsDivider(),
        SettingsSwitchTile(
          icon: Icons.vibration_rounded,
          title: l10n?.hapticFeedback ?? 'Haptic Feedback',
          subtitle: l10n?.vibrateOnTouch ?? 'Vibrate on touch interactions',
          value: accessibility.hapticFeedback,
          onChanged: notifier.toggleHapticFeedback,
        ),
        const SettingsDivider(),
        SettingsSwitchTile(
          icon: Icons.contrast_rounded,
          title: l10n?.highContrast ?? 'High Contrast',
          subtitle:
              l10n?.solidBackgrounds ??
              'Solid backgrounds for better readability',
          value: accessibility.highContrast,
          onChanged: notifier.toggleHighContrast,
        ),
        const SettingsDivider(),
        SettingsSwitchTile(
          icon: Icons.text_fields_rounded,
          title: l10n?.largeText ?? 'Large Text',
          subtitle: l10n?.increaseTextSize ?? 'Increase text size globally',
          value: accessibility.largeText,
          onChanged: notifier.toggleLargeText,
        ),
      ],
    );
  }
}

Future<void> _showCalendarSystemPicker(
  BuildContext context,
  WidgetRef ref, {
  required bool isPrimary,
}) async {
  final currentSystem = isPrimary
      ? ref.read(primaryCalendarSystemProvider)
      : ref.read(secondaryCalendarSystemProvider);

  await showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (context) {
      return Container(
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              isPrimary
                  ? 'Select Primary Calendar'
                  : 'Select Secondary Calendar',
              style: context.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: context.colors.onSurface,
              ),
            ),
            const SizedBox(height: 16),
            ...AppCalendarSystem.values.map((system) {
              final isSelected = system == currentSystem;
              return ListTile(
                title: Text(
                  system.label,
                  style: TextStyle(
                    fontWeight: isSelected
                        ? FontWeight.bold
                        : FontWeight.normal,
                    color: isSelected
                        ? context.colors.primary
                        : context.colors.onSurface,
                  ),
                ),
                trailing: isSelected
                    ? Icon(
                        Icons.check_circle_rounded,
                        color: context.colors.primary,
                      )
                    : null,
                onTap: () async {
                  if (isPrimary) {
                    await ref
                        .read(primaryCalendarSystemProvider.notifier)
                        .setSystem(system);
                  } else {
                    await ref
                        .read(secondaryCalendarSystemProvider.notifier)
                        .setSystem(system);
                  }
                  if (context.mounted) Navigator.pop(context);
                },
              );
            }),
            const SizedBox(height: 16),
          ],
        ),
      );
    },
  );
}
