import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../models/festival.dart';
import '../providers/accessibility_provider.dart';
import '../providers/festival_countdown_provider.dart';
import '../providers/festival_provider.dart';
import '../providers/home_widget_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/festival_countdown_card.dart';
import '../widgets/home_widget_card.dart';

class FestivalCountdownScreen extends ConsumerWidget {
  const FestivalCountdownScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    // Keep widget in sync
    ref.watch(homeWidgetSyncProvider);
    final countdowns = ref.watch(allFestivalCountdownTargetsProvider);
    final preferences = ref.watch(festivalCountdownPreferencesProvider);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(l10n?.festivalCountdowns ?? 'Festival Countdowns'),
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            tooltip: l10n?.addCountdown ?? 'Add countdown',
            onPressed: () => _addCountdown(context, ref),
          ),
          const SizedBox(width: 8),
        ],
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
            // skipLoadingOnReload: pin/unpin/delete rebuilds the targets
            // provider; without this the list is replaced by the loading
            // shimmer on every toggle (the full-screen "flash"). The
            // previous list stays put (and keeps its scroll offset) while
            // the reload resolves underneath.
            child: countdowns.when(
              skipLoadingOnReload: true,
              data: (targets) {
                if (targets.isEmpty) {
                  return ListView(
                    padding: const EdgeInsets.all(16),
                    children: const [
                      _EmptyCountdowns(),
                      SizedBox(height: 20),
                      HomeWidgetCard(),
                    ],
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                  itemBuilder: (context, index) {
                    // Header widget card at index 0
                    if (index == 0) {
                      return const HomeWidgetCard();
                    }
                    final target = targets[index - 1];
                    final isPinned = preferences.isPinnedToHome(target.id);
                    return FestivalCountdownTile(
                      target: target,
                      showActions: true,
                      isPinnedToHome: isPinned,
                      onToggleHome: () {
                        if (ref.read(accessibilityProvider).hapticFeedback) {
                          HapticFeedback.lightImpact();
                        }
                        ref
                            .read(
                              festivalCountdownPreferencesProvider.notifier,
                            )
                            .toggleHomePinned(target.id);
                      },
                      onRemove: () {
                        if (ref.read(accessibilityProvider).hapticFeedback) {
                          HapticFeedback.lightImpact();
                        }
                        _removeCountdown(context, ref, target.id);
                      },
                    );
                  },
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemCount: targets.length + 1,
                );
              },
              loading: () => const Padding(
                padding: EdgeInsets.all(16),
                child: _CountdownScreenLoading(),
              ),
              error: (error, _) => _CountdownError(message: error.toString()),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _addCountdown(BuildContext context, WidgetRef ref) async {
    final festival = await showSearch<Festival?>(
      context: context,
      delegate: CountdownFestivalSearchDelegate(ref: ref),
    );
    if (festival == null) return;

    final added = await ref
        .read(festivalCountdownPreferencesProvider.notifier)
        .addFestival(festival.id);
    if (!context.mounted) return;
    final l10n = AppLocalizations.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          added
              ? (l10n?.countdownAddedForFestival(festival.name) ??
                  'Countdown added for ${festival.name}')
              : (l10n?.festivalAlreadyInCountdowns(festival.name) ??
                  '${festival.name} is already in your countdowns'),
        ),
      ),
    );
  }

  Future<void> _removeCountdown(
    BuildContext context,
    WidgetRef ref,
    String festivalId,
  ) async {
    final l10n = AppLocalizations.of(context);
    await ref
        .read(festivalCountdownPreferencesProvider.notifier)
        .removeFestival(festivalId);
    if (!context.mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n?.countdownRemoved ?? 'Countdown removed')));
  }
}

class CountdownFestivalSearchDelegate extends SearchDelegate<Festival?> {
  CountdownFestivalSearchDelegate({required this.ref});

  final WidgetRef ref;

  @override
  String? get searchFieldLabel => AppLocalizations.of(ref.context)?.searchFestivalName ?? 'Search festival name';

  @override
  ThemeData appBarTheme(BuildContext context) {
    final theme = Theme.of(context);
    return theme.copyWith(
      appBarTheme: theme.appBarTheme.copyWith(
        backgroundColor: theme.colorScheme.surface,
        elevation: 0,
      ),
      inputDecorationTheme: const InputDecorationTheme(
        border: InputBorder.none,
        hintStyle: TextStyle(fontSize: 18),
      ),
    );
  }

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        IconButton(
          icon: const Icon(Icons.clear_rounded),
          onPressed: () => query = '',
        ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back_rounded),
      onPressed: () => close(context, null),
    );
  }

  @override
  Widget buildResults(BuildContext context) => _buildList(context);

  @override
  Widget buildSuggestions(BuildContext context) => _buildList(context);

  Widget _buildList(BuildContext context) {
    final festivals = ref.read(festivalProvider);
    final existingIds = ref
        .read(festivalCountdownPreferencesProvider)
        .countdownIds;
    final results = _searchFestivals(festivals, query, existingIds);

    if (query.trim().isEmpty) {
      return const _SearchPrompt();
    }

    if (results.isEmpty) {
      final l10n = AppLocalizations.of(context);
      return Center(child: Text(l10n?.noFestivalsFound ?? 'No festivals found'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: results.length,
      itemBuilder: (context, index) {
        final festival = results[index];
        return _FestivalSearchTile(
          festival: festival,
          onTap: () => close(context, festival),
        );
      },
    );
  }

  List<Festival> _searchFestivals(
    List<Festival> festivals,
    String query,
    List<String> existingIds,
  ) {
    final normalizedQuery = query.trim().toLowerCase();
    if (normalizedQuery.isEmpty) return const [];

    final existing = existingIds.toSet();
    final matches = festivals.where((festival) {
      if (existing.contains(festival.id)) return false;

      return festival.name.toLowerCase().contains(normalizedQuery) ||
          (festival.nameHindi?.toLowerCase().contains(normalizedQuery) ??
              false) ||
          (festival.nameRegional.nameBengali?.toLowerCase().contains(
                normalizedQuery,
              ) ??
              false) ||
          festival.category.toLowerCase().contains(normalizedQuery);
    }).toList();

    matches.sort((a, b) {
      final majorCompare = _isMajor(b).compareTo(_isMajor(a));
      if (majorCompare != 0) return majorCompare;
      return a.name.compareTo(b.name);
    });
    return matches;
  }

  int _isMajor(Festival festival) => festival.category == 'major' ? 1 : 0;
}

class _FestivalSearchTile extends StatelessWidget {
  const _FestivalSearchTile({required this.festival, required this.onTap});

  final Festival festival;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isMajor = festival.category == 'major';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: ListTile(
          onTap: onTap,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          tileColor: colors.surfaceContainerHighest.withValues(alpha: 0.3),
          leading: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: colors.primary.withValues(alpha: isMajor ? 0.18 : 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isMajor ? Icons.celebration_rounded : Icons.event_rounded,
              color: colors.primary,
            ),
          ),
          title: Text(
            festival.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: festival.nameHindi == null
              ? null
              : Text(
                  festival.nameHindi!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
          trailing: const Icon(Icons.add_circle_outline_rounded),
        ),
      ),
    );
  }
}

class _SearchPrompt extends StatelessWidget {
  const _SearchPrompt();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Icon(
        Icons.search_rounded,
        size: 64,
        color: context.colors.onSurface.withValues(alpha: 0.2),
      ),
    );
  }
}

class _EmptyCountdowns extends StatelessWidget {
  const _EmptyCountdowns();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.event_busy_rounded,
            size: 56,
            color: context.colors.onSurface.withValues(alpha: 0.28),
          ),
          const SizedBox(height: 12),
          Text(
            l10n?.noCountdownsYet ?? 'No countdowns yet',
            style: context.textTheme.titleMedium?.copyWith(
              color: context.colors.onSurface.withValues(alpha: 0.7),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _CountdownScreenLoading extends StatelessWidget {
  const _CountdownScreenLoading();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [_LoadingCard(), SizedBox(height: 10), _LoadingCard()],
    );
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 108,
      decoration: AppTheme.glassmorphism(context: context),
    );
  }
}

class _CountdownError extends StatelessWidget {
  const _CountdownError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(color: context.colors.error),
        ),
      ),
    );
  }
}
