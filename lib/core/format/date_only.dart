// P0-1: canonical date-only helpers. Replaces the scattered private copies:
// normalizeUiDate (panchang_cache), _dateOnly (festival_matching_pipeline,
// countdown_providers, all_festivals_screen), _isSameDay (panchang_provider,
// tithi_detail_sheet) — all identical day-truncation/day-equality logic.

/// Truncates [date] to its calendar day (local time).
DateTime dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

/// True when [a] and [b] fall on the same calendar day.
bool isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;
