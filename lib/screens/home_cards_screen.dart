import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../l10n/app_localizations.dart';
import '../core/anim/press_scale.dart';
import '../theme/app_theme.dart';
import '../providers/accessibility_provider.dart';
import '../providers/home_cards_visibility_provider.dart';
import '../widgets/settings_widgets.dart';

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
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          title: const Text('Home Cards'),
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: PressScale(
            child: IconButton(
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
        ),
        body: Stack(
          children: [
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
                      const SettingsSectionHeader('HOME SCREEN'),
                      Padding(
                        padding: const EdgeInsets.only(
                          left: 8,
                          right: 8,
                          bottom: 12,
                        ),
                        child: Text(
                          'Choose which cards appear on your home screen. '
                          'Hidden cards stop loading until you show them again.',
                          style: context.textTheme.bodySmall?.copyWith(
                            color: context.colors.onSurface.withValues(
                              alpha: 0.6,
                            ),
                          ),
                        ),
                      ),
                      SettingsGroupCard(
                        children: [
                          SettingsSwitchTile(
                            icon: Icons.auto_stories_rounded,
                            title:
                                l10n?.dailyWisdom ?? 'Daily Wisdom',
                            subtitle: 'Verse of the day with translation',
                            value: ref.watch(dailyWisdomVisibleProvider),
                            onChanged: (v) async => ref
                                .read(dailyWisdomVisibleProvider.notifier)
                                .setVisible(v),
                          ),
                          const SettingsDivider(),
                          SettingsSwitchTile(
                            icon: Icons.hourglass_bottom_rounded,
                            title:
                                l10n?.countdownHeading ??
                                'Festival Countdowns',
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
            ),
          ],
        ),
      ),
    );
  }
}
