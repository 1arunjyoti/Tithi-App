// Scroll-position arithmetic for the schedule view, extracted from the former
// widgets/schedule_view_widget.dart monolith.
//
// The view is a bidirectional CustomScrollView centred on an anchor day, so
// every visible row is addressed by a signed day offset from that anchor.

/// Estimated height of one schedule row.
///
/// Only used to map a scroll offset back to a date for the sticky header; the
/// rows themselves are laid out by the slivers.
const double scheduleRowEstimate = 80.0;

/// The calendar date [dayOffset] days from [anchor].
///
/// Negative offsets are past days, positive are future days. `DateTime`
/// normalises month/year overflow, so no manual rollover is needed.
DateTime scheduleDayAt(DateTime anchor, int dayOffset) =>
    DateTime(anchor.year, anchor.month, anchor.day + dayOffset);

/// The date the sticky header should name for [scrollOffset] pixels.
DateTime scheduleVisibleDate(DateTime anchor, double scrollOffset) =>
    scheduleDayAt(anchor, (scrollOffset / scheduleRowEstimate).round());

/// Whether the sticky header must repaint: the visible month or year crossed.
bool scheduleMonthChanged(DateTime current, DateTime visible) =>
    visible.month != current.month || visible.year != current.year;
