import 'dart:async';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../l10n/app_localizations.dart';
import '../core/anim/press_scale.dart';
import '../core/navigation/haptic_back_button.dart';
import '../utils/tithi_localization.dart';
import '../providers/planetary_view_provider.dart';
import '../services/planetary_view_service.dart';
import '../widgets/solar_system_painter.dart';
import '../widgets/responsive_layout.dart';
import '../widgets/page_scaffold.dart';
import '../widgets/state_views.dart';
import '../theme/app_theme.dart';
import '../theme/app_metrics.dart';
import '../theme/app_typography.dart';

/// Full-screen solar system visualization with interactive planets
class SolarSystemScreen extends ConsumerStatefulWidget {
  const SolarSystemScreen({super.key});

  @override
  ConsumerState<SolarSystemScreen> createState() => _SolarSystemScreenState();
}

class _SolarSystemScreenState extends ConsumerState<SolarSystemScreen> {
  bool _showZodiac = true;
  bool _isAnimating = false;
  double _animationSpeed = 1.0; // Days per frame
  Timer? _animationTimer;
  Offset _panOffset = Offset.zero;

  @override
  void dispose() {
    _animationTimer?.cancel();
    _animationTimer = null;
    super.dispose();
  }

  void _toggleAnimation() {
    if (_isAnimating) {
      _stopAnimation();
    } else {
      _startAnimation();
    }
  }

  void _startAnimation() {
    setState(() => _isAnimating = true);
    // ~30 FPS
    _animationTimer = Timer.periodic(const Duration(milliseconds: 33), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      _adjustDate(_animationSpeed);
    });
  }

  void _stopAnimation() {
    _animationTimer?.cancel();
    _animationTimer = null;
    if (mounted) setState(() => _isAnimating = false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return PageScaffold(
      leading: const HapticBackButton(),
      title: Text(l10n.solarSystem),
      actions: [
        // Date picker button (gated press haptic + scale in PressScale).
        PressScale(
          child: IconButton(
            icon: const Icon(Icons.calendar_today),
            tooltip: l10n.selectDate,
            onPressed: () => _selectDate(context),
          ),
        ),
        // Reset to today
        PressScale(
          child: IconButton(
            icon: const Icon(Icons.today),
            tooltip: l10n.goToToday,
            onPressed: () {
              ref
                  .read(planetaryViewDateProvider.notifier)
                  .setDate(DateTime.now());
            },
          ),
        ),
      ],
      // The time panel paints behind the gesture handle and pads its own
      // controls clear of it, so the canvas is left edge to edge.
      body: Stack(
        children: [
          // Main content column
          Column(
            children: [
              // Top controls row
              _buildTopControls(context, theme, l10n),

              // Solar system visualization
              Expanded(
                child: Consumer(
                  builder: (context, ref, _) {
                    final solarSystemAsync = ref.watch(solarSystemDataProvider);
                    return solarSystemAsync.when(
                      skipLoadingOnReload: true,
                      data: (data) => _buildSolarSystem(
                        context,
                        ref,
                        data,
                        isDark,
                        showZodiac: _showZodiac,
                      ),
                      loading: () => const Center(
                        child: CircularProgressIndicator.adaptive(),
                      ),
                      error: (error, _) {
                        debugPrint('Solar system data failed: $error');
                        return ErrorState(
                          message: l10n.errorLoadingData,
                          onRetry: () =>
                              ref.invalidate(solarSystemDataProvider),
                        );
                      },
                    );
                  },
                ),
              ),

              // Planet info panel (MOVED TO STACK)

              // Time slider control
              _buildTimeSlider(context, theme, l10n),
            ],
          ),

          // Zoom controls overlay
          _buildZoomControls(context, theme),

          // Planet info panel overlay
          Consumer(
            builder: (context, ref, _) {
              final selectedPlanetData = ref.watch(selectedPlanetDataProvider);
              if (selectedPlanetData == null) return const SizedBox.shrink();
              return Positioned(
                top: 100,
                right: ResponsiveLayout.value(
                  context,
                  mobile: AppSpacing.s16,
                  tablet: AppSpacing.s24,
                  desktop: AppSpacing.s32,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 300),
                  child: _buildPlanetInfoPanel(
                    context,
                    selectedPlanetData,
                    isDark,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTopControls(
    BuildContext context,
    ThemeData theme,
    AppLocalizations l10n,
  ) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: ResponsiveLayout.value(
          context,
          mobile: AppSpacing.s16,
          tablet: AppSpacing.s24,
          desktop: AppSpacing.s32,
        ),
        vertical: AppSpacing.s8,
      ),
      child: Row(
        children: [
          // View mode toggle
          _buildViewModeToggle(context, theme),
          const Spacer(),
          // Date chip
          Consumer(
            builder: (context, ref, _) {
              final viewDate = ref.watch(planetaryViewDateProvider);
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.s12,
                  vertical: AppSpacing.s6,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(AppRadius.tile),
                  border: Border.all(
                    color: theme.colorScheme.primary.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.calendar_today,
                      size: AppIconSize.inline,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: AppSpacing.s6),
                    Text(
                      formatLocalizedDate(
                        viewDate,
                        'MMM d, y',
                        l10n.localeName,
                      ),
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: AppTypography.semibold,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(width: AppSpacing.s8),
          // Zodiac Toggle
          _buildModeChip(
            context,
            label: '♈',
            tooltip: l10n.zodiacSign,
            isSelected: _showZodiac,
            onTap: () => setState(() => _showZodiac = !_showZodiac),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeSlider(
    BuildContext context,
    ThemeData theme,
    AppLocalizations l10n,
  ) {
    return Consumer(
      builder: (context, ref, _) {
        final viewDate = ref.watch(planetaryViewDateProvider);
        // Time slider spans from -1 year to +1 year
        final now = DateTime.now();
        final minDate = now.subtract(const Duration(days: 365));
        final maxDate = now.add(const Duration(days: 365));

        // Convert current date to slider value (0-730)
        final daysDiff = viewDate.difference(minDate).inDays.toDouble();
        final sliderValue = daysDiff.clamp(0.0, 730.0);

        return Container(
          padding: EdgeInsets.fromLTRB(
            ResponsiveLayout.value(
              context,
              mobile: AppSpacing.s16,
              tablet: AppSpacing.s24,
              desktop: AppSpacing.s32,
            ),
            AppSpacing.s8,
            ResponsiveLayout.value(
              context,
              mobile: AppSpacing.s16,
              tablet: AppSpacing.s24,
              desktop: AppSpacing.s32,
            ),
            // The panel now runs to the bottom edge of the screen (the body no
            // longer insets it), so its own controls carry the gesture-bar
            // clearance while the rounded surface paints behind the handle.
            16 + AppTheme.navigationBarInset(context),
          ),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface.withValues(alpha: 0.8),
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppRadius.card),
            ),
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
                margin: const EdgeInsets.only(bottom: AppSpacing.s12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(AppRadius.micro),
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
                    tooltip: l10n.back30Days,
                    onPressed: () => _adjustDate(-30),
                  ),
                  // Backward (1 day)
                  _buildTimeButton(
                    context,
                    icon: Icons.skip_previous_rounded,
                    tooltip: l10n.back1Day,
                    onPressed: () => _adjustDate(-1),
                  ),
                  const SizedBox(width: AppSpacing.s8),
                  // Today button
                  FilledButton.icon(
                    onPressed: () {
                      ref
                          .read(planetaryViewDateProvider.notifier)
                          .setDate(DateTime.now());
                    },
                    icon: const Icon(Icons.today, size: AppIconSize.dense),
                    label: Text(l10n.today),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.s16,
                        vertical: AppSpacing.s8,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s8),
                  // Forward (1 day)
                  _buildTimeButton(
                    context,
                    icon: Icons.skip_next_rounded,
                    tooltip: l10n.forward1Day,
                    onPressed: () => _adjustDate(1),
                  ),
                  // Fast forward (1 month)
                  _buildTimeButton(
                    context,
                    icon: Icons.fast_forward_rounded,
                    tooltip: l10n.forward30Days,
                    onPressed: () => _adjustDate(30),
                  ),
                ],
              ),

              const SizedBox(height: AppSpacing.s2),

              // Animation Controls
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.s12,
                  vertical: AppSpacing.s4,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(AppRadius.round),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(
                        _isAnimating
                            ? Icons.pause_circle_filled
                            : Icons.play_circle_fill,
                      ),
                      iconSize: AppIconSize.hero,
                      color: theme.colorScheme.primary,
                      onPressed: _toggleAnimation,
                      tooltip: _isAnimating
                          ? l10n.pauseAnimation
                          : l10n.playAnimation,
                    ),
                    if (_isAnimating) ...[
                      const SizedBox(width: AppSpacing.s8),
                      Text(
                        '${l10n.speedLabel}:',
                        style: theme.textTheme.labelSmall,
                      ),
                      SizedBox(
                        width: 100,
                        child: Slider(
                          value: _animationSpeed,
                          min: 0.1,
                          max: 5.0,
                          divisions: 10,
                          label: '${_animationSpeed.toStringAsFixed(1)}x',
                          onChanged: (val) =>
                              setState(() => _animationSpeed = val),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.s2),

              // Slider
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 4,
                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 8,
                  ),
                  overlayShape: const RoundSliderOverlayShape(
                    overlayRadius: 16,
                  ),
                  activeTrackColor: theme.colorScheme.primary,
                  inactiveTrackColor: theme.colorScheme.primary.withValues(
                    alpha: 0.2,
                  ),
                  thumbColor: theme.colorScheme.primary,
                  overlayColor: theme.colorScheme.primary.withValues(
                    alpha: 0.2,
                  ),
                ),
                child: Slider(
                  value: sliderValue,
                  max: 730,
                  onChanged: (value) {
                    final newDate = minDate.add(Duration(days: value.round()));
                    ref
                        .read(planetaryViewDateProvider.notifier)
                        .setDate(newDate);
                  },
                ),
              ),

              // Date labels
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      formatLocalizedDate(minDate, 'MMM y', l10n.localeName),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: context.hintInk,
                      ),
                    ),
                    Text(
                      l10n.today,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: AppTypography.bold,
                      ),
                    ),
                    Text(
                      formatLocalizedDate(maxDate, 'MMM y', l10n.localeName),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: context.hintInk,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTimeButton(
    BuildContext context, {
    required IconData icon,
    required VoidCallback onPressed,
    required String tooltip,
  }) {
    final theme = Theme.of(context);
    return IconButton(
      onPressed: onPressed,
      tooltip: tooltip,
      icon: Icon(icon),
      iconSize: AppIconSize.title,
      color: theme.colorScheme.primary,
      style: IconButton.styleFrom(
        backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
      ),
    );
  }

  void _adjustDate(double days) {
    final currentDate = ref.read(planetaryViewDateProvider);
    // Convert days (double) to Duration (microseconds for precision)
    final micros = (days * 24 * 60 * 60 * 1000 * 1000).round();
    ref
        .read(planetaryViewDateProvider.notifier)
        .setDate(currentDate.add(Duration(microseconds: micros)));
  }

  Widget _buildZoomControls(BuildContext context, ThemeData theme) {
    final l10n = AppLocalizations.of(context)!;
    return Positioned(
      // Offset from the stack's bottom, which now runs to the screen edge, so
      // the gesture inset is added back to keep the same visual clearance from
      // the time panel.
      bottom: 210 + AppTheme.navigationBarInset(context),
      right: ResponsiveLayout.value(
        context,
        mobile: AppSpacing.s16,
        tablet: AppSpacing.s24,
        desktop: AppSpacing.s32,
      ),
      child: Column(
        // Vertical column for better mobile ergonomics
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.small(
            heroTag: 'zoom_in',
            onPressed: () {
              final currentZoom =
                  (ref.read(zoomLevelProvider) as num?)?.toDouble() ?? 1.0;
              final newZoom = (currentZoom + 0.25).clamp(0.5, 3.0);
              ref.read(zoomLevelProvider.notifier).setZoom(newZoom);
              if (newZoom == 1.0 && _panOffset != Offset.zero) {
                setState(() => _panOffset = Offset.zero);
              }
            },
            tooltip: l10n.zoomIn,
            child: const Icon(Icons.add),
          ),
          const SizedBox(height: AppSpacing.s8),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.s8,
              vertical: AppSpacing.s4,
            ),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(AppRadius.dense),
            ),
            child: Text(
              '${(((ref.watch(zoomLevelProvider) as num?)?.toDouble() ?? 1.0) * 100).round()}%',
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: AppTypography.bold,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.s8),
          FloatingActionButton.small(
            heroTag: 'zoom_out',
            onPressed: () {
              final currentZoom =
                  (ref.read(zoomLevelProvider) as num?)?.toDouble() ?? 1.0;
              final newZoom = (currentZoom - 0.25).clamp(0.5, 3.0);
              ref.read(zoomLevelProvider.notifier).setZoom(newZoom);
              if (newZoom == 1.0 && _panOffset != Offset.zero) {
                setState(() => _panOffset = Offset.zero);
              }
            },
            tooltip: l10n.zoomOut,
            child: const Icon(Icons.remove),
          ),
        ],
      ),
    );
  }

  Widget _buildSolarSystem(
    BuildContext context,
    WidgetRef ref,
    SolarSystemData data,
    bool isDark, {
    required bool showZodiac,
  }) {
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
          panOffset: _panOffset,
        );

        return Semantics(
          label: AppLocalizations.of(context)!.planetPositions,
          button: true,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanUpdate: (details) {
              if (zoomLevel <= 1.0) return;
              setState(() => _panOffset += details.delta);
            },
            onTapDown: (details) {
              final hitIndex = hitTester.hitTest(details.localPosition);
              if (hitIndex != null) {
                ref
                    .read(selectedPlanetProvider.notifier)
                    .setPlanet(data.planets[hitIndex].planet);
              } else {
                ref.read(selectedPlanetProvider.notifier).setPlanet(null);
              }
            },
            // Two cached layers (Phase 6a): the static background paints
            // once per configuration change; only the planet layer
            // repaints every data frame during animation.
            child: Stack(
              fit: StackFit.expand,
              children: [
                RepaintBoundary(
                  child: CustomPaint(
                    size: size,
                    painter: SolarSystemStaticPainter(
                      viewMode: data.viewMode,
                      isDark: isDark,
                      zoomLevel: zoomLevel,
                      showZodiac: showZodiac,
                      panOffset: _panOffset,
                    ),
                  ),
                ),
                RepaintBoundary(
                  child: CustomPaint(
                    size: size,
                    painter: SolarSystemPainter(
                      solarSystemData: data,
                      selectedPlanetIndex: selectedIndex,
                      zoomLevel: zoomLevel,
                      panOffset: _panOffset,
                    ),
                  ),
                ),
              ],
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
      margin: const EdgeInsets.all(AppSpacing.s16),
      padding: const EdgeInsets.all(AppSpacing.s16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.round),
        border: Border.all(color: planetColor.withValues(alpha: 0.3), width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
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
              const SizedBox(width: AppSpacing.s12),
              Text(
                PlanetaryViewService.getPlanetDisplayName(planetData.planet),
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: AppTypography.bold,
                ),
              ),
              if (planetData.isRetrograde) ...[
                const SizedBox(width: AppSpacing.s8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.s8,
                    vertical: AppSpacing.s2,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.retrogradeIndicator.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(AppRadius.chip),
                    border: Border.all(
                      color: AppTheme.retrogradeIndicator.withValues(
                        alpha: 0.5,
                      ),
                    ),
                  ),
                  child: Text(
                    l10n.retrograde,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppTheme.retrogradeIndicator,
                      fontWeight: AppTypography.bold,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.s16),

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
            const SizedBox(height: AppSpacing.s12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildInfoItem(
                  context,
                  icon: Icons.straighten_outlined,
                  label: l10n.distance,
                  value:
                      '${planetData.distanceAU! < 0.1 ? planetData.distanceAU!.toStringAsFixed(4) : planetData.distanceAU!.toStringAsFixed(2)} AU',
                ),
                if (planetData.orbitalPeriodDays != null &&
                    planetData.orbitalPeriodDays! > 0)
                  _buildInfoItem(
                    context,
                    icon: Icons.timelapse,
                    label: l10n.orbit,
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
        Icon(icon, size: AppIconSize.medium, color: theme.colorScheme.primary),
        const SizedBox(height: AppSpacing.s4),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: context.secondaryInk,
          ),
        ),
        const SizedBox(height: AppSpacing.s2),
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: AppTypography.bold,
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
        borderRadius: BorderRadius.circular(AppRadius.round),
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
            tooltip: AppLocalizations.of(context)!.heliocentric,
            isSelected: isHeliocentric,
            onTap: () => ref
                .read(solarSystemViewModeProvider.notifier)
                .setViewMode(SolarSystemViewMode.heliocentric),
          ),
          _buildModeChip(
            context,
            label: '🌍',
            tooltip: AppLocalizations.of(context)!.geocentric,
            isSelected: !isHeliocentric,
            onTap: () => ref
                .read(solarSystemViewModeProvider.notifier)
                .setViewMode(SolarSystemViewMode.geocentric),
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
      child: Semantics(
        button: true,
        label: tooltip,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(AppRadius.tile),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.s12,
                vertical: AppSpacing.s6,
              ),
              decoration: BoxDecoration(
                color: isSelected
                    ? theme.colorScheme.primary.withValues(alpha: 0.2)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(AppRadius.tile),
              ),
              child: Text(
                label,
                style: const TextStyle(fontSize: AppTypography.sizeHeading),
              ),
            ),
          ),
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
      ref.read(planetaryViewDateProvider.notifier).setDate(selectedDate);
    }
  }
}
