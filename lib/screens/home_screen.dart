import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../l10n/app_localizations.dart';
import '../models/panchang_data.dart';
import '../providers/calendar_provider.dart';
import '../providers/location_provider.dart';
import '../providers/panchang_provider.dart';
import '../providers/accessibility_provider.dart';
import '../providers/view_mode_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/calendar_widget.dart';
import '../widgets/event_list_widget.dart';
import '../widgets/schedule_view_widget.dart';
import '../widgets/app_drawer.dart';
import '../widgets/moon_animation_widget.dart';
import '../widgets/daily_quote_widget.dart';
import '../widgets/festival_search_delegate.dart';
import '../widgets/weather_sheet.dart';
import '../widgets/responsive_layout.dart';

/// Main home screen with calendar and event list
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isWideScreen = ResponsiveLayout.isTabletOrLarger(context);

    return Scaffold(
      extendBodyBehindAppBar: true,
      // Only show drawer on mobile, desktop uses persistent sidebar
      drawer: isWideScreen ? null : const AppDrawer(),
      appBar: AppBar(
        // Hide hamburger menu on wide screens
        automaticallyImplyLeading: !isWideScreen,
        title: Text(l10n?.appTitle ?? 'Tithi'),
        backgroundColor: Colors.transparent,
        actions: [
          // Search button
          Consumer(
            builder: (context, ref, _) {
              return IconButton(
                icon: Icon(
                  Icons.search_rounded,
                  color: context.colors.onSurface,
                ),
                tooltip: 'Search Festivals',
                onPressed: () {
                  showSearch(
                    context: context,
                    delegate: FestivalSearchDelegate(
                      ref: ref,
                      parentContext: context,
                    ),
                  );
                },
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
          : const _HomeBody(), // Mobile layout remains exactly as before
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

    if (!showJumpToToday) return const SizedBox.shrink();

    return FloatingActionButton(
      onPressed: () {
        final now = DateTime.now();
        ref.read(focusedMonthProvider.notifier).state = now;
        ref.read(selectedDateProvider.notifier).state = now;
      },
      tooltip: l10n?.goToToday ?? 'Go to Today',
      backgroundColor: context.colors.primary,
      foregroundColor: context.colors.onPrimary,
      child: const Icon(Icons.today_rounded),
    );
  }
}

class _HomeBody extends ConsumerWidget {
  const _HomeBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accessibility = ref.watch(accessibilityProvider);
    final viewMode = ref.watch(homeViewModeProvider);
    final isScheduleView = viewMode == HomeViewMode.schedule;
    final l10n = AppLocalizations.of(context);

    return Stack(
      children: [
        // Ambient Background Gradient - Cached with RepaintBoundary
        Positioned.fill(
          child: RepaintBoundary(
            child: Container(
              decoration: BoxDecoration(
                gradient: accessibility.reduceMotion
                    ? null
                    : LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors:
                            context.theme.scaffoldBackgroundColor ==
                                Colors.black
                            ? [Colors.black, Colors.black, Colors.black]
                            : context.isDark
                            ? [
                                const Color(0xFF10002B),
                                const Color(0xFF240046),
                                const Color(0xFF10002B),
                              ]
                            : [
                                const Color(0xFFFFFDF7),
                                const Color(0xFFFFECB3).withValues(alpha: 0.3),
                                const Color(0xFFFFFDF7),
                              ],
                      ),
                color: accessibility.reduceMotion
                    ? context.theme.scaffoldBackgroundColor
                    : null,
              ),
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
                // Calendar View
                Expanded(
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Column(
                      children: [
                        // Calendar
                        const CalendarWidget(),

                        const SizedBox(height: 8),

                        // Event List Title
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Row(
                            children: [
                              Expanded(
                                child: Divider(
                                  color: context.colors.onSurface.withValues(
                                    alpha: 0.1,
                                  ),
                                  thickness: 1,
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                ),
                                child: Text(
                                  l10n?.events ?? "EVENTS",
                                  style: context.textTheme.labelSmall?.copyWith(
                                    letterSpacing: 1.5,
                                    fontWeight: FontWeight.bold,
                                    color: context.colors.primary,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Divider(
                                  color: context.colors.onSurface.withValues(
                                    alpha: 0.1,
                                  ),
                                  thickness: 1,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 8),

                        // Event list
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16),
                          child: EventListWidget(),
                        ),

                        const SizedBox(height: 2),

                        // Paksha indicator
                        const _PakshaIndicator(),

                        const SizedBox(height: 16),

                        // Daily Shloka
                        const DailyQuoteWidget(),

                        // Bottom padding for FAB
                        const SizedBox(height: 80),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PakshaIndicator extends ConsumerWidget {
  const _PakshaIndicator();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final todayPanchang = ref.watch(todayPanchangProvider);
    final cityName = ref.watch(cityNameProvider);

    return todayPanchang.when(
      data: (panchang) => _buildIndicatorContent(
        context,
        ref,
        panchang,
        cityName.when(
          data: (city) => city,
          loading: () => null,
          error: (_, _) => null,
        ),
      ),
      loading: () => const SizedBox(height: 40),
      error: (_, _) => const SizedBox(height: 40),
    );
  }

  Widget _buildIndicatorContent(
    BuildContext context,
    WidgetRef ref,
    PanchangData panchang,
    String? cityName,
  ) {
    final primaryView = ref.watch(primaryEventViewProvider);
    final isShukla = panchang.paksha == 'Shukla';
    final l10n = AppLocalizations.of(context);

    // Determine what to show based on preference
    String title;
    String subtitle;
    switch (primaryView) {
      case PrimaryEventView.festival:
        if (panchang.festivals.isNotEmpty) {
          final festival = panchang.festivals.firstWhere(
            (f) => f.category == 'major',
            orElse: () => panchang.festivals.first,
          );
          title = festival.name;
          subtitle = l10n?.todaysFestival ?? 'Today\'s Festival';
        } else {
          title = panchang.tithiName;
          subtitle = l10n?.noFestivalsToday ?? 'Tithi • No Festivals Today';
        }
        break;

      case PrimaryEventView.tithi:
        title = panchang.tithiName;
        subtitle =
            l10n?.pakshaWithName(panchang.paksha) ??
            '${panchang.paksha} Paksha';
        break;

      case PrimaryEventView.moonPhase:
        title =
            l10n?.pakshaWithName(panchang.paksha) ??
            '${panchang.paksha} Paksha';
        subtitle = isShukla
            ? (l10n?.waxingMoonPhase ?? 'Waxing Moon Phase')
            : (l10n?.waningMoonPhase ?? 'Waning Moon Phase');
        break;
    }

    return GestureDetector(
      onTap: () {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (context) => const WeatherSheet(),
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
        decoration: AppTheme.glassmorphism(context: context, ref: ref),
        child: Column(
          children: [
            // Top Row: Moon, Title, and Sun/Moon Time
            Row(
              children: [
                MoonAnimationWidget(
                  paksha: panchang.paksha,
                  tithi: panchang.tithiNumber,
                  size: 40,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: context.colors.onSurface,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: context.colors.onSurface.withValues(
                            alpha: 0.6,
                          ),
                          fontSize: 12,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),

                // Sun Time in Top Row if available
                if (panchang.sunrise != null && panchang.sunset != null) ...[
                  const SizedBox(width: 8),
                  Container(
                    height: 32,
                    width: 1,
                    color: context.colors.onSurface.withValues(alpha: 0.1),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _buildSunTime(
                        context,
                        Icons.wb_sunny_rounded,
                        panchang.sunrise!,
                        Colors.orange.shade300,
                      ),
                      const SizedBox(height: 4),
                      _buildSunTime(
                        context,
                        Icons.nightlight_round,
                        panchang.sunset!,
                        Colors.indigo.shade300,
                      ),
                    ],
                  ),
                ],
              ],
            ),

            // Bottom Row: Location Info (if available)
            if (cityName != null) ...[
              const SizedBox(height: 12),
              Container(
                //width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: context.colors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.location_on_rounded,
                      size: 14,
                      color: context.colors.primary,
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        cityName,
                        style: TextStyle(
                          color: context.colors.primary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSunTime(
    BuildContext context,
    IconData icon,
    DateTime time,
    Color color,
  ) {
    return Row(
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(
          DateFormat.jm().format(time),
          style: TextStyle(
            fontSize: 11,
            color: context.colors.onSurface.withValues(alpha: 0.8),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
