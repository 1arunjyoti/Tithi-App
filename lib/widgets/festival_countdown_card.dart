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

    return countdowns.when(
      data: (targets) {
        if (targets.isEmpty) return const SizedBox.shrink();
        return Column(
          children: [
            for (var i = 0; i < targets.length; i++) ...[
              FestivalCountdownTile(target: targets[i]),
              if (i < targets.length - 1) const SizedBox(height: 10),
            ],
          ],
        );
      },
      loading: () => const _CountdownLoadingCard(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}

class FestivalCountdownTile extends ConsumerWidget {
  const FestivalCountdownTile({
    super.key,
    required this.target,
    this.isPinnedToHome = false,
    this.showActions = false,
    this.onToggleHome,
    this.onRemove,
  });

  final FestivalCountdownTarget target;
  final bool isPinnedToHome;
  final bool showActions;
  final VoidCallback? onToggleHome;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final dateLabel = DateFormat('EEE, MMM d').format(target.date);
    final statusLabel = target.isToday
        ? 'Today'
        : target.isTomorrow
        ? 'Tomorrow'
        : '${target.daysRemaining} days to go';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: () {
          if (ref.read(accessibilityProvider).hapticFeedback) {
            HapticFeedback.lightImpact();
          }
          _showFestivalDetail(context, target.festival);
        },
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: AppTheme.glassmorphism(context: context, ref: ref),
          child: Row(
            children: [
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.auto_awesome_rounded,
                      color: colors.primary,
                      size: 22,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      target.isToday ? '0' : target.daysRemaining.toString(),
                      style: context.textTheme.headlineSmall?.copyWith(
                        color: colors.primary,
                        fontWeight: FontWeight.w800,
                        height: 1,
                      ),
                    ),
                    Text(
                      target.isToday ? 'day' : 'days',
                      style: context.textTheme.labelSmall?.copyWith(
                        color: colors.primary,
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
                    Text(
                      '${target.title} Countdown',
                      style: context.textTheme.labelMedium?.copyWith(
                        color: colors.primary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
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
                    Row(
                      children: [
                        Icon(
                          Icons.calendar_today_rounded,
                          size: 14,
                          color: colors.onSurface.withValues(alpha: 0.58),
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            '$dateLabel • $statusLabel',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.textTheme.bodySmall?.copyWith(
                              color: colors.onSurface.withValues(alpha: 0.68),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
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
                  color: colors.onSurface.withValues(alpha: 0.42),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showFestivalDetail(BuildContext context, Festival festival) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => EventDetailSheet(festival: festival),
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
                ? colors.primary
                : colors.onSurface.withValues(alpha: 0.56),
          ),
        ),
        Tooltip(
          message: 'Remove countdown',
          child: IconButton(
            onPressed: onRemove,
            icon: const Icon(Icons.delete_outline_rounded),
            color: colors.error,
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
              color: context.colors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  color: context.colors.primary,
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
