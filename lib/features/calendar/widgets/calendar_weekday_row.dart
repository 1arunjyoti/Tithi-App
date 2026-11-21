import 'package:material_ui/material_ui.dart';

import '../../../l10n/app_localizations.dart';
import '../../../providers/calendar_provider.dart' as cp;
import '../../../theme/app_metrics.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/app_typography.dart';

/// Weekday header row shared by the Gregorian and adaptive grids: 3-letter
/// uppercase labels with weekend columns in the accent color. Order follows
/// [startOfWeek] to match the grid columns below. Labels come from
/// AppLocalizations so Hindi/Bengali/Sanskrit show their own weekday names.
class CalendarWeekdayRow extends StatelessWidget {
  const CalendarWeekdayRow({super.key, required this.startOfWeek});

  final cp.StartingDayOfWeek startOfWeek;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // Sunday-first and Monday-first orders of the localized short names
    // (English fallbacks for contexts without localizations, e.g. tests).
    List<String> ordered(bool mondayFirst) {
      final days = [
        l10n?.weekdaySundayShort ?? 'SUN',
        l10n?.weekdayMondayShort ?? 'MON',
        l10n?.weekdayTuesdayShort ?? 'TUE',
        l10n?.weekdayWednesdayShort ?? 'WED',
        l10n?.weekdayThursdayShort ?? 'THU',
        l10n?.weekdayFridayShort ?? 'FRI',
        l10n?.weekdaySaturdayShort ?? 'SAT',
      ];
      return mondayFirst ? [...days.sublist(1), days[0]] : days;
    }

    final labels = ordered(startOfWeek == cp.StartingDayOfWeek.monday);
    // Weekend columns depend on the week start (Sun/Sat at 0+6 or 5+6).
    bool isWeekend(int index) => startOfWeek == cp.StartingDayOfWeek.monday
        ? index >= 5
        : (index == 0 || index == 6);
    return Row(
      children: [
        for (var i = 0; i < 7; i++)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.s6),
              child: Text(
                labels[i],
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: AppTypography.sizeMicro,
                  fontWeight: AppTypography.semibold,
                  letterSpacing: 0.6,
                  color: isWeekend(i)
                      ? context.colors.primary
                      : context.secondaryInk,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Weekend column tint behind a 7-column grid (redesign weekend striping).
/// Runs are contiguous weekend-column ranges so Monday-start weekends render
/// as one stripe. Both children grids use equal full-width columns, so
/// sevenths geometry always lines up.
class CalendarWeekendStripes extends StatelessWidget {
  const CalendarWeekendStripes({
    super.key,
    required this.startOfWeek,
    required this.child,
  });

  final cp.StartingDayOfWeek startOfWeek;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final runs = startOfWeek == cp.StartingDayOfWeek.monday
        ? const [
            [5, 6],
          ]
        : const [
            [0, 0],
            [6, 6],
          ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final column = constraints.maxWidth / 7;
        return Stack(
          children: [
            for (final run in runs)
              Positioned(
                top: 0,
                bottom: 0,
                left: column * run[0],
                width: column * (run[1] - run[0] + 1),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppTheme.calendarWeekendStripe(context),
                    borderRadius: BorderRadius.circular(AppRadius.dense),
                  ),
                ),
              ),
            child,
          ],
        );
      },
    );
  }
}
