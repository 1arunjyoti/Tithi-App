import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/navigation/home_tab.dart';
import '../l10n/app_localizations.dart';
import '../theme/app_theme.dart';
import '../theme/app_metrics.dart';
import '../widgets/animated_tab_layer.dart';
import '../widgets/floating_nav_bar.dart';
import '../widgets/jump_to_today_button.dart';
import '../widgets/responsive_layout.dart';
import 'all_festivals_screen.dart';
import 'home_screen.dart';

/// Root of the narrow-screen app: keeps both top-level tabs mounted and
/// floats a [FloatingNavBar] above them.
///
/// Wide screens (>= [ResponsiveLayout.tabletBreakpoint]) return the untouched
/// [HomeScreen]: that layout already owns a persistent 280px sidebar, and a
/// second navigation affordance at the bottom would be a competing system.
class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  static final int _tabCount = HomeTab.values.length;

  /// How far the tabs travel during a switch. Small enough to read as one
  /// screen changing, large enough to show which way the switch went.
  static const double _switchSlide = 24;

  /// The tab that is shown. Today is the opening destination.
  int _index = HomeTab.today.index;

  /// The tab being switched away from, while the switch runs. -1 once the
  /// switch is over (the tab then becomes idle and stops being painted).
  int _previousIndex = -1;

  /// +1 when the incoming tab sits to the right of the outgoing one, -1 for
  /// the reverse. Both tabs read it, so they move as one.
  int _direction = 1;

  /// True only during the shell's first build: the opening tab is simply
  /// there, with no fade-in over the app's launch.
  bool _firstBuild = true;

  /// The drawer lives inside [HomeScreen]'s own Scaffold, which paints below
  /// this stack: without hiding the capsule it would float on top of the open
  /// drawer and its scrim.
  bool _drawerOpen = false;

  /// Tabs mount on first visit, not at startup. [AllFestivalsScreen] resolves
  /// ~100 festival occurrences through the ephemeris; paying that on launch
  /// would push work into the first frame for a tab the user may never open.
  /// Once mounted they stay mounted, which is what keeps scroll offsets and
  /// search state alive across tab switches.
  final Set<int> _mounted = {HomeTab.today.index};

  /// One widget instance per tab, created the first time that tab is shown.
  ///
  /// The tabs stay in the tree (their scroll offsets, search text and filters
  /// must survive a switch), so without the cache each switch rebuilt both
  /// subtrees. Reusing the same instance makes `Element.update` a no-op for
  /// the tab that did not change: an offscreen tab still exists, but costs no
  /// build.
  final Map<int, Widget> _tabs = <int, Widget>{};

  /// Ambient theme handed to the tabs, with the snackbar lifted above the
  /// floating bar. `ThemeData.copyWith` allocates and invalidates every
  /// `Theme.of` dependency below it, so it is only rebuilt when the incoming
  /// theme itself changed (identity, not equality: themes are immutable and
  /// the parent hands us the same instance between builds).
  ThemeData? _snackBarThemeSource;
  ThemeData? _snackBarTheme;

  /// The switch finished: the tab that left becomes idle, so it stops being
  /// painted. It stays in the tree, so it comes back exactly as it was.
  void _onTabExited(int index) {
    if (!mounted || _previousIndex != index) return;
    setState(() => _previousIndex = -1);
  }

  void _select(int index) {
    if (index < 0 || index >= _tabCount) return;
    if (index == _index) {
      // The destination is already selected: the tab is on screen and the
      // gesture can only mean "show me the top of it". The shell cannot scroll
      // for the tab, so it bumps a counter the tab listens to.
      ref.read(tabRevealProvider(HomeTab.values[index]).notifier).state++;
      return;
    }
    setState(() {
      _previousIndex = _index;
      _direction = index > _index ? 1 : -1;
      _index = index;
      _mounted.add(index);
      // Each tab hosts its own drawer, so "the drawer is open" belongs to the
      // tab that reported it. A switch means that drawer is gone; clearing the
      // flag here keeps a missed close callback from leaving the capsule
      // hidden on the tab we just opened.
      _drawerOpen = false;
    });
  }

  void _onDrawerStateChanged(bool open) {
    if (_drawerOpen == open || !mounted) return;
    setState(() => _drawerOpen = open);
  }

  Widget _tab(int index) {
    return _tabs.putIfAbsent(index, () {
      switch (HomeTab.values[index]) {
        case HomeTab.today:
          return HomeScreen(
            bottomContentInset: FloatingNavBar.reserve,
            // The shell floats this action beside the capsule instead; two
            // live copies in the same frame would both jump.
            showJumpToToday: false,
            // The home cards' "View all N festivals" button asks for the
            // Festivals destination, so it must switch this shell's tab rather
            // than push a second copy of the screen over it.
            onSelectTab: _selectTab,
            onDrawerStateChanged: _onDrawerStateChanged,
          );
        case HomeTab.festivals:
          return AllFestivalsScreen(
            bottomContentInset: FloatingNavBar.reserve,
            // The drawer hosts Settings (and every other drawer
            // destination), so reaching it must not require a detour through
            // Today.
            onSelectTab: _selectTab,
            onDrawerStateChanged: _onDrawerStateChanged,
          );
      }
    });
  }

  /// Switches to [tab] from inside a tab (the home card's "view all", which
  /// only knows the destination it wants), where only the enum is known.
  void _selectTab(HomeTab tab) => _select(tab.index);

  TabLayerRole _roleFor(int index) {
    if (index == _index) return TabLayerRole.entering;
    if (index == _previousIndex) return TabLayerRole.exiting;
    return TabLayerRole.idle;
  }

  /// The tabs, stacked instead of indexed.
  ///
  /// An `IndexedStack` swaps instantly and paints one child; the switch needs
  /// both the old and the new tab on screen at once, so the tabs are a plain
  /// [Stack] and each one animates itself (see [AnimatedTabLayer]). The
  /// visible tab is painted last so it slides in *over* the tab it replaces.
  Widget _tabStack() {
    final order = <int>[
      for (var i = 0; i < _tabCount; i++)
        if (i != _index && _mounted.contains(i)) i,
      if (_mounted.contains(_index)) _index,
    ];
    // The opening tab must be on screen on the very first frame, with no
    // fade-in over the app's launch. Every tab opened later fades in.
    final initiallyVisible = _firstBuild;
    _firstBuild = false;
    return Stack(
      children: [
        for (final i in order)
          AnimatedTabLayer(
            // Keyed: the order changes on every switch, and without keys the
            // framework would hand one tab's element to another tab.
            key: ValueKey<int>(i),
            role: _roleFor(i),
            direction: _direction,
            slide: _switchSlide,
            initiallyVisible: initiallyVisible && i == _index,
            onExited: i == _previousIndex ? () => _onTabExited(i) : null,
            child: TickerMode(
              // Offscreen tabs stay alive (scroll offsets, providers) but stop
              // ticking: an idle moon animation on a hidden tab must not keep
              // requesting frames.
              enabled: _index == i,
              child: _tab(i),
            ),
          ),
      ],
    );
  }

  ThemeData _tabTheme(ThemeData theme) {
    if (identical(theme, _snackBarThemeSource)) return _snackBarTheme!;
    _snackBarThemeSource = theme;
    return _snackBarTheme = theme.copyWith(
      // Floating snackbars are laid out by each tab's own Scaffold, whose
      // `contentBottom` knows nothing about the capsule. Lift them by the
      // bar's strip so a confirmation never lands underneath it.
      snackBarTheme: theme.snackBarTheme.copyWith(
        insetPadding: const EdgeInsets.fromLTRB(
          AppSpacing.s16,
          AppSpacing.s16,
          AppSpacing.s16,
          FloatingNavBar.reserve + AppSpacing.s8,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (ResponsiveLayout.isTabletOrLarger(context)) {
      return const HomeScreen();
    }

    final l10n = AppLocalizations.of(context);
    final destinations = [
      FloatingNavDestination(
        icon: Icons.today_rounded,
        label: l10n?.navToday ?? 'Today',
      ),
      FloatingNavDestination(
        icon: Icons.event_available_rounded,
        label: l10n?.navFestivals ?? 'Festivals',
      ),
    ];

    return PopScope(
      // Back from a tab returns to Today before it leaves the app, so the
      // bottom bar behaves like a set of tabs rather than pushed routes.
      canPop: _index == HomeTab.today.index,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop || _index == HomeTab.today.index) return;
        _select(HomeTab.today.index);
      },
      child: Stack(
        children: [
          Positioned.fill(
            child: Theme(
              data: _tabTheme(Theme.of(context)),
              child: _tabStack(),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: IgnorePointer(
              ignoring: _drawerOpen,
              child: AnimatedOpacity(
                opacity: _drawerOpen ? 0 : 1,
                duration: AppTheme.animationDuration(
                  context,
                  const Duration(milliseconds: 160),
                ),
                // Scoped consumer: the "jump to today" rule depends on the
                // calendar's focused month and selected day, so watching it in
                // the shell's build would rebuild both tabs on every date
                // tap. Here only the bar rebuilds.
                child: Consumer(
                  builder: (context, ref, child) {
                    // The calendar is the Today tab's content, so its action
                    // belongs to that tab: on the others the bar keeps its
                    // full width.
                    final showJumpToToday =
                        HomeTab.values[_index] == HomeTab.today &&
                        ref.watch(jumpToTodayVisibleProvider);
                    return FloatingNavBar(
                      destinations: destinations,
                      selectedIndex: _index,
                      onSelected: _select,
                      trailingAction: const JumpToTodayButton(),
                      showTrailingAction: showJumpToToday,
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
