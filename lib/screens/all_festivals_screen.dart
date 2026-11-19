import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import '../l10n/app_localizations.dart';
import '../models/festival.dart';
import '../models/festival_filter.dart';
import '../core/feedback/app_haptics.dart';
import '../providers/calendar_provider.dart';
import '../providers/festival_provider.dart';
import '../providers/panchang_provider.dart';
import '../theme/app_theme.dart';
import '../theme/app_metrics.dart';
import '../theme/app_motion.dart';
import '../theme/app_typography.dart';
import '../features/sheets/sheet_launcher.dart';
import '../widgets/festival_filter_chip.dart';
import '../widgets/festival_filter_sheet.dart';
import '../widgets/festival_row_tile.dart';
import '../widgets/major_festival_card.dart';
import '../widgets/app_drawer_button.dart';
import '../widgets/app_drawer.dart';
import '../widgets/app_card.dart';
import '../widgets/page_scaffold.dart';
import '../widgets/screen_body.dart';
import '../widgets/skeleton.dart';
import '../widgets/state_views.dart';
import '../core/anim/stagger_entrance.dart';
import '../core/navigation/haptic_back_button.dart';
import '../core/navigation/home_tab.dart';
import '../core/async/keep_alive.dart';
import '../core/format/date_only.dart';
import '../features/countdown/data/festival_year_snapshot.dart';
import '../features/countdown/domain/target_resolution.dart';

export '../features/countdown/domain/target_resolution.dart'
    show DatedFestival, sortDatedFestivals;
export '../models/festival_filter.dart'
    show
        FestivalCategoryFilter,
        FestivalFilterSelection,
        festivalMatchesCategoryFilter,
        festivalMatchesFilters,
        festivalMatchesRegionFilter;

/// Years the festival list can resolve for. Matches the calendar's Gregorian
/// year picker range (calendar_widget.dart), which is the bundled ephemeris
/// window; the year selector's arrows clamp to it.
const int kFestivalFirstYear = 1976;
const int kFestivalLastYear = 2076;

/// All bundled festivals with [year]'s occurrence dates, ascending from
/// January — past festivals first, then the upcoming ones (for the current
/// year the screen auto-scrolls to those on open), undatable entries last.
/// Recurring entries (Ekadashi, Purnima, Amavasya) appear once per
/// occurrence, not once per catalog entry, so the yearly list shows all 24
/// Ekadashis.
///
/// The year is the family parameter: the screen's year selector picks it and
/// each year resolves (and caches) independently, so 2025, 2026 and 2027
/// show their own dates, not today's year.
///
/// Each festival reuses the vriddhi-aware
/// [PanchangService.findNextFestivalOccurrence] forward scan (the same source
/// the countdowns use), run in small parallel batches. Scanning forward from
/// Jan 1 of [year] is correct for past years too — the first match on/after
/// that date lands inside the year.
///
/// Perf: the completed list is persisted as one Hive record per
/// year/location/school/catalog generation ([readFestivalYearSnapshot]), so a
/// revisit (or a launch after process death) paints from disk instead of
/// rebuilding ~150 scans. Resolution always runs from Jan 1 through Dec 31,
/// so a stored list cannot go stale inside the year; a moved place,
/// school/engine bump or catalog edit changes the key and misses cleanly.
///
/// A 5-minute timed `keepAlive` (same pattern as `monthlyPanchangProvider`)
/// still releases the in-memory list when the screen has been closed for a
/// while; reopening then costs one box read. The watch on [todayDateProvider]
/// refreshes the lists at midnight (the key only changes on Jan 1), and a
/// location change invalidates via [resolvedCoordinatesProvider].
final allFestivalOccurrencesProvider = FutureProvider.autoDispose
    .family<List<DatedFestival>, int>((ref, year) async {
      ref.keepAliveFor(const Duration(minutes: 5));

      await ref.watch(panchangInitProvider.future);
      await ref.watch(festivalInitProvider.future);

      final festivals = ref.read(festivalProvider);
      if (festivals.isEmpty) return const [];
      // Watch (not read) so a midnight rollover re-resolves: the year key
      // only changes on Jan 1, when the new year's list must first appear.
      ref.watch(todayDateProvider);
      final yearStart = DateTime(year);
      final coords = ref.watch(resolvedCoordinatesProvider);
      // Read the service first: building it resolves the persisted school,
      // which is part of the snapshot key. Reading it after the snapshot
      // could look up the wrong generation on a cold start.
      final service = ref.read(panchangServiceProvider);
      final catalogVersion = ref
          .read(festivalRepositoryProvider)
          .catalogVersion;

      final snapshot = await readFestivalYearSnapshot(
        yearStart: yearStart,
        festivals: festivals,
        latitude: coords.latitude,
        longitude: coords.longitude,
        catalogVersion: catalogVersion,
      );
      if (snapshot != null) return snapshot;

      try {
        // Shared resolver (features/countdown/domain): batched cached
        // scans — one bad rule resolves dateless instead of failing.
        // Recurring vrats (Ekadashi, Purnima, Amavasya) expand to every
        // occurrence through Dec 31, so the yearly list shows all of them.
        // No month-system watch: resolution is Amanta-fixed, so toggling
        // Amanta↔Purnimant no longer re-scans (rows show dates, not masas).
        final resolved = await resolveDatedFestivals(
          service: service,
          festivals: festivals,
          baseDate: yearStart,
          through: DateTime(year, 12, 31),
          latitude: coords.latitude,
          longitude: coords.longitude,
        );
        await writeFestivalYearSnapshot(
          yearStart: yearStart,
          items: resolved,
          latitude: coords.latitude,
          longitude: coords.longitude,
          catalogVersion: catalogVersion,
        );
        return resolved;
      } catch (e, st) {
        debugPrint('allFestivalOccurrences failed: $e\n$st');
        rethrow;
      }
    });

/// Full browsable list behind the home card's "View all N festivals" button:
/// every festival sorted by the selected year's occurrence date, January
/// first, with the date on each row. A year selector (chevron arrows plus a
/// tappable year that opens a picker) loads any year's list, not just the
/// current one — each year resolves independently through
/// [allFestivalOccurrencesProvider]. On open the current year's list
/// auto-scrolls to the current point (first festival dated today or later);
/// other years open at January. A live search field filters by
/// name/category/description, a chip strip under it applies the category
/// (All / Major / Vrat / Recurring / Featured) in one tap, and the app-bar
/// filter button opens a sheet with the same categories plus region (all
/// regions or one zone) narrowing; search and filters compose, and a dot on
/// the button marks an active filter. Tapping a row opens the festival detail
/// sheet with the row's occurrence date, so the sheet can backfill that day's
/// panchang (timings, puja/paran windows).
class AllFestivalsScreen extends ConsumerStatefulWidget {
  const AllFestivalsScreen({
    super.key,
    this.bottomContentInset = 0,
    this.onSelectTab,
    this.onDrawerStateChanged,
  });

  /// Scroll padding that lets the last row rest above a floating navigation
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

  /// Key of the inline category strip under the search field, so tests (and
  /// future tooltips) can address it without matching the same chip labels the
  /// filter sheet renders.
  static const categoryChipsKey = ValueKey('all-festivals-category-chips');

  /// Key of the app-bar year stepper, so tests can reach its arrows without
  /// matching unrelated chevrons elsewhere on the screen.
  static const yearSelectorKey = ValueKey('all-festivals-year-selector');

  @override
  ConsumerState<AllFestivalsScreen> createState() => _AllFestivalsScreenState();
}

class _AllFestivalsScreenState extends ConsumerState<AllFestivalsScreen> {
  final _searchController = TextEditingController();
  final _itemScrollController = ItemScrollController();
  Timer? _searchDebounce;
  String _query = '';
  FestivalFilterSelection _filters = const FestivalFilterSelection();

  /// The year whose list is shown. Defaults to today's year; the selector
  /// row changes it and every year resolves independently (each family
  /// instance keeps its own snapshot-backed list).
  late int _selectedYear = dateOnly(ref.read(todayDateProvider)).year;

  // Leak-free auto-scroll token: an int key, NOT the list itself, so the
  // previous occurrence list can be GC'd after a midnight/location refresh.
  int? _scrolledForKey;
  int _scrollVersion = 0;

  // Memoized filter: rebuilt only when the source list identity, the
  // applied query, or the filter selection changes — not on every unrelated
  // rebuild (theme, today).
  List<DatedFestival>? _filterSource;
  String _filterQuery = '';
  FestivalFilterSelection _filterSelection = const FestivalFilterSelection();
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
    // refilters ~150 rows (each with a KB-long description) at 60wpm.
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

  Future<void> _openFilters() async {
    final result = await showFestivalFilterSheet(context, initial: _filters);
    if (!mounted || result == null || result == _filters) return;
    setState(() => _filters = result);
  }

  /// Applies a category from the inline strip, keeping the sheet's region
  /// narrowing (the two dimensions compose, so a chip must not silently clear
  /// the region the user picked).
  void _selectCategory(FestivalCategoryFilter category) {
    if (category == _filters.category) return;
    AppHaptics.tap(ref);
    setState(() => _filters = _filters.copyWith(category: category));
  }

  /// Steps the year selector by [delta], clamped to the ephemeris window.
  /// Out-of-range arrows are disabled, so the clamp is only a guard.
  void _shiftYear(int delta) {
    final next = (_selectedYear + delta).clamp(
      kFestivalFirstYear,
      kFestivalLastYear,
    );
    if (next == _selectedYear) return;
    AppHaptics.tap(ref);
    setState(() => _selectedYear = next);
  }

  /// Opens the same Material year picker the calendar header uses
  /// (calendar_widget.dart's Gregorian picker), bounded to the ephemeris
  /// window, and applies the picked year.
  Future<void> _pickYear() async {
    AppHaptics.tap(ref);
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(_selectedYear),
      firstDate: DateTime(kFestivalFirstYear),
      lastDate: DateTime(kFestivalLastYear, 12, 31),
      initialDatePickerMode: DatePickerMode.year,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: context.colors.primary,
              onPrimary: Theme.of(context).colorScheme.onPrimary,
              surface: Theme.of(context).scaffoldBackgroundColor,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked == null || picked.year == _selectedYear) return;
    if (!mounted) return;
    AppHaptics.tap(ref);
    setState(() => _selectedYear = picked.year);
  }

  List<DatedFestival> _visible(List<DatedFestival> all) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty && !_filters.isActive) return all;
    if (identical(all, _filterSource) &&
        q == _filterQuery &&
        _filters == _filterSelection &&
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
      final festival = all[i].festival;
      if (!festivalMatchesFilters(festival, _filters)) continue;
      if (q.isNotEmpty && !haystacks[i].contains(q)) continue;
      out.add(all[i]);
    }
    _filterQuery = q;
    _filterSelection = _filters;
    _filterResult = out;
    return out;
  }

  /// Re-tapping the already-selected Festivals destination returns the list to
  /// its first row.
  ///
  /// The offset belongs to the [ItemScrollController]: `ScrollablePositionedList`
  /// builds its scrollable with `primary: true` and never exposes a
  /// `ScrollController`, so this is the only way to move it.
  void _revealTop() {
    if (!_itemScrollController.isAttached) return;
    _itemScrollController.scrollTo(
      index: 0,
      duration: AppMotion.of(context, AppMotion.scroll),
      curve: AppMotion.standardCurve,
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<int>(tabRevealProvider(HomeTab.festivals), (previous, next) {
      if (previous == next) return;
      _revealTop();
    });
    final l10n = AppLocalizations.of(context);
    final occurrencesAsync = ref.watch(
      allFestivalOccurrencesProvider(_selectedYear),
    );
    final today = dateOnly(ref.watch(todayDateProvider));

    return PageScaffold(
      drawer: widget.onSelectTab == null ? null : const AppDrawer(),
      onDrawerChanged: widget.onDrawerStateChanged,
      leading: widget.onSelectTab == null
          ? const HapticBackButton()
          : const AppDrawerButton(),
      title: Text(l10n?.allFestivals ?? 'All Festivals'),
      // The year stepper widens the actions strip; a themed centered title
      // would then sit in the leftover middle space and look off-center.
      centerTitle: false,
      actions: [
        _buildYearStepper(context),
        IconButton(
          tooltip: l10n?.festivalFilterTitle ?? 'Filter festivals',
          onPressed: _openFilters,
          icon: Badge(
            isLabelVisible: _filters.isActive,
            smallSize: 8,
            backgroundColor: context.colors.primary,
            child: Icon(
              Icons.tune_rounded,
              color: _filters.isActive ? context.colors.primary : null,
            ),
          ),
        ),
      ],
      // Shared page frame: 12dp gutter and the 800 reading width. The
      // search field, chip strip and list all sit inside it, so their
      // own horizontal padding is gone and the cards line up with the
      // home screen's.
      body: ScreenBody(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.only(
                top: AppSpacing.s8,
                bottom: AppSpacing.s12,
              ),
              child: AppCard(
                padding: EdgeInsets.zero,
                child: TextField(
                  controller: _searchController,
                  onChanged: _onSearchChanged,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: l10n?.searchFestivalsHint ?? 'Search festivals',
                    prefixIcon: Icon(
                      Icons.search_rounded,
                      color: context.hintInk,
                    ),
                    suffixIcon: _query.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.clear_rounded),
                            tooltip: l10n?.clearSearch ?? 'Clear search',
                            onPressed: _clearSearch,
                          ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.s16,
                      vertical: AppSpacing.s14,
                    ),
                  ),
                ),
              ),
            ),
            _buildCategoryChips(context),
            Expanded(
              child: occurrencesAsync.when(
                // Same stale-first pattern as the home card: a recompute
                // (e.g. midnight rollover) keeps the old list up instead
                // of flashing a skeleton.
                skipLoadingOnReload: true,
                data: (items) =>
                    _buildList(context, items, today, _selectedYear),
                loading: () =>
                    _OccurrencesLoading(bottomInset: widget.bottomContentInset),
                error: (error, _) => _OccurrencesError(
                  message:
                      l10n?.couldNotLoadFestivals ??
                      'Could not load festivals. Please try again.',
                  onRetry: () => ref.invalidate(
                    allFestivalOccurrencesProvider(_selectedYear),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// App-bar year stepper: a back arrow, the tappable year (opens the
  /// Material year picker) and a forward arrow. It lives in the actions
  /// strip instead of the body so the list keeps its full height, while
  /// year stepping stays one tap away and always visible. Arrows disable
  /// at the ephemeris window's edges, so a tap never resolves a year the
  /// engine cannot compute.
  Widget _buildYearStepper(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final canGoBack = _selectedYear > kFestivalFirstYear;
    final canGoForward = _selectedYear < kFestivalLastYear;
    return Row(
      key: AllFestivalsScreen.yearSelectorKey,
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: l10n?.previousYear ?? 'Previous year',
          onPressed: canGoBack ? () => _shiftYear(-1) : null,
          icon: const Icon(Icons.chevron_left_rounded, size: 20),
          visualDensity: VisualDensity.compact,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s2),
        ),
        Tooltip(
          message: l10n?.selectYear ?? 'Select year',
          child: InkWell(
            onTap: _pickYear,
            borderRadius: BorderRadius.circular(AppRadius.chip),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.s4,
                vertical: AppSpacing.s8,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$_selectedYear',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: AppTypography.semibold,
                    ),
                  ),
                  const Icon(Icons.expand_more_rounded, size: 16),
                ],
              ),
            ),
          ),
        ),
        IconButton(
          tooltip: l10n?.nextYear ?? 'Next year',
          onPressed: canGoForward ? () => _shiftYear(1) : null,
          icon: const Icon(Icons.chevron_right_rounded, size: 20),
          visualDensity: VisualDensity.compact,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s2),
        ),
      ],
    );
  }

  /// The filter sheet's category dimension, surfaced as a chip strip under the
  /// search field so the common narrowing (and Featured) takes one tap.
  ///
  /// Both entry points write the same [_filters] state: a chip tap updates the
  /// category through `copyWith`, and the sheet opens already showing that
  /// choice. The strip scrolls horizontally instead of wrapping, so the list
  /// below keeps its height on narrow screens and at large text scales.
  Widget _buildCategoryChips(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SingleChildScrollView(
      key: AllFestivalsScreen.categoryChipsKey,
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.only(bottom: AppSpacing.s12),
      child: Row(
        children: [
          for (final filter in FestivalCategoryFilter.values)
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.s8),
              child: FestivalFilterChip(
                label: festivalCategoryFilterLabel(l10n, filter),
                selected: _filters.category == filter,
                onTap: () => _selectCategory(filter),
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
    int selectedYear,
  ) {
    final visible = _visible(items);
    // The list runs January → December, so on open (fresh data, no search)
    // the current year's list lands on the current point: the first festival
    // dated today or later, with earlier entries reachable by scrolling up.
    // Another year's list opens at its January instead — "today or later"
    // is meaningless for a past year and trivially row 0 for a future one.
    final queryEmpty = _query.trim().isEmpty;
    final isCurrentYear = selectedYear == today.year;
    if (queryEmpty) {
      // Int key — never retains the old occurrence list (multi-KB
      // descriptions) after a refresh, unlike holding the list itself.
      final key = Object.hash(
        identityHashCode(items),
        today.millisecondsSinceEpoch,
        selectedYear,
        _filters.category.index,
        _filters.region.index,
      );
      if (_scrolledForKey != key) {
        _scrolledForKey = key;
        final target = !isCurrentYear
            ? (visible.isEmpty ? -1 : 0)
            : visible.indexWhere(
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
      return EmptyState(
        icon: Icons.event_busy_rounded,
        title:
            AppLocalizations.of(context)?.noFestivalsFound ??
            'No festivals found',
      );
    }
    return ScrollablePositionedList.separated(
      itemScrollController: _itemScrollController,
      // [ScreenBody] supplies the side gutter; only the vertical rhythm and
      // the system/nav insets are left to the list. [AppTheme.cardGap] is the
      // same 16dp the home cards use between them.
      padding: EdgeInsets.only(
        bottom:
            32 +
            widget.bottomContentInset +
            AppTheme.navigationBarInset(context),
      ),
      itemCount: visible.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppTheme.cardGap),
      itemBuilder: (context, index) {
        final item = visible[index];
        // Calendar-day diff (DST-safe); see calendarDaysBetween docs.
        final daysAway = item.date == null
            ? null
            : calendarDaysBetween(today, item.date!);
        // Stable key keeps element diffing O(1) on filter changes;
        // RepaintBoundary confines each row's repaint during fast scrolls.
        // StaggerEntrance is position-matched (no key): filter reorder
        // reuses states and shows instantly; only fresh mounts animate.
        // Transform-only, so the post-frame jumpTo target never shifts.
        //
        // Featured is a curated flag in the catalog, not a category and not a
        // date heuristic. 96 of the 110 records are `category: 'major'`, so
        // promoting the category made the list a wall of identical tall cards;
        // featuring whichever major came next made importance depend on the
        // calendar (a minor fast a few weeks before Diwali took the card) and
        // split a celebration that runs for days. `"featured": true` lives on
        // ~20 records in assets/festivals.json, so a whole celebration run can
        // carry the card and a quiet fortnight stays rows.
        final isFeatured = item.festival.featured;
        final key = ValueKey(
          '${item.festival.id}@'
          '${item.date?.toIso8601String() ?? 'undated'}',
        );
        final child = isFeatured
            ? MajorFestivalCard(
                key: key,
                item: item,
                onTap: () => _showDetails(context, item.festival, item.date),
              )
            : FestivalRowTile(
                key: key,
                festival: item.festival,
                date: item.date,
                daysAway: daysAway,
                onTap: () => _showDetails(context, item.festival, item.date),
              );
        return StaggerEntrance(
          index: index,
          maxStaggered: 10,
          child: RepaintBoundary(child: child),
        );
      },
    );
  }

  void _showDetails(BuildContext context, Festival festival, DateTime? date) {
    // Haptics belong to FestivalRowTile, which already fires them before
    // invoking this callback; firing them here too double-buzzes the tap.
    showEventDetailSheet(context, festival: festival, date: date);
  }
}

class _OccurrencesLoading extends StatelessWidget {
  const _OccurrencesLoading({required this.bottomInset});

  final double bottomInset;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.only(
        bottom:
            AppSpacing.s32 + bottomInset + AppTheme.navigationBarInset(context),
      ),
      itemCount: 6,
      separatorBuilder: (_, _) => const SizedBox(height: AppTheme.cardGap),
      itemBuilder: (context, _) => const SkeletonBox(height: 76),
    );
  }
}

class _OccurrencesError extends StatelessWidget {
  const _OccurrencesError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ErrorState(message: message, onRetry: onRetry);
  }
}
