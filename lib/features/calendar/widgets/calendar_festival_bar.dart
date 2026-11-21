import 'package:material_ui/material_ui.dart';

import '../../../models/panchang_data.dart';
import '../../../theme/app_metrics.dart';
import '../../../theme/app_theme.dart';
import '../data/calendar_caches.dart';

/// Festival pill-bar marker (redesign): a 12x3 rounded bar instead of a dot.
/// Color follows tile state — moon-fill on selected, ring color on today,
/// accent bar otherwise (minor festivals dimmed). Takes pre-resolved flags so
/// callers never mismatch date ranges.
class CalendarFestivalBar extends StatelessWidget {
  const CalendarFestivalBar({
    super.key,
    required this.isMajor,
    required this.isSelected,
    required this.isToday,
  });

  final bool isMajor;
  final bool isSelected;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    final highContrast = AppTheme.highContrastOf(context);
    Color color;
    if (isSelected) {
      color = highContrast
          ? context.colors.onPrimary
          : AppTheme.heroMoonFill(context);
    } else if (isToday) {
      color = highContrast
          ? context.colors.primary
          : AppTheme.calendarTodayRing(context);
    } else {
      color = AppTheme.calendarFestivalBar(context);
      if (!isMajor) color = color.withValues(alpha: 0.45);
    }
    return Positioned(
      bottom: 5,
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          width: 12,
          height: 3,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
        ),
      ),
    );
  }
}

/// Optimized festival marker using pre-loaded monthly panchang cache.
/// Used by the Gregorian TableCalendar path.
/// Falls back to the sync stale-dot LRU when [monthlyPanchang] doesn't
/// contain [date] yet (during swipe animation, or while the next month's
/// provider is still loading) so dots don't pop in late.
Widget? buildFestivalMarkerFromCache(
  BuildContext context,
  DateTime date,
  Map<DateTime, PanchangData> monthlyPanchang, {
  required bool isSelected,
  required bool isToday,
}) {
  final normalizedDate = DateTime(date.year, date.month, date.day);
  final panchang = monthlyPanchang[normalizedDate];

  if (panchang != null) {
    if (!panchang.hasFestivals) return null;
    return CalendarFestivalBar(
      isMajor: panchang.majorFestivals.isNotEmpty,
      isSelected: isSelected,
      isToday: isToday,
    );
  }

  final stale = cachedFestivalDotSync(normalizedDate);
  if (stale == null || !stale.hasFestivals) return null;
  return CalendarFestivalBar(
    isMajor: stale.isMajor,
    isSelected: isSelected,
    isToday: isToday,
  );
}
