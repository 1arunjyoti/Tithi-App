import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/eclipse/widgets/eclipse_list.dart';
import '../l10n/app_localizations.dart';
import '../core/navigation/haptic_back_button.dart';
import '../models/eclipse.dart';
import '../providers/eclipse_provider.dart';
import '../theme/app_theme.dart';

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

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: const HapticBackButton(),
        title: Text(l10n.eclipses),
        backgroundColor: Colors.transparent,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          dividerColor: Colors.transparent,
          tabs: [
            Tab(text: l10n.solarEclipses),
            Tab(text: l10n.lunarEclipses),
          ],
          indicatorColor: theme.colorScheme.primary,
          labelColor: theme.colorScheme.primary,
          unselectedLabelColor: theme.colorScheme.onSurface.withValues(
            alpha: 0.6,
          ),
        ),
      ),
      body: Stack(
        children: [
          // Background - isolated in its own RepaintBoundary
          Positioned.fill(
            child: RepaintBoundary(
              child: Container(
                decoration: AppTheme.backgroundDecoration(context),
              ),
            ),
          ),
          SafeArea(
            // The page background paints behind the gesture handle; the list
            // adds the system inset to its own bottom padding instead.
            bottom: false,
            child: eclipsesAsync.when(
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
              loading: () =>
                  const Center(child: CircularProgressIndicator.adaptive()),
              error: (e, _) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 48,
                      color: theme.colorScheme.error,
                    ),
                    const SizedBox(height: 16),
                    Text(l10n.errorLoadingData),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: () => ref.refresh(upcomingEclipsesProvider),
                      child: Text(l10n.retry),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
