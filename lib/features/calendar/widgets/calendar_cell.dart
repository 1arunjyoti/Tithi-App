import 'package:material_ui/material_ui.dart';

import '../../../core/anim/press_scale.dart';
import '../../../l10n/app_localizations.dart';
import '../../../theme/app_metrics.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/app_typography.dart';
import '../../../utils/tithi_localization.dart';
import '../../../widgets/calendar_day_semantics.dart';

/// One date tile, shared by the Gregorian and adaptive grids.
///
/// The tap handler lives on the enclosing grid; this widget owns the visual
/// states (selected/today/outside) and the press-scale microinteraction.
class CalendarCell extends StatelessWidget {
  final DateTime date;
  final bool isSelected;
  final bool isToday;
  final String primaryText;
  final String? secondaryText;
  final bool isOutside;

  const CalendarCell({
    super.key,
    required this.date,
    required this.isSelected,
    required this.isToday,
    this.primaryText = '',
    this.secondaryText,
    this.isOutside = false,
  });

  @override
  Widget build(BuildContext context) {
    // The app propagates the accessibility high-contrast setting into
    // MediaQuery, so no provider watch is needed here.
    final highContrast = AppTheme.highContrastOf(context);
    // Locale digits for the day/tithi numbers: Latin in every locale stays
    // Latin, Bengali renders Bengali digits. Applied at render time (not in
    // the providers) so the sync label caches stay locale-independent.
    final locale = Localizations.localeOf(context).languageCode;
    final resolvedPrimary = localizeDigits(
      primaryText.isEmpty ? date.day.toString() : primaryText,
      locale,
    );

    final scheme = context.colors;
    // Selected wins over today (spec .today.sel).
    BoxDecoration? decoration;
    Color textColor = scheme.onSurface;
    FontWeight weight = AppTypography.medium;
    Matrix4? transform;

    if (isSelected) {
      decoration = BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.dense),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: AppTheme.calendarSelectedGradient(context),
        ),
        border: highContrast
            ? Border.all(
                color: scheme.onSurface.withValues(alpha: 0.6),
                width: 1.5,
              )
            : null,
        // Dark themes get a soft glow; light stays flat (zero shadows).
        boxShadow: highContrast || !context.isDark
            ? null
            : [
                BoxShadow(
                  color: AppTheme.heroGlow(context),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
      );
      textColor = AppTheme.calendarSelectedForeground(context);
      weight = AppTypography.semibold;
      transform = Matrix4.identity()..scaleByDouble(1.08, 1.08, 1.0, 1.0);
    } else if (isToday) {
      decoration = BoxDecoration(
        color: AppTheme.calendarTodayBackground(context),
        borderRadius: BorderRadius.circular(AppRadius.dense),
        border: Border.all(
          color: AppTheme.calendarTodayRing(context),
          width: 1.5,
        ),
      );
      textColor = AppTheme.calendarTodayForeground(context);
      weight = AppTypography.semibold;
    }

    // Outside-month days render muted (spec `.d.muted`: dim at 35%) unless
    // they carry the selected/today emphasis.
    if (isOutside && !isSelected && !isToday) {
      textColor = context.faintInk;
    }

    final secondaryColor = isSelected
        ? AppTheme.calendarSelectedForeground(context).withValues(alpha: 0.7)
        : isToday
        ? AppTheme.calendarTodayForeground(context).withValues(alpha: 0.7)
        : isOutside
        ? context.faintInk
        : context.hintInk;

    // 2px gutter on every tile: adjacent squares no longer touch, so the
    // selected tile's 1.08 scale (~2px overflow on a ~50px cell) just fills
    // its own gutter instead of covering the neighbor's today-ring. The
    // weekend stripe shows through the gutters, as in the spec grid.
    // Press-down microinteraction + gated haptic live in PressScale, shared
    // by the Gregorian builders and the adaptive grid (single wrap point).
    // Callers' onTap/onDaySelected must NOT buzz separately (double-buzz).
    // The fill matters here: most tiles are transparent, so scale alone
    // wouldn't read as a hit — the tint briefly reveals the tap target.
    // The painted tile has no text semantics of its own beyond the day number
    // and the corner label; a screen reader should hear one node that also
    // says this is a button, and whether it is today/selected.
    final l10n = AppLocalizations.of(context);
    final detail = secondaryText == null
        ? null
        : localizeDigits(secondaryText!, locale);

    return CalendarDaySemantics(
      dayLabel: resolvedPrimary,
      detail: detail,
      isToday: isToday,
      isSelected: isSelected,
      todayLabel: l10n?.today ?? 'Today',
      selectedLabel: l10n?.selected ?? 'Selected',
      child: PressScale(
        highlightColor: scheme.primary.withValues(alpha: 0.12),
        highlightRadius: BorderRadius.circular(AppRadius.dense),
        child: Container(
          margin: const EdgeInsets.all(AppSpacing.s2),
          decoration: decoration,
          transform: transform,
          transformAlignment: Alignment.center,
          // NOTE: no clipBehavior here — Container asserts
          // (decoration != null || clipBehavior == Clip.none), and plain day
          // tiles have no decoration. The children (centered number + corner
          // label) never reach the rounded corners, so no clip is needed.
          child: Stack(
            children: [
              Center(
                child: Text(
                  resolvedPrimary,
                  style: TextStyle(
                    color: textColor,
                    fontSize: AppTypography.sizeBody,
                    fontWeight: weight,
                  ),
                ),
              ),
              if (detail != null)
                Positioned(
                  top: 4,
                  left: 6,
                  child: Text(
                    detail,
                    style: TextStyle(
                      color: secondaryColor,
                      fontSize: AppTypography.sizeMicro,
                      fontWeight: AppTypography.medium,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
