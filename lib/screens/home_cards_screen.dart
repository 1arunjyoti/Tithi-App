import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../l10n/app_localizations.dart';
import '../core/navigation/haptic_back_button.dart';
import '../theme/app_theme.dart';
import '../theme/app_metrics.dart';
import '../providers/accessibility_provider.dart';
import '../providers/home_cards_visibility_provider.dart';
import '../widgets/app_divider.dart';
import '../widgets/settings_widgets.dart';
import '../widgets/page_scaffold.dart';
import '../widgets/screen_body.dart';

/// Home cards management screen: show or hide the optional home-screen
/// cards (Daily Wisdom, Festival Countdowns). Reached from Settings; it is
/// the only place these cards are toggled.
///
/// First install shows everything (both providers default to visible), so
/// this screen only ever removes — and restores — cards. Hiding a card
/// skips its sliver entirely on home: no gap and no data fetch until it is
/// shown again.
class HomeCardsScreen extends ConsumerWidget {
  const HomeCardsScreen({super.key});

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
        title: const Text('Home Cards'),
        leading: const HapticBackButton(),
        body: ScreenBody(
          child: ListView(
            padding: EdgeInsets.only(
              top: AppSpacing.s16,
              bottom: AppSpacing.s16 + AppTheme.navigationBarInset(context),
            ),
            children: [
              const SettingsSectionHeader('HOME SCREEN'),
              Padding(
                padding: const EdgeInsets.only(
                  left: AppSpacing.s8,
                  right: AppSpacing.s8,
                  bottom: AppSpacing.s12,
                ),
                child: Text(
                  'Choose which cards appear on your home screen. '
                  'Hidden cards stop loading until you show them again.',
                  style: context.textTheme.bodySmall?.copyWith(
                    color: context.secondaryInk,
                  ),
                ),
              ),
              SettingsGroupCard(
                children: [
                  SettingsSwitchTile(
                    icon: Icons.auto_stories_rounded,
                    title: l10n?.dailyWisdom ?? 'Daily Wisdom',
                    subtitle: 'Verse of the day with translation',
                    value: ref.watch(dailyWisdomVisibleProvider),
                    onChanged: (v) async => ref
                        .read(dailyWisdomVisibleProvider.notifier)
                        .setVisible(v),
                  ),
                  const AppDivider(),
                  SettingsSwitchTile(
                    icon: Icons.hourglass_bottom_rounded,
                    title: l10n?.countdownHeading ?? 'Festival Countdowns',
                    subtitle: 'Upcoming festival countdowns',
                    value: ref.watch(festivalCountdownsVisibleProvider),
                    onChanged: (v) async => ref
                        .read(festivalCountdownsVisibleProvider.notifier)
                        .setVisible(v),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
