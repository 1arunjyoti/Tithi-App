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
import '../widgets/festival_search_delegate.dart';
import '../widgets/weather_sheet.dart';

/// Main home screen with calendar and event list
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final todayPanchang = ref.watch(todayPanchangProvider);
    final cityName = ref.watch(cityNameProvider);
    final accessibility = ref.watch(accessibilityProvider);
    final viewMode = ref.watch(homeViewModeProvider);
    final focusedMonth = ref.watch(focusedMonthProvider);
    final selectedDate = ref.watch(selectedDateProvider);
    final isScheduleView = viewMode == HomeViewMode.schedule;

    // Check if we should show the "Jump to Today" button
    final now = DateTime.now();
    final isSameMonth =
        focusedMonth.year == now.year && focusedMonth.month == now.month;
    final isToday =
        selectedDate.year == now.year &&
        selectedDate.month == now.month &&
        selectedDate.day == now.day;
    final showJumpToToday = !isSameMonth || !isToday;

    final l10n = AppLocalizations.of(context);

    return Scaffold(
      extendBodyBehindAppBar: true,
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: Text(l10n?.appTitle ?? 'Tithi'),
        backgroundColor: Colors.transparent,
        actions: [
          // Search button
          IconButton(
            icon: Icon(Icons.search_rounded, color: context.colors.onSurface),
            tooltip: 'Search Festivals', // Localize later
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

          // Location refresh button
          IconButton(
            icon: Icon(
              Icons.my_location_rounded,
              color: context.colors.onSurface,
            ),
            tooltip: l10n?.refreshLocation ?? 'Refresh Location',
            onPressed: () => _refreshLocation(context, ref),
          ),

          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: showJumpToToday
          ? FloatingActionButton(
              onPressed: () {
                final now = DateTime.now();
                ref.read(focusedMonthProvider.notifier).state = now;
                ref.read(selectedDateProvider.notifier).state = now;
              },
              tooltip: l10n?.goToToday ?? 'Go to Today',
              backgroundColor: context.colors.primary,
              foregroundColor: context.colors.onPrimary,
              child: const Icon(Icons.today_rounded),
            )
          : null,
      body: Stack(
        children: [
          // Ambient Background Gradient
          Positioned.fill(
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

          SafeArea(
            child: isScheduleView
                ? Column(
                    children: [
                      const SizedBox(height: 8),

                      // Paksha indicator with city name (shown in both views)
                      todayPanchang.when(
                        data: (panchang) => _buildPakshaIndicator(
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
                      ),

                      const SizedBox(height: 8),

                      // Schedule View (scrollable event list)
                      const Expanded(child: ScheduleViewWidget()),
                    ],
                  )
                : Column(
                    children: [
                      const SizedBox(height: 8),

                      // Paksha indicator with city name
                      todayPanchang.when(
                        data: (panchang) => _buildPakshaIndicator(
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
                      ),

                      const SizedBox(height: 8),

                      // Calendar
                      const CalendarWidget(),

                      const SizedBox(height: 8),

                      // Modern Divider with text
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
                      const Expanded(child: EventListWidget()),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildPakshaIndicator(
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
        // Show first major festival or first festival, else fallback to Tithi
        if (panchang.festivals.isNotEmpty) {
          final festival = panchang.festivals.firstWhere(
            (f) => f.category == 'major',
            orElse: () => panchang.festivals.first,
          );
          title = festival.name;
          subtitle = l10n?.todaysFestival ?? 'Today\'s Festival';
        } else {
          // Fallback if no festival
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
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
        decoration: AppTheme.glassmorphism(
          context: context,
          opacity: 0.1,
          borderRadius: 30, // Pill shape
          ref: ref,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icon(icon, size: 20, color: context.colors.primary),
            MoonAnimationWidget(
              paksha: panchang.paksha,
              tithi: panchang.tithiNumber,
              size: 40,
            ),
            const SizedBox(width: 8),
            Column(
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
                    color: context.colors.onSurface.withValues(alpha: 0.6),
                    fontSize: 12,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
            // City name indicator
            if (cityName != null) ...[
              const SizedBox(width: 16),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: context.colors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.location_on,
                      size: 14,
                      color: context.colors.primary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      cityName,
                      style: TextStyle(
                        color: context.colors.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            // Sunrise/Sunset indicator
            if (panchang.sunrise != null && panchang.sunset != null) ...[
              const SizedBox(width: 12),
              Container(
                height: 32,
                width: 1,
                color: context.colors.onSurface.withValues(alpha: 0.2),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.wb_sunny_rounded,
                        size: 14,
                        color: Colors.orange.shade300,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        DateFormat.jm().format(panchang.sunrise!),
                        style: TextStyle(
                          fontSize: 11,
                          color: context.colors.onSurface.withValues(
                            alpha: 0.8,
                          ),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(
                        Icons.nightlight_round,
                        size: 14,
                        color: Colors.indigo.shade300,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        DateFormat.jm().format(panchang.sunset!),
                        style: TextStyle(
                          fontSize: 11,
                          color: context.colors.onSurface.withValues(
                            alpha: 0.8,
                          ),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _refreshLocation(BuildContext context, WidgetRef ref) async {
    // Show loading indicator
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

    // Refresh the location
    ref.invalidate(currentLocationProvider);

    // Wait a bit and then invalidate panchang to recalculate
    await Future.delayed(const Duration(milliseconds: 500));
    ref.invalidate(todayPanchangProvider);
  }
}
