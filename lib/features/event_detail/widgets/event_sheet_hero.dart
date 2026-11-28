import 'package:material_ui/material_ui.dart';

import '../../../l10n/app_localizations.dart';
import '../../../models/festival.dart';
import '../../../services/share_service.dart';
import '../../../theme/app_metrics.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/app_typography.dart';
import '../../../utils/tithi_localization.dart';
import '../../../widgets/app_buttons.dart';
import '../../sheets/widgets/sheet_hero_tile.dart';
import '../domain/event_content.dart';
import 'hero_language_chips.dart';

/// Hero header of the festival sheet: observance date, title row (icon,
/// name/subtitle, tithi badge, share) and the collapsible language chips.
class EventSheetHero extends StatelessWidget {
  const EventSheetHero({
    super.key,
    required this.festival,
    required this.content,
    required this.headerDate,
    this.headerDateLabel,
    required this.displayName,
    required this.categoryLabel,
    required this.heroChips,
    required this.highContrast,
    required this.locale,
  });

  final Festival festival;
  final EventSheetContent? content;
  final DateTime? headerDate;

  /// Calendar-specific half of the header date, resolved in the primary
  /// calendar by the sheet. Null falls back to the Gregorian date.
  final String? headerDateLabel;
  final String displayName;
  final String categoryLabel;
  final List<String> heroChips;
  final bool highContrast;
  final String locale;

  @override
  Widget build(BuildContext context) {
    final dateBaseStyle = AppTypography.display(
      fontSize: AppTypography.sizeHeadline,
      height: 1.3,
      color: highContrast
          ? context.colors.onSurface
          : AppTheme.heroForeground(context),
    );
    final heroInk = highContrast
        ? context.colors.onSurface
        : AppTheme.heroForeground(context);
    final heroAccent = highContrast
        ? context.colors.primary
        : AppTheme.heroAccent(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Header date: observance weekday + primary-calendar date (the sheet
        // resolves the date half; the Gregorian string is its fallback).
        if (headerDate != null)
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '${formatLocalizedDate(headerDate!, 'EEEE', locale)}, ',
                  style: dateBaseStyle,
                ),
                TextSpan(
                  text:
                      headerDateLabel ??
                      formatLocalizedDate(headerDate!, 'd MMMM y', locale),
                  style: dateBaseStyle,
                ),
              ],
            ),
          ),
        if (headerDate != null) const SizedBox(height: AppSpacing.s12),
        // Title row: icon tile + name/subtitle + tithi badge + share.
        // Center-aligned like the tithi sheet's moon row, so the badge
        // and share button sit mid-row instead of riding the top edge.
        Row(
          children: [
            SheetHeroTile(
              highContrast: highContrast,
              child: Icon(
                Icons.celebration_outlined,
                size: AppIconSize.nav,
                color: highContrast
                    ? context.colors.primary
                    : AppTheme.heroForeground(context),
              ),
            ),
            const SizedBox(width: AppSpacing.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayName,
                    style: TextStyle(
                      fontSize: AppTypography.sizeHeading,
                      fontWeight: AppTypography.semibold,
                      color: heroInk,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s2),
                  Text(
                    // Sanskrit companion to the title.
                    festival.nameSanskrit ?? categoryLabel,
                    style: TextStyle(
                      fontSize: AppTypography.sizeCaption,
                      fontWeight: AppTypography.medium,
                      color: heroInk,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.s8),
            if (content != null)
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
                        : heroAccent.withValues(alpha: 0.7),
                  ),
                ),
                child: Text(
                  '${content!.displayTithiNum}',
                  style: TextStyle(
                    color: heroAccent,
                    fontWeight: AppTypography.bold,
                    fontSize: AppTypography.sizeProse,
                  ),
                ),
              ),
            AppIconButton(
              onPressed: () => ShareService().shareFestival(context, festival),
              icon: const Icon(Icons.share_outlined),
              tooltip: AppLocalizations.of(context)?.shareCard ?? 'Share Card',
            ),
          ],
        ),
        // Hero chips (shared pill style): regional names only, minus the
        // title language. Collapsed to the first row with a "show more"
        // toggle so festivals with many names don't push the hero tall.
        // The category stays in the Panchang Details rows below.
        if (heroChips.isNotEmpty)
          HeroLanguageChips(chips: heroChips, highContrast: highContrast),
      ],
    );
  }
}
