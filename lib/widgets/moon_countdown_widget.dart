import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/moon_phase_provider.dart';
import '../services/moon_phase_service.dart';
import '../core/navigation/app_routes.dart';
import '../screens/moon_phases_screen.dart';
import '../l10n/app_localizations.dart';
import '../theme/app_theme.dart';
import 'moon_animation_widget.dart';

/// Compact widget showing countdown to next Amavasya and Purnima
/// Designed for integration into the home screen
class MoonCountdownWidget extends ConsumerWidget {
  const MoonCountdownWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final moonPhaseAsync = ref.watch(moonPhaseDataProvider);
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return GestureDetector(
      onTap: () {
        // Fade through (not shared-X slide): back lands directly on
        // home, so pop fades instead of sliding out over the home card.
        // The 'moon_icon' Hero flight still runs on top of the fade.
        AppRoutes.pushFadeThrough(context, const MoonPhasesScreen());
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: AppTheme.moonCountdownGradient(isDark),
          ),
          border: Border.all(color: AppTheme.moonCountdownBorder(isDark)),
          boxShadow: [
            BoxShadow(
              color: AppTheme.moonCountdownShadow(isDark),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: moonPhaseAsync.when(
          data: (data) => _buildContent(context, data, l10n, isDark),
          loading: () => const Center(
            child: SizedBox(
              height: 60,
              child: CircularProgressIndicator.adaptive(),
            ),
          ),
          error: (e, _) => Center(
            child: Text(
              'Unable to load moon phase data',
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    MoonPhaseData data,
    AppLocalizations l10n,
    bool isDark,
  ) {
    final theme = Theme.of(context);
    // Same widget type as the MoonPhasesScreen destination so the
    // 'moon_icon' Hero flight scales moon-to-moon instead of morphing
    // Icon -> CustomPaint (which flashed mid-push).
    final phase =
        (MoonPhaseService.illuminationForTithi(data.currentTithi) / 100.0)
            .clamp(0.0, 1.0);

    return Row(
      children: [
        // Moon icon
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: AppTheme.moonDiscGradient(isDark),
            ),
            boxShadow: [
              BoxShadow(
                color: AppTheme.moonGlowColor(isDark),
                blurRadius: 16,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Hero(
            tag: 'moon_icon',
            // Shuttle the source appearance during flight: the destination
            // contains a TweenAnimationBuilder that would otherwise keep
            // animating mid-flight while the hero scales 32 -> 168.
            flightShuttleBuilder:
                (
                  flightContext,
                  animation,
                  flightDirection,
                  fromHeroContext,
                  toHeroContext,
                ) => Material(
                  type: MaterialType.transparency,
                  child:
                      flightDirection == HeroFlightDirection.push
                          ? toHeroContext.widget
                          : fromHeroContext.widget,
                ),
            child: MoonAnimationWidget(
              phase: phase,
              isWaxing: data.isShukla,
              size: 32,
            ),
          ),
        ),
        const SizedBox(width: 16),
        // Countdown info
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Next Purnima
              _CountdownRow(
                label: l10n.nextPurnima,
                countdown: data.purnimaCountdown,
                icon: Icons.circle,
                iconColor: AppTheme.purnimaIconColor(isDark),
              ),
              const SizedBox(height: 8),
              // Next Amavasya
              _CountdownRow(
                label: l10n.nextAmavasya,
                countdown: data.amavasyaCountdown,
                icon: Icons.circle_outlined,
                iconColor: AppTheme.amavasyaIconColor(isDark),
              ),
            ],
          ),
        ),
        // Chevron
        Icon(
          Icons.chevron_right,
          color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
        ),
      ],
    );
  }
}

class _CountdownRow extends StatelessWidget {
  const _CountdownRow({
    required this.label,
    required this.countdown,
    required this.icon,
    required this.iconColor,
  });

  final String label;
  final Duration countdown;
  final IconData icon;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Icon(icon, size: 14, color: iconColor),
        const SizedBox(width: 6),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
        const Spacer(),
        _LiveCountdownText(targetDate: DateTime.now().add(countdown)),
      ],
    );
  }
}

class _LiveCountdownText extends StatefulWidget {
  final DateTime targetDate;

  const _LiveCountdownText({required this.targetDate});

  @override
  State<_LiveCountdownText> createState() => _LiveCountdownTextState();
}

class _LiveCountdownTextState extends State<_LiveCountdownText> {
  Timer? _timer;
  late Duration _countdown;

  @override
  void initState() {
    super.initState();
    _updateCountdown();
    // Update just this text every minute
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) {
        setState(() {
          _updateCountdown();
        });
      }
    });
  }

  void _updateCountdown() {
    _countdown = widget.targetDate.difference(DateTime.now());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = _formatCountdown(_countdown);
    // Cross-fade on minute ticks instead of a hard text cut.
    return AnimatedSwitcher(
      duration: AppTheme.animationDuration(
        context,
        const Duration(milliseconds: 250),
      ),
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.3),
            end: Offset.zero,
          ).animate(animation),
          child: child,
        ),
      ),
      child: Text(
        label,
        key: ValueKey(label),
        style: theme.textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.bold,
          color: theme.colorScheme.onSurface,
        ),
      ),
    );
  }

  String _formatCountdown(Duration duration) {
    if (duration.isNegative) {
      return 'Now';
    }

    final days = duration.inDays;
    final hours = duration.inHours % 24;

    if (days > 0) {
      return '${days}d ${hours}h';
    } else {
      final minutes = duration.inMinutes % 60;
      return '${hours}h ${minutes}m';
    }
  }
}
