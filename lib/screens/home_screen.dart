import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/navigation/home_tab.dart';
import '../l10n/app_localizations.dart';
import '../providers/home_cards_visibility_provider.dart';
import '../providers/view_mode_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/calendar_widget.dart';
import '../widgets/event_list_widget.dart';
import '../widgets/schedule_view_widget.dart';
import '../widgets/app_drawer.dart';
import '../widgets/daily_quote_widget.dart';
import '../widgets/app_drawer_button.dart';
import '../widgets/festival_countdown_card.dart';
import '../widgets/festival_search_delegate.dart';
import '../widgets/jump_to_today_button.dart';
import '../widgets/paksha_hero_card.dart';
import '../widgets/responsive_layout.dart';
import '../core/anim/press_scale.dart';
import '../widgets/home_widget_card.dart';
import '../providers/home_widget_provider.dart';

/// Main home screen with calendar and event list
class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    this.bottomContentInset = 0,
    this.showJumpToToday = true,
    this.onDrawerStateChanged,
    this.onSelectTab,
  });

  /// Extra bottom padding for the scroll view and the FAB.
  ///
  /// The shell passes `FloatingNavBar.reserve` so the last card can be
  /// scrolled clear of the capsule. Zero when this screen is the whole screen
  /// (wide layout), where nothing floats over the content.
  final double bottomContentInset;

  /// Whether the "jump to today" action is drawn in this Scaffold's FAB slot.
  ///
  /// The narrow shell passes false: it renders the same [JumpToTodayButton]
  /// beside the floating capsule instead, and two live copies would both jump.
  final bool showJumpToToday;

  /// Reports the navigation drawer opening/closing.
  ///
  /// Needed only when this screen is embedded (see `HomeShell`): the drawer is
  /// painted inside this Scaffold, which sits below any sibling overlay, so
  /// the shell has to retract the floating bar while the drawer is out.
  final ValueChanged<bool>? onDrawerStateChanged;

  /// Switches the hosting shell to another tab, when this screen is one tab of
  /// [HomeShell] rather than the whole app.
  ///
  /// The drawer lists destinations the shell already keeps mounted, so picking
  /// one must select that tab, not push a second copy of the same screen over
  /// the shell. Null (wide layout, where there is no shell) keeps the drawer's
  /// own push navigation.
  final ValueChanged<HomeTab>? onSelectTab;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isDrawerOpen = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isWideScreen = ResponsiveLayout.isTabletOrLarger(context);

    return Scaffold(
      extendBodyBehindAppBar: true,
      // Only show drawer on mobile, desktop uses persistent sidebar
      drawer: isWideScreen ? null : const AppDrawer(),
      onDrawerChanged: (isOpened) {
        widget.onDrawerStateChanged?.call(isOpened);
        if (_isDrawerOpen != isOpened) {
          setState(() => _isDrawerOpen = isOpened);
        }
      },
      appBar: AppBar(
        // Explicit hamburger (not automaticallyImplyLeading): the
        // framework-built one can't carry PressScale's gated haptic.
        automaticallyImplyLeading: false,
        leading: isWideScreen ? null : const AppDrawerButton(),
        title: Text(l10n?.appTitle ?? 'Tithi'),
        backgroundColor: Colors.transparent,
        actions: [
          // Search button (press-scale owns the gated haptic + press feel)
          Consumer(
            builder: (context, ref, _) {
              return PressScale(
                child: IconButton(
                  icon: Icon(
                    Icons.search_rounded,
                    color: context.colors.onSurface,
                  ),
                  tooltip: l10n?.searchFestivals ?? 'Search Festivals',
                  onPressed: () {
                    showSearch(
                      context: context,
                      delegate: FestivalSearchDelegate(
                        ref: ref,
                        parentContext: context,
                      ),
                    );
                  },
                ),
              );
            },
          ),

          // Location refresh button
          /*
          Consumer(
            builder: (context, ref, _) {
              return IconButton(
                icon: Icon(
                  Icons.my_location_rounded,
                  color: context.colors.onSurface,
                ),
                tooltip: l10n?.refreshLocation ?? 'Refresh Location',
                onPressed: () => _refreshLocation(context, ref),
              );
            },
          ),
          */
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: widget.showJumpToToday
          ? Padding(
              // The FAB anchors to the window bottom, so it lands under the
              // capsule unless it is lifted by the capsule's own strip.
              padding: EdgeInsets.only(bottom: widget.bottomContentInset),
              child: const _JumpToTodayFab(),
            )
          : null,
      // Use distinct layouts for mobile and desktop to prevent any regression on mobile
      body: isWideScreen
          ? Row(
              children: [
                // Persistent sidebar on wide screens
                const SizedBox(width: 280, child: AppDrawer(isSidebar: true)),
                // Main content with constrained width
                Expanded(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 800),
                      // Force full height to ensure background gradient fills screen
                      // and Column/Expanded widgets work correctly
                      child: SizedBox.expand(
                        child: _HomeBody(
                          bottomInset: widget.bottomContentInset,
                          onSelectTab: widget.onSelectTab,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            )
          : RepaintBoundary(
              child: TickerMode(
                enabled: !_isDrawerOpen,
                child: _HomeBody(
                  bottomInset: widget.bottomContentInset,
                  onSelectTab: widget.onSelectTab,
                ),
              ),
            ), // Mobile layout remains exactly as before
    );
  }

  /*
  Future<void> _refreshLocation(BuildContext context, WidgetRef ref) async {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Theme.of(context).colorScheme.onPrimary,
              ),
            ),
            const SizedBox(width: 12),
            const Text('Fetching location...'),
          ],
        ),
        duration: const Duration(seconds: 2),
      ),
    );

    ref.invalidate(currentLocationProvider);
    // todayPanchangProvider depends on currentLocationProvider, so it will update automatically
  }
  */
}

class _JumpToTodayFab extends ConsumerWidget {
  const _JumpToTodayFab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visible = ref.watch(jumpToTodayVisibleProvider);

    // Scale + fade instead of popping between button and SizedBox.shrink:
    // month browsing feels calm, and Reduce Motion collapses to 1ms.
    return IgnorePointer(
      ignoring: !visible,
      child: AnimatedScale(
        scale: visible ? 1.0 : 0.0,
        duration: AppTheme.animationDuration(
          context,
          const Duration(milliseconds: 200),
        ),
        curve: Curves.easeOutCubic,
        child: AnimatedOpacity(
          opacity: visible ? 1.0 : 0.0,
          duration: AppTheme.animationDuration(
            context,
            const Duration(milliseconds: 200),
          ),
          // Press-down microinteraction (scale + haptic) lives in the button's
          // own PressScale; IgnorePointer above already blocks input while
          // hidden, so there is no double-gating.
          child: const JumpToTodayButton(
            // The wide layout keeps the M3 FAB outline it had before this
            // action also started floating beside the nav capsule.
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(16)),
            ),
          ),
        ),
      ),
    );
  }
}

class _HomeBody extends ConsumerStatefulWidget {
  const _HomeBody({required this.bottomInset, this.onSelectTab});

  /// Scroll padding that lets the last card come to rest above the floating
  /// capsule instead of behind it.
  final double bottomInset;

  final ValueChanged<HomeTab>? onSelectTab;

  @override
  ConsumerState<_HomeBody> createState() => _HomeBodyState();
}

class _HomeBodyState extends ConsumerState<_HomeBody> {
  /// Owns the calendar view's offset so a re-tap of the Today destination can
  /// return to the top. The schedule view owns its own controller (its list is
  /// anchored to today), so a re-tap is a no-op while that view is showing.
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  /// Re-tapping the already-selected Today destination means "take me back to
  /// the top" (the same gesture every other tab bar has).
  ///
  /// The shell owns the tap but not this scroll view, so it bumps
  /// [tabRevealProvider] and the tab reacts here.
  void _revealTop() {
    if (!_scrollController.hasClients) return;
    final ScrollPosition position = _scrollController.position;
    if (!position.hasContentDimensions ||
        position.pixels <= position.minScrollExtent) {
      return;
    }
    _scrollController.animateTo(
      position.minScrollExtent,
      duration: AppTheme.animationDuration(
        context,
        const Duration(milliseconds: 260),
      ),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<int>(tabRevealProvider(HomeTab.today), (previous, next) {
      if (previous == next) return;
      _revealTop();
    });
    // Keep home widget in sync with all countdowns
    ref.watch(homeWidgetSyncProvider);
    final viewMode = ref.watch(homeViewModeProvider);
    final isScheduleView = viewMode == HomeViewMode.schedule;
    // Optional cards the user hid (Daily Wisdom, Countdowns) are skipped
    // entirely: no sliver, no gap, and their providers never fire.
    final showWisdom = ref.watch(dailyWisdomVisibleProvider);
    final showCountdowns = ref.watch(festivalCountdownsVisibleProvider);
    final List<_HomeCard> cards = [
      _HomeCard.calendar,
      _HomeCard.events,
      if (showWisdom) _HomeCard.wisdom,
      if (showCountdowns) _HomeCard.countdowns,
      _HomeCard.widget,
    ];
    return Stack(
      children: [
        // Ambient Background — delegates to AppTheme.backgroundDecoration
        // so the gradient logic lives in one place (SMELL-1).
        // Reduce Motion is handled centrally there (flat scaffold color).
        Positioned.fill(
          child: RepaintBoundary(
            child: Container(
              decoration: AppTheme.backgroundDecoration(context),
            ),
          ),
        ),

        SafeArea(
          // The page background (the `Positioned.fill` layer above) paints
          // edge-to-edge, so only the content is inset from the sides and the
          // status bar. The navigation area is handled by the scroll padding
          // below instead: insetting the viewport here would stop the last
          // card above the gesture handle and leave a bare background band.
          bottom: false,
          child: Column(
            children: [
              const SizedBox(height: 8),

              if (isScheduleView)
                // Schedule View
                const Expanded(child: ScheduleViewWidget())
              else
                // Calendar View — genuinely lazy: SliverList.builder creates
                // each card on demand as it approaches the viewport, so
                // offscreen cards neither build nor trigger their
                // provider/fetch work until scrolled to. Each card paints
                // behind its own RepaintBoundary.
                Expanded(
                  child: CustomScrollView(
                    controller: _scrollController,
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      // No entrance animation here: this is a SliverList, so
                      // every card that scrolls into view mid-session is a
                      // fresh mount and would re-run the stagger, putting a
                      // Timer + opacity layer on the critical path of a fling
                      // (and delaying the cards' own content fade-ins). Each
                      // card still cross-fades its own skeleton → content
                      // internally, which is the feedback that matters.
                      // Paksha hero (redesign v3 faithful) — above calendar
                      // (top 8px breath comes from the Column above; 20px
                      // breath below). Kept in a SliverToBoxAdapter (not the
                      // lazy list below) so scrolling down then back up does
                      // not dispose + remount it: a remount replays its
                      // AnimatedSize glide + AnimatedSwitcher fade, reading
                      // as its own slide-down independent of the scroll.
                      const SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.only(bottom: 20),
                          child: RepaintBoundary(child: PakshaHeroCard()),
                        ),
                      ),
                      // Calendar View — genuinely lazy: SliverList.builder
                      // creates each card on demand as it approaches the
                      // viewport, so offscreen cards neither build nor trigger
                      // their provider/fetch work until scrolled to. Each card
                      // paints behind its own RepaintBoundary.
                      SliverList.builder(
                        itemCount: cards.length,
                        itemBuilder: (context, index) {
                          switch (cards[index]) {
                            case _HomeCard.calendar:
                              // Calendar.
                              return const Padding(
                                padding: EdgeInsets.only(bottom: 16),
                                child: RepaintBoundary(child: CalendarWidget()),
                              );
                            case _HomeCard.events:
                              // Event list (uniform 16px gaps; cards carry
                              // no vertical margin; gutter via theme).
                              return Padding(
                                padding: const EdgeInsets.only(
                                  left: AppTheme.homeCardGutter,
                                  right: AppTheme.homeCardGutter,
                                  bottom: 16,
                                ),
                                child: RepaintBoundary(
                                  child: EventListWidget(
                                    onSelectTab: widget.onSelectTab,
                                  ),
                                ),
                              );
                            case _HomeCard.wisdom:
                              // Daily Shloka (hideable in Settings).
                              return const Padding(
                                padding: EdgeInsets.only(bottom: 16),
                                child: RepaintBoundary(
                                  child: DailyQuoteWidget(),
                                ),
                              );
                            case _HomeCard.countdowns:
                              // Featured festival countdown (hideable).
                              return const Padding(
                                padding: EdgeInsets.only(
                                  left: AppTheme.homeCardGutter,
                                  right: AppTheme.homeCardGutter,
                                  bottom: 16,
                                ),
                                child: RepaintBoundary(
                                  child: FestivalCountdownCard(),
                                ),
                              );
                            case _HomeCard.widget:
                              // Home screen widget affordance.
                              return const Padding(
                                padding: EdgeInsets.only(
                                  left: AppTheme.homeCardGutter,
                                  right: AppTheme.homeCardGutter,
                                ),
                                child: RepaintBoundary(
                                  child: HomeWidgetCard(showDismiss: true),
                                ),
                              );
                          }
                        },
                      ),

                      // Bottom padding for the FAB and the floating capsule.
                      // The system inset is part of it: the viewport now runs
                      // behind the gesture handle, so the last card needs this
                      // much padding to rest clear of it.
                      SliverToBoxAdapter(
                        child: SizedBox(
                          height:
                              40 +
                              widget.bottomInset +
                              AppTheme.navigationBarInset(context),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Order of the lazy home cards below the hero. The list in [_HomeBody]
/// filters out cards the user hid, so indices stay dense.
enum _HomeCard { calendar, events, wisdom, countdowns, widget }
