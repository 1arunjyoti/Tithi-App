// Shared date-formatting utilities used by both providers and services.
//
// Centralises the panchang date-key format (`YYYY-MM-DD`) so that every
// consumer produces identical keys for the same calendar date.

/// Returns a zero-padded `YYYY-MM-DD` string suitable for use as a Hive key
/// or cache key.  Time components are stripped before formatting.
String panchangDateKey(DateTime date) {
  final normalized = DateTime(date.year, date.month, date.day);
  final month = normalized.month.toString().padLeft(2, '0');
  final day = normalized.day.toString().padLeft(2, '0');
  return '${normalized.year}-$month-$day';
}
