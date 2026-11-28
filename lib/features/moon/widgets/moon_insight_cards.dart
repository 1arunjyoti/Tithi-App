import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../features/eclipse/providers/eclipse_providers.dart';
import '../../../features/eclipse/widgets/eclipse_details_sheet.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/eclipse.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/app_metrics.dart';
import '../../../theme/app_typography.dart';
import '../../../utils/tithi_localization.dart';
import '../../../widgets/app_card.dart';
import '../domain/moon_distance.dart';
import '../providers/moon_details_providers.dart';

/// Geocentric Moon distance and its Supermoon/Micromoon classification.
class MoonDistanceCard extends ConsumerWidget {
  const MoonDistanceCard({super.key, required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final info = ref.watch(moonDistanceInfoProvider(date)).valueOrNull;
    if (info == null) return const SizedBox.shrink();

    final label = switch (info.kind) {
      MoonDistanceKind.supermoon => l10n.supermoon,
      MoonDistanceKind.micromoon => l10n.micromoon,
      MoonDistanceKind.normal => l10n.averageDistance,
    };

    return AppCard(
      semanticLabel:
          '${l10n.moonDistance}: '
          '${formatLocalizedNumber(info.distanceKm.round(), l10n.localeName)} km, $label',
      child: Row(
        children: [
          Icon(
            Icons.straighten_rounded,
            size: AppIconSize.medium,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: AppSpacing.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.moonDistance,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: context.secondaryInk,
                  ),
                ),
                Text(
                  l10n.moonDistanceKm(
                    formatLocalizedNumber(
                      info.distanceKm.round(),
                      l10n.localeName,
                    ),
                  ),
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: AppTypography.semibold,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.s8,
              vertical: AppSpacing.s4,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.tile),
              color:
                  (info.kind == MoonDistanceKind.supermoon
                          ? AppTheme.moonGlowLight
                          : AppTheme.spaceStar)
                      .withValues(alpha: 0.25),
            ),
            child: Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: AppTypography.bold,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Next lunar eclipse with local visibility and a link to the details sheet.
///
/// Lunar-only on purpose: this is the Moon screen, and a solar eclipse is
/// already covered by the dedicated Eclipse screen.
class MoonEclipseCard extends ConsumerWidget {
  const MoonEclipseCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final lunarEclipses = ref
        .watch(upcomingEclipsesProvider)
        .valueOrNull
        ?.where((eclipse) => eclipse.type.isLunar)
        .toList();
    if (lunarEclipses == null || lunarEclipses.isEmpty) {
      return const SizedBox.shrink();
    }
    final eclipse = lunarEclipses.first;

    return AppCard(
      onTap: () => showEclipseDetailsSheet(context, eclipse),
      semanticLabel:
          '${l10n.nextEclipse}: '
          '${formatLocalizedDate(eclipse.maxEclipseTime.toLocal(), 'yMMMd', l10n.localeName)}',
      child: Row(
        children: [
          Icon(
            Icons.nightlight_round,
            size: AppIconSize.medium,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: AppSpacing.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.nextEclipse,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: context.secondaryInk,
                  ),
                ),
                Text(
                  formatLocalizedDate(
                    eclipse.maxEclipseTime.toLocal(),
                    'yMMMd',
                    l10n.localeName,
                  ),
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: AppTypography.semibold,
                  ),
                ),
                Text(
                  eclipse.visibleAtLocation
                      ? l10n.visibleFromYourLocation
                      : l10n.notVisibleFromYourLocation,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: context.secondaryInk,
                  ),
                ),
              ],
            ),
          ),
          Text(
            l10n.lunarEclipses,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: AppTypography.semibold,
            ),
          ),
          const SizedBox(width: AppSpacing.s4),
          const Icon(Icons.chevron_right, size: AppIconSize.dense),
        ],
      ),
    );
  }
}
