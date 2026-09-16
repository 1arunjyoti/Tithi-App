import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/festival.dart';
import '../providers/accessibility_provider.dart';
import '../providers/festival_countdown_provider.dart';
import '../theme/app_theme.dart';
import 'event_detail_sheet.dart';

class FestivalCountdownCard extends ConsumerWidget {
  const FestivalCountdownCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final countdowns = ref.watch(homeFestivalCountdownTargetsProvider);

    // Size glides from a pinned top edge on first launch and whenever the
    // pinned set changes, instead of snapping the column below.
    return AnimatedSize(
      alignment: Alignment.topCenter,
      duration: AppTheme.animationDuration(
        context,
        const Duration(milliseconds: 250),
      ),
      curve: Curves.easeInOutCubic,
      child: countdowns.when(
        data: (targets) {
          if (targets.isEmpty) return const SizedBox.shrink();
          // One base card grouping the pinned countdowns — same pattern as
          // the Festivals & Events card (glass base + title + rows).
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: AppTheme.glassmorphism(context: context, ref: ref),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Festival Countdowns',
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                    color: context.colors.onSurface,
                  ),
                ),
                const SizedBox(height: 12),
                for (var i = 0; i < targets.length; i++) ...[
                  FestivalCountdownTile(
                    target: targets[i],
                    showTitle: false,
                  ),
                  if (i < targets.length - 1) const SizedBox(height: 10),
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
  final VoidCallback? onToggleHome;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    // Festival-gold accent shared with the Festivals & Events rows and the
    // calendar's festival marks — NOT scheme primary (purple in Krishna).
    final accent = AppTheme.festivalAccent(context);
    // Embedded rows (home base card) wear the festival-row surface; the
    // standalone countdown screen keeps the glass card.
    final embedded = !showTitle;
    final dateLabel = DateFormat('EEE, MMM d').format(target.date);
    final statusLabel = target.isToday
        ? 'Today'
        : target.isTomorrow
        ? 'Tomorrow'
        : '${target.daysRemaining} days to go';

    return RepaintBoundary(
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(embedded ? 16 : 24),
        child: InkWell(
          borderRadius: BorderRadius.circular(embedded ? 16 : 24),
          onTap: () {
            if (ref.read(accessibilityProvider).hapticFeedback) {
              HapticFeedback.lightImpact();
            }
            _showFestivalDetail(context, target.festival);
          },
          child: Container(
            padding: EdgeInsets.all(embedded ? 12 : 16),
            // Embedded rows match the festival rows' surface exactly (same
            // helper); standalone tiles keep their glass card.
            decoration: embedded
                ? AppTheme.festivalRowDecoration(context)
                : AppTheme.glassmorphism(context: context, ref: ref),
            child: Row(
              children: [
                Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    color: AppTheme.festivalTileBackground(context),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.auto_awesome_rounded,
                        color: accent,
                        size: 22,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        target.isToday ? '0' : target.daysRemaining.toString(),
                        style: context.textTheme.headlineSmall?.copyWith(
                          color: accent,
                          fontWeight: FontWeight.w800,
                          height: 1,
                        ),
                      ),
                      Text(
                        target.isToday ? 'day' : 'days',
                        style: context.textTheme.labelSmall?.copyWith(
                          color: accent,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (showTitle) ...[
                        Text(
                          '${target.title} Countdown',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: context.textTheme.labelMedium?.copyWith(
                            color: accent,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                      ],
                      Text(
                        target.festival.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: context.textTheme.titleMedium?.copyWith(
                          color: colors.onSurface,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.calendar_today_rounded,
                                size: 14,
                                color: colors.onSurface.withValues(
                                  alpha: AppTheme.contrastAlpha(context, 0.58),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  dateLabel,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: context.textTheme.bodySmall?.copyWith(
                                    color: colors.onSurface.withValues(
                                      alpha: AppTheme.contrastAlpha(
                                        context,
                                        0.68,
                                      ),
                                    ),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          _StatusPill(
                            label: statusLabel,
                            filled: target.isToday,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
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
            ),
          ),
        ),
      ),
    );
  }

  void _showFestivalDetail(BuildContext context, Festival festival) {
    showModalBottomSheet(
      context: context,
      sheetAnimationStyle: AppTheme.sheetAnimationStyleOf(context),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => EventDetailSheet(festival: festival),
    );
  }
}

/// Status pill beside the date: tinted gold normally, filled gold when the
/// festival is today so the "happening now" row stands out.
class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.filled});

  final String label;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final accent = AppTheme.festivalAccent(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: filled ? accent : accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        maxLines: 1,
        style: context.textTheme.labelSmall?.copyWith(
          color: filled ? AppTheme.onFestivalAccent(context) : accent,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
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
          message: isPinnedToHome
              ? 'Remove from home screen'
              : 'Show on home screen',
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
        Tooltip(
          message: 'Remove countdown',
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
      ],
    );
  }
}

class _CountdownLoadingCard extends ConsumerWidget {
  const _CountdownLoadingCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      height: 108,
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.glassmorphism(context: context, ref: ref),
      child: Row(
        children: [
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              color: AppTheme.festivalTileBackground(context),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  color: AppTheme.festivalAccent(context),
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 130,
                  height: 12,
                  decoration: BoxDecoration(
                    color: context.colors.onSurface.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  height: 16,
                  decoration: BoxDecoration(
                    color: context.colors.onSurface.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
