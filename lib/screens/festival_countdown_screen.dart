import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../core/format/festival_labels.dart';
import '../models/festival.dart';
import '../core/feedback/app_haptics.dart';
import '../features/countdown/providers/countdown_providers.dart';
import '../features/festival_search/widgets/countdown_search_delegate.dart';
import '../providers/festival_provider.dart';
import '../providers/home_widget_provider.dart';
import '../theme/app_theme.dart';
import '../theme/app_metrics.dart';
import '../theme/app_typography.dart';
import '../core/anim/press_scale.dart';
import '../core/anim/stagger_entrance.dart';
import '../core/navigation/haptic_back_button.dart';
import '../core/navigation/home_tab.dart';
import '../core/feedback/app_messages.dart';
import '../widgets/festival_countdown_card.dart';
import '../widgets/app_card.dart';
import '../widgets/app_drawer.dart';
import '../widgets/app_drawer_button.dart';
import '../widgets/home_widget_card.dart';
import '../widgets/page_scaffold.dart';
import '../widgets/screen_body.dart';
import '../widgets/skeleton.dart';
import '../widgets/state_views.dart';

class FestivalCountdownScreen extends ConsumerStatefulWidget {
  const FestivalCountdownScreen({
    super.key,
    this.bottomContentInset = 0,
    this.onSelectTab,
    this.onDrawerStateChanged,
  });

  /// Scroll padding that lets the last tile rest above a floating navigation
  /// bar. Zero when this screen is pushed as a full page.
  final double bottomContentInset;

  /// Non-null when this screen is one tab of `HomeShell`.
  ///
  /// The shell already keeps the drawer's other destinations mounted, so this
  /// screen hosts its own copy of `AppDrawer` and the app bar's hamburger
  /// opens it - the drawer must not be reachable only from the Today tab.
  /// Pushed full-page (null), the leading slot stays the back arrow.
  final ValueChanged<HomeTab>? onSelectTab;

  /// Reports this tab's drawer opening/closing, so the shell can retract the
  /// floating capsule while it is out (the drawer paints inside this Scaffold,
  /// below the shell's overlay).
  final ValueChanged<bool>? onDrawerStateChanged;

  @override
  ConsumerState<FestivalCountdownScreen> createState() =>
      _FestivalCountdownScreenState();
}

class _FestivalCountdownScreenState
    extends ConsumerState<FestivalCountdownScreen> {
  /// Shared by all three list variants below: only one is ever mounted at a
  /// time, so they can take turns attaching to it.
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // Keep widget in sync
    ref.watch(homeWidgetSyncProvider);
    final countdowns = ref.watch(allFestivalCountdownTargetsProvider);
    final preferences = ref.watch(festivalCountdownPreferencesProvider);
    final allFestivals = ref.watch(festivalProvider);

    return PageScaffold(
      drawer: widget.onSelectTab == null ? null : const AppDrawer(),
      onDrawerChanged: widget.onDrawerStateChanged,
      leading: widget.onSelectTab == null
          ? const HapticBackButton()
          : const AppDrawerButton(),
      title: Text(l10n?.festivalCountdowns ?? 'Festival Countdowns'),
      actions: [
        // Gated press haptic + scale live in PressScale.
        PressScale(
          child: IconButton(
            icon: const Icon(Icons.add_rounded),
            tooltip: l10n?.addCountdown ?? 'Add countdown',
            onPressed: () => _addCountdown(context, ref),
          ),
        ),
        const SizedBox(width: AppSpacing.s8),
      ],
      // skipLoadingOnReload: pin/unpin/delete rebuilds the targets
      // provider; without this the list is replaced by the loading
      // shimmer on every toggle (the full-screen "flash"). The
      // previous list stays put (and keeps its scroll offset) while
      // the reload resolves underneath.
      // Shared page frame: 12dp gutter and the 800 reading width, so the
      // countdown cards line up with the home cards.
      body: ScreenBody(
        child: countdowns.when(
          skipLoadingOnReload: true,
          data: (targets) {
            // IDs with no occurrence in the forward window (Kshaya-skip
            // years, invalid rules): previously they vanished silently.
            // Surface them as footer notes instead of dropping them.
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

            final undatedEntries = <({String id, String name})>[];
            for (final id in missingIds) {
              final festival = lookup(id);
              undatedEntries.add((
                id: id,
                name: festival == null
                    ? id
                    : festivalDisplayName(
                        festival: festival,
                        locale: l10n?.localeName ?? 'en',
                      ),
              ));
            }
            final hasMissing = undatedEntries.isNotEmpty;
            // Entries carry ids, not just names, so stuck countdowns
            // are dismissible.
            void removeEntry(String id) => _removeCountdown(context, ref, id);

            if (targets.isEmpty) {
              // All-undated is NOT empty: show the note(s), not the
              // "no countdowns yet" illustration.
              if (hasMissing) {
                return ListView(
                  controller: _scrollController,
                  padding: EdgeInsets.only(
                    top: AppSpacing.s16,
                    bottom:
                        AppSpacing.s16 +
                        widget.bottomContentInset +
                        AppTheme.navigationBarInset(context),
                  ),
                  children: [
                    const HomeWidgetCard(),
                    const SizedBox(height: AppTheme.cardGap),
                    if (undatedEntries.isNotEmpty)
                      _UndatedCountdowns(
                        entries: undatedEntries,
                        onRemove: removeEntry,
                      ),
                  ],
                );
              }
              return ListView(
                controller: _scrollController,
                padding: EdgeInsets.only(
                  top: AppSpacing.s16,
                  bottom:
                      AppSpacing.s16 +
                      widget.bottomContentInset +
                      AppTheme.navigationBarInset(context),
                ),
                children: const [
                  _EmptyCountdowns(),
                  SizedBox(height: AppSpacing.s20),
                  HomeWidgetCard(),
                ],
              );
            }

            final hasUndatedNote = undatedEntries.isNotEmpty;
            return ListView.separated(
              controller: _scrollController,
              padding: EdgeInsets.only(
                top: AppSpacing.s16,
                bottom:
                    AppSpacing.s32 +
                    widget.bottomContentInset +
                    AppTheme.navigationBarInset(context),
              ),
              itemBuilder: (context, index) {
                // Header widget card at index 0
                if (index == 0) {
                  return const HomeWidgetCard();
                }
                // Trailing footer for undated entries.
                if (hasUndatedNote && index == targets.length + 1) {
                  return _UndatedCountdowns(
                    entries: undatedEntries,
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
                      AppHaptics.tap(ref);
                      ref
                          .read(festivalCountdownPreferencesProvider.notifier)
                          .toggleHomePinned(target.id);
                    },
                    onRemove: () {
                      AppHaptics.tap(ref);
                      _removeCountdown(context, ref, target.id);
                    },
                  ),
                );
              },
              separatorBuilder: (_, _) =>
                  const SizedBox(height: AppTheme.cardGap),
              itemCount: targets.length + 1 + (hasUndatedNote ? 1 : 0),
            );
          },
          loading: () => const Padding(
            padding: EdgeInsets.all(AppSpacing.s16),
            child: _CountdownScreenLoading(),
          ),
          error: (error, _) {
            // Keep the exception in the log: the old copy printed
            // `error.toString()` straight into the screen.
            debugPrint('Countdown load failed: $error');
            return ErrorState(
              message:
                  AppLocalizations.of(context)?.couldNotLoadFestivals ??
                  'Could not load countdowns. Please try again.',
              onRetry: () =>
                  ref.invalidate(allFestivalCountdownTargetsProvider),
            );
          },
        ),
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
    final displayName = festivalDisplayName(
      festival: festival,
      locale: l10n?.localeName ?? 'en',
    );
    if (added) {
      showAppMessage(
        context,
        l10n?.countdownAddedForFestival(displayName) ??
            'Countdown added for $displayName',
        kind: AppMessageKind.success,
      );
    } else {
      showAppMessage(
        context,
        l10n?.festivalAlreadyInCountdowns(displayName) ??
            '$displayName is already in your countdowns',
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

    showAppMessage(context, l10n?.countdownRemoved ?? 'Countdown removed');
  }
}

class _EmptyCountdowns extends StatelessWidget {
  const _EmptyCountdowns();

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.event_busy_rounded,
      title:
          AppLocalizations.of(context)?.noCountdownsYet ?? 'No countdowns yet',
    );
  }
}

class _CountdownScreenLoading extends StatelessWidget {
  const _CountdownScreenLoading();

  @override
  Widget build(BuildContext context) {
    return const Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SkeletonBox(height: 108, radius: AppRadius.card),
        SizedBox(height: AppTheme.cardGap),
        SkeletonBox(height: 108, radius: AppRadius.card),
      ],
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
      message:
          l10n?.couldNotFindUpcomingOccurrence ??
          'Could not find upcoming occurrence within a year.',
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
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.s14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: AppIconSize.large, color: context.hintInk),
              const SizedBox(width: AppSpacing.s10),
              Expanded(
                child: Text(
                  message,
                  style: context.textTheme.bodySmall?.copyWith(
                    color: context.secondaryInk,
                    fontWeight: AppTypography.semibold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s6),
          for (final entry in entries)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.s4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      entry.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.textTheme.bodyMedium?.copyWith(
                        fontWeight: AppTypography.bold,
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
