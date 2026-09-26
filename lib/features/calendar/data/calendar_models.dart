// Phase 3b: calendar cell models extracted from widgets/calendar_widget.dart
// (_CalendarCellData / _AdaptiveCalendarData, made public). The widget
// re-exports these so existing grid code keeps working during migration.
class CalendarCellData {
  final String primary;
  final String? secondary;
  final bool hasFestivals;
  final bool hasMajorFestival;

  const CalendarCellData({
    required this.primary,
    this.secondary,
    this.hasFestivals = false,
    this.hasMajorFestival = false,
  });
}

class AdaptiveCalendarData {
  final List<DateTime?> days;
  final Map<DateTime, CalendarCellData> cellData;

  const AdaptiveCalendarData({required this.days, required this.cellData});
}

/// Data class to hold header information for the calendar.
/// The secondary line splits into an accent part (month range) and a dim
/// part (year), mirroring the redesign's lunar line.
class HeaderData {
  final String primaryText;
  final String? secondaryAccent;
  final String? secondaryDim;

  HeaderData({
    required this.primaryText,
    this.secondaryAccent,
    this.secondaryDim,
  });
}

/// Month-range parts for the lunar line: accent (months) + dim (years).
typedef MonthRangeParts = ({String accent, String dim});
