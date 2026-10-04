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

/// Best-effort glyph per festival category (the bundle ships no per-festival
/// icon metadata). Major festivals get the gold sun from the redesign mock,
/// vrats the temple glyph, everything else the celebration glyph.
IconData festivalRowIcon(Festival festival) {
  return switch (festival.category) {
    'major' => Icons.wb_sunny_rounded,
    'vrat' => Icons.temple_buddhist,
    _ => Icons.celebration_rounded,
  };
}

/// Single festival row shared by the home "Festivals & Events" card and the
/// all-festivals screen: gold icon tile, bold name, gold date/tithi line with
/// an optional "in N days" suffix, dim one-line description, chevron.
///
/// Pass [date]/[panchang]/[daysAway] for dated rows (home card). Without a
/// date the gold line falls back to the category label (all-festivals list).
/// A null [onTap] renders the row without a chevron or ripple.
class FestivalRowTile extends ConsumerWidget {
  const FestivalRowTile({
    super.key,
    required this.festival,
    this.date,
    this.panchang,
    this.daysAway,
    this.onTap,
  });

  final Festival festival;
  final DateTime? date;
  final PanchangData? panchang;
  final int? daysAway;
  final VoidCallback? onTap;


  String? _goldLine(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context) ?? AppLocalizationsEn();
    final day = date;
    if (day != null) {
      // App "today" (midnight-refreshed + resume-corrected), not wall-clock
      // now: a suspended-then-resumed app would otherwise label rows with
      // yesterday's Today around midnight.
      final today = ref.watch(todayDateProvider);
      final isToday = isSameDay(day, today);
      final parts = <String>[
        isToday
            ? l10n.today
            : formatLocalizedDate(day, 'EEE, d MMM', l10n.localeName),
      ];
      // The tithi half needs the day's panchang, which the home card already
      // holds; the all-festivals list passes date-only rows (no extra fetch).
      final p = panchang;
      if (p != null) {
        parts.add(
          '${p.isShukla ? l10n.waxing : l10n.waning} '
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
    final goldLine = _goldLine(context, ref);
    final description = festival.description.trim();

    return Semantics(
      button: onTap != null,
      label: festival.name,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: AppTheme.festivalRowDecoration(context),
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
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppTheme.festivalTileBackground(context),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      festivalRowIcon(festival),
                      size: 24,
                      color: gold,
                    ),
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
    );
  }
}
