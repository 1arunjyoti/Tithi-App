import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/calendar/calendar_guards.dart';
import '../core/format/date_only.dart';
import '../core/locale/app_locale.dart';
import '../features/sheets/domain/sheet_labels.dart';
import '../l10n/app_localizations.dart';
import '../models/hindu_month_system.dart';
import '../services/bengali_calendar_service.dart';
import '../services/hindu_calendar_service.dart';
import '../utils/tithi_localization.dart';
import 'calendar_provider.dart';
import 'locale_provider.dart';

// Festival list dates used to be formatted straight from their Gregorian
// DateTime (`'EEE, d MMM'` and friends), so changing the primary calendar in
// Settings never changed a row. This is the single resolver for those labels:
// it keeps the caller's Gregorian pattern for the Gregorian (and `none`) case
// and swaps in the same masa/tithi or Bengali date the hero and tithi sheet
// already use for every other system.

/// Arguments for [primaryCalendarDatePartProvider].
///
/// [gregorianPattern] is the intl pattern the call site used before this
/// helper existed, so Gregorian output stays byte-for-byte identical (and
/// existing widget tests keep finding the same strings).
typedef PrimaryCalendarDateArgs = ({
  DateTime date,
  String gregorianPattern,
  String locale,
});

/// The calendar-specific half of a date label, in the primary calendar:
///
/// * Gregorian (or `none`): [PrimaryCalendarDateArgs.date] formatted with
///   [PrimaryCalendarDateArgs.gregorianPattern].
/// * Hindu: Purnimant-correct masa + paksha/tithi (e.g. "Kartik Shukla
///   Ekadashi"), using the same rules as the hero and the tithi sheet.
/// * Bengali: "day month year" (Bengali script/digits under the `bn` app
///   language), from [bengaliDateLabels].
///
/// Falls back to the Gregorian string while resolving or when a calendar
/// service is unavailable. The weekday is deliberately left out: every
/// calendar shares it, and callers need different widths (`EEE` vs `EEEE`)
/// or replace it entirely with "Today". Use [primaryCalendarDateLine] for
/// the common short "weekday, date" form.
final primaryCalendarDatePartProvider = FutureProvider.autoDispose
    .family<String, PrimaryCalendarDateArgs>((ref, arg) async {
  final date = dateOnly(arg.date);
  final gregorian = formatLocalizedDate(date, arg.gregorianPattern, arg.locale);
  final system = ref.watch(primaryCalendarSystemProvider);

  switch (system) {
    case AppCalendarSystem.gregorian:
    case AppCalendarSystem.none:
      return gregorian;

    case AppCalendarSystem.hindu:
      // Masa follows the selected Panjika and month system; watch both so a
      // school/toggle change recomputes the label instead of pinning a stale
      // one (same guard the sheet and schedule providers use).
      ref.watch(panchangSchoolProvider);
      final monthSystem = ref.watch(hinduMonthSystemProvider);
      final appLocale = resolveAppLocale(ref.watch(localeProvider));
      final l10n = await _safeL10n(appLocale);
      final hDate = await guarded(
        () => ref.read(hinduCalendarServiceProvider).calculateDate(date),
      );
      if (hDate == null) return gregorian;
      final masa = localizedHinduMonthName(
        displayMasaName(hDate.masa, hDate.paksha, monthSystem).replaceAll(
          '_',
          ' ',
        ),
        l10n,
      );
      final tithiIndex = hDate.paksha == 'Krishna'
          ? hDate.tithi + 15
          : hDate.tithi;
      return '$masa ${localizedPakshaTithiName(tithiIndex, l10n)}'.trim();

    case AppCalendarSystem.bengali:
      final useBengaliScript =
          resolveAppLocale(ref.watch(localeProvider)).languageCode == 'bn';
      final bDate = await guarded(
        () => ref.read(bengaliCalendarServiceProvider).calculateDate(date),
      );
      if (bDate == null) return gregorian;
      return bengaliDateLabels(
        day: bDate.day,
        month: bDate.month,
        year: bDate.year,
        useBengaliScript: useBengaliScript,
      ).compact;
  }
});

Future<AppLocalizations> _safeL10n(Locale locale) async {
  try {
    return await AppLocalizations.delegate.load(locale);
  } catch (_) {
    return AppLocalizations.delegate.load(const Locale('en'));
  }
}

/// Watched primary-calendar date part with a synchronous Gregorian fallback.
/// Widgets call this from `build` so the row paints immediately and upgrades
/// in place once an FFI-backed label resolves.
String primaryCalendarDatePart(
  WidgetRef ref,
  DateTime date,
  String locale, {
  required String gregorianPattern,
}) {
  final args = (
    date: dateOnly(date),
    gregorianPattern: gregorianPattern,
    locale: locale,
  );
  return ref.watch(primaryCalendarDatePartProvider(args)).valueOrNull ??
      formatLocalizedDate(date, gregorianPattern, locale);
}

/// Short "weekday, date" line shared by festival rows, featured cards and
/// countdown tiles. The weekday stays Gregorian (all calendars share it);
/// only the date half follows the primary calendar.
String primaryCalendarDateLine(
  WidgetRef ref,
  DateTime date,
  String locale, {
  required String gregorianPattern,
}) {
  return '${formatLocalizedDate(date, 'EEE', locale)}, '
      '${primaryCalendarDatePart(
        ref,
        date,
        locale,
        gregorianPattern: gregorianPattern,
      )}';
}
