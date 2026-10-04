import 'package:flutter/foundation.dart' show kIsWeb;
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
import '../core/anim/press_scale.dart';
import '../core/anim/stagger_entrance.dart';
import '../core/navigation/haptic_back_button.dart';
import '../core/feedback/app_messages.dart';
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
    final allFestivals = ref.watch(festivalProvider);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: const HapticBackButton(),
        title: Text(l10n?.festivalCountdowns ?? 'Festival Countdowns'),
        backgroundColor: Colors.transparent,
        actions: [
          // Gated press haptic + scale live in PressScale.
          PressScale(
            child: IconButton(
              icon: const Icon(Icons.add_rounded),
              tooltip: l10n?.addCountdown ?? 'Add countdown',
              onPressed: () => _addCountdown(context, ref),
            ),
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
                // IDs with no occurrence in the forward window (Kshaya-skip
                // years, invalid rules): previously they vanished silently.
                // Surface them as footer notes instead of dropping them.
                // On web, nakshatra-observed festivals can never resolve (no
                // ephemeris) — label those distinctly instead of implying
                // the date is merely far away.
                final targetIds = targets.map((t) => t.id).toSet();
                final missingIds = preferences.countdownIds
                    .where((id) => !targetIds.contains(id))
                    .toList();
                Festival? lookup(String id) {
                  for (final f in allFestivals) {
                    if (f.id == id) return f;
                  }
                  return null;
                }

                final webUnsupportedEntries = <({String id, String name})>[];
                final undatedEntries = <({String id, String name})>[];
                for (final id in missingIds) {
                  final festival = lookup(id);
                  if (kIsWeb &&
                      festival?.nakshatraCondition != null) {
                    webUnsupportedEntries.add((id: id, name: festival!.name));
                  } else {
                    undatedEntries.add((id: id, name: festival?.name ?? id));
                  }
                }
                final hasMissing = undatedEntries.isNotEmpty ||
                    webUnsupportedEntries.isNotEmpty;
                // Removal shared by both footers (entries carry ids, not just
                // names, so stuck countdowns are dismissible).
                void removeEntry(String id) =>
                    _removeCountdown(context, ref, id);

                if (targets.isEmpty) {
                  // All-undated is NOT empty: show the note(s), not the
                  // "no countdowns yet" illustration.
                  if (hasMissing) {
                    return ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        const HomeWidgetCard(),
                        const SizedBox(height: 10),
                        if (undatedEntries.isNotEmpty)
                          _UndatedCountdowns(
                            entries: undatedEntries,
                            onRemove: removeEntry,
                          ),
                        if (webUnsupportedEntries.isNotEmpty) ...[
                          if (undatedEntries.isNotEmpty)
                            const SizedBox(height: 10),
                          _WebUnsupportedCountdowns(
                            entries: webUnsupportedEntries,
                            onRemove: removeEntry,
                          ),
                        ],
                      ],
                    );
                  }
                  return ListView(
                    padding: const EdgeInsets.all(16),
                    children: const [
                      _EmptyCountdowns(),
                      SizedBox(height: 20),
                      HomeWidgetCard(),
                    ],
                  );
                }

                final hasUndatedNote = undatedEntries.isNotEmpty;
                final hasWebNote = webUnsupportedEntries.isNotEmpty;
                final footerCount =
                    (hasUndatedNote ? 1 : 0) + (hasWebNote ? 1 : 0);
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                  itemBuilder: (context, index) {
                    // Header widget card at index 0
                    if (index == 0) {
                      return const HomeWidgetCard();
                    }
                    // Trailing footers: undated first, web-limitation last.
                    if (hasUndatedNote && index == targets.length + 1) {
                      return _UndatedCountdowns(
                        entries: undatedEntries,
                        onRemove: removeEntry,
                      );
                    }
                    if (hasWebNote &&
                        index == targets.length + footerCount) {
                      return _WebUnsupportedCountdowns(
                        entries: webUnsupportedEntries,
                        onRemove: removeEntry,
                      );
                    }
                    final target = targets[index - 1];
                    final isPinned = preferences.isPinnedToHome(target.id);
                    // Header (index 0) stays static; tiles stagger once on
                    // mount. Pin/remove rebuilds reuse positions instantly.
                    return StaggerEntrance(
                      index: index - 1,
                      child: FestivalCountdownTile(
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
                      ),
                    );
                  },
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemCount: targets.length + 1 + footerCount,
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
    if (added) {
      showAppMessage(
        context,
        l10n?.countdownAddedForFestival(festival.name) ??
            'Countdown added for ${festival.name}',
        kind: AppMessageKind.success,
      );
    } else {
      showAppMessage(
        context,
        l10n?.festivalAlreadyInCountdowns(festival.name) ??
            '${festival.name} is already in your countdowns',
      );
    }
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

    showAppMessage(
      context,
      l10n?.countdownRemoved ?? 'Countdown removed',
    );
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
        PressScale(
          child: IconButton(
            icon: const Icon(Icons.clear_rounded),
            onPressed: () => query = '',
          ),
        ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return PressScale(
      child: IconButton(
        icon: const Icon(Icons.arrow_back_rounded),
        onPressed: () => close(context, null),
      ),
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
        // Stateless-safe gated haptic + scale.
        child: PressScale(
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

/// Footer note for countdown IDs with no occurrence in the forward window
/// (Kshaya-skip years, invalid rules). Previously these vanished silently;
/// now the user sees which countdowns are affected instead of wondering
/// where they went. Every entry carries a remove button — without one,
/// unresolvable countdowns would be stuck forever (tiles have delete
/// actions; these rows would otherwise have none).
class _UndatedCountdowns extends StatelessWidget {
  const _UndatedCountdowns({required this.entries, required this.onRemove});

  final List<({String id, String name})> entries;
  final void Function(String id) onRemove;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return _UnresolvableCard(
      icon: Icons.event_busy_rounded,
      message: l10n?.couldNotFindUpcomingOccurrence ??
          'Could not find upcoming occurrence within a year.',
      entries: entries,
      onRemove: onRemove,
      removeTooltip: l10n?.removeCountdown ?? 'Remove countdown',
    );
  }
}

/// Footer note for nakshatra-observed festivals on web: the web fallback has
/// no ephemeris, so these can never resolve there (not merely "far away").
class _WebUnsupportedCountdowns extends StatelessWidget {
  const _WebUnsupportedCountdowns({
    required this.entries,
    required this.onRemove,
  });

  final List<({String id, String name})> entries;
  final void Function(String id) onRemove;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return _UnresolvableCard(
      icon: Icons.cloud_off_rounded,
      message: 'Needs precise moon data, unavailable on web',
      entries: entries,
      onRemove: onRemove,
      removeTooltip: l10n?.removeCountdown ?? 'Remove countdown',
    );
  }
}

/// Shared card for unresolvable countdown entries: an explanatory line plus
/// one dismissible row per entry.
class _UnresolvableCard extends StatelessWidget {
  const _UnresolvableCard({
    required this.icon,
    required this.message,
    required this.entries,
    required this.onRemove,
    required this.removeTooltip,
  });

  final IconData icon;
  final String message;
  final List<({String id, String name})> entries;
  final void Function(String id) onRemove;
  final String removeTooltip;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: AppTheme.glassmorphism(context: context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                icon,
                size: 22,
                color: context.colors.onSurface.withValues(alpha: 0.5),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: context.textTheme.bodySmall?.copyWith(
                    color: context.colors.onSurface.withValues(alpha: 0.65),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          for (final entry in entries)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      entry.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  PressScale(
                    child: IconButton(
                      onPressed: () => onRemove(entry.id),
                      icon: const Icon(Icons.delete_outline_rounded),
                      tooltip: removeTooltip,
                      color: context.colors.error,
                      style: IconButton.styleFrom(
                        minimumSize: const Size(40, 40),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
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
}
