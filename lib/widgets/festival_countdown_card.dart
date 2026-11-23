import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../core/anim/press_scale.dart';
import '../core/format/festival_labels.dart';
import '../models/festival.dart';
import '../core/feedback/app_haptics.dart';
import '../features/countdown/providers/countdown_providers.dart';
import '../providers/primary_date_label_provider.dart';
import '../theme/app_theme.dart';
import '../theme/app_metrics.dart';
import '../theme/app_motion.dart';
import '../theme/app_typography.dart';
import '../utils/tithi_localization.dart';
import '../features/sheets/sheet_launcher.dart';
import 'app_card.dart';
import 'inset_row_divider.dart';
import 'skeleton.dart';

class FestivalCountdownCard extends ConsumerWidget {
  const FestivalCountdownCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final countdowns = ref.watch(homeFestivalCountdownTargetsProvider);

    // Size glides from a pinned top edge on first launch and whenever the
    // pinned set changes, instead of snapping the column below.
    return AnimatedSize(
      alignment: Alignment.topCenter,
      duration: AppMotion.of(context, AppMotion.emphasized),
      curve: AppMotion.emphasizedCurve,
      child: countdowns.when(
        data: (targets) {
          if (targets.isEmpty) return const SizedBox.shrink();
          // One base card grouping the pinned countdowns — same pattern as
          // the Festivals & Events card (glass base + title + rows).
          return AppCard(
            // Side padding is smaller than the heading gutter: the embedded
            // rows add `homeCardRowInset` inside their own highlight, so the
            // day badge still lines up with the heading while the highlight
            // gets left/right breathing room.
            padding: const EdgeInsets.fromLTRB(
              AppTheme.homeCardRowPadding,
              AppSpacing.s16,
              AppTheme.homeCardRowPadding,
              AppSpacing.s16,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.homeCardRowInset,
                  ),
                  child: Text(
                    AppLocalizations.of(context)?.countdownHeading ??
                        'Festival Countdowns',
                    style: AppTypography.display(
                      fontSize: AppTypography.sizeHeading,
                      fontWeight: AppTypography.bold,
                      height: 1.3,
                      color: context.colors.onSurface,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.s12),
                for (var i = 0; i < targets.length; i++) ...[
                  // Flush rows on the base card: hairline only between them.
                  if (i > 0)
                    const InsetRowDivider(
                      leadingInset:
                          FestivalCountdownTile.textColumnInset +
                          AppTheme.homeCardRowInset,
                    ),
                  FestivalCountdownTile(
                    target: targets[i],
                    showTitle: false,
                    horizontalPadding: AppTheme.homeCardRowInset,
                  ),
                ],
              ],
            ),
          );
        },
        loading: () => const _CountdownLoadingCard(),
        error: (_, _) => const SizedBox.shrink(),
      ),
    );
  }
}

class FestivalCountdownTile extends ConsumerWidget {
  const FestivalCountdownTile({
    super.key,
    required this.target,
    this.isPinnedToHome = false,
    this.showActions = false,
    this.showTitle = true,
    this.horizontalPadding,
    this.onToggleHome,
    this.onRemove,
  });

  final FestivalCountdownTarget target;
  final bool isPinnedToHome;
  final bool showActions;

  /// Whether to show the "<title> Countdown" eyebrow. The home base card
  /// carries its own "Festival Countdowns" heading, so embedded rows hide
  /// it; the standalone countdown screen keeps it.
  final bool showTitle;

  /// Horizontal padding inside an embedded row's tappable surface, between
  /// its press highlight edge and the day badge. The home base card passes
  /// [AppTheme.homeCardRowInset] so the badge and chevron never sit on the
  /// highlight edge; standalone tiles keep their own 16dp card padding.
  final double? horizontalPadding;
  final VoidCallback? onToggleHome;
  final VoidCallback? onRemove;

  /// Leading day-count badge size and the gap after it.
  static const double badgeSize = 76;
  static const double badgeGap = 14;

  /// Distance from the row's leading edge to the text column. The home card's
  /// inter-row divider starts here so it never cuts under the day badge.
  static const double textColumnInset = badgeSize + badgeGap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    // Festival-gold accent shared with the Festivals & Events rows and the
    // calendar's festival marks — NOT scheme primary (purple in Krishna).
    final accent = AppTheme.festivalAccent(context);
    // Embedded rows (home base card) sit flush on the card surface like the
    // festival rows; the standalone countdown screen keeps the glass card.
    final embedded = !showTitle;
    final radius = BorderRadius.circular(embedded ? 14 : 24);
    final l10n = AppLocalizations.of(context);
    final locale =
        l10n?.localeName ?? Localizations.localeOf(context).languageCode;
    final dateLabel = primaryCalendarDateLine(
      ref,
      target.date,
      locale,
      gregorianPattern: 'MMM d',
    );

    final row = Row(
      children: [
        Container(
          width: badgeSize,
          height: badgeSize,
          decoration: BoxDecoration(
            // The old status pill's job lives here now: the block
            // fills gold when the festival is today so the
            // "happening now" row still stands out.
            color: target.isToday
                ? accent
                : AppTheme.festivalTileBackground(context),
            borderRadius: BorderRadius.circular(AppRadius.round),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                target.isToday
                    ? (l10n?.zeroDays ?? '0')
                    : formatLocalizedNumber(target.daysRemaining, locale),
                style: context.textTheme.headlineSmall?.copyWith(
                  color: target.isToday
                      ? AppTheme.onFestivalAccent(context)
                      : accent,
                  fontWeight: AppTypography.bold,
                  height: 1,
                ),
              ),
              Text(
                target.isToday
                    ? (l10n?.today ?? 'Today')
                    : target.daysRemaining == 1
                    ? (l10n?.day ?? 'day')
                    : (l10n?.days ?? 'days'),
                style: context.textTheme.labelSmall?.copyWith(
                  color: target.isToday
                      ? AppTheme.onFestivalAccent(context)
                      : accent,
                  fontWeight: AppTypography.bold,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: FestivalCountdownTile.badgeGap),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (showTitle) ...[
                Text(
                  l10n?.festivalCountdownTitle(target.title) ??
                      '${target.title} Countdown',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: context.textTheme.labelMedium?.copyWith(
                    color: accent,
                    fontWeight: AppTypography.bold,
                  ),
                ),
                const SizedBox(height: AppSpacing.s4),
              ],
              Text(
                festivalDisplayName(
                  festival: target.festival,
                  locale:
                      AppLocalizations.of(context)?.localeName ?? 'en',
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: context.textTheme.titleMedium?.copyWith(
                  color: colors.onSurface,
                  fontWeight: AppTypography.bold,
                ),
              ),
              const SizedBox(height: AppSpacing.s8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.calendar_today_rounded,
                    size: AppIconSize.inline,
                    // Same voice as the event rows' date line
                    // (FestivalRowTile gold line): the date is data,
                    // not dim chrome.
                    color: accent,
                  ),
                  const SizedBox(width: AppSpacing.s6),
                  Flexible(
                    child: Text(
                      dateLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.textTheme.bodySmall?.copyWith(
                        color: accent,
                        fontWeight: AppTypography.semibold,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.s8),
        if (showActions)
          _CountdownActions(
            isPinnedToHome: isPinnedToHome,
            onToggleHome: onToggleHome,
            onRemove: onRemove,
          )
        else
          Icon(
            Icons.chevron_right_rounded,
            color: colors.onSurface.withValues(
              alpha: AppTheme.contrastAlpha(context, 0.42),
            ),
          ),
      ],
    );

    if (embedded) {
      // Flush row inside the home base card: the base card owns the surface
      // and the dividers, so this branch only carries the tap target. The
      // Container stays (decoration-free) because the row's own padding and
      // its "no surface" state are what the home card relies on.
      return RepaintBoundary(
        child: Material(
          color: Colors.transparent,
          borderRadius: radius,
          child: InkWell(
            borderRadius: radius,
            onTap: () {
              AppHaptics.tap(ref);
              _showFestivalDetail(context, target.festival, target.date);
            },
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: horizontalPadding ?? 0,
                vertical: AppSpacing.s12,
              ),
              child: row,
            ),
          ),
        ),
      );
    }

    // Standalone tile: the page card owns the surface, radius, ripple and
    // haptic, so the countdown screen cannot drift from the other pages.
    return RepaintBoundary(
      child: AppCard(
        onTap: () => _showFestivalDetail(context, target.festival, target.date),
        child: row,
      ),
    );
  }

  void _showFestivalDetail(
    BuildContext context,
    Festival festival,
    DateTime date,
  ) {
    showEventDetailSheet(context, festival: festival, date: date);
  }
}

class _CountdownActions extends StatelessWidget {
  const _CountdownActions({
    required this.isPinnedToHome,
    this.onToggleHome,
    this.onRemove,
  });

  final bool isPinnedToHome;
  final VoidCallback? onToggleHome;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final accent = AppTheme.festivalAccent(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Tooltip(
          message:
              AppLocalizations.of(context)?.removeFromHomeScreen ??
              'Remove from home screen',
          // Scale only: the onToggleHome callback already buzzes.
          child: PressScale(
            haptic: false,
            child: IconButton(
              onPressed: onToggleHome,
              icon: Icon(
                isPinnedToHome ? Icons.home_rounded : Icons.home_outlined,
              ),
              color: isPinnedToHome
                  ? accent
                  : colors.onSurface.withValues(
                      alpha: AppTheme.contrastAlpha(context, 0.56),
                    ),
              style: IconButton.styleFrom(
                backgroundColor: isPinnedToHome
                    ? accent.withValues(alpha: 0.12)
                    : Colors.transparent,
                minimumSize: const Size(40, 40),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ),
        ),
        Tooltip(
          message:
              AppLocalizations.of(context)?.removeCountdown ??
              'Remove countdown',
          // Scale only: the onRemove callback already buzzes.
          child: PressScale(
            haptic: false,
            child: IconButton(
              onPressed: onRemove,
              icon: const Icon(Icons.delete_outline_rounded),
              color: colors.error,
              style: IconButton.styleFrom(
                minimumSize: const Size(40, 40),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _CountdownLoadingCard extends StatelessWidget {
  const _CountdownLoadingCard();

  @override
  Widget build(BuildContext context) {
    // 108dp tall like the loaded tile (76dp content + 2x16dp card padding).
    return AppCard(
      child: SizedBox(
        height: 76,
        child: Row(
          children: [
            Container(
              width: FestivalCountdownTile.badgeSize,
              height: FestivalCountdownTile.badgeSize,
              decoration: BoxDecoration(
                color: AppTheme.festivalTileBackground(context),
                borderRadius: BorderRadius.circular(AppRadius.round),
              ),
              child: Center(
                child: InlineSpinner(
                  size: AppIconSize.large,
                  color: AppTheme.festivalAccent(context),
                ),
              ),
            ),
            const SizedBox(width: FestivalCountdownTile.badgeGap),
            const Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkeletonBox(width: 130, height: 12, radius: AppRadius.chip),
                  SizedBox(height: AppSpacing.s12),
                  SkeletonBox(
                    width: double.infinity,
                    height: 16,
                    radius: AppRadius.chip,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
