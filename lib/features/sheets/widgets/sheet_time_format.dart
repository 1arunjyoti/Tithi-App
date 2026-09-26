import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format/date_only.dart';
import '../../../utils/tithi_localization.dart';
import '../../tithi_sheet/providers/sheet_providers.dart';

// Shared timing formatters for the tithi detail sheet and the festival
// event sheet: both show the same observed-tithi Begins/Ends span, so the
// "clock time, primary-calendar date" values and the almanac-style ranges
// render identically instead of drifting (event sheet was Gregorian-only).

/// Full timing value for an instant: clock time plus the primary-calendar
/// date label, falling back to the Gregorian date while resolving (or when
/// Gregorian is primary). Single watch per call site via
/// [instantPrimaryLabelProvider]; Riverpod memoizes repeat instants.
String sheetInstantValue(
  WidgetRef ref,
  DateTime instant,
  int tithiIndex,
  String locale,
) {
  final label = ref
      .watch(
        instantPrimaryLabelProvider((instant: instant, tithiIndex: tithiIndex)),
      )
      .valueOrNull;
  return '${formatLocalizedDate(instant, 'jm', locale)}, '
      '${label ?? formatLocalizedDate(instant, 'MMM d', locale)}';
}

/// Time range with a shared day period ("8:27 – 9:59 AM"): the start drops
/// its own period, matching almanac convention. When the ends fall in
/// different halves (Nishita spans midnight), both periods are shown
/// ("11:26 PM – 12:16 AM"). Either end outside the sheet's civil [day]
/// gains a short date of its own ("11:26 PM, Oct 3 – 12:16 AM, Oct 4"),
/// so previous/next-day spans stay unambiguous.
String sheetTimeRange(
  DateTime start,
  DateTime end,
  DateTime day,
  String locale,
) {
  String stamp(DateTime t, {required bool withPeriod}) {
    final time = withPeriod
        ? formatLocalizedDate(t, 'jm', locale)
        : formatLocalizedDate(t, 'h:mm', locale);
    return isSameDay(t, day)
        ? time
        : '$time, ${formatLocalizedDate(t, 'MMM d', locale)}';
  }

  final sharedPeriod =
      formatLocalizedDate(start, 'a', locale) ==
      formatLocalizedDate(end, 'a', locale);
  if (sharedPeriod && isSameDay(start, day)) {
    return '${stamp(start, withPeriod: false)} – '
        '${stamp(end, withPeriod: true)}';
  }
  return '${stamp(start, withPeriod: true)} – '
      '${stamp(end, withPeriod: true)}';
}
