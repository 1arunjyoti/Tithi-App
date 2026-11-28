import 'package:material_ui/material_ui.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/theme_provider.dart';
import '../l10n/app_localizations.dart';
import '../core/navigation/app_routes.dart';
import '../core/navigation/haptic_back_button.dart';
import '../core/feedback/app_haptics.dart';
import '../theme/app_theme.dart';
import '../theme/app_metrics.dart';
import '../providers/accessibility_provider.dart';
import '../widgets/page_scaffold.dart';
import '../widgets/app_divider.dart';
import '../widgets/settings_widgets.dart';
import '../widgets/app_card.dart';
import '../widgets/screen_body.dart';
import '../features/settings/widgets/notification_settings.dart';
import '../features/settings/widgets/location_settings.dart';
import '../features/settings/widgets/language_display_settings.dart';
import '../features/settings/widgets/calendar_settings.dart';
import '../features/settings/widgets/region_settings.dart';
import '../features/settings/widgets/accessibility_settings.dart';
import '../features/settings/widgets/app_update_settings.dart';
import '../features/settings/widgets/data_settings.dart';
import '../features/ai/widgets/ai_section.dart';
import 'home_cards_screen.dart';

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
      child: PageScaffold(
        title: Text(l10n?.settings ?? 'Settings'),
        leading: const HapticBackButton(),
        body: ScreenBody(
          child: ListView(
            padding: EdgeInsets.only(
              top: AppSpacing.s16,
              bottom: AppSpacing.s16 + AppTheme.navigationBarInset(context),
            ),
            children: [
              SettingsSectionHeader(l10n?.appearance ?? 'APPEARANCE'),
              _buildThemeSection(context),

              const SizedBox(height: AppSpacing.s32),

              SettingsSectionHeader(l10n?.preferences ?? 'PREFERENCES'),
              const SettingsGroupCard(
                children: [
                  NotificationSettings(),
                  AppDivider(),
                  LocationSettingsSection(),
                  AppDivider(),
                  HomeLocationSetting(),
                  AppDivider(),
                  LanguageSetting(),
                  AppDivider(),
                  FestivalRegionSetting(),
                ],
              ),

              const SizedBox(height: AppSpacing.s32),

              SettingsSectionHeader(l10n?.calendar ?? 'CALENDAR'),
              const SettingsGroupCard(
                children: [
                  StartOfWeekSetting(),
                  AppDivider(),
                  PrimaryViewSetting(),
                  AppDivider(),
                  PrimaryCalendarSetting(),
                  AppDivider(),
                  SecondaryCalendarSetting(),
                  AppDivider(),
                  PanchangSchoolSetting(),
                  AppDivider(),
                  HinduMonthSystemSetting(),
                  AppDivider(),
                  HinduYearEraSetting(),
                  AppDivider(),
                  TithiDisplayModeSetting(),
                ],
              ),

              const SizedBox(height: AppSpacing.s32),

              const SettingsSectionHeader('HOME SCREEN'),
              SettingsGroupCard(
                children: [
                  SettingsActionTile(
                    icon: Icons.widgets_rounded,
                    title: 'Home screen cards',
                    subtitle: 'Show or hide Daily Wisdom and Countdowns',
                    onTap: () =>
                        AppRoutes.pushSharedX(context, const HomeCardsScreen()),
                  ),
                ],
              ),

              const SizedBox(height: AppSpacing.s32),

              SettingsSectionHeader(l10n?.accessibility ?? 'ACCESSIBILITY'),
              const AccessibilitySettings(),

              const SizedBox(height: AppSpacing.s32),

              SettingsSectionHeader(l10n?.dataStorage ?? 'DATA & STORAGE'),
              const SettingsGroupCard(
                children: [
                  ClearCacheSetting(),
                  AppDivider(),
                  ExportFestivalsSetting(),
                  AppDivider(),
                  ExportFestivalsCalendarSetting(),
                  AppDivider(),
                  ResetSettingsTile(),
                ],
              ),
              const SizedBox(height: AppSpacing.s32),

              SettingsSectionHeader(l10n?.aiAssistSection ?? 'AI ASSIST'),
              const SettingsGroupCard(children: [AiSection()]),
              const SizedBox(height: AppSpacing.s32),

              SettingsSectionHeader(l10n?.about ?? 'ABOUT'),
              const SettingsGroupCard(children: [CheckForUpdatesTile()]),
              const SizedBox(height: AppSpacing.s32),
              Center(
                child: Text(
                  l10n?.madeWithLove ?? 'Made with ❤️ for Sanatan Dharma',
                  style: context.textTheme.labelSmall?.copyWith(
                    color: context.hintInk,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildThemeSection(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) {
        final l10n = AppLocalizations.of(context);
        final currentOverride = ref.watch(themeOverrideProvider);
        // Four icon+label segments are tight on a phone. Keep the expressive
        // segment chrome but tighten its spacing so labels are not ellipsized.
        final m3e = M3ETheme.of(context);
        final compactSegments = m3e.copyWith(
          segmentedButtonTheme: m3e.segmentedButtonTheme.copyWith(
            segmentHorizontalPadding: AppSpacing.s4,
            iconLabelGap: AppSpacing.s2,
            iconSize: AppIconSize.small,
          ),
        );

        // RepaintBoundary for the same reason as SettingsGroupCard:
        // glass shadow must not repaint on every scroll frame.
        return RepaintBoundary(
          child: AppCard(
            child: Center(
              child: M3ETheme(
                data: compactSegments,
                child: M3ESegmentedButton<String?>(
                  segments: [
                    M3ESegment(
                      value: null,
                      label: l10n?.themeAuto ?? 'Auto',
                      icon: const Icon(Icons.brightness_auto_rounded),
                    ),
                    M3ESegment(
                      value: 'Shukla',
                      label: l10n?.themeShukla ?? 'Shukla',
                      icon: const Icon(Icons.light_mode_rounded),
                    ),
                    M3ESegment(
                      value: 'PureDark',
                      label: l10n?.themeDark ?? 'Dark',
                      icon: const Icon(Icons.contrast),
                    ),
                    M3ESegment(
                      value: 'Krishna',
                      label: l10n?.themePurple ?? 'Purple',
                      icon: const Icon(Icons.bubble_chart),
                    ),
                  ],
                  selected: {currentOverride},
                  // Keep each theme's own icon; the default check would replace
                  // it on the selected segment.
                  showSelectedIcon: false,
                  semanticLabel: l10n?.appearance ?? 'Appearance',
                  onSelectionChanged: (selection) {
                    AppHaptics.tap(ref);
                    ref
                        .read(themeOverrideProvider.notifier)
                        .setOverride(selection.first);
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
