import 'package:material_ui/material_ui.dart';

import '../../../l10n/app_localizations.dart';
import '../../../widgets/app_buttons.dart';
import '../../../theme/app_metrics.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/app_typography.dart';

/// Card header: gold-tinted glyph tile (same language as the festival rows),
/// bold title with the browsed-day pill underneath, a filled "Today" reset
/// while browsing, and a tinted circular share button.
class QuoteCardHeader extends StatelessWidget {
  const QuoteCardHeader({
    super.key,
    required this.dayLabel,
    required this.showTodayReset,
    required this.onJumpToToday,
    required this.onShare,
    required this.l10n,
  });

  final String dayLabel;
  final bool showTodayReset;
  final VoidCallback onJumpToToday;
  final VoidCallback onShare;
  final AppLocalizations? l10n;

  @override
  Widget build(BuildContext context) {
    // Festival-gold accent shared with the Festivals & Events rows and the
    // calendar's festival marks — NOT scheme primary (purple in the Krishna
    // theme) — so this card sits visually with its home-screen neighbours.
    final accent = AppTheme.festivalAccent(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.s16,
        AppSpacing.s14,
        AppSpacing.s12,
        0,
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppTheme.festivalTileBackground(context),
              borderRadius: BorderRadius.circular(AppRadius.tile),
            ),
            alignment: Alignment.center,
            child: Icon(
              Icons.auto_stories_rounded,
              size: AppIconSize.large,
              color: accent,
            ),
          ),
          const SizedBox(width: AppSpacing.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l10n?.dailyWisdom ?? 'Daily Wisdom',
                  style: context.textTheme.titleMedium?.copyWith(
                    fontWeight: AppTypography.bold,
                    color: context.colors.onSurface,
                  ),
                ),
                const SizedBox(height: AppSpacing.s4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.s8,
                    vertical: AppSpacing.s4,
                  ),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppRadius.round),
                  ),
                  child: Text(
                    dayLabel,
                    style: context.textTheme.labelSmall?.copyWith(
                      color: accent,
                      fontWeight: AppTypography.bold,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (showTodayReset) ...[
            AppButton(
              onPressed: onJumpToToday,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s12),
              minimumSize: const Size(0, 32),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              label: Text(l10n?.today ?? 'Today'),
            ),
            const SizedBox(width: AppSpacing.s8),
          ],
          AppIconButton(
            onPressed: onShare,
            tooltip: l10n?.share ?? 'Share',
            icon: const Icon(Icons.share_rounded, size: AppIconSize.dense),
          ),
        ],
      ),
    );
  }
}
