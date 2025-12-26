import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import '../providers/location_provider.dart';
import '../providers/notification_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/version_provider.dart';

import '../theme/app_theme.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Settings'),
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
                _buildSectionHeader(context, 'APPEARANCE'),
                _buildThemeCard(context, ref),

                const SizedBox(height: 32),

                _buildSectionHeader(context, 'PREFERENCES'),
                _buildSettingsCard(
                  context,
                  children: [
                    Consumer(
                      builder: (context, ref, _) {
                        // Load notification state on first build
                        ref.watch(loadNotificationStateProvider);

                        final notificationService = ref.read(
                          notificationServiceProvider,
                        );

                        return FutureBuilder<bool>(
                          future: notificationService.isEnabled(),
                          builder: (context, snapshot) {
                            final isEnabled = snapshot.data ?? false;
                            return _buildSwitchTile(
                              context,
                              icon: Icons.notifications_active_rounded,
                              title: 'Daily Notifications',
                              subtitle: isEnabled
                                  ? 'Scheduled at 8:00 AM'
                                  : 'Get notified about Tithi daily',
                              value: isEnabled,
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
                                ref.invalidate(loadNotificationStateProvider);
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
                              title: 'Auto Location',
                              subtitle: locationAsync.when(
                                data: (loc) => loc?.cityName != null
                                    ? 'Using: ${loc!.cityName}'
                                    : 'Use GPS for precise Tithi calculation',
                                loading: () => 'Fetching location...',
                                error: (_, _) => 'Location unavailable',
                              ),
                              value: isEnabled,
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
                  ],
                ),

                const SizedBox(height: 32),

                _buildSectionHeader(context, 'ABOUT'),
                _buildSettingsCard(
                  context,
                  children: [
                    Consumer(
                      builder: (context, ref, _) {
                        final versionAsync = ref.watch(versionStringProvider);
                        return _buildActionTile(
                          context,
                          icon: Icons.info_rounded,
                          title: 'Version',
                          trailing: versionAsync.when(
                            data: (v) => v,
                            loading: () => '...',
                            error: (_, _) => '?',
                          ),
                          onTap: () {},
                        );
                      },
                    ),
                    Divider(
                      height: 1,
                      color: context.colors.onSurface.withValues(alpha: 0.1),
                    ),
                    _buildActionTile(
                      context,
                      icon: Icons.privacy_tip_rounded,
                      title: 'Privacy Policy',
                      onTap: () {},
                    ),
                  ],
                ),

                const SizedBox(height: 48),
                Center(
                  child: Text(
                    'Made with ❤️ for Sanatan Dharma',
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
        opacity: 0.6,
        borderRadius: 24,
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
      onTap: onTap,
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
  }) {
    return Container(
      decoration: AppTheme.glassmorphism(
        context: context,
        opacity: 0.6,
        borderRadius: 24,
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
            onChanged: onChanged,
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
    String? trailing,
    required VoidCallback onTap,
  }) {
    return ListTile(
      onTap: onTap,
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
          if (trailing != null)
            Text(
              trailing,
              style: context.textTheme.bodyMedium?.copyWith(
                color: context.colors.onSurface.withValues(alpha: 0.5),
              ),
            ),
          const SizedBox(width: 8),
          Icon(
            Icons.chevron_right_rounded,
            color: context.colors.onSurface.withValues(alpha: 0.4),
          ),
        ],
      ),
    );
  }
}
