import 'package:flutter_riverpod/legacy.dart';

/// Provider for currently selected date in calendar
final selectedDateProvider = StateProvider<DateTime>((ref) {
  return DateTime.now();
});

/// Provider for the focused month in calendar view
final focusedMonthProvider = StateProvider<DateTime>((ref) {
  return DateTime.now();
});

/// Provider for calendar format (month/week/2 weeks)
enum CalendarViewFormat { month, twoWeeks, week }

final calendarFormatProvider = StateProvider<CalendarViewFormat>((ref) {
  return CalendarViewFormat.month;
});
