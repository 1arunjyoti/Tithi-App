import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/app_metrics.dart';
import '../../../theme/app_typography.dart';
import '../../../utils/tithi_localization.dart';
import '../../../widgets/app_card.dart';
import '../../../widgets/app_divider.dart';
import '../providers/moon_details_providers.dart';

/// Today's lunar anchors plus the offline "Moon up, Sun down" window.
class MoonTimingsCard extends ConsumerWidget {
  const MoonTimingsCard({super.key, required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    // Async errors (no native ephemeris during host tests, polar days) hide
    // the card rather than turning the whole Moon screen into an error page.
    final sky = ref.watch(moonSkyTimesProvider(date)).valueOrNull;
    final window = ref.watch(moonViewingWindowProvider(date)).valueOrNull;
    if (sky == null) return const SizedBox.shrink();

    String time(DateTime instant) =>
        formatLocalizedDate(instant, 'jm', l10n.localeName);
    String fallbackDate(DateTime instant) =>
        formatLocalizedDate(instant, 'yMMMd', l10n.localeName);

    return AppCard(
      semanticLabel:
          '${l10n.moonrise} ${sky.rise == null ? '' : time(sky.rise!)}, '
          '${l10n.moonset} ${sky.set == null ? '' : time(sky.set!)}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                Icons.wb_twilight_outlined,
                size: AppIconSize.medium,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: AppSpacing.s8),
              Text(
                l10n.bestViewingTime,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: AppTypography.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s12),
          if (window == null)
            Text(
              l10n.moonNotVisible,
              style: theme.textTheme.bodySmall?.copyWith(
                color: context.secondaryInk,
              ),
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${time(window.start)} – ${time(window.end)}',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: AppTypography.semibold,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: AppSpacing.s2),
                Text(
                  window.isMorning
                      ? l10n.moonViewingMorning
                      : l10n.moonViewingEvening,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: context.secondaryInk,
                  ),
                ),
              ],
            ),
          const SizedBox(height: AppSpacing.s12),
          const AppDivider(),
          const SizedBox(height: AppSpacing.s12),
          _TimingRow(
            icon: Icons.arrow_upward_rounded,
            label: l10n.moonrise,
            value: sky.rise == null ? '—' : time(sky.rise!),
            note: sky.riseIsFallback && sky.rise != null
                ? fallbackDate(sky.rise!)
                : null,
          ),
          const SizedBox(height: AppSpacing.s8),
          _TimingRow(
            icon: Icons.arrow_downward_rounded,
            label: l10n.moonset,
            value: sky.set == null ? '—' : time(sky.set!),
            note: sky.setIsFallback && sky.set != null
                ? fallbackDate(sky.set!)
                : null,
          ),
        ],
      ),
    );
  }
}

class _TimingRow extends StatelessWidget {
  const _TimingRow({
    required this.icon,
    required this.label,
    required this.value,
    this.note,
  });

  final IconData icon;
  final String label;
  final String value;
  final String? note;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: AppIconSize.dense, color: context.secondaryInk),
        const SizedBox(width: AppSpacing.s8),
        Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: context.secondaryInk,
          ),
        ),
        const Spacer(),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              value,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: AppTypography.semibold,
              ),
            ),
            if (note != null)
              Text(
                note!,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: context.hintInk,
                ),
              ),
          ],
        ),
      ],
    );
  }
}
