import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/theme_provider.dart';
import '../l10n/app_localizations.dart';
import '../theme/app_theme.dart';
import '../providers/accessibility_provider.dart';
import '../widgets/settings_widgets.dart';
import '../features/settings/widgets/notification_settings.dart';
import '../features/settings/widgets/location_settings.dart';
import '../features/settings/widgets/language_display_settings.dart';
import '../features/settings/widgets/calendar_settings.dart';
import '../features/settings/widgets/accessibility_settings.dart';
import '../features/settings/widgets/data_settings.dart';

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
                            NotificationSettings(),
                            SettingsDivider(),
                          ],
                          LocationSettingsSection(),
                          SettingsDivider(),
                          HomeLocationSetting(),
                          SettingsDivider(),
                          LanguageSetting(),
                        ],
                      ),

                      const SizedBox(height: 32),

                      SettingsSectionHeader(l10n?.calendar ?? 'CALENDAR'),
                      const SettingsGroupCard(
                        children: [
                          StartOfWeekSetting(),
                          SettingsDivider(),
                          PrimaryViewSetting(),
                          SettingsDivider(),
                          PrimaryCalendarSetting(),
                          SettingsDivider(),
                          SecondaryCalendarSetting(),
                          SettingsDivider(),
                          HinduMonthSystemSetting(),
                          SettingsDivider(),
                          HinduYearEraSetting(),
                          SettingsDivider(),
                          TithiDisplayModeSetting(),
                        ],
                      ),

                      const SizedBox(height: 32),

                      SettingsSectionHeader(
                        l10n?.accessibility ?? 'ACCESSIBILITY',
                      ),
                      const AccessibilitySettings(),

                      const SizedBox(height: 32),

                      SettingsSectionHeader(
                        l10n?.dataStorage ?? 'DATA & STORAGE',
                      ),
                      const SettingsGroupCard(
                        children: [
                          ClearCacheSetting(),
                          SettingsDivider(),
                          ExportFestivalsSetting(),
                          SettingsDivider(),
                          ResetSettingsTile(),
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
        final l10n = AppLocalizations.of(context);
        final currentOverride = ref.watch(themeOverrideProvider);
        final autoMode = currentOverride == null;

        // Use cached config
        final config = ref.watch(glassmorphismConfigProvider);
        final theme = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;
        final isPureDark = theme.scaffoldBackgroundColor == Colors.black;

        // RepaintBoundary for the same reason as SettingsGroupCard:
        // glass shadow must not repaint on every scroll frame.
        return RepaintBoundary(
          child: Container(
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
                label: l10n?.themeAuto ?? 'Auto',
                icon: Icons.brightness_auto_rounded,
                isSelected: autoMode,
                onTap: () =>
                    ref.read(themeOverrideProvider.notifier).setOverride(null),
              ),
              ThemeOptionButton(
                label: l10n?.themeShukla ?? 'Shukla',
                icon: Icons.light_mode_rounded,
                isSelected: currentOverride == 'Shukla',
                onTap: () => ref
                    .read(themeOverrideProvider.notifier)
                    .setOverride('Shukla'),
              ),
              ThemeOptionButton(
                label: l10n?.themeDark ?? 'Dark',
                icon: Icons.contrast,
                isSelected: currentOverride == 'PureDark',
                onTap: () => ref
                    .read(themeOverrideProvider.notifier)
                    .setOverride('PureDark'),
              ),
              ThemeOptionButton(
                label: l10n?.themePurple ?? 'Purple',
                icon: Icons.bubble_chart,
                isSelected: currentOverride == 'Krishna',
                onTap: () => ref
                    .read(themeOverrideProvider.notifier)
                    .setOverride('Krishna'),
              ),
            ],
          ),
          ),
        );
      },
    );
  }
}
