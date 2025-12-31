import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../l10n/app_localizations.dart';
import '../providers/planetary_view_provider.dart';
import '../services/planetary_view_service.dart';
import '../widgets/solar_system_painter.dart';
import '../theme/app_theme.dart';

/// Full-screen solar system visualization with interactive planets
class SolarSystemScreen extends ConsumerStatefulWidget {
  const SolarSystemScreen({super.key});

  @override
  ConsumerState<SolarSystemScreen> createState() => _SolarSystemScreenState();
}

class _SolarSystemScreenState extends ConsumerState<SolarSystemScreen> {
  @override
  Widget build(BuildContext context) {
    final solarSystemAsync = ref.watch(solarSystemDataProvider);
    final selectedPlanetData = ref.watch(selectedPlanetDataProvider);
    final viewDate = ref.watch(planetaryViewDateProvider);
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(l10n.solarSystem),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          // Date picker button
          IconButton(
            icon: const Icon(Icons.calendar_today),
            tooltip: l10n.selectDate,
            onPressed: () => _selectDate(context),
          ),
          // Reset to today
          IconButton(
            icon: const Icon(Icons.today),
            tooltip: l10n.goToToday,
            onPressed: () {
              ref.read(planetaryViewDateProvider.notifier).state =
                  DateTime.now();
            },
          ),
        ],
      ),
      body: Container(
        decoration: AppTheme.backgroundDecoration(context),
        child: SafeArea(
          child: Stack(
            children: [
              // Main content column
              Column(
                children: [
                  // Top controls row
                  _buildTopControls(context, theme, viewDate),

                  // Solar system visualization
                  Expanded(
                    child: solarSystemAsync.when(
                      data: (data) => _buildSolarSystem(context, data, isDark),
                      loading: () => const Center(
                        child: CircularProgressIndicator.adaptive(),
                      ),
                      error: (e, _) => Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.error_outline,
                              size: 48,
                              color: theme.colorScheme.error,
                            ),
                            const SizedBox(height: 16),
                            Text(l10n.errorLoadingData),
                            const SizedBox(height: 8),
                            ElevatedButton(
                              onPressed: () =>
                                  ref.refresh(solarSystemDataProvider),
                              child: Text(l10n.retry),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Planet info panel (if selected)
                  if (selectedPlanetData != null) ...[
                    _buildPlanetInfoPanel(context, selectedPlanetData, isDark),
                    const SizedBox(
                      height: 50,
                    ), // Reserve space for zoom controls
                  ],

                  // Time slider control
                  _buildTimeSlider(context, theme, viewDate),
                ],
              ),

              // Zoom controls overlay
              _buildZoomControls(context, theme),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopControls(
    BuildContext context,
    ThemeData theme,
    DateTime viewDate,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          // View mode toggle
          _buildViewModeToggle(context, theme),
          const Spacer(),
          // Date chip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: theme.colorScheme.primary.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.calendar_today,
                  size: 14,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 6),
                Text(
                  DateFormat('MMM d, y').format(viewDate),
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeSlider(
    BuildContext context,
    ThemeData theme,
    DateTime viewDate,
  ) {
    // Time slider spans from -1 year to +1 year
    final now = DateTime.now();
    final minDate = now.subtract(const Duration(days: 365));
    final maxDate = now.add(const Duration(days: 365));

    // Convert current date to slider value (0-730)
    final daysDiff = viewDate.difference(minDate).inDays.toDouble();
    final sliderValue = daysDiff.clamp(0.0, 730.0);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.8),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Time navigation buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Fast backward (1 month)
              _buildTimeButton(
                context,
                icon: Icons.fast_rewind_rounded,
                onPressed: () => _adjustDate(-30),
              ),
              // Backward (1 day)
              _buildTimeButton(
                context,
                icon: Icons.skip_previous_rounded,
                onPressed: () => _adjustDate(-1),
              ),
              const SizedBox(width: 8),
              // Today button
              FilledButton.icon(
                onPressed: () {
                  ref.read(planetaryViewDateProvider.notifier).state =
                      DateTime.now();
                },
                icon: const Icon(Icons.today, size: 18),
                label: const Text('Today'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Forward (1 day)
              _buildTimeButton(
                context,
                icon: Icons.skip_next_rounded,
                onPressed: () => _adjustDate(1),
              ),
              // Fast forward (1 month)
              _buildTimeButton(
                context,
                icon: Icons.fast_forward_rounded,
                onPressed: () => _adjustDate(30),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Slider
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 4,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
              activeTrackColor: theme.colorScheme.primary,
              inactiveTrackColor: theme.colorScheme.primary.withValues(
                alpha: 0.2,
              ),
              thumbColor: theme.colorScheme.primary,
              overlayColor: theme.colorScheme.primary.withValues(alpha: 0.2),
            ),
            child: Slider(
              value: sliderValue,
              min: 0,
              max: 730,
              onChanged: (value) {
                final newDate = minDate.add(Duration(days: value.round()));
                ref.read(planetaryViewDateProvider.notifier).state = newDate;
              },
            ),
          ),

          // Date labels
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  DateFormat('MMM y').format(minDate),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
                Text(
                  'Now',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  DateFormat('MMM y').format(maxDate),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeButton(
    BuildContext context, {
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    final theme = Theme.of(context);
    return IconButton(
      onPressed: onPressed,
      icon: Icon(icon),
      iconSize: 28,
      color: theme.colorScheme.primary,
      style: IconButton.styleFrom(
        backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
      ),
    );
  }

  void _adjustDate(int days) {
    final currentDate = ref.read(planetaryViewDateProvider);
    ref.read(planetaryViewDateProvider.notifier).state = currentDate.add(
      Duration(days: days),
    );
  }

  Widget _buildZoomControls(BuildContext context, ThemeData theme) {
    return Positioned(
      bottom: 160,
      right: 16,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.small(
            heroTag: 'zoom_out',
            onPressed: () {
              final currentZoom =
                  (ref.read(zoomLevelProvider) as num?)?.toDouble() ?? 1.0;
              ref.read(zoomLevelProvider.notifier).state = (currentZoom - 0.25)
                  .clamp(0.5, 3.0);
            },
            tooltip: 'Zoom Out',
            child: const Icon(Icons.remove),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              '${(((ref.watch(zoomLevelProvider) as num?)?.toDouble() ?? 1.0) * 100).round()}%',
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 8),
          FloatingActionButton.small(
            heroTag: 'zoom_in',
            onPressed: () {
              final currentZoom =
                  (ref.read(zoomLevelProvider) as num?)?.toDouble() ?? 1.0;
              ref.read(zoomLevelProvider.notifier).state = (currentZoom + 0.25)
                  .clamp(0.5, 3.0);
            },
            tooltip: 'Zoom In',
            child: const Icon(Icons.add),
          ),
        ],
      ),
    );
  }

  Widget _buildSolarSystem(
    BuildContext context,
    SolarSystemData data,
    bool isDark,
  ) {
    final selectedPlanet = ref.watch(selectedPlanetProvider);
    // Explicitly handle dynamic/null return from legacy provider
    final double zoomLevel =
        (ref.watch(zoomLevelProvider) as num?)?.toDouble() ?? 1.0;
    int? selectedIndex;

    if (selectedPlanet != null) {
      selectedIndex = data.planets.indexWhere(
        (p) => p.planet == selectedPlanet,
      );
      if (selectedIndex == -1) selectedIndex = null;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        final hitTester = PlanetHitTester(
          solarSystemData: data,
          size: size,
          zoomLevel: zoomLevel,
        );

        return GestureDetector(
          onTapDown: (details) {
            final hitIndex = hitTester.hitTest(details.localPosition);
            if (hitIndex != null) {
              ref.read(selectedPlanetProvider.notifier).state =
                  data.planets[hitIndex].planet;
            } else {
              ref.read(selectedPlanetProvider.notifier).state = null;
            }
          },
          child: CustomPaint(
            size: size,
            painter: SolarSystemPainter(
              solarSystemData: data,
              selectedPlanetIndex: selectedIndex,
              isDark: isDark,
              zoomLevel: zoomLevel,
            ),
          ),
        );
      },
    );
  }

  Widget _buildPlanetInfoPanel(
    BuildContext context,
    PlanetVisualData planetData,
    bool isDark,
  ) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final planetColor = Color(
      PlanetaryViewService.getPlanetColor(planetData.planet),
    );

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.glassmorphism(
        context: context,
        ref: ref,
        borderRadius: 20,
        border: Border.all(color: planetColor.withValues(alpha: 0.3), width: 2),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Planet name and retrograde indicator
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: planetColor,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: planetColor.withValues(alpha: 0.5),
                      blurRadius: 8,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(
                PlanetaryViewService.getPlanetDisplayName(planetData.planet),
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (planetData.isRetrograde) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.red.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Text(
                    l10n.retrograde,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),

          // Position details
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildInfoItem(
                context,
                icon: Icons.circle_outlined,
                label: l10n.zodiacSign,
                value: planetData.zodiacSign,
              ),
              _buildInfoItem(
                context,
                icon: Icons.straighten,
                label: l10n.degree,
                value: "${planetData.degree.toStringAsFixed(1)}°",
              ),
              _buildInfoItem(
                context,
                icon: Icons.explore,
                label: l10n.longitude,
                value: "${planetData.longitude.toStringAsFixed(2)}°",
              ),
            ],
          ),

          // Distance and orbital info (if available)
          if (planetData.distanceAU != null && planetData.distanceAU! > 0) ...[
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildInfoItem(
                  context,
                  icon: Icons.straighten_outlined,
                  label: 'Distance',
                  value: '${planetData.distanceAU!.toStringAsFixed(2)} AU',
                ),
                if (planetData.orbitalPeriodDays != null &&
                    planetData.orbitalPeriodDays! > 0)
                  _buildInfoItem(
                    context,
                    icon: Icons.timelapse,
                    label: 'Orbit',
                    value: _formatOrbitalPeriod(planetData.orbitalPeriodDays!),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _formatOrbitalPeriod(double days) {
    if (days < 365) {
      return '${days.toStringAsFixed(0)}d';
    } else {
      final years = days / 365.25;
      return '${years.toStringAsFixed(1)}y';
    }
  }

  Widget _buildInfoItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    final theme = Theme.of(context);

    return Column(
      children: [
        Icon(icon, size: 20, color: theme.colorScheme.primary),
        const SizedBox(height: 4),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildViewModeToggle(BuildContext context, ThemeData theme) {
    final viewMode = ref.watch(solarSystemViewModeProvider);
    final isHeliocentric = viewMode == SolarSystemViewMode.heliocentric;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildModeChip(
            context,
            label: '☀️',
            tooltip: 'Heliocentric (Sun-centered)',
            isSelected: isHeliocentric,
            onTap: () => ref.read(solarSystemViewModeProvider.notifier).state =
                SolarSystemViewMode.heliocentric,
          ),
          _buildModeChip(
            context,
            label: '🌍',
            tooltip: 'Geocentric (Earth-centered)',
            isSelected: !isHeliocentric,
            onTap: () => ref.read(solarSystemViewModeProvider.notifier).state =
                SolarSystemViewMode.geocentric,
          ),
        ],
      ),
    );
  }

  Widget _buildModeChip(
    BuildContext context, {
    required String label,
    required String tooltip,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);

    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected
                ? theme.colorScheme.primary.withValues(alpha: 0.2)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(label, style: const TextStyle(fontSize: 18)),
        ),
      ),
    );
  }

  Future<void> _selectDate(BuildContext context) async {
    final currentDate = ref.read(planetaryViewDateProvider);

    final selectedDate = await showDatePicker(
      context: context,
      initialDate: currentDate,
      firstDate: DateTime(1900),
      lastDate: DateTime(2100),
    );

    if (selectedDate != null && mounted) {
      ref.read(planetaryViewDateProvider.notifier).state = selectedDate;
    }
  }
}
