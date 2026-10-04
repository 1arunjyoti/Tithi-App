// P0-1: canonical date-only helpers. Replaces the scattered private copies:
// normalizeUiDate (panchang_cache), _dateOnly (festival_matching_pipeline,
// countdown_providers, all_festivals_screen), _isSameDay (panchang_provider,
// tithi_detail_sheet) — all identical day-truncation/day-equality logic.

/// Truncates [date] to its calendar day (local time).
DateTime dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

/// True when [a] and [b] fall on the same calendar day.
bool isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// Calendar-day difference `to - from` (whole days, DST-safe).
///
/// `DateTime.difference().inDays` on local midnights truncates 23/25-hour
/// DST days, so a one-calendar-day span across a DST transition can report
/// 0. Comparing UTC-midnight constructions of the same wall dates counts
/// calendar days instead of elapsed hours — matching
/// `ChronoUnit.DAYS.between(LocalDate)` on the Android widget side.
int calendarDaysBetween(DateTime from, DateTime to) {
  final a = DateTime.utc(from.year, from.month, from.day);
  final b = DateTime.utc(to.year, to.month, to.day);
  return b.difference(a).inDays;
}
