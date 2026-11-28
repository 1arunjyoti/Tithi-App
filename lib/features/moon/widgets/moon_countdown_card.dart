import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../../../l10n/app_localizations.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/app_metrics.dart';
import '../../../theme/app_typography.dart';
import '../../../utils/tithi_localization.dart';

/// Countdown to the next Purnima or Amavasya, with its own 1-second timer so
/// the rest of the screen is not rebuilt every tick.
class MoonCountdownCard extends StatefulWidget {
  const MoonCountdownCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.targetDate,
    required this.icon,
    required this.color,
    required this.isDark,
    this.eventName,
    this.highlight,
  });

  final String title;
  final String subtitle;
  final DateTime targetDate;
  final IconData icon;
  final Color color;
  final bool isDark;

  /// Traditional full-moon name (Wolf Moon, Sharad Purnima, ...).
  final String? eventName;

  /// Extra tag such as "Blue Moon".
  final String? highlight;

  @override
  State<MoonCountdownCard> createState() => _MoonCountdownCardState();
}

class _MoonCountdownCardState extends State<MoonCountdownCard> {
  Timer? _timer;
  late Duration _countdown;

  @override
  void initState() {
    super.initState();
    _updateCountdown();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        _updateCountdown();
        setState(() {});
      }
    });
  }

  void _updateCountdown() =>
      _countdown = widget.targetDate.difference(DateTime.now());

  @override
  void didUpdateWidget(MoonCountdownCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.targetDate != widget.targetDate) _updateCountdown();
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
      padding: const EdgeInsets.all(AppSpacing.s16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
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
              Icon(widget.icon, color: widget.color, size: AppIconSize.medium),
              const SizedBox(width: AppSpacing.s8),
              Text(
                widget.title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: AppTypography.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s4),
          Text(
            widget.eventName ?? widget.subtitle,
            style: theme.textTheme.bodySmall?.copyWith(
              color: context.secondaryInk,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (widget.highlight != null) ...[
            const SizedBox(height: AppSpacing.s4),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.s8,
                vertical: AppSpacing.s2,
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.tile),
                color:
                    (widget.isDark
                            ? AppTheme.moonGlowDark
                            : AppTheme.moonGlowLight)
                        .withValues(alpha: 0.3),
              ),
              child: Text(
                widget.highlight!,
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: AppTypography.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.s12),
          _buildCountdownDisplay(context, l10n),
          const SizedBox(height: AppSpacing.s8),
          Text(
            formatLocalizedDate(widget.targetDate, 'yMMMd', l10n.localeName),
            style: theme.textTheme.bodySmall?.copyWith(
              color: context.secondaryInk,
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
          fontWeight: AppTypography.bold,
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
          _TimeUnit(value: days, unit: l10n.dayUnitShort),
          const SizedBox(width: AppSpacing.s6),
        ],
        _TimeUnit(value: hours, unit: l10n.hourUnitShort),
        const SizedBox(width: AppSpacing.s6),
        _TimeUnit(value: minutes, unit: l10n.minuteUnitShort),
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
            fontWeight: AppTypography.bold,
          ),
        ),
        Text(
          unit,
          style: theme.textTheme.bodySmall?.copyWith(
            color: context.secondaryInk,
          ),
        ),
      ],
    );
  }
}
