import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/accessibility_provider.dart';
import '../providers/moon_phase_provider.dart';
import '../providers/panchang_provider.dart';
import '../services/moon_phase_service.dart';
import '../l10n/app_localizations.dart';
import '../widgets/moon_animation_widget.dart';
import '../theme/app_theme.dart';

/// Scrub offset in days from today for the hero moon. 0 = today.
final moonScrubOffsetProvider = StateProvider.autoDispose<int>((ref) => 0);

/// Scrub range in days. Panchang month batches are Hive-cached, so stepping
/// through these dates stays cheap (no per-step ephemeris work).
const int moonScrubRangeDays = 15;

/// Clamps a scrub offset into the supported range.
int clampMoonScrubOffset(int value) =>
    value.clamp(-moonScrubRangeDays, moonScrubRangeDays);

/// Full-screen moon phases view with detailed countdown and upcoming dates
class MoonPhasesScreen extends ConsumerStatefulWidget {
  const MoonPhasesScreen({super.key});

  @override
  ConsumerState<MoonPhasesScreen> createState() => _MoonPhasesScreenState();
}

class _MoonPhasesScreenState extends ConsumerState<MoonPhasesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  double _dragAccum = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    // Timer moved to _CountdownCard to avoid rebuilding entire screen every second
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  /// Accumulates horizontal drag distance into whole-day scrub steps.
  void _scrubBy(double dx) {
    _dragAccum += dx;
    const pixelsPerDay = 28.0;
    final steps = (_dragAccum / pixelsPerDay).truncate();
    if (steps == 0) return;
    _dragAccum -= steps * pixelsPerDay;
    final current = ref.read(moonScrubOffsetProvider);
    final next = clampMoonScrubOffset(current + steps);
    if (next != current) {
      ref.read(moonScrubOffsetProvider.notifier).state = next;
    }
  }

  /// Snaps the hero moon back to today.
  void _resetScrub() {
    _dragAccum = 0;
    if (ref.read(moonScrubOffsetProvider) != 0) {
      if (ref.read(accessibilityProvider).hapticFeedback) {
        HapticFeedback.lightImpact();
      }
      ref.read(moonScrubOffsetProvider.notifier).state = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final moonPhaseAsync = ref.watch(moonPhaseDataProvider);
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(l10n.moonPhases),
        backgroundColor: Colors.transparent,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          dividerColor: Colors.transparent,
          tabs: [
            Tab(text: l10n.purnima),
            Tab(text: l10n.amavasya),
          ],
          indicatorColor: theme.colorScheme.primary,
          labelColor: theme.colorScheme.primary,
          unselectedLabelColor: theme.colorScheme.onSurface.withValues(
            alpha: 0.6,
          ),
        ),
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
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800),
                child: moonPhaseAsync.when(
                  data: (data) => _buildContent(context, data, l10n, isDark),
                  loading: () =>
                      const Center(child: CircularProgressIndicator.adaptive()),
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
                          onPressed: () => ref.refresh(moonPhaseDataProvider),
                          child: Text(l10n.retry),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    MoonPhaseData data,
    AppLocalizations l10n,
    bool isDark,
  ) {
    // Scrubbed day: stale-while-reloading keeps moon, labels and illumination
    // self-consistent while the next day's panchang resolves (same pattern
    // as the Daily Wisdom card).
    final offset = ref.watch(moonScrubOffsetProvider);
    final now = DateTime.now();
    final shownDate = DateTime(now.year, now.month, now.day + offset);
    final dayPanchang = ref
        .watch(panchangForDateProvider(shownDate))
        .valueOrNull;
    final bool shownWaxing = dayPanchang != null
        ? dayPanchang.paksha == 'Shukla'
        : data.isShukla;
    // Painter phase is a lit fraction (0 = new, 1 = full), not a day count.
    final double targetPhase = dayPanchang != null
        ? MoonPhaseService.illuminationFractionForDay(
            tithiNumber: dayPanchang.tithiNumber,
            isShukla: shownWaxing,
            rawTithi: dayPanchang.rawTithi,
          )
        : ref
                  .read(moonPhaseServiceProvider)
                  .getMoonIllumination(data.currentTithi) /
              100.0;
    final double illumination01 = targetPhase;

    return Column(
      children: [
        const SizedBox(height: 16),
        // Scrubbable moon visualization - wrapped in RepaintBoundary for performance
        RepaintBoundary(
          child: Semantics(
            label: l10n.currentMoonPhase,
            child: Listener(
              key: const ValueKey('moon-scrub-area'),
              // Raw pointer moves (not a drag recognizer): they bypass the
              // gesture arena, so scrubbing coexists with the double-tap
              // reset. A HorizontalDragGestureRecognizer starves here —
              // the double-tap tracker holds the arena and drag updates
              // never resolve.
              behavior: HitTestBehavior.opaque,
              onPointerMove: (event) => _scrubBy(event.delta.dx),
              onPointerUp: (_) => _dragAccum = 0,
              onPointerCancel: (_) => _dragAccum = 0,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onDoubleTap: _resetScrub,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      height: 168,
                      width: 168,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.moonGlowLight.withValues(
                              alpha: 0.10 + 0.40 * illumination01,
                            ),
                            blurRadius: 24 + 36 * illumination01,
                          ),
                        ],
                      ),
                      child: Hero(
                        tag: 'moon_icon',
                        child: TweenAnimationBuilder<double>(
                          duration: AppTheme.animationDuration(
                            context,
                            const Duration(milliseconds: 350),
                          ),
                          tween: Tween<double>(end: targetPhase),
                          builder: (context, phase, _) => MoonAnimationWidget(
                            phase: phase,
                            isWaxing: shownWaxing,
                            size: 168,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      offset == 0
                          ? l10n.today
                          : DateFormat.yMMMd().format(shownDate),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.5),
                        letterSpacing: 0.5,
                      ),
                    ),
                    // Fixed-height slot: swapping tithi/hint/empty while
                    // scrubbing must not move the content below.
                    SizedBox(
                      height: 28,
                      child: Center(
                        child: dayPanchang != null
                            ? Text(
                                '${dayPanchang.tithiName} • ${dayPanchang.paksha}',
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w600),
                              )
                            : offset == 0
                            ? Text(
                                'Drag to explore • Double-tap resets',
                                style: Theme.of(context).textTheme.labelSmall
                                    ?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface
                                          .withValues(alpha: 0.4),
                                    ),
                              )
                            : null,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        // Precise illumination percentage
        Text(
          'Illumination: ${(illumination01 * 100).toStringAsFixed(1)}%',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.8),
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 24),
        // Main countdown cards
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: _CountdownCard(
                  title: l10n.purnima,
                  subtitle: l10n.fullMoon,
                  targetDate: data.nextPurnima,
                  icon: Icons.circle,
                  color: AppTheme.purnimaIconColor(isDark),
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _CountdownCard(
                  title: l10n.amavasya,
                  subtitle: l10n.newMoon,
                  targetDate: data.nextAmavasya,
                  icon: Icons.circle_outlined,
                  color: AppTheme.amavasyaIconColor(isDark),
                  isDark: isDark,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        // Tab content - upcoming dates
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _UpcomingDatesTab(
                provider: upcomingPurnimasProvider,
                emptyMessage: l10n.noUpcomingDates,
                isDark: isDark,
              ),
              _UpcomingDatesTab(
                provider: upcomingAmavasyasProvider,
                emptyMessage: l10n.noUpcomingDates,
                isDark: isDark,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Countdown card with its own Timer for performance optimization.
/// Only rebuilds itself, not the entire screen.
class _CountdownCard extends StatefulWidget {
  const _CountdownCard({
    required this.title,
    required this.subtitle,
    required this.targetDate,
    required this.icon,
    required this.color,
    required this.isDark,
  });

  final String title;
  final String subtitle;
  final DateTime targetDate;
  final IconData icon;
  final Color color;
  final bool isDark;

  @override
  State<_CountdownCard> createState() => _CountdownCardState();
}

class _CountdownCardState extends State<_CountdownCard> {
  Timer? _timer;
  late Duration _countdown;

  @override
  void initState() {
    super.initState();
    _updateCountdown();
    // Update countdown every second - only rebuilds this card, not the whole screen
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        _updateCountdown();
        setState(() {});
      }
    });
  }

  void _updateCountdown() {
    _countdown = widget.targetDate.difference(DateTime.now());
  }

  @override
  void didUpdateWidget(_CountdownCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.targetDate != widget.targetDate) {
      _updateCountdown();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: widget.isDark
              ? [
                  AppTheme.spaceStar.withValues(alpha: 0.1),
                  AppTheme.spaceStar.withValues(alpha: 0.05),
                ]
              : [
                  AppTheme.spaceStar.withValues(alpha: 0.8),
                  AppTheme.spaceStar.withValues(alpha: 0.5),
                ],
        ),
        border: Border.all(color: AppTheme.moonCountdownBorder(widget.isDark)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(widget.icon, color: widget.color, size: 20),
              const SizedBox(width: 8),
              Text(
                widget.title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            widget.subtitle,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 12),
          // Countdown display
          _buildCountdownDisplay(context, l10n),
          const SizedBox(height: 8),
          Text(
            DateFormat.yMMMd().format(widget.targetDate),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCountdownDisplay(BuildContext context, AppLocalizations l10n) {
    final theme = Theme.of(context);

    if (_countdown.isNegative) {
      return Text(
        l10n.now,
        style: theme.textTheme.headlineMedium?.copyWith(
          fontWeight: FontWeight.bold,
          color: widget.color,
        ),
      );
    }

    final days = _countdown.inDays;
    final hours = _countdown.inHours % 24;
    final minutes = _countdown.inMinutes % 60;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (days > 0) ...[
          _TimeUnit(value: days, unit: 'd'),
          const SizedBox(width: 6),
        ],
        _TimeUnit(value: hours, unit: 'h'),
        const SizedBox(width: 6),
        _TimeUnit(value: minutes, unit: 'm'),
      ],
    );
  }
}

class _TimeUnit extends StatelessWidget {
  const _TimeUnit({required this.value, required this.unit});

  final int value;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Text(
          value.toString().padLeft(2, '0'),
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          unit,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }
}

class _UpcomingDatesTab extends ConsumerWidget {
  const _UpcomingDatesTab({
    required this.provider,
    required this.emptyMessage,
    required this.isDark,
  });

  final FutureProvider<List<DateTime>> provider;
  final String emptyMessage;
  final bool isDark;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final datesAsync = ref.watch(provider);
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return datesAsync.when(
      data: (dates) {
        if (dates.isEmpty) {
          return Center(child: Text(emptyMessage));
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: dates.length,
          itemBuilder: (context, index) {
            final date = dates[index];
            final now = DateTime.now();
            final daysUntil = date.difference(now).inDays;

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: isDark
                    ? AppTheme.spaceStar.withValues(alpha: 0.05)
                    : AppTheme.spaceStar.withValues(alpha: 0.6),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          DateFormat.yMMMMEEEEd().format(date),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          DateFormat.jm().format(date),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.6,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      color: (isDark
                              ? AppTheme.moonGlowDark
                              : AppTheme.moonGlowLight)
                          .withValues(alpha: 0.3),
                    ),
                    child: Text(
                      daysUntil == 0
                          ? l10n.today
                          : daysUntil == 1
                          ? l10n.tomorrow
                          : l10n.daysFromNow(daysUntil),
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator.adaptive()),
      error: (_, _) => Center(child: Text(emptyMessage)),
    );
  }
}
