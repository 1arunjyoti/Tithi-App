import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/location_provider.dart';
import '../providers/panchang_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/calendar_widget.dart';
import '../widgets/event_list_widget.dart';
import '../widgets/app_drawer.dart';

/// Main home screen with calendar and event list
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final todayPanchang = ref.watch(todayPanchangProvider);
    final cityName = ref.watch(cityNameProvider);

    return Scaffold(
      extendBodyBehindAppBar: true,
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: const Text('Tithi'),
        backgroundColor: Colors.transparent,
        actions: [
          // Location refresh button
          IconButton(
            icon: Icon(
              Icons.location_on_outlined,
              color: context.colors.onSurface,
            ),
            tooltip: 'Refresh Location',
            onPressed: () => _refreshLocation(context, ref),
          ),
        ],
      ),
      body: Stack(
        children: [
          // Ambient Background Gradient
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: context.theme.scaffoldBackgroundColor == Colors.black
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
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 8),

                // Paksha indicator with city name
                todayPanchang.when(
                  data: (panchang) => _buildPakshaIndicator(
                    context,
                    panchang.paksha,
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
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          "UPCOMING EVENTS",
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
    String paksha,
    String? cityName,
  ) {
    final isShukla = paksha == 'Shukla';

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
      decoration: AppTheme.glassmorphism(
        context: context,
        opacity: 0.1,
        borderRadius: 50, // Pill shape
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isShukla
                ? Icons.brightness_high_rounded
                : Icons.nights_stay_rounded,
            size: 20,
            color: context.colors.primary,
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$paksha Paksha',
                style: TextStyle(
                  color: context.colors.onSurface,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              Text(
                isShukla ? 'Waxing Moon Phase' : 'Waning Moon Phase',
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
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
        ],
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
