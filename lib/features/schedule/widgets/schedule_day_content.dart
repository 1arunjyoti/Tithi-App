import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/feedback/app_haptics.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/festival.dart';
import '../../../models/panchang_data.dart';
import '../../../theme/app_metrics.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/app_typography.dart';
import '../../../utils/tithi_localization.dart';
import '../../sheets/sheet_launcher.dart';

/// Right-hand content column of one schedule row: the paksha/tithi summary,
/// the sunrise/sunset line, and one card per festival observed that day.
///
/// The summary + sun times render whether or not the day has an observance;
/// the festival cards are the only part that appears conditionally.
class ScheduleDayContent extends StatelessWidget {
  const ScheduleDayContent({super.key, required this.panchang});

  final PanchangData panchang;

  @override
  Widget build(BuildContext context) {
    final festivals = panchang.festivals;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _PanchangSummaryRow(panchang: panchang),
        _SunTimesRow(panchang: panchang),
        if (festivals.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.s8),
          ...festivals.map(
            (festival) => _FestivalCard(festival: festival, panchang: panchang),
          ),
        ],
      ],
    );
  }
}

/// Paksha + tithi name with the tithi-number chip on the right.
class _PanchangSummaryRow extends StatelessWidget {
  const _PanchangSummaryRow({required this.panchang});

  final PanchangData panchang;

  @override
  Widget build(BuildContext context) {
    final isShukla = panchang.isShukla;

    return Row(
      children: [
        Icon(
          isShukla ? Icons.brightness_high_rounded : Icons.nights_stay_rounded,
          size: AppIconSize.small,
          color: context.colors.primary.withValues(alpha: 0.7),
        ),
        const SizedBox(width: AppSpacing.s8),
        Expanded(
          child: Text(
            '${panchang.paksha} ${panchang.tithiName}',
            style: context.textTheme.bodyMedium?.copyWith(
              color: context.secondaryInk,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.s8,
            vertical: AppSpacing.s2,
          ),
          decoration: BoxDecoration(
            color: context.colors.primary.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(AppRadius.chip),
          ),
          child: Text(
            '${panchang.tithiNumber}',
            style: context.textTheme.labelSmall?.copyWith(
              color: context.colors.primary,
              fontWeight: AppTypography.bold,
            ),
          ),
        ),
      ],
    );
  }
}

/// Sunrise/sunset line; collapses to nothing when the day has neither.
class _SunTimesRow extends StatelessWidget {
  const _SunTimesRow({required this.panchang});

  final PanchangData panchang;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = l10n.localeName;

    if (panchang.sunrise == null && panchang.sunset == null) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.s6),
      child: Row(
        children: [
          if (panchang.sunrise != null) ...[
            Semantics(
              label: l10n.sunrise,
              child: Icon(
                Icons.wb_sunny_outlined,
                size: AppIconSize.inline,
                color: context.secondaryInk,
              ),
            ),
            const SizedBox(width: AppSpacing.s4),
            Text(
              '${l10n.sunrise}: ${formatLocalizedDate(panchang.sunrise!, 'h:mm a', locale)}',
              style: context.textTheme.labelSmall?.copyWith(
                color: context.secondaryInk,
              ),
            ),
          ],
          if (panchang.sunrise != null && panchang.sunset != null)
            const SizedBox(width: AppSpacing.s12),
          if (panchang.sunset != null) ...[
            Semantics(
              label: l10n.sunset,
              child: Icon(
                Icons.nightlight_round,
                size: AppIconSize.inline,
                color: context.secondaryInk,
              ),
            ),
            const SizedBox(width: AppSpacing.s4),
            Text(
              '${l10n.sunset}: ${formatLocalizedDate(panchang.sunset!, 'h:mm a', locale)}',
              style: context.textTheme.labelSmall?.copyWith(
                color: context.secondaryInk,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// One tappable observance card; major festivals get a stronger tint, a
/// primary rail and the celebration glyph.
class _FestivalCard extends ConsumerWidget {
  const _FestivalCard({required this.festival, required this.panchang});

  final Festival festival;
  final PanchangData panchang;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isMajor = festival.category == 'major';

    return GestureDetector(
      onTap: () {
        AppHaptics.tap(ref);
        showEventDetailSheet(context, festival: festival, panchang: panchang);
      },
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: AppSpacing.s8),
        padding: const EdgeInsets.all(AppSpacing.s12),
        decoration: AppTheme.glassmorphism(
          context: context,
          opacity: isMajor ? 0.25 : 0.15,
          borderRadius: AppRadius.dense,
          ref: ref,
        ),
        child: Row(
          children: [
            Container(
              width: 4,
              height: 40,
              decoration: BoxDecoration(
                color: isMajor
                    ? context.colors.primary
                    : context.colors.secondary,
                borderRadius: BorderRadius.circular(AppRadius.micro),
              ),
            ),
            const SizedBox(width: AppSpacing.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    festival.name,
                    style: context.textTheme.bodyLarge?.copyWith(
                      fontWeight: AppTypography.semibold,
                    ),
                  ),
                  if (festival.description.isNotEmpty)
                    Text(
                      festival.description,
                      style: context.textTheme.bodySmall?.copyWith(
                        color: context.secondaryInk,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            Icon(
              isMajor ? Icons.celebration_rounded : Icons.event_rounded,
              size: AppIconSize.medium,
              color: context.colors.primary.withValues(alpha: 0.7),
            ),
          ],
        ),
      ),
    );
  }
}
