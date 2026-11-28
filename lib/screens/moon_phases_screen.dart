import 'package:material_ui/material_ui.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/navigation/haptic_back_button.dart';
import '../features/moon/providers/moon_details_providers.dart';
import '../features/moon/providers/moon_providers.dart';
import '../features/moon/widgets/moon_countdown_card.dart';
import '../features/moon/widgets/moon_hero.dart';
import '../features/moon/widgets/moon_insight_cards.dart'
    show MoonDistanceCard, MoonEclipseCard;
import '../features/moon/widgets/moon_timings_card.dart';
import '../features/moon/widgets/moon_upcoming_tab.dart';
import '../features/moon/domain/full_moon_names.dart';
import '../l10n/app_localizations.dart';
import '../services/moon_phase_service.dart';
import '../theme/app_theme.dart';
import '../theme/app_metrics.dart';
import '../theme/app_typography.dart';
import '../widgets/page_scaffold.dart';
import '../widgets/state_views.dart';

/// Full-screen moon phases view: hero, lunar timings, distance, next eclipse,
/// countdowns and upcoming dates. Panels live in `features/moon/widgets` so
/// this file stays a thin coordinator.
class MoonPhasesScreen extends ConsumerStatefulWidget {
  const MoonPhasesScreen({super.key});

  @override
  ConsumerState<MoonPhasesScreen> createState() => _MoonPhasesScreenState();
}

class _MoonPhasesScreenState extends ConsumerState<MoonPhasesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final moonPhaseAsync = ref.watch(moonPhaseDataProvider);
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return PageScaffold(
      leading: const HapticBackButton(),
      title: Text(l10n.moonPhases),
      // No app-bar TabBar: the tabs live with the list they switch.
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: moonPhaseAsync.when(
            data: (data) => _buildContent(context, data, l10n, isDark),
            loading: () => const Center(child: M3EProgressIndicator.circular()),
            error: (error, _) {
              debugPrint('Moon phase data failed: $error');
              return ErrorState(
                message: l10n.errorLoadingData,
                onRetry: () => ref.invalidate(moonPhaseDataProvider),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    MoonPhaseData data,
    AppLocalizations l10n,
    bool isDark,
  ) {
    final selected = ref.watch(moonSelectedDateProvider);
    final purnimas = ref.watch(upcomingPurnimasProvider).valueOrNull ?? [];
    final nextPurnima = purnimas.isEmpty ? data.nextPurnima : purnimas.first;
    final fullMoonName = traditionalFullMoonName(nextPurnima.month, l10n);
    final isBlue = isBlueMoon(nextPurnima, purnimas);

    return SingleChildScrollView(
      padding: EdgeInsets.only(bottom: AppTheme.navigationBarInset(context)),
      child: Column(
        children: [
          // Room for the halo above the moon so it never meets the app-bar
          // edge with a hard cut.
          const SizedBox(height: AppSpacing.s32),
          MoonHero(isDark: isDark),
          const SizedBox(height: AppSpacing.s12),
          // The countdowns are the primary information; keep them beside the
          // hero and put the supplementary cards below.
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.pageGutter,
            ),
            child: Row(
              children: [
                Expanded(
                  child: MoonCountdownCard(
                    key: const ValueKey('moon-countdown-purnima'),
                    title: l10n.purnima,
                    subtitle: l10n.fullMoon,
                    targetDate: data.nextPurnima,
                    icon: Icons.circle,
                    color: AppTheme.purnimaIconColor(isDark),
                    isDark: isDark,
                    eventName: fullMoonName,
                    highlight: isBlue ? l10n.blueMoon : null,
                  ),
                ),
                const SizedBox(width: AppSpacing.s12),
                Expanded(
                  child: MoonCountdownCard(
                    key: const ValueKey('moon-countdown-amavasya'),
                    title: l10n.amavasya,
                    subtitle: l10n.newMoon,
                    targetDate: data.nextAmavasya,
                    icon: Icons.circle_outlined,
                    color: AppTheme.amavasyaIconColor(isDark),
                    isDark: isDark,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.s24),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.pageGutter,
            ),
            child: MoonTimingsCard(date: selected),
          ),
          const SizedBox(height: AppTheme.cardGap),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.pageGutter,
            ),
            child: MoonDistanceCard(date: selected),
          ),
          const SizedBox(height: AppTheme.cardGap),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: AppTheme.pageGutter),
            child: MoonEclipseCard(),
          ),
          const SizedBox(height: AppSpacing.s24),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.pageGutter,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l10n.upcomingMoonDates,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: AppTypography.bold,
                  ),
                ),
                const SizedBox(height: AppSpacing.s4),
                TabBar(
                  controller: _tabController,
                  dividerColor: Colors.transparent,
                  tabs: [Tab(text: l10n.purnima), Tab(text: l10n.amavasya)],
                  indicatorColor: Theme.of(context).colorScheme.primary,
                  labelColor: Theme.of(context).colorScheme.primary,
                  unselectedLabelColor: context.secondaryInk,
                ),
              ],
            ),
          ),
          SizedBox(
            height: 320,
            child: TabBarView(
              controller: _tabController,
              children: [
                MoonUpcomingTab(
                  provider: upcomingPurnimasProvider,
                  emptyMessage: l10n.noUpcomingDates,
                  isDark: isDark,
                ),
                MoonUpcomingTab(
                  provider: upcomingAmavasyasProvider,
                  emptyMessage: l10n.noUpcomingDates,
                  isDark: isDark,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
