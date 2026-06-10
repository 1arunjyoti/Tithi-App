import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import '../providers/calendar_provider.dart';
import '../providers/location_provider.dart';
import '../providers/notification_provider.dart';
import '../providers/storage_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/locale_provider.dart';
import '../l10n/app_localizations.dart';
import '../theme/app_theme.dart';
import '../providers/accessibility_provider.dart';
import '../screens/location_picker_screen.dart';
import '../models/hindu_month_system.dart';
import '../widgets/settings_widgets.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final accessibility = ref.watch(accessibilityProvider);
    final mediaQuery = MediaQuery.of(context);

    return MediaQuery(
      data: mediaQuery.copyWith(
        textScaler: TextScaler.linear(
          mediaQuery.textScaler.scale(1.0) *
              (accessibility.largeText ? 1.1 : 1.0),
        ),
        disableAnimations: accessibility.reduceMotion
            ? true
            : mediaQuery.disableAnimations,
      ),
      child: Scaffold(
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
            // Background — delegates to AppTheme.backgroundDecoration (SMELL-1)
            Positioned.fill(
              child: RepaintBoundary(
                child: Container(
                  decoration: AppTheme.backgroundDecoration(context),
                ),
              ),
            ),

            SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 800),
                  child: ListView(
                    padding: const EdgeInsets.all(24),
                    children: [
                      SettingsSectionHeader(l10n?.appearance ?? 'APPEARANCE'),
                      _buildThemeSection(context),

                      const SizedBox(height: 32),

                      SettingsSectionHeader(l10n?.preferences ?? 'PREFERENCES'),
                      const SettingsGroupCard(
                        children: [
                          // Hide notifications on web - not supported
                          if (!kIsWeb) ...[
                            _NotificationSettings(),
                            SettingsDivider(),
                          ],
                          _LocationSettings(),
                          SettingsDivider(),
                          _HomeLocationSetting(),
                          SettingsDivider(),
                          _LanguageSetting(),
                        ],
                      ),

                      const SizedBox(height: 32),

                      SettingsSectionHeader(l10n?.calendar ?? 'CALENDAR'),
                      const SettingsGroupCard(
                        children: [
                          _StartOfWeekSetting(),
                          SettingsDivider(),
                          _PrimaryViewSetting(),
                          SettingsDivider(),
                          _PrimaryCalendarSetting(),
                          SettingsDivider(),
                          _SecondaryCalendarSetting(),
                          SettingsDivider(),
                          _HinduMonthSystemSetting(),
                          SettingsDivider(),
                          _HinduYearEraSetting(),
                          SettingsDivider(),
                          _TithiDisplayModeSetting(),
                        ],
                      ),

                      const SizedBox(height: 32),

                      SettingsSectionHeader(
                        l10n?.accessibility ?? 'ACCESSIBILITY',
                      ),
                      const _AccessibilitySettings(),

                      const SizedBox(height: 32),

                      SettingsSectionHeader(
                        l10n?.dataStorage ?? 'DATA & STORAGE',
                      ),
                      const SettingsGroupCard(
                        children: [
                          _ClearCacheSetting(),
                          SettingsDivider(),
                          _ResetSettingsTile(),
                        ],
                      ),
                      const SizedBox(height: 32),
                      Center(
                        child: Text(
                          l10n?.madeWithLove ??
                              'Made with ❤️ for Sanatan Dharma',
                          style: context.textTheme.labelSmall?.copyWith(
                            color: context.colors.onSurface.withValues(
                              alpha: 0.5,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThemeSection(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) {
        final currentOverride = ref.watch(themeOverrideProvider);
        final autoMode = currentOverride == null;

        // Use cached config
        final config = ref.watch(glassmorphismConfigProvider);
        final theme = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;
        final isPureDark = theme.scaffoldBackgroundColor == Colors.black;

        return Container(
          decoration: config.getDecoration(
            isDark: isDark,
            isPureDark: isPureDark,
            primaryColor: theme.primaryColor,
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
                label: 'Purple',
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
              if (!granted) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Notification permission denied. Please enable it in system settings.',
                      ),
                    ),
                  );
                }
                return;
              }
            }
            await notificationService.setEnabled(val);
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
    final isEnabledAsync = ref.watch(locationEnabledProvider);

    final isEnabled = isEnabledAsync.whenOrNull(data: (val) => val);
    final isLoading = isEnabledAsync.isLoading;

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
        error: (e, s) => l10n?.locationUnavailable ?? 'Location unavailable',
      ),
      value: isEnabled ?? false,
      isLoading: isLoading,
      onChanged: isEnabled == null
          ? null
          : (val) async {
              if (val) {
                // User wants to enable location
                var permission = await Geolocator.checkPermission();

                if (permission == LocationPermission.deniedForever) {
                  // Permission permanently denied, guide user to app settings
                  if (context.mounted) {
                    final shouldOpenSettings = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: Text(
                          l10n?.permissionRequired ?? 'Permission Required',
                        ),
                        content: Text(
                          l10n?.locationPermissionPermanentlyDenied ??
                              'Location permission was permanently denied. Please enable it in your device settings.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: Text(l10n?.cancel ?? 'Cancel'),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: Text(l10n?.openSettings ?? 'Open Settings'),
                          ),
                        ],
                      ),
                    );

                    if (shouldOpenSettings == true) {
                      await Geolocator.openAppSettings();
                    }
                    return; // Don't enable until user grants permission manually
                  }
                }

                if (permission == LocationPermission.denied) {
                  permission = await Geolocator.requestPermission();
                  if (permission == LocationPermission.denied ||
                      permission == LocationPermission.deniedForever) {
                    // Permission still denied, don't enable
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            l10n?.locationPermissionDenied ??
                                'Location permission denied.',
                          ),
                        ),
                      );
                    }
                    return;
                  }
                }
              }

              await locationService.setLocationEnabled(val);
              // Invalidate both providers to refresh state
              ref.invalidate(locationEnabledProvider);
              ref.invalidate(currentLocationProvider);
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

    await SettingsBottomSheet.show(
      context: context,
      title: l10n?.selectLanguage ?? 'Select Language',
      children: [
        // System Default option
        SettingsPickerItem(
          title: l10n?.systemDefault ?? 'System Default',
          isSelected: currentLocale == null,
          onTap: () async {
            await ref.read(localeProvider.notifier).clearLocale();
            if (context.mounted) Navigator.pop(context);
          },
        ),
        // Supported locales
        ...supportedLocales.map((supported) {
          return SettingsPickerItem(
            title: supported.nativeName,
            subtitle: supported.name,
            isSelected:
                supported.locale.languageCode == currentLocale?.languageCode,
            onTap: () async {
              await ref
                  .read(localeProvider.notifier)
                  .setLocale(supported.locale);
              if (context.mounted) Navigator.pop(context);
            },
          );
        }),
      ],
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
        await ref
            .read(calendarPreferencesProvider.notifier)
            .setStartOfWeek(newValue);
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
            .read(calendarPreferencesProvider.notifier)
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

    await SettingsBottomSheet.show(
      context: context,
      title: 'Hindu Month System',
      subtitle: 'Choose how months are named during Krishna Paksha',
      children: HinduMonthSystem.values.map((system) {
        return SettingsPickerItem(
          title: system.label,
          subtitle: system.description,
          isSelected: system == currentSystem,
          onTap: () async {
            await ref
                .read(calendarPreferencesProvider.notifier)
                .setHinduMonthSystem(system);
            if (context.mounted) Navigator.pop(context);
          },
        );
      }).toList(),
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

    await SettingsBottomSheet.show(
      context: context,
      title: 'Hindu Year Era',
      subtitle: 'Choose the calendar era for year display',
      children: HinduYearEra.values.map((era) {
        return SettingsPickerItem(
          title: era.label,
          subtitle: era.description,
          isSelected: era == currentEra,
          onTap: () async {
            await ref
                .read(calendarPreferencesProvider.notifier)
                .setHinduYearEra(era);
            if (context.mounted) Navigator.pop(context);
          },
        );
      }).toList(),
    );
  }
}

class _TithiDisplayModeSetting extends ConsumerWidget {
  const _TithiDisplayModeSetting();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final displayMode = ref.watch(tithiDisplayModeProvider);
    return SettingsActionTile(
      icon: Icons.calendar_view_day_rounded,
      title: 'Tithi Display',
      trailing: Text(
        displayMode == TithiDisplayMode.pakshaBased
            ? 'Paksha (1-15)'
            : '30 Days',
        style: context.textTheme.bodyMedium?.copyWith(
          color: context.colors.primary,
          fontWeight: FontWeight.bold,
        ),
      ),
      onTap: () => _showTithiDisplayModePicker(context, ref),
    );
  }

  Future<void> _showTithiDisplayModePicker(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final currentMode = ref.read(tithiDisplayModeProvider);

    await SettingsBottomSheet.show(
      context: context,
      title: 'Tithi Display',
      subtitle: 'Choose how tithis are numbered in the calendar',
      children: TithiDisplayMode.values.map((mode) {
        return SettingsPickerItem(
          title: mode == TithiDisplayMode.pakshaBased
              ? 'Paksha Based'
              : '30 Days',
          subtitle: mode == TithiDisplayMode.pakshaBased
              ? 'Show 1-15 for each paksha separately'
              : 'Show 1-30 continuously',
          isSelected: mode == currentMode,
          onTap: () async {
            await ref
                .read(calendarPreferencesProvider.notifier)
                .setTithiDisplayMode(mode);
            if (context.mounted) Navigator.pop(context);
          },
        );
      }).toList(),
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
          onChanged: (v) async => notifier.toggleReduceMotion(v),
        ),
        const SettingsDivider(),
        if (!kIsWeb) ...[
          SettingsSwitchTile(
            icon: Icons.vibration_rounded,
            title: l10n?.hapticFeedback ?? 'Haptic Feedback',
            subtitle: l10n?.vibrateOnTouch ?? 'Vibrate on touch interactions',
            value: accessibility.hapticFeedback,
            onChanged: (v) async => notifier.toggleHapticFeedback(v),
          ),
          const SettingsDivider(),
        ],
        SettingsSwitchTile(
          icon: Icons.contrast_rounded,
          title: l10n?.highContrast ?? 'High Contrast',
          subtitle:
              l10n?.solidBackgrounds ??
              'Solid backgrounds for better readability',
          value: accessibility.highContrast,
          onChanged: (v) async => notifier.toggleHighContrast(v),
        ),
        const SettingsDivider(),
        SettingsSwitchTile(
          icon: Icons.text_fields_rounded,
          title: l10n?.largeText ?? 'Large Text',
          subtitle: l10n?.increaseTextSize ?? 'Increase text size globally',
          value: accessibility.largeText,
          onChanged: (v) async => notifier.toggleLargeText(v),
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

  await SettingsBottomSheet.show(
    context: context,
    title: isPrimary ? 'Select Primary Calendar' : 'Select Secondary Calendar',
    children: AppCalendarSystem.values.map((system) {
      return SettingsPickerItem(
        title: system.label,
        isSelected: system == currentSystem,
        onTap: () async {
          if (isPrimary) {
            await ref
                .read(calendarPreferencesProvider.notifier)
                .setPrimaryCalendarSystem(system);
          } else {
            await ref
                .read(calendarPreferencesProvider.notifier)
                .setSecondaryCalendarSystem(system);
          }
          if (context.mounted) Navigator.pop(context);
        },
      );
    }).toList(),
  );
}

class _ClearCacheSetting extends ConsumerWidget {
  const _ClearCacheSetting();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return SettingsActionTile(
      icon: Icons.cleaning_services_rounded,
      title: l10n?.clearLocationCache ?? 'Clear Location Cache',
      onTap: () async {
        final scaffold = ScaffoldMessenger.of(context);
        await ref.read(locationServiceProvider).clearCache();
        ref.invalidate(currentLocationProvider);
        scaffold.showSnackBar(
          SnackBar(
            content: Text(
              l10n?.locationCacheCleared ?? 'Location cache cleared',
            ),
          ),
        );
      },
    );
  }
}

class _ResetSettingsTile extends ConsumerWidget {
  const _ResetSettingsTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final notificationService = ref.read(notificationServiceProvider);
    final locationService = ref.read(locationServiceProvider);
    final storageService = ref.read(storageServiceProvider);
    return SettingsActionTile(
      icon: Icons.restore_rounded,
      title: l10n?.resetAppSettings ?? 'Reset App Settings',
      onTap: () async {
        final confirm = await showDialog<bool>(
          context: context,
          builder: (c) => AlertDialog(
            title: Text(l10n?.resetSettingsTitle ?? 'Reset Settings?'),
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
          await storageService.resetAll();

          await locationService.setLocationEnabled(false);
          await locationService.clearCache();
          await notificationService.cancelAllNotifications();

          // Reset providers
          ref.invalidate(startOfWeekProvider);
          ref.invalidate(primaryEventViewProvider);
          ref.invalidate(themeOverrideProvider);
          ref.invalidate(primaryCalendarSystemProvider);
          ref.invalidate(secondaryCalendarSystemProvider);
          ref.invalidate(hinduMonthSystemProvider);
          ref.invalidate(hinduYearEraProvider);
          ref.invalidate(localeProvider);
          ref.invalidate(accessibilityProvider);
          ref.invalidate(currentLocationProvider);
          ref.invalidate(locationEnabledProvider);
          ref.invalidate(homeLocationProvider);

          ref.invalidate(loadNotificationStateProvider);
          ref.read(notificationEnabledProvider.notifier).setEnabled(false);
          ref
              .read(shlokaNotificationEnabledProvider.notifier)
              .setEnabled(false);
          ref.read(notificationTimeProvider.notifier).setTime((
            hour: 8,
            minute: 0,
          ));

          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  l10n?.appResetComplete ?? 'App reset complete',
                  textScaler: MediaQuery.of(context).textScaler,
                ),
              ),
            );
          }
        }
      },
    );
  }
}
