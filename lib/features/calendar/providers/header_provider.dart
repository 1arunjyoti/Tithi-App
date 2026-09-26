import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/locale/app_locale.dart';
import '../../../providers/calendar_provider.dart' as cp;
import '../../../providers/locale_provider.dart';
import '../data/calendar_models.dart';
import '../domain/header_builders.dart';

// Phase 3c: header provider extracted from widgets/calendar_widget.dart.
// Name and behavior unchanged; the widget re-exports it.

// autoDispose: one tiny HeaderData per visited month; the sync LRU
// (headerDataCache) preserves headers across disposal, so the next visit
// renders stale text instantly while fresh data resolves behind it.
final calendarHeaderDataProvider = FutureProvider.autoDispose<HeaderData>((
  ref,
) async {
  final date = ref.watch(cp.focusedMonthProvider);
  final primary = ref.watch(cp.primaryCalendarSystemProvider);
  final secondary = ref.watch(cp.secondaryCalendarSystemProvider);
  final hinduYearEra = ref.watch(cp.hinduYearEraProvider);
  final hinduMonthSystem = ref.watch(cp.hinduMonthSystemProvider);
  // Re-resolve when the app language changes: Gregorian month names (and the
  // header cache key below) are locale-dependent.
  final localeCode = resolveAppLocale(ref.watch(localeProvider)).languageCode;
  // Tapping a date tile narrows the secondary range label to that date's
  // single month; the tap state (not the default-selected today) drives a
  // header refresh, so the two-month range stays the default. Subscribed
  // whenever the secondary header is a range — Gregorian primary with a
  // traditional secondary, or a lunar (Hindu/Bengali) primary with any
  // secondary (Gregorian range over the lunar span, or the other
  // traditional system's range over the span). Otherwise tile taps would
  // pointlessly recompute a single-month primary label.
  final tapNarrowsSecondary =
      (primary == cp.AppCalendarSystem.gregorian &&
          (secondary == cp.AppCalendarSystem.hindu ||
              secondary == cp.AppCalendarSystem.bengali)) ||
      ((primary == cp.AppCalendarSystem.hindu ||
              primary == cp.AppCalendarSystem.bengali) &&
          secondary != cp.AppCalendarSystem.none &&
          secondary != primary);
  final tappedDate = tapNarrowsSecondary
      ? ref.watch(cp.tappedCalendarDateProvider)
      : null;
  // Gregorian months compare by year-month; lunar months span two Gregorian
  // months, so a tapped date inside the viewed lunar span usually has a
  // different Gregorian month than the focused start date. Pass it through
  // and let the range builder validate containment (out-of-span taps fall
  // back to the range).
  final tappedInMonth = tappedDate == null
      ? null
      : (primary == cp.AppCalendarSystem.gregorian
            ? (tappedDate.year == date.year && tappedDate.month == date.month
                  ? DateTime(tappedDate.year, tappedDate.month, tappedDate.day)
                  : null)
            : DateTime(tappedDate.year, tappedDate.month, tappedDate.day));

  final data = await buildCalendarHeaderData(
    ref,
    date,
    primary,
    secondary,
    hinduYearEra,
    hinduMonthSystem,
    selectedDate: tappedInMonth,
  );
  // Feed the stale-header LRU so the next swipe shows text instantly
  // instead of falling back to bare Gregorian and flipping.
  storeHeaderSync(
    date,
    primary,
    secondary,
    hinduYearEra,
    hinduMonthSystem,
    data,
    locale: localeCode,
    selectedDate: tappedInMonth,
  );
  return data;
});
