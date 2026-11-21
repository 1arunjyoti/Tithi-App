import 'package:material_ui/material_ui.dart';

import '../../../core/anim/press_scale.dart';
import '../../../l10n/app_localizations.dart';
import '../../../theme/app_metrics.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/app_typography.dart';

/// Bottom pill bar: previous-day / expand-toggle / next-day. The toggle's
/// visible label names its state (also what screen readers announce),
/// localized the same way as the translations toggle.
class QuoteControlBar extends StatelessWidget {
  const QuoteControlBar({
    super.key,
    required this.atPastBound,
    required this.atToday,
    required this.isExpanded,
    required this.onPrevious,
    required this.onNext,
    required this.onToggleExpanded,
  });

  final bool atPastBound;
  final bool atToday;
  final bool isExpanded;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onToggleExpanded;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final accent = AppTheme.festivalAccent(context);
    final onSurface = context.colors.onSurface;
    final highContrast = AppTheme.highContrastOf(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s6,
        vertical: AppSpacing.s4,
      ),
      decoration: BoxDecoration(
        color: onSurface.withValues(alpha: highContrast ? 0.06 : 0.05),
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(
          color: onSurface.withValues(alpha: highContrast ? 0.3 : 0.08),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Disabled chevrons report enabled: false so PressScale stays
          // quiet (no haptic/scale on a dead button).
          PressScale(
            enabled: !atPastBound,
            child: IconButton(
              icon: const Icon(Icons.chevron_left_rounded),
              tooltip: l10n?.previousDaysVerse ?? "Previous day's verse",
              onPressed: atPastBound ? null : onPrevious,
              color: accent.withValues(alpha: atPastBound ? 0.25 : 0.75),
              style: IconButton.styleFrom(
                minimumSize: const Size(44, 40),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ),
          PressScale(
            child: TextButton.icon(
              onPressed: onToggleExpanded,
              icon: Icon(
                isExpanded
                    ? Icons.keyboard_arrow_up_rounded
                    : Icons.keyboard_arrow_down_rounded,
                color: accent,
                size: AppIconSize.medium,
              ),
              label: Text(
                isExpanded
                    ? (l10n?.hideTranslation ?? 'Hide translation')
                    : (l10n?.showTranslation ?? 'Show translation'),
                style: context.textTheme.labelLarge?.copyWith(
                  color: accent,
                  fontWeight: AppTypography.bold,
                ),
              ),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s12),
                minimumSize: const Size(0, 40),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
              ),
            ),
          ),
          PressScale(
            enabled: !atToday,
            child: IconButton(
              icon: const Icon(Icons.chevron_right_rounded),
              tooltip: l10n?.nextDaysVerse ?? "Next day's verse",
              onPressed: atToday ? null : onNext,
              color: accent.withValues(alpha: atToday ? 0.25 : 0.75),
              style: IconButton.styleFrom(
                minimumSize: const Size(44, 40),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
