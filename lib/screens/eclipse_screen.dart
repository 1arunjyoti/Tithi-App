import 'package:material_ui/material_ui.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/eclipse/providers/eclipse_providers.dart';
import '../features/eclipse/widgets/eclipse_list.dart';
import '../l10n/app_localizations.dart';
import '../core/navigation/haptic_back_button.dart';
import '../models/eclipse.dart';
import '../theme/app_theme.dart';
import '../widgets/page_scaffold.dart';
import '../widgets/state_views.dart';

/// Screen displaying upcoming eclipses.
///
/// Solar and lunar eclipses were two stacked sections on one long scroll, so
/// the lunar list sat below six solar cards and needed a scroll to even see.
/// They are now peers behind a tab bar (same pattern as the moon phases
/// screen): the app bar owns the switch, each tab is one type's list, and
/// neither section can push the other off-screen.
class EclipseScreen extends ConsumerStatefulWidget {
  const EclipseScreen({super.key});

  @override
  ConsumerState<EclipseScreen> createState() => _EclipseScreenState();
}

class _EclipseScreenState extends ConsumerState<EclipseScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

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
    final eclipsesAsync = ref.watch(upcomingEclipsesProvider);
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return PageScaffold(
      leading: const HapticBackButton(),
      title: Text(l10n.eclipses),
      bottom: TabBar(
        controller: _tabController,
        dividerColor: Colors.transparent,
        tabs: [
          Tab(text: l10n.solarEclipses),
          Tab(text: l10n.lunarEclipses),
        ],
        indicatorColor: theme.colorScheme.primary,
        labelColor: theme.colorScheme.primary,
        unselectedLabelColor: context.secondaryInk,
      ),
      body: eclipsesAsync.when(
        data: (eclipses) => TabBarView(
          controller: _tabController,
          children: [
            EclipseList(
              eclipses: eclipses
                  .where((e) => e.type.isSolar)
                  .toList(growable: false),
            ),
            EclipseList(
              eclipses: eclipses
                  .where((e) => e.type.isLunar)
                  .toList(growable: false),
            ),
          ],
        ),
        loading: () => const Center(child: M3EProgressIndicator.circular()),
        error: (error, _) {
          debugPrint('Eclipse list failed: $error');
          return ErrorState(
            message: l10n.errorLoadingData,
            onRetry: () => ref.invalidate(upcomingEclipsesProvider),
          );
        },
      ),
    );
  }
}
