import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../l10n/app_localizations_en.dart';
import '../core/format/date_only.dart';
import '../models/festival.dart';
import '../models/panchang_data.dart';
import '../providers/accessibility_provider.dart';
import '../providers/calendar_provider.dart';
import '../theme/app_theme.dart';
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
class FestivalRowTile extends ConsumerWidget {
  const FestivalRowTile({
    super.key,
    required this.festival,
    this.date,
    this.panchang,
    this.daysAway,
    this.isSelectedDay = false,
    this.onTap,
  });

  final Festival festival;
  final DateTime? date;
  final PanchangData? panchang;
  final int? daysAway;
  final bool isSelectedDay;
  final VoidCallback? onTap;


  String? _goldLine(
    BuildContext context, {
    required bool isToday,
  }) {
    final l10n = AppLocalizations.of(context) ?? AppLocalizationsEn();
    final day = date;
    if (day != null) {
      final parts = <String>[
        isToday
            ? l10n.today
            : formatLocalizedDate(day, 'EEE, d MMM', l10n.localeName),
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
    final goldLine = _goldLine(context, isToday: isToday);
    final description = festival.description.trim();
    // One composed label instead of the row's separate Text nodes (which
    // would otherwise repeat the name and date after this label).
    final semanticsLabel = [festival.name, ?goldLine].join('. ');

    return Semantics(
      button: onTap != null,
      label: semanticsLabel,
      hint: description.isEmpty ? null : description,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: AppTheme.festivalRowDecoration(
            context,
            isSelectedDay: isSelectedDay,
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onTap == null
                ? null
                : () {
                    if (ref.read(accessibilityProvider).hapticFeedback) {
                      HapticFeedback.lightImpact();
                    }
                    onTap!();
                  },
            child: ExcludeSemantics(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    FestivalThumbnail(
                      festival: festival,
                      size: 48,
                      backgroundColor: AppTheme.festivalTileBackground(
                        context,
                      ),
                      glyphColor: gold,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            festival.name,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: context.colors.onSurface,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (goldLine != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              goldLine,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: gold,
                              ),
                              // Two lines so the "in N days" suffix survives on
                              // narrow screens instead of ellipsizing away.
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                          if (description.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              description,
                              style: TextStyle(
                                fontSize: 13,
                                color: context.colors.onSurface.withValues(
                                  alpha: 0.6,
                                ),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (onTap != null) ...[
                      const SizedBox(width: 8),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: context.colors.onSurface.withValues(alpha: 0.5),
                      ),
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

