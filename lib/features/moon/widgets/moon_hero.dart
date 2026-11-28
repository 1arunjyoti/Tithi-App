import 'package:material_ui/material_ui.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/feedback/app_haptics.dart';
import '../../../l10n/app_localizations.dart';
import '../../../providers/panchang_provider.dart';
import '../../../services/moon_phase_service.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/app_metrics.dart';
import '../../../theme/app_typography.dart';
import '../../../widgets/app_buttons.dart';
import '../../../widgets/moon_animation_widget.dart';
import '../domain/full_moon_names.dart';
import '../providers/moon_details_providers.dart';
import '../providers/moon_providers.dart';

/// Scrubbable hero moon with the selected date's phase, age and illumination.
class MoonHero extends ConsumerStatefulWidget {
  const MoonHero({super.key, required this.isDark});

  final bool isDark;

  @override
  ConsumerState<MoonHero> createState() => _MoonHeroState();
}

class _MoonHeroState extends ConsumerState<MoonHero> {
  double _dragAccum = 0;

  /// Accumulates horizontal drag distance into whole-day scrub steps.
  void _scrubBy(double dx) {
    _dragAccum += dx;
    const pixelsPerDay = 28.0;
    final steps = (_dragAccum / pixelsPerDay).truncate();
    if (steps == 0) return;
    _dragAccum -= steps * pixelsPerDay;
    final current = ref.read(moonScrubOffsetProvider);
    // A date picked far from today is scrubbed one day at a time; the ±15-day
    // clamp only applies near today where panchang batches are cached.
    final delta = current.abs() > moonScrubRangeDays
        ? steps
        : clampMoonScrubOffset(current + steps) - current;
    if (delta != 0) {
      ref.read(moonSelectedDateProvider.notifier).stepDays(delta);
    }
  }

  void _resetScrub() {
    _dragAccum = 0;
    if (ref.read(moonScrubOffsetProvider) != 0) {
      AppHaptics.tap(ref);
      ref.read(moonSelectedDateProvider.notifier).resetToToday();
    }
  }

  Future<void> _pickDate(DateTime initial) async {
    final picked = await M3EDatePicker.show(
      context,
      initialDate: initial,
      firstDate: DateTime(1900),
      lastDate: DateTime(2100),
    );
    if (picked == null || !mounted) return;
    AppHaptics.tap(ref);
    ref.read(moonSelectedDateProvider.notifier).setDate(picked);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final selected = ref.watch(moonSelectedDateProvider);
    final offset = ref.watch(moonScrubOffsetProvider);
    final dayPanchang = ref
        .watch(panchangForDateProvider(selected))
        .valueOrNull;
    final shownWaxing = dayPanchang?.paksha == 'Shukla';
    final targetPhase = dayPanchang != null
        ? MoonPhaseService.illuminationFractionForDay(
            tithiNumber: dayPanchang.tithiNumber,
            isShukla: shownWaxing,
            rawTithi: dayPanchang.rawTithi,
          )
        : 0.0;
    final stage = moonPhaseStage(targetPhase, shownWaxing);
    final age = dayPanchang == null ? null : lunarAgeDays(dayPanchang.rawTithi);
    // A pale surface needs a little less bloom to keep the rim crisp.
    final glowStrength = widget.isDark ? 1.0 : 0.82;

    return Column(
      children: [
        RepaintBoundary(
          child: Semantics(
            label: l10n.currentMoonPhase,
            child: Listener(
              key: const ValueKey('moon-scrub-area'),
              // Raw pointer moves bypass the gesture arena so scrubbing
              // coexists with the double-tap reset.
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
                    // The halo is painted *inside* this box and fades to
                    // transparent at its edge. A BoxShadow would be painted
                    // outside the 168px disc and clipped by the scroll
                    // viewport just below the app bar, leaving a hard edge.
                    Container(
                      key: const ValueKey('moon-halo'),
                      height: 168 + 2 * AppSpacing.s32,
                      width: 168 + 2 * AppSpacing.s32,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          // A layered bloom: warm core, a bright rim just
                          // outside the disc (0.724 of this radius), then a
                          // faint cool scatter fading into the sky.
                          colors: [
                            AppTheme.moonGlowCore.withValues(
                              alpha: (0.18 + 0.24 * targetPhase) * glowStrength,
                            ),
                            AppTheme.moonGlowRim.withValues(
                              alpha: (0.08 + 0.12 * targetPhase) * glowStrength,
                            ),
                            AppTheme.moonGlowRim.withValues(
                              alpha: (0.18 + 0.20 * targetPhase) * glowStrength,
                            ),
                            AppTheme.moonGlowScatter.withValues(
                              alpha: (0.04 + 0.08 * targetPhase) * glowStrength,
                            ),
                            Colors.transparent,
                          ],
                          stops: const [0.0, 0.62, 0.74, 0.86, 1.0],
                        ),
                      ),
                      child: Center(
                        child: SizedBox(
                          height: 168,
                          width: 168,
                          child: Hero(
                            tag: 'moon_icon',
                            child: MoonAnimationWidget(
                              phase: targetPhase,
                              isWaxing: shownWaxing,
                              size: 168,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s8),
                    Text(
                      offset == 0
                          ? l10n.today
                          : DateFormat.yMMMd().format(selected),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: context.hintInk,
                        letterSpacing: 0.5,
                      ),
                    ),
                    SizedBox(
                      height: 28,
                      child: Center(
                        child: dayPanchang != null
                            ? Text(
                                '${dayPanchang.tithiName} • ${dayPanchang.paksha}',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: AppTypography.semibold,
                                ),
                              )
                            : offset == 0
                            ? Text(
                                l10n.moonScrubHint,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: context.hintInk,
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
        if (dayPanchang != null)
          Text(
            moonPhaseStageName(stage, l10n),
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: AppTypography.semibold,
            ),
          ),
        if (age != null)
          Text(
            l10n.moonAge(age.toStringAsFixed(1)),
            style: theme.textTheme.bodySmall?.copyWith(
              color: context.secondaryInk,
            ),
          ),
        if (dayPanchang != null &&
            targetPhase >= 0.98 &&
            dayPanchang.masa.isNotEmpty)
          Text(
            indianFullMoonName(dayPanchang.masa, l10n),
            style: theme.textTheme.labelMedium?.copyWith(
              color: context.secondaryInk,
            ),
          ),
        const SizedBox(height: AppSpacing.s8),
        Text(
          l10n.moonIllumination((targetPhase * 100).toStringAsFixed(1)),
          style: theme.textTheme.titleMedium?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
            fontWeight: AppTypography.medium,
          ),
        ),
        const SizedBox(height: AppSpacing.s8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AppButton(
              key: const ValueKey('moon-choose-date'),
              style: M3EButtonStyle.text,
              onPressed: () => _pickDate(selected),
              icon: const Icon(
                Icons.calendar_month_outlined,
                size: AppIconSize.dense,
              ),
              label: Text(l10n.chooseMoonDate),
            ),
            if (offset != 0)
              AppIconButton(
                key: const ValueKey('moon-reset-today'),
                haptic: false, // the callback already buzzes
                tooltip: l10n.today,
                onPressed: () {
                  AppHaptics.tap(ref);
                  ref.read(moonSelectedDateProvider.notifier).resetToToday();
                },
                icon: const Icon(
                  Icons.today_outlined,
                  size: AppIconSize.medium,
                ),
              ),
          ],
        ),
      ],
    );
  }
}
