import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../l10n/app_localizations.dart';
import '../providers/calendar_provider.dart';
import '../providers/view_mode_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/calendar_widget.dart';
import '../widgets/event_list_widget.dart';
import '../widgets/schedule_view_widget.dart';
import '../widgets/app_drawer.dart';
import '../widgets/daily_quote_widget.dart';
import '../widgets/festival_countdown_card.dart';
import '../widgets/festival_search_delegate.dart';
import '../widgets/paksha_hero_card.dart';
import '../widgets/responsive_layout.dart';
import '../core/anim/press_scale.dart';
import '../widgets/home_widget_card.dart';
import '../providers/home_widget_provider.dart';

/// Main home screen with calendar and event list
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

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
        if (_isDrawerOpen != isOpened) {
          setState(() => _isDrawerOpen = isOpened);
        }
      },
      appBar: AppBar(
        // Explicit hamburger (not automaticallyImplyLeading): the
        // framework-built one can't carry PressScale's gated haptic.
        automaticallyImplyLeading: false,
        leading: isWideScreen
            ? null
            : Builder(
                builder: (innerContext) => PressScale(
                  child: IconButton(
                    icon: Icon(
                      Icons.menu_rounded,
                      color: context.colors.onSurface,
                    ),
                    tooltip: MaterialLocalizations.of(
                      innerContext,
                    ).openAppDrawerTooltip,
                    onPressed: () =>
                        Scaffold.of(innerContext).openDrawer(),
                  ),
                ),
              ),
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
      floatingActionButton: const _JumpToTodayFab(),
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
                      child: const SizedBox.expand(child: _HomeBody()),
                    ),
                  ),
                ),
              ],
            )
          : RepaintBoundary(
              child: TickerMode(
                enabled: !_isDrawerOpen,
                child: const _HomeBody(),
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
    final focusedMonth = ref.watch(focusedMonthProvider);
    final selectedDate = ref.watch(selectedDateProvider);
    final l10n = AppLocalizations.of(context);

    final now = DateTime.now();
    final isSameMonth =
        focusedMonth.year == now.year && focusedMonth.month == now.month;
    final isToday =
        selectedDate.year == now.year &&
        selectedDate.month == now.month &&
        selectedDate.day == now.day;
    final showJumpToToday = !isSameMonth || !isToday;

    // Scale + fade instead of popping between FAB and SizedBox.shrink:
    // month browsing feels calm, and Reduce Motion collapses to 1ms.
    return IgnorePointer(
      ignoring: !showJumpToToday,
      child: AnimatedScale(
        scale: showJumpToToday ? 1.0 : 0.0,
        duration: AppTheme.animationDuration(
          context,
          const Duration(milliseconds: 200),
        ),
        curve: Curves.easeOutCubic,
        child: AnimatedOpacity(
          opacity: showJumpToToday ? 1.0 : 0.0,
          duration: AppTheme.animationDuration(
            context,
            const Duration(milliseconds: 200),
          ),
          // Press-down microinteraction (scale + haptic live in
          // PressScale); the outer AnimatedScale above owns show/hide.
          // IgnorePointer above already blocks input while hidden,
          // so PressScale stays enabled: no double-gating.
          child: PressScale(
            child: FloatingActionButton(
              onPressed: showJumpToToday
                  ? () {
                      final now = DateTime.now();
                      setCalendarMonth(ref, now);
                      ref.read(selectedDateProvider.notifier).setDate(now);
                    }
                  : null,
              tooltip: l10n?.goToToday ?? 'Go to Today',
              backgroundColor: context.colors.primary,
              foregroundColor: context.colors.onPrimary,
              child: const Icon(Icons.today_rounded),
            ),
          ),
        ),
      ),
    );
  }
}

class _HomeBody extends ConsumerWidget {
  const _HomeBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Keep home widget in sync with all countdowns
    ref.watch(homeWidgetSyncProvider);
    final viewMode = ref.watch(homeViewModeProvider);
    final isScheduleView = viewMode == HomeViewMode.schedule;

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
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      // No entrance animation here: this is a SliverList, so
                      // every card that scrolls into view mid-session is a
                      // fresh mount and would re-run the stagger, putting a
                      // Timer + opacity layer on the critical path of a fling
                      // (and delaying the cards' own content fade-ins). Each
                      // card still cross-fades its own skeleton → content
                      // internally, which is the feedback that matters.
                      SliverList.builder(
                        itemCount: 6,
                        itemBuilder: (context, index) {
                          switch (index) {
                            case 0:
                              // Paksha hero (redesign v3 faithful) — above
                              // calendar (top 8px breath comes from the
                              // Column above; 20px breath below).
                              return const Padding(
                                padding: EdgeInsets.only(bottom: 20),
                                child: RepaintBoundary(
                                  child: PakshaHeroCard(),
                                ),
                              );
                            case 1:
                              // Calendar.
                              return const Padding(
                                padding: EdgeInsets.only(bottom: 16),
                                child: RepaintBoundary(
                                  child: CalendarWidget(),
                                ),
                              );
                            case 2:
                              // Event list (uniform 16px gaps; cards carry
                              // no vertical margin; gutter via theme).
                              return const Padding(
                                padding: EdgeInsets.only(
                                  left: AppTheme.homeCardGutter,
                                  right: AppTheme.homeCardGutter,
                                  bottom: 16,
                                ),
                                child: RepaintBoundary(
                                  child: EventListWidget(),
                                ),
                              );
                            case 3:
                              // Daily Shloka.
                              return const Padding(
                                padding: EdgeInsets.only(bottom: 16),
                                child: RepaintBoundary(
                                  child: DailyQuoteWidget(),
                                ),
                              );
                            case 4:
                              // Featured festival countdown.
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
                            default:
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

                      // Bottom padding for FAB.
                      const SliverToBoxAdapter(child: SizedBox(height: 40)),
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
