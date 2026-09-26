import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import '../l10n/app_localizations.dart';
import '../models/festival.dart';
import '../providers/accessibility_provider.dart';
import '../providers/calendar_provider.dart';
import '../providers/festival_provider.dart';
import '../providers/panchang_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/event_detail_sheet.dart';
import '../widgets/festival_row_tile.dart';
import '../core/async/keep_alive.dart';
import '../core/format/date_only.dart';
import '../features/countdown/domain/target_resolution.dart';

export '../features/countdown/domain/target_resolution.dart'
    show DatedFestival, sortDatedFestivals;

/// All bundled festivals with this year's occurrence dates, ascending from
/// January — past festivals first, then the current/upcoming ones (the screen
/// auto-scrolls to those on open), undatable entries last.
///
/// Each festival reuses the vriddhi-aware
/// [PanchangService.findNextFestivalOccurrence] forward scan (the same source
/// the countdowns use), run in small parallel batches.
///
/// Perf: 5-minute timed `keepAlive` (same pattern as `monthlyPanchangProvider`)
/// so reopening the screen is instant but idle data is released instead of
/// pinning ~100 festivals (with multi-KB descriptions) for the whole session.
/// The watch on [todayDateProvider] still refreshes it at midnight, and a
/// location change invalidates via [resolvedCoordinatesProvider].
final allFestivalOccurrencesProvider =
    FutureProvider.autoDispose<List<DatedFestival>>((ref) async {
      ref.keepAliveFor(const Duration(minutes: 5));

      await ref.watch(panchangInitProvider.future);
      await ref.watch(festivalInitProvider.future);

      final festivals = ref.read(festivalProvider);
      if (festivals.isEmpty) return const [];
      final today = dateOnly(ref.watch(todayDateProvider));
      final yearStart = DateTime(today.year);
      final coords = ref.watch(resolvedCoordinatesProvider);
      final service = ref.read(panchangServiceProvider);
      final monthSystem = ref.watch(hinduMonthSystemProvider);

      try {
        // Shared resolver (features/countdown/domain): batched cached
        // scans — one bad rule resolves dateless instead of failing.
        return await resolveDatedFestivals(
          service: service,
          festivals: festivals,
          baseDate: yearStart,
          latitude: coords.latitude,
          longitude: coords.longitude,
          monthSystem: monthSystem,
        );
      } catch (e, st) {
        debugPrint('allFestivalOccurrences failed: $e\n$st');
        rethrow;
      }
    });

/// Full browsable list behind the home card's "View all N festivals" button:
/// every festival sorted by this year's occurrence date, January first, with
/// the date on each row. On open the list auto-scrolls to the current point
/// (first festival dated today or later). A live search field filters by
/// name/category/description. Tapping a row opens its [EventDetailSheet]
/// (dateless — the sheet renders festival info without a panchang day).
class AllFestivalsScreen extends ConsumerStatefulWidget {
  const AllFestivalsScreen({super.key});

  @override
  ConsumerState<AllFestivalsScreen> createState() => _AllFestivalsScreenState();
}

class _AllFestivalsScreenState extends ConsumerState<AllFestivalsScreen> {
  final _searchController = TextEditingController();
  final _itemScrollController = ItemScrollController();
  Timer? _searchDebounce;
  String _query = '';

  // Leak-free auto-scroll token: an int key, NOT the list itself, so the
  // previous occurrence list can be GC'd after a midnight/location refresh.
  int? _scrolledForKey;
  int _scrollVersion = 0;

  // Memoized filter: rebuilt only when the source list identity or the
  // applied query changes — not on every unrelated rebuild (theme, today).
  List<DatedFestival>? _filterSource;
  String _filterQuery = '';
  List<DatedFestival>? _filterResult;
  // Precomputed lowercase haystacks, aligned with _filterSource indices.
  // Built once per source list so typing never re-lowercases multi-KB
  // descriptions on every keystroke.
  List<String>? _filterHaystacks;

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    _filterSource = null;
    _filterResult = null;
    _filterHaystacks = null;
    super.dispose();
  }

  void _onSearchChanged(String value) {
    // Debounce: without this, every keystroke rebuilds the scaffold +
    // refilters ~100 items (each with a KB-long description) at 60wpm.
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 250), () {
      if (!mounted) return;
      setState(() => _query = value);
    });
  }

  void _clearSearch() {
    _searchDebounce?.cancel();
    _searchController.clear();
    setState(() => _query = '');
  }

  List<DatedFestival> _visible(List<DatedFestival> all) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return all;
    if (identical(all, _filterSource) &&
        q == _filterQuery &&
        _filterResult != null) {
      return _filterResult!;
    }
    if (!identical(all, _filterSource)) {
      _filterHaystacks = List<String>.generate(all.length, (i) {
        final f = all[i].festival;
        // Name + category carry the signal; description kept for parity
        // with the old filter but lowercased once, not per keystroke.
        return '${f.name}\n${f.category}\n${f.description}'.toLowerCase();
      }, growable: false);
      _filterSource = all;
    }
    final haystacks = _filterHaystacks!;
    final out = <DatedFestival>[];
    for (var i = 0; i < all.length; i++) {
      if (haystacks[i].contains(q)) out.add(all[i]);
    }
    _filterQuery = q;
    _filterResult = out;
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final occurrencesAsync = ref.watch(allFestivalOccurrencesProvider);
    final today = dateOnly(ref.watch(todayDateProvider));

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(l10n?.allFestivals ?? 'All Festivals'),
        backgroundColor: Colors.transparent,
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
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: Container(
                    decoration: AppTheme.glassmorphism(context: context),
                    child: TextField(
                      controller: _searchController,
                      onChanged: _onSearchChanged,
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                        hintText: l10n?.searchFestivalsHint ?? 'Search festivals',
                        prefixIcon: Icon(
                          Icons.search_rounded,
                          color: context.colors.onSurface.withValues(
                            alpha: 0.5,
                          ),
                        ),
                        suffixIcon: _query.isEmpty
                            ? null
                            : IconButton(
                                icon: const Icon(Icons.clear_rounded),
                                onPressed: _clearSearch,
                              ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: occurrencesAsync.when(
                    // Same stale-first pattern as the home card: a recompute
                    // (e.g. midnight rollover) keeps the old list up instead
                    // of flashing a skeleton.
                    skipLoadingOnReload: true,
                    data: (items) => _buildList(context, items, today),
                    loading: () => const _OccurrencesLoading(),
                    error: (error, _) => _OccurrencesError(
                      message: l10n?.couldNotLoadFestivals ?? 'Could not load festivals. Please try again.',
                      onRetry: () =>
                          ref.invalidate(allFestivalOccurrencesProvider),
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

  Widget _buildList(
    BuildContext context,
    List<DatedFestival> items,
    DateTime today,
  ) {
    final visible = _visible(items);
    // The list runs January → December, so on open (fresh data, no search)
    // it lands on the current point: the first festival dated today or
    // later, with earlier entries reachable by scrolling up.
    final queryEmpty = _query.trim().isEmpty;
    if (queryEmpty) {
      // Int key — never retains the old occurrence list (multi-KB
      // descriptions) after a refresh, unlike holding the list itself.
      final key = Object.hash(
        identityHashCode(items),
        today.millisecondsSinceEpoch,
      );
      if (_scrolledForKey != key) {
        _scrolledForKey = key;
        final target = visible.indexWhere(
          (e) => e.date != null && !e.date!.isBefore(today),
        );
        // Indexed jump lands exactly even when the target row was never
        // built (list laziness) — no measurement, no mistimed animation: the
        // screen simply opens at the current point, like a calendar opening
        // on today.
        if (target >= 0) {
          final version = ++_scrollVersion;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted ||
                version != _scrollVersion ||
                !_itemScrollController.isAttached) {
              return;
            }
            try {
              _itemScrollController.jumpTo(index: target, alignment: 0.02);
            } catch (e) {
              debugPrint('Festival list auto-scroll skipped: $e');
            }
          });
        }
      }
    }
    if (visible.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.event_busy_rounded,
              size: 48,
              color: context.colors.onSurface.withValues(alpha: 0.35),
            ),
            const SizedBox(height: 12),
            Text(
              AppLocalizations.of(context)?.noFestivalsFound ??
                  'No festivals found',
              style: TextStyle(
                color: context.colors.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      );
    }
    return ScrollablePositionedList.separated(
      itemScrollController: _itemScrollController,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
      itemCount: visible.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final item = visible[index];
        final daysAway = item.date?.difference(today).inDays;
        // Stable key keeps element diffing O(1) on filter changes;
        // RepaintBoundary confines each row's repaint during fast scrolls.
        return RepaintBoundary(
          child: FestivalRowTile(
            key: ValueKey(item.festival.id),
            festival: item.festival,
            date: item.date,
            daysAway: daysAway,
            onTap: () => _showDetails(context, item.festival),
          ),
        );
      },
    );
  }

  void _showDetails(BuildContext context, Festival festival) {
    if (ref.read(accessibilityProvider).hapticFeedback) {
      HapticFeedback.lightImpact();
    }
    showModalBottomSheet(
      context: context,
      sheetAnimationStyle: AppTheme.sheetAnimationStyleOf(context),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => EventDetailSheet(festival: festival),
    );
  }
}

class _OccurrencesLoading extends StatelessWidget {
  const _OccurrencesLoading();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
      itemCount: 6,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, _) => Container(
        height: 76,
        decoration: BoxDecoration(
          color: context.colors.onSurface.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }
}

class _OccurrencesError extends StatelessWidget {
  const _OccurrencesError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 48,
              color: context.colors.onSurface.withValues(alpha: 0.35),
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: context.colors.onSurface.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(AppLocalizations.of(context)?.retry ?? 'Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
