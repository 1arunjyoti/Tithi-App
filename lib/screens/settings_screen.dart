import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
          // Background Gradient
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: context.theme.scaffoldBackgroundColor == Colors.black
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

          SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                _buildSectionHeader(context, l10n?.appearance ?? 'APPEARANCE'),
                _buildThemeCard(context, ref),

                const SizedBox(height: 32),

                _buildSectionHeader(
                  context,
                  l10n?.preferences ?? 'PREFERENCES',
                ),
                _buildSettingsCard(
                  context,
                  ref: ref,
                  children: [
                    Consumer(
                      builder: (context, ref, _) {
                        // Load notification state on first build
                        ref.watch(loadNotificationStateProvider);

                        final notificationService = ref.read(
                          notificationServiceProvider,
                        );
                        final notifTime = ref.watch(notificationTimeProvider);
                        // We also need to listen to enabled state effectively
                        // For now we rely on the FutureBuilder below for switch, but simpler to check enabled state for time picker visibility

                        return FutureBuilder<bool>(
                          future: notificationService.isEnabled(),
                          builder: (context, snapshot) {
                            final isEnabled = snapshot.data ?? false;

                            return Column(
                              children: [
                                _buildSwitchTile(
                                  context,
                                  icon: Icons.notifications_active_rounded,
                                  title:
                                      l10n?.dailyNotifications ??
                                      'Daily Notifications',
                                  subtitle: isEnabled
                                      ? (l10n?.notificationScheduled ??
                                            'Scheduled daily')
                                      : (l10n?.getNotifiedTithiDaily ??
                                            'Get notified about Tithi daily'),
                                  value: isEnabled,
                                  ref: ref,
                                  onChanged: (val) async {
                                    if (val) {
                                      // Request permission first
                                      final granted = await notificationService
                                          .requestPermission();
                                      if (!granted) {
                                        return;
                                      }
                                    }
                                    await notificationService.setEnabled(val);
                                    ref.invalidate(
                                      loadNotificationStateProvider,
                                    );
                                  },
                                ),

                                // Time Picker (Only show if enabled)
                                if (isEnabled) ...[
                                  Divider(
                                    height: 1,
                                    color: context.colors.onSurface.withValues(
                                      alpha: 0.1,
                                    ),
                                  ),
                                  _buildActionTile(
                                    context,
                                    icon: Icons.access_time_rounded,
                                    title:
                                        l10n?.notificationTime ??
                                        'Notification Time',
                                    ref: ref,
                                    trailing: Text(
                                      _formatTime(
                                        TimeOfDay(
                                          hour: notifTime.hour,
                                          minute: notifTime.minute,
                                        ),
                                        context,
                                      ),
                                      style: context.textTheme.bodyMedium
                                          ?.copyWith(
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
                                              timePickerTheme:
                                                  TimePickerThemeData(
                                                    backgroundColor:
                                                        context.colors.surface,
                                                    hourMinuteTextColor:
                                                        context.colors.primary,
                                                    dayPeriodTextColor: context
                                                        .colors
                                                        .onSurface,
                                                    dialHandColor:
                                                        context.colors.primary,
                                                    dialBackgroundColor: context
                                                        .colors
                                                        .onSurface
                                                        .withValues(alpha: 0.1),
                                                  ),
                                            ),
                                            child: child!,
                                          );
                                        },
                                      );

                                      if (time != null) {
                                        await notificationService
                                            .setNotificationTime(
                                              time.hour,
                                              time.minute,
                                            );
                                        ref.invalidate(
                                          loadNotificationStateProvider,
                                        );
                                      }
                                    },
                                  ),
                                ],
                              ],
                            );
                          },
                        );
                      },
                    ),
                    Divider(
                      height: 1,
                      color: context.colors.onSurface.withValues(alpha: 0.1),
                    ),
                    Consumer(
                      builder: (context, ref, _) {
                        final locationAsync = ref.watch(
                          currentLocationProvider,
                        );
                        final locationService = ref.read(
                          locationServiceProvider,
                        );

                        return FutureBuilder<bool>(
                          future: locationService.isLocationEnabled(),
                          builder: (context, snapshot) {
                            final isEnabled = snapshot.data ?? false;
                            return _buildSwitchTile(
                              context,
                              icon: Icons.location_on_rounded,
                              title: l10n?.autoLocation ?? 'Auto Location',
                              subtitle: locationAsync.when(
                                data: (loc) {
                                  final cityName = loc?.cityName;
                                  if (cityName != null) {
                                    return l10n?.usingLocation(cityName) ??
                                        'Using: $cityName';
                                  }
                                  return l10n?.useGpsForTithi ??
                                      'Use GPS for precise Tithi calculation';
                                },
                                loading: () =>
                                    l10n?.fetchingLocation ??
                                    'Fetching location...',
                                error: (_, _) =>
                                    l10n?.locationUnavailable ??
                                    'Location unavailable',
                              ),
                              value: isEnabled,
                              ref: ref,
                              onChanged: (val) async {
                                await locationService.setLocationEnabled(val);
                                if (val) {
                                  // Request permission if enabling
                                  final permission =
                                      await Geolocator.checkPermission();
                                  if (permission == LocationPermission.denied) {
                                    await Geolocator.requestPermission();
                                  }
                                }
                                ref.invalidate(currentLocationProvider);
                              },
                            );
                          },
                        );
                      },
                    ),
                    Divider(
                      height: 1,
                      color: context.colors.onSurface.withValues(alpha: 0.1),
                    ),
                    Consumer(
                      builder: (context, ref, _) {
                        final homeLocation = ref.watch(homeLocationProvider);

                        return _buildActionTile(
                          context,
                          icon: Icons.home_rounded,
                          title: l10n?.homeLocation ?? 'Home Location',
                          ref: ref,
                          trailing: SizedBox(
                            width: 120,
                            child: Text(
                              homeLocation?.cityName ??
                                  (l10n?.notSet ?? 'Not set'),
                              textAlign: TextAlign.end,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: context.textTheme.labelSmall?.copyWith(
                                color: context.colors.onSurface.withValues(
                                  alpha: 0.6,
                                ),
                              ),
                            ),
                          ),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const LocationPickerScreen(),
                              ),
                            );
                          },
                        );
                      },
                    ),
                    Divider(
                      height: 1,
                      color: context.colors.onSurface.withValues(alpha: 0.1),
                    ),
                    // Language Selection
                    Consumer(
                      builder: (context, ref, _) {
                        final currentLocale = ref.watch(localeProvider);
                        final l10n = AppLocalizations.of(context);
                        final currentName = currentLocale == null
                            ? l10n?.systemDefault ?? 'System Default'
                            : findSupportedLocale(currentLocale)?.nativeName ??
                                  currentLocale.languageCode;

                        return _buildActionTile(
                          context,
                          icon: Icons.language_rounded,
                          title: l10n?.language ?? 'Language',
                          ref: ref,
                          trailing: Text(
                            currentName,
                            style: context.textTheme.bodyMedium?.copyWith(
                              color: context.colors.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          onTap: () => _showLanguagePicker(context, ref),
                        );
                      },
                    ),
                  ],
                ),

                const SizedBox(height: 32),

                _buildSectionHeader(context, l10n?.calendar ?? 'CALENDAR'),
                _buildSettingsCard(
                  context,
                  ref: ref,
                  children: [
                    Consumer(
                      builder: (context, ref, _) {
                        final startOfWeek = ref.watch(startOfWeekProvider);
                        return _buildActionTile(
                          context,
                          icon: Icons.calendar_today_rounded,
                          title: l10n?.startOfWeek ?? 'Start of Week',
                          ref: ref,
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
                            final newValue =
                                startOfWeek == StartingDayOfWeek.sunday
                                ? StartingDayOfWeek.monday
                                : StartingDayOfWeek.sunday;
                            await ref
                                .read(startOfWeekProvider.notifier)
                                .setStartOfWeek(newValue);
                          },
                        );
                      },
                    ),
                    Divider(
                      height: 1,
                      color: context.colors.onSurface.withValues(alpha: 0.1),
                    ),
                    Consumer(
                      builder: (context, ref, _) {
                        final primaryView = ref.watch(primaryEventViewProvider);
                        return _buildActionTile(
                          context,
                          icon: Icons.view_agenda_rounded,
                          title: l10n?.primaryView ?? 'Primary View',
                          ref: ref,
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
                            // Cycle through views
                            final nextIndex =
                                (primaryView.index + 1) %
                                PrimaryEventView.values.length;
                            ref
                                .read(primaryEventViewProvider.notifier)
                                .setPrimaryView(
                                  PrimaryEventView.values[nextIndex],
                                );
                          },
                        );
                      },
                    ),
                    Divider(
                      height: 1,
                      color: context.colors.onSurface.withValues(alpha: 0.1),
                    ),
                    Consumer(
                      builder: (context, ref, _) {
                        final primarySystem = ref.watch(
                          primaryCalendarSystemProvider,
                        );
                        return _buildActionTile(
                          context,
                          icon: Icons.event_note_rounded,
                          title: l10n?.primaryCalendar ?? 'Primary Calendar',
                          ref: ref,
                          trailing: Text(
                            primarySystem.label,
                            style: context.textTheme.bodyMedium?.copyWith(
                              color: context.colors.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          onTap: () => _showCalendarSystemPicker(
                            context,
                            ref,
                            isPrimary: true,
                          ),
                        );
                      },
                    ),
                    Divider(
                      height: 1,
                      color: context.colors.onSurface.withValues(alpha: 0.1),
                    ),
                    Consumer(
                      builder: (context, ref, _) {
                        final secondarySystem = ref.watch(
                          secondaryCalendarSystemProvider,
                        );
                        return _buildActionTile(
                          context,
                          icon: Icons.event_available_rounded,
                          title:
                              l10n?.secondaryCalendar ?? 'Secondary Calendar',
                          ref: ref,
                          trailing: Text(
                            secondarySystem.label,
                            style: context.textTheme.bodyMedium?.copyWith(
                              color: context.colors.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          onTap: () => _showCalendarSystemPicker(
                            context,
                            ref,
                            isPrimary: false,
                          ),
                        );
                      },
                    ),
                    Divider(
                      height: 1,
                      color: context.colors.onSurface.withValues(alpha: 0.1),
                    ),
                    // Hindu Month System (Amanta/Purnimant)
                    Consumer(
                      builder: (context, ref, _) {
                        final monthSystem = ref.watch(hinduMonthSystemProvider);
                        return _buildActionTile(
                          context,
                          icon: Icons.date_range_rounded,
                          title: 'Hindu Month System',
                          ref: ref,
                          trailing: Text(
                            monthSystem.label,
                            style: context.textTheme.bodyMedium?.copyWith(
                              color: context.colors.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          onTap: () =>
                              _showHinduMonthSystemPicker(context, ref),
                        );
                      },
                    ),
                    Divider(
                      height: 1,
                      color: context.colors.onSurface.withValues(alpha: 0.1),
                    ),
                    // Hindu Year Era (Vikram/Shaka Samvat)
                    Consumer(
                      builder: (context, ref, _) {
                        final yearEra = ref.watch(hinduYearEraProvider);
                        return _buildActionTile(
                          context,
                          icon: Icons.calendar_month_rounded,
                          title: 'Hindu Year Era',
                          ref: ref,
                          trailing: Text(
                            yearEra.shortLabel,
                            style: context.textTheme.bodyMedium?.copyWith(
                              color: context.colors.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          onTap: () => _showHinduYearEraPicker(context, ref),
                        );
                      },
                    ),
                  ],
                ),

                const SizedBox(height: 32),

                _buildSectionHeader(
                  context,
                  l10n?.accessibility ?? 'ACCESSIBILITY',
                ),
                _buildSettingsCard(
                  context,
                  ref: ref,
                  children: [
                    Consumer(
                      builder: (context, ref, _) {
                        final accessibility = ref.watch(accessibilityProvider);
                        final notifier = ref.read(
                          accessibilityProvider.notifier,
                        );

                        return Column(
                          children: [
                            _buildSwitchTile(
                              context,
                              icon: Icons.motion_photos_off_outlined,
                              title: l10n?.reduceMotion ?? 'Reduce Motion',
                              subtitle:
                                  l10n?.disableAnimations ??
                                  'Disable animations & effects',
                              value: accessibility.reduceMotion,
                              ref: ref,
                              onChanged: notifier.toggleReduceMotion,
                            ),
                            Divider(
                              height: 1,
                              color: context.colors.onSurface.withValues(
                                alpha: 0.1,
                              ),
                            ),
                            _buildSwitchTile(
                              context,
                              icon: Icons.vibration_rounded,
                              title: l10n?.hapticFeedback ?? 'Haptic Feedback',
                              subtitle:
                                  l10n?.vibrateOnTouch ??
                                  'Vibrate on touch interactions',
                              value: accessibility.hapticFeedback,
                              ref: ref,
                              onChanged: notifier.toggleHapticFeedback,
                            ),
                            Divider(
                              height: 1,
                              color: context.colors.onSurface.withValues(
                                alpha: 0.1,
                              ),
                            ),
                            _buildSwitchTile(
                              context,
                              icon: Icons.contrast_rounded,
                              title: l10n?.highContrast ?? 'High Contrast',
                              subtitle:
                                  l10n?.solidBackgrounds ??
                                  'Solid backgrounds for better readability',
                              value: accessibility.highContrast,
                              ref: ref,
                              onChanged: notifier.toggleHighContrast,
                            ),
                            Divider(
                              height: 1,
                              color: context.colors.onSurface.withValues(
                                alpha: 0.1,
                              ),
                            ),
                            _buildSwitchTile(
                              context,
                              icon: Icons.text_fields_rounded,
                              title: l10n?.largeText ?? 'Large Text',
                              subtitle:
                                  l10n?.increaseTextSize ??
                                  'Increase text size globally',
                              value: accessibility.largeText,
                              ref: ref,
                              onChanged: notifier.toggleLargeText,
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),

                const SizedBox(height: 32),

                _buildSectionHeader(
                  context,
                  l10n?.dataStorage ?? 'DATA & STORAGE',
                ),
                _buildSettingsCard(
                  context,
                  ref: ref,
                  children: [
                    _buildActionTile(
                      context,
                      icon: Icons.cleaning_services_rounded,
                      title: l10n?.clearLocationCache ?? 'Clear Location Cache',
                      ref: ref,
                      onTap: () async {
                        final scaffold = ScaffoldMessenger.of(context);
                        await ref.read(locationServiceProvider).clearCache();
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
                    ),
                    Divider(
                      height: 1,
                      color: context.colors.onSurface.withValues(alpha: 0.1),
                    ),
                    _buildActionTile(
                      context,
                      icon: Icons.restore_rounded,
                      title: l10n?.resetAppSettings ?? 'Reset App Settings',
                      ref: ref,
                      trailing: const Text(
                        'Using default',
                        style: TextStyle(color: Colors.transparent),
                      ), // Just spacer
                      onTap: () async {
                        // Show confirmation dialog
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
                          // notification_settings handled separately usually, but good to clear too
                          // Ideally we access the specific service clearing methods, but Hive.deleteFromDisk or iteration works
                          // For now just settings box which covers theme/calendar
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
                    ),
                  ],
                ),

                const SizedBox(height: 32),

                _buildSectionHeader(context, l10n?.about ?? 'ABOUT'),
                _buildSettingsCard(
                  context,
                  ref: ref,
                  children: [
                    _buildActionTile(
                      context,
                      icon: Icons.privacy_tip_rounded,
                      title: l10n?.privacyPolicy ?? 'Privacy Policy',
                      ref: ref,
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

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 12),
      child: Text(
        title,
        style: context.textTheme.labelSmall?.copyWith(
          letterSpacing: 2,
          fontWeight: FontWeight.bold,
          color: context.colors.primary,
        ),
      ),
    );
  }

  Widget _buildThemeCard(BuildContext context, WidgetRef ref) {
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
          _buildThemeOption(
            context,
            ref,
            label: 'Auto',
            icon: Icons.brightness_auto_rounded,
            isSelected: autoMode,
            onTap: () =>
                ref.read(themeOverrideProvider.notifier).setOverride(null),
          ),
          _buildThemeOption(
            context,
            ref,
            label: 'Shukla',
            icon: Icons.light_mode_rounded,
            isSelected: currentOverride == 'Shukla',
            onTap: () =>
                ref.read(themeOverrideProvider.notifier).setOverride('Shukla'),
          ),
          _buildThemeOption(
            context,
            ref,
            label: 'Dark',
            icon: Icons.contrast,
            isSelected: currentOverride == 'PureDark',
            onTap: () => ref
                .read(themeOverrideProvider.notifier)
                .setOverride('PureDark'),
          ),
          _buildThemeOption(
            context,
            ref,
            label: 'Krishna',
            icon: Icons.bubble_chart,
            isSelected: currentOverride == 'Krishna',
            onTap: () =>
                ref.read(themeOverrideProvider.notifier).setOverride('Krishna'),
          ),
        ],
      ),
    );
  }

  Widget _buildThemeOption(
    BuildContext context,
    WidgetRef ref, {
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () {
        if (ref.read(accessibilityProvider).hapticFeedback) {
          HapticFeedback.selectionClick();
        }
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? context.colors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected
                  ? Colors.white
                  : context.colors.onSurface.withValues(alpha: 0.6),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: context.textTheme.labelSmall?.copyWith(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected
                    ? Colors.white
                    : context.colors.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsCard(
    BuildContext context, {
    required List<Widget> children,
    required WidgetRef ref,
  }) {
    return Container(
      decoration: AppTheme.glassmorphism(
        context: context,
        opacity: 0.1,
        borderRadius: 24,
        ref: ref,
      ),
      child: Column(children: children),
    );
  }

  Widget _buildSwitchTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required Function(bool) onChanged,
    WidgetRef? ref,
  }) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: context.colors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: context.colors.primary, size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: context.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  subtitle,
                  style: context.textTheme.labelSmall?.copyWith(
                    color: context.colors.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: (val) {
              if (ref != null &&
                  ref.read(accessibilityProvider).hapticFeedback) {
                HapticFeedback.lightImpact();
              }
              onChanged(val);
            },
            activeThumbColor: context.colors.primary,
          ),
        ],
      ),
    );
  }

  Widget _buildActionTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    Widget? trailing,
    required VoidCallback onTap,
    WidgetRef? ref, // Optional ref to check accessibility
  }) {
    return ListTile(
      onTap: () {
        if (ref != null && ref.read(accessibilityProvider).hapticFeedback) {
          HapticFeedback.lightImpact();
        } else if (ref == null) {
          // Fallback or skip?
          // We can't check setting without ref.
          // Let's enforce ref or check if we can read it from context (no).
          // We'll skip if no ref.
        }
        onTap();
      },
      contentPadding: const EdgeInsets.all(16),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: context.colors.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: context.colors.primary, size: 22),
      ),
      title: Text(
        title,
        style: context.textTheme.bodyLarge?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (trailing != null) trailing,
          const SizedBox(width: 8),
          Icon(
            Icons.chevron_right_rounded,
            color: context.colors.onSurface.withValues(alpha: 0.4),
          ),
        ],
      ),
    );
  }

  String _formatTime(TimeOfDay time, BuildContext context) {
    final localizations = MaterialLocalizations.of(context);
    return localizations.formatTimeOfDay(time);
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
              // System Default option
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
              // Supported locales
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
