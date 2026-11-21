import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../l10n/app_localizations_en.dart';
import '../core/format/date_only.dart';
import '../core/format/festival_labels.dart';
import '../models/festival.dart';
import '../models/panchang_data.dart';
import '../core/feedback/app_haptics.dart';
import '../providers/calendar_provider.dart';
import '../providers/primary_date_label_provider.dart';
import '../theme/app_theme.dart';
import '../theme/app_metrics.dart';
import '../theme/app_typography.dart';
import '../utils/tithi_localization.dart';
import 'festival_thumbnail.dart';

/// Single festival row shared by the home "Festivals & Events" card and the
/// all-festivals screen: gold icon or festival artwork tile, bold name, gold
/// date/tithi line with an optional "in N days" suffix, dim one-line
/// description, chevron.
///
/// Pass [date]/[panchang]/[daysAway] for dated rows (home card). Without a
/// date the gold line falls back to the category label (all-festivals list).
/// [isSelectedDay] gives the row the accent surface: the home card sets it
/// for the festivals of the calendar's selected date, so that day's rows
/// stand out from the following days (whether the selection is today or a
/// browsed date).
/// A null [onTap] renders the row without a chevron or ripple.
///
/// [flush] drops the row's own surface and horizontal padding so the leading
/// tile lines up with the parent card's heading text, with rows separated by
/// `InsetRowDivider` instead of boxes (home cards and the tithi sheet use
/// this; the all-festivals list has no card behind it, so it keeps the inset
/// self-contained row). [isSelectedDay] still washes the day's rows.
///
/// [horizontalPadding] is the breathing room between the row's wash/highlight
/// edge and its content. Flush rows default to 0 (heading alignment); the
/// home card passes a value so the tile and chevron do not sit on the wash
/// edge - it pairs with the card's smaller side padding, so the content still
/// lines up with the heading.
class FestivalRowTile extends ConsumerWidget {
  const FestivalRowTile({
    super.key,
    required this.festival,
    this.date,
    this.panchang,
    this.daysAway,
    this.isSelectedDay = false,
    this.flush = false,
    this.horizontalPadding,
    this.onTap,
  });

  final Festival festival;
  final DateTime? date;
  final PanchangData? panchang;
  final int? daysAway;
  final bool isSelectedDay;
  final bool flush;
  final double? horizontalPadding;
  final VoidCallback? onTap;

  /// Leading tile size and the gap after it.
  static const double leadingTileSize = 48;
  static const double leadingGap = 12;

  /// Distance from the row's leading edge to the text column. The home card's
  /// inter-row divider starts here so it never cuts under the icon tile.
  static const double textColumnInset = leadingTileSize + leadingGap;

  String? _goldLine(
    BuildContext context,
    WidgetRef ref, {
    required bool isToday,
  }) {
    final l10n = AppLocalizations.of(context) ?? AppLocalizationsEn();
    final day = date;
    if (day != null) {
      final parts = <String>[
        isToday
            ? l10n.today
            : primaryCalendarDateLine(
                ref,
                day,
                l10n.localeName,
                gregorianPattern: 'd MMM',
              ),
      ];
      // The tithi half needs the day's panchang, which the home card already
      // holds; the all-festivals list passes date-only rows (no extra fetch).
      final p = panchang;
      if (p != null) {
        // Paksha name, not the "Waxing/Waning" phase word: "Waxing Ekadashi"
        // describes the moon, not the tithi. Panchang convention is
        // "Shukla Ekadashi" / "Krishna Ekadashi".
        parts.add(
          '${p.isShukla ? l10n.themeShukla : l10n.themeKrishna} '
          '${localizedTithiName(p.tithiNumber, p.paksha, l10n)}',
        );
      }
      final away = daysAway ?? 0;
      // No countdown suffix on today's row: the date is already "Today", so
      // an "in N days" suffix (counted from the selected day on the home
      // card) would contradict it.
      if (!isToday && away > 0) {
        parts.add(l10n.festivalInDays(away));
      }
      return parts.join(' · ');
    }
    final category = festival.category.trim();
    if (category.isEmpty) return null;
    return '${category[0].toUpperCase()}${category.substring(1)}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gold = AppTheme.festivalAccent(context);
    // App "today" (midnight-refreshed + resume-corrected), not wall-clock
    // now: a suspended-then-resumed app would otherwise label rows with
    // yesterday's Today around midnight. The accent surface below follows
    // the calendar selection instead (see [isSelectedDay]).
    final day = date;
    final isToday = day != null && isSameDay(day, ref.watch(todayDateProvider));
    final goldLine = _goldLine(context, ref, isToday: isToday);
    final description = festival.description.trim();
    // The name follows the app language (catalog regional name, else English).
    final locale = AppLocalizations.of(context)?.localeName ?? 'en';
    final displayName = festivalDisplayName(festival: festival, locale: locale);
    // One composed label instead of the row's separate Text nodes (which
    // would otherwise repeat the name and date after this label).
    final semanticsLabel = [displayName, ?goldLine].join('. ');

    return Semantics(
      button: onTap != null,
      label: semanticsLabel,
      hint: description.isEmpty ? null : description,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(flush ? 14 : 16),
        child: Ink(
          // Flush rows live on a parent card and stay transparent (the card
          // draws dividers); standalone rows supply their own surface.
          decoration: flush
              ? AppTheme.festivalRowDecoration(
                  context,
                  isSelectedDay: isSelectedDay,
                )
              : AppTheme.festivalListRowDecoration(context),
          child: InkWell(
            borderRadius: BorderRadius.circular(flush ? 14 : 16),
            onTap: onTap == null
                ? null
                : () {
                    AppHaptics.tap(ref);
                    onTap!();
                  },
            child: ExcludeSemantics(
              child: Padding(
                // Flush rows hand their horizontal inset to the parent card,
                // so the leading tile lines up with the card heading.
                // [horizontalPadding] then pads inside the tappable surface
                // (the wash/highlight) without moving the tile.
                padding: EdgeInsets.symmetric(
                  horizontal: horizontalPadding ?? (flush ? 0 : AppSpacing.s12),
                  vertical: AppSpacing.s12,
                ),
                child: Row(
                  children: [
                    FestivalThumbnail(
                      festival: festival,
                      size: leadingTileSize,
                      backgroundColor: AppTheme.festivalTileBackground(context),
                      glyphColor: gold,
                    ),
                    const SizedBox(width: leadingGap),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            displayName,
                            style: AppTypography.ui(
                              fontSize: AppTypography.sizeSubtitle,
                              fontWeight: AppTypography.semibold,
                              height: 1.3,
                              color: context.colors.onSurface,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (goldLine != null) ...[
                            const SizedBox(height: AppSpacing.s2),
                            Text(
                              goldLine,
                              style: TextStyle(
                                fontSize: AppTypography.sizeDetail,
                                fontWeight: AppTypography.semibold,
                                color: gold,
                              ),
                              // Two lines so the "in N days" suffix survives on
                              // narrow screens instead of ellipsizing away.
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                          if (description.isNotEmpty) ...[
                            const SizedBox(height: AppSpacing.s2),
                            Text(
                              description,
                              style: TextStyle(
                                fontSize: AppTypography.sizeDetail,
                                color: context.secondaryInk,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (onTap != null) ...[
                      const SizedBox(width: AppSpacing.s8),
                      Icon(Icons.chevron_right_rounded, color: context.hintInk),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
