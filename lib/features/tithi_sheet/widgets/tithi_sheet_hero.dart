import 'package:material_ui/material_ui.dart';

import '../../../providers/calendar_provider.dart' show AppCalendarSystem;
import '../../../theme/app_metrics.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/app_typography.dart';
import '../../../utils/tithi_localization.dart';
import '../../../widgets/moon_animation_widget.dart';
import '../../sheets/domain/sheet_labels.dart';
import '../../sheets/widgets/sheet_hero_tile.dart';
import '../domain/tithi_sheet_context.dart';

/// Hero header of the tithi sheet: primary-calendar date line, moon tile,
/// paksha/tithi identity, illumination and the tithi-number badge.
class TithiSheetHero extends StatelessWidget {
  const TithiSheetHero({
    super.key,
    required this.ctx,
    required this.primarySystem,
    required this.bengali,
    required this.hinduYear,
    required this.displayMasa,
    required this.displayTithiName,
    required this.displayNum,
    required this.illumination,
    required this.isShukla,
    required this.illuminationPct,
    required this.phaseWord,
    required this.weekday,
    required this.useBengaliScript,
  });

  final TithiSheetContext ctx;
  final AppCalendarSystem primarySystem;
  final ({int day, String month, int year})? bengali;
  final ({int year, String eraLabel})? hinduYear;
  final String displayMasa;
  final String displayTithiName;
  final int displayNum;
  final double illumination;
  final bool isShukla;
  final String illuminationPct;
  final String phaseWord;
  final String weekday;
  final bool useBengaliScript;

  @override
  Widget build(BuildContext context) {
    final panchang = ctx.panchang;
    final l10n = ctx.l10n;
    final locale = ctx.locale;
    final highContrast = ctx.highContrast;

    // Header date line follows the primary calendar (date, month, year) in
    // hero-title styling. Gregorian/Hindu slots are sync; the Hindu year and
    // Bengali date resolve async and join when ready (weekday alone meanwhile).
    final dateBaseStyle = AppTypography.display(
      fontSize: AppTypography.sizeHeadline,
      height: 1.3,
      color: highContrast
          ? context.colors.onSurface
          : AppTheme.heroForeground(context),
    );
    final dateAccentStyle = dateBaseStyle.copyWith(
      fontStyle: FontStyle.italic,
      color: highContrast
          ? context.colors.primary
          : AppTheme.heroAccent(context),
    );
    final dateSpans = <InlineSpan>[];
    switch (primarySystem) {
      case AppCalendarSystem.gregorian:
        dateSpans.add(
          TextSpan(
            text: formatLocalizedDate(panchang.date, 'd MMMM y', locale),
            style: dateBaseStyle,
          ),
        );
      case AppCalendarSystem.hindu:
        dateSpans.add(
          TextSpan(
            text: '$displayMasa $displayTithiName'.trim(),
            style: dateAccentStyle,
          ),
        );
        final hy = hinduYear;
        if (hy != null) {
          dateSpans.add(
            TextSpan(
              text: ' · ${hy.eraLabel} ${hy.year}',
              // Below the display floor: AppTypography routes this to the UI
              // sans so Newsreader's hairlines never render at 16pt.
              style: AppTypography.display(
                fontSize: AppTypography.sizeSubtitle,
                fontStyle: FontStyle.italic,
                color: highContrast
                    ? context.colors.primary
                    : AppTheme.heroAccent(context),
              ),
            ),
          );
        }
      case AppCalendarSystem.bengali:
        final b = bengali;
        if (b != null) {
          final labels = bengaliDateLabels(
            day: b.day,
            month: b.month,
            year: b.year,
            useBengaliScript: useBengaliScript,
          );
          dateSpans.add(TextSpan(text: labels.compact, style: dateAccentStyle));
        }
      case AppCalendarSystem.none:
        break;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header date: primary calendar date, month, year.
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: dateSpans.isEmpty ? weekday : '$weekday, ',
                style: dateBaseStyle,
              ),
              ...dateSpans,
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.s12),
        // Moon row: tile + paksha/tithi + illumination + number badge.
        Row(
          children: [
            SheetHeroTile(
              highContrast: highContrast,
              child: MoonAnimationWidget(
                phase: illumination,
                isWaxing: isShukla,
                size: 28,
              ),
            ),
            const SizedBox(width: AppSpacing.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${l10n.pakshaWithName(panchang.isShukla ? l10n.themeShukla : l10n.themeKrishna)} · $displayTithiName',
                    style: TextStyle(
                      fontSize: AppTypography.sizeHeading,
                      fontWeight: AppTypography.semibold,
                      color: highContrast
                          ? context.colors.onSurface
                          : AppTheme.heroForeground(context),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s2),
                  Text(
                    '$phaseWord · ${l10n.illuminatedPercent(illuminationPct)}',
                    style: TextStyle(
                      fontSize: AppTypography.sizeCaption,
                      fontWeight: AppTypography.medium,
                      color: highContrast
                          ? context.secondaryInk
                          : AppTheme.heroForeground(context),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.s8),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.s12,
                vertical: AppSpacing.s6,
              ),
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(AppRadius.dense),
                border: Border.all(
                  color: highContrast
                      ? context.colors.primary.withValues(alpha: 0.4)
                      : AppTheme.heroAccent(context).withValues(alpha: 0.7),
                ),
              ),
              child: Text(
                '$displayNum',
                style: TextStyle(
                  color: highContrast
                      ? context.colors.primary
                      : AppTheme.heroAccent(context),
                  fontWeight: AppTypography.bold,
                  fontSize: AppTypography.sizeProse,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
