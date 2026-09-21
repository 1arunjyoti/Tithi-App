import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/locale/app_locale.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/hindu_month_system.dart';
import '../../../providers/calendar_provider.dart' as cp;
import '../../../providers/locale_provider.dart';
import '../../../providers/panchang_provider.dart';
import '../../../services/bengali_calendar_service.dart';
import '../../../services/hindu_calendar_service.dart';
import '../../../utils/tithi_localization.dart';
import '../data/calendar_caches.dart';
import '../data/calendar_models.dart';

// Phase 3c: header builders extracted from widgets/calendar_widget.dart.
// Provider-side builders run without a BuildContext, resolving
// AppLocalizations through the localeProvider-then-system rule.

// Sync LRU for calendar headers (Gregorian primary + Hindu/Bengali secondary
// range needs 2 FFI calls). Without a stale fallback the header shows bare
// Gregorian text during the swipe then flips once FFI resolves — perceived
// as lag. Populated from every loaded month so the next swipe shows stale
// text instantly while fresh data resolves behind it.
final Map<String, HeaderData> headerDataCache = {};
const int headerDataCacheMax = 120;

String headerCacheKey(
  DateTime date,
  cp.AppCalendarSystem primary,
  cp.AppCalendarSystem secondary,
  HinduYearEra yearEra,
  HinduMonthSystem monthSystem, {
  required String locale,
  DateTime? selectedDate,
}) {
  final selectedKey = selectedDate == null
      ? 'range'
      : '${selectedDate.year}-${selectedDate.month}-${selectedDate.day}';
  // Lunar primaries are keyed by the exact focused day (the Hindu/Bengali
  // month start): two lunar months can start in the same Gregorian month,
  // so a year-month key would collide and serve the previous month's header
  // (the "stuck Bengali month" bug). Gregorian stays month-normalized so
  // TableCalendar's varying focusedDay still hits one entry per month.
  final dateKey = primary == cp.AppCalendarSystem.gregorian
      ? '${date.year}-${date.month}'
      : '${date.year}-${date.month}-${date.day}';
  return '${locale}_${dateKey}_${primary.index}_${secondary.index}_${yearEra.index}_${monthSystem.index}_$selectedKey';
}

HeaderData? cachedHeaderSync(
  DateTime date,
  cp.AppCalendarSystem primary,
  cp.AppCalendarSystem secondary,
  HinduYearEra yearEra,
  HinduMonthSystem monthSystem, {
  required String locale,
  DateTime? selectedDate,
}) {
  return headerDataCache[headerCacheKey(
    date,
    primary,
    secondary,
    yearEra,
    monthSystem,
    locale: locale,
    selectedDate: selectedDate,
  )];
}

void storeHeaderSync(
  DateTime date,
  cp.AppCalendarSystem primary,
  cp.AppCalendarSystem secondary,
  HinduYearEra yearEra,
  HinduMonthSystem monthSystem,
  HeaderData value, {
  required String locale,
  DateTime? selectedDate,
}) {
  if (headerDataCache.length >= headerDataCacheMax) {
    final toRemove = headerDataCache.keys
        .take(headerDataCacheMax ~/ 5)
        .toList();
    for (final k in toRemove) {
      headerDataCache.remove(k);
    }
  }
  headerDataCache[headerCacheKey(
        date,
        primary,
        secondary,
        yearEra,
        monthSystem,
        locale: locale,
        selectedDate: selectedDate,
      )] =
      value;
}

// Provider-side localizations: calendar header/range builders run without a
// BuildContext, so they resolve AppLocalizations through the same
// localeProvider-then-system rule the app shell uses (cf.
// hinduInstantLabelProvider in tithi_detail_sheet.dart).
Future<AppLocalizations> calendarL10n(Ref ref) async {
  final locale = resolveAppLocale(ref.read(localeProvider));
  try {
    return await AppLocalizations.delegate.load(locale);
  } catch (_) {
    return await AppLocalizations.delegate.load(const Locale('en'));
  }
}

Future<HeaderData> buildCalendarHeaderData(
  Ref ref,
  DateTime date,
  cp.AppCalendarSystem primary,
  cp.AppCalendarSystem secondary,
  HinduYearEra hinduYearEra,
  HinduMonthSystem hinduMonthSystem, {
  DateTime? selectedDate,
}) async {
  String primaryText;
  String? secondaryAccent;
  String? secondaryDim;

  // Single locale resolution for the whole header: month names, digits and
  // (for bn) masa script all follow the UI language.
  final l10n = await calendarL10n(ref);

  primaryText = await getSystemHeaderTextForCalendar(
    ref,
    l10n,
    date,
    primary,
    hinduYearEra,
    hinduMonthSystem,
  );

  if (primary == cp.AppCalendarSystem.gregorian) {
    final monthRange = await getTraditionalMonthRangeForCalendar(
      ref,
      date,
      secondary,
      hinduYearEra,
      hinduMonthSystem,
      selectedDate: selectedDate,
    );
    if (monthRange != null) {
      secondaryAccent = monthRange.accent;
      secondaryDim = monthRange.dim;
    }
  } else if ((primary == cp.AppCalendarSystem.hindu ||
          primary == cp.AppCalendarSystem.bengali) &&
      secondary == cp.AppCalendarSystem.gregorian) {
    final monthRange = await getGregorianMonthRangeForCalendar(
      ref,
      l10n,
      date,
      primary,
      selectedDate: selectedDate,
    );
    if (monthRange != null) {
      secondaryAccent = monthRange.accent;
      secondaryDim = monthRange.dim;
    }
  } else if ((primary == cp.AppCalendarSystem.hindu ||
          primary == cp.AppCalendarSystem.bengali) &&
      (secondary == cp.AppCalendarSystem.hindu ||
          secondary == cp.AppCalendarSystem.bengali) &&
      secondary != primary) {
    // Hindu primary + Bengali secondary (and vice versa): the secondary
    // line is the Bengali/Hindu month RANGE overlapping the viewed lunar
    // month's span — never a single month of the focused start day.
    final monthRange = await getSecondaryTraditionalRangeForLunarPrimary(
      ref,
      date,
      primary,
      secondary,
      hinduYearEra,
      hinduMonthSystem,
      selectedDate: selectedDate,
    );
    if (monthRange != null) {
      secondaryAccent = monthRange.accent;
      secondaryDim = monthRange.dim;
    }
  } else if (secondary != cp.AppCalendarSystem.none && secondary != primary) {
    secondaryAccent = await getSystemHeaderTextForCalendar(
      ref,
      l10n,
      date,
      secondary,
      hinduYearEra,
      hinduMonthSystem,
    );
  }

  logCalNav(
    'header date=${ymd(date)} primary=$primary secondary=$secondary '
    '-> "$primaryText" / "$secondaryAccent $secondaryDim"',
  );
  // UI-language finish: Bengali script for Hindu masa names under the bn
  // locale, locale digits for all years. The stale-header LRU is keyed by
  // locale, so cached entries stay consistent across language switches.
  final locale = l10n.localeName;
  String localizeHeaderPart(String text) =>
      localizeDigits(localizeMasaName(text, locale), locale);
  return HeaderData(
    primaryText: localizeHeaderPart(primaryText),
    secondaryAccent: secondaryAccent == null
        ? null
        : localizeHeaderPart(secondaryAccent),
    secondaryDim: secondaryDim == null
        ? null
        : localizeDigits(secondaryDim, locale),
  );
}

Future<MonthRangeParts?> getTraditionalMonthRangeForCalendar(
  Ref ref,
  DateTime date,
  cp.AppCalendarSystem system,
  HinduYearEra hinduYearEra,
  HinduMonthSystem hinduMonthSystem, {
  DateTime? selectedDate,
}) async {
  if (system != cp.AppCalendarSystem.bengali &&
      system != cp.AppCalendarSystem.hindu) {
    return null;
  }

  try {
    // Tapped date in the focused month: narrow the range to that date's
    // single month with the year (e.g. "Shravana 1948" instead of
    // "Shravana - Bhadrapada 1948").
    if (selectedDate != null) {
      if (system == cp.AppCalendarSystem.bengali) {
        final service = ref.read(bengaliCalendarServiceProvider);
        await ref.read(panchangInitProvider.future);
        final selectedBDate = await service.calculateDate(selectedDate);
        return (accent: selectedBDate.month, dim: '${selectedBDate.year}');
      } else {
        final service = ref.read(hinduCalendarServiceProvider);
        await ref.read(panchangInitProvider.future);
        final selectedHDate = await service.calculateDate(selectedDate);
        final year = hinduYearEra == HinduYearEra.vikramSamvat
            ? selectedHDate.vsYear
            : selectedHDate.shakaYear;
        final masa = displayMasaName(
          selectedHDate.masa,
          selectedHDate.paksha,
          hinduMonthSystem,
        ).replaceAll('_', ' ');
        return (accent: masa, dim: '$year');
      }
    }

    final startOfMonth = DateTime(date.year, date.month);
    final endOfMonth = DateTime(date.year, date.month + 1, 0);

    String startMonth;
    String endMonth;
    int startYear;
    int endYear;

    if (system == cp.AppCalendarSystem.bengali) {
      final service = ref.read(bengaliCalendarServiceProvider);
      await ref.read(panchangInitProvider.future);

      final startBDate = await service.calculateDate(startOfMonth);
      final endBDate = await service.calculateDate(endOfMonth);

      startMonth = startBDate.month;
      endMonth = endBDate.month;
      startYear = startBDate.year;
      endYear = endBDate.year;

      if (startMonth == endMonth && startYear == endYear) {
        return (accent: startMonth, dim: '$startYear');
      } else if (startYear == endYear) {
        return (accent: '$startMonth - $endMonth', dim: '$startYear');
      } else {
        return (
          accent: '$startMonth - $endMonth',
          dim: '$startYear - $endYear',
        );
      }
    } else {
      final service = ref.read(hinduCalendarServiceProvider);
      await ref.read(panchangInitProvider.future);

      final startHDate = await service.calculateDate(startOfMonth);
      final endHDate = await service.calculateDate(endOfMonth);

      startMonth = displayMasaName(
        startHDate.masa,
        startHDate.paksha,
        hinduMonthSystem,
      ).replaceAll('_', ' ');
      endMonth = displayMasaName(
        endHDate.masa,
        endHDate.paksha,
        hinduMonthSystem,
      ).replaceAll('_', ' ');

      startYear = hinduYearEra == HinduYearEra.vikramSamvat
          ? startHDate.vsYear
          : startHDate.shakaYear;
      endYear = hinduYearEra == HinduYearEra.vikramSamvat
          ? endHDate.vsYear
          : endHDate.shakaYear;

      if (startMonth == endMonth && startYear == endYear) {
        return (accent: startMonth, dim: '$startYear');
      } else if (startYear == endYear) {
        return (accent: '$startMonth - $endMonth', dim: '$startYear');
      } else {
        return (
          accent: '$startMonth - $endMonth',
          dim: '$startYear - $endYear',
        );
      }
    }
  } catch (e) {
    logCalError('traditional month range', e);
    return null;
  }
}

Future<MonthRangeParts?> getGregorianMonthRangeForCalendar(
  Ref ref,
  AppLocalizations l10n,
  DateTime date,
  cp.AppCalendarSystem primarySystem, {
  DateTime? selectedDate,
}) async {
  if (primarySystem != cp.AppCalendarSystem.bengali &&
      primarySystem != cp.AppCalendarSystem.hindu) {
    return null;
  }

  try {
    final gregorianMonths = [
      l10n.monthJanuary,
      l10n.monthFebruary,
      l10n.monthMarch,
      l10n.monthApril,
      l10n.monthMay,
      l10n.monthJune,
      l10n.monthJuly,
      l10n.monthAugust,
      l10n.monthSeptember,
      l10n.monthOctober,
      l10n.monthNovember,
      l10n.monthDecember,
    ];

    DateTime startDate;
    DateTime endDate;

    if (primarySystem == cp.AppCalendarSystem.bengali) {
      final service = ref.read(bengaliCalendarServiceProvider);
      await ref.read(panchangInitProvider.future);

      final bDate = await service.calculateDate(date);
      final monthIndex = service.bengaliMonths.indexOf(bDate.month);
      final year = bDate.year;

      startDate = await service.getMonthStart(year, monthIndex);

      var nextIndex = monthIndex + 1;
      var nextYear = year;
      if (nextIndex > 11) {
        nextIndex = 0;
        nextYear++;
      }
      endDate = await service.getMonthStart(nextYear, nextIndex);
      endDate = endDate.subtract(const Duration(days: 1));
    } else {
      // Exact-masa range: the containing month only, so an Adhika month no
      // longer stretches the range across both Adhika and Nija.
      final service = ref.read(hinduCalendarServiceProvider);
      await ref.read(panchangInitProvider.future);

      startDate = await service.monthStartContaining(date);
      endDate = await service.nextMonthStartAfter(startDate);
      endDate = endDate.subtract(const Duration(days: 1));
    }

    // Tapped tile inside the viewed lunar span narrows to that date's
    // single Gregorian month (mirrors the Gregorian-primary tap behavior).
    if (selectedDate != null &&
        !selectedDate.isBefore(startDate) &&
        !selectedDate.isAfter(endDate)) {
      final single = gregorianMonths[selectedDate.month - 1];
      return (accent: single, dim: '${selectedDate.year}');
    }

    final startMonth = gregorianMonths[startDate.month - 1];
    final endMonth = gregorianMonths[endDate.month - 1];
    final startYear = startDate.year;
    final endYear = endDate.year;

    if (startMonth == endMonth && startYear == endYear) {
      return (accent: startMonth, dim: '$startYear');
    } else if (startYear == endYear) {
      return (accent: '$startMonth - $endMonth', dim: '$startYear');
    } else {
      return (accent: '$startMonth - $endMonth', dim: '$startYear - $endYear');
    }
  } catch (e) {
    logCalError('gregorian month range', e);
    return null;
  }
}

/// Secondary traditional range over a lunar primary month's span.
///
/// Hindu primary + Bengali secondary shows the Bengali months overlapping
/// the viewed Hindu (lunar) month, e.g. "Shrabon - Bhadro 1432"; Bengali
/// primary + Hindu secondary mirrors it. Previously this combination fell
/// through to a single-month label of the focused start day and never
/// updated on tile taps, which is the reported "stuck Bengali month" bug.
Future<MonthRangeParts?> getSecondaryTraditionalRangeForLunarPrimary(
  Ref ref,
  DateTime date,
  cp.AppCalendarSystem primarySystem,
  cp.AppCalendarSystem secondarySystem,
  HinduYearEra hinduYearEra,
  HinduMonthSystem hinduMonthSystem, {
  DateTime? selectedDate,
}) async {
  if ((primarySystem != cp.AppCalendarSystem.hindu &&
          primarySystem != cp.AppCalendarSystem.bengali) ||
      (secondarySystem != cp.AppCalendarSystem.hindu &&
          secondarySystem != cp.AppCalendarSystem.bengali) ||
      primarySystem == secondarySystem) {
    return null;
  }

  try {
    await ref.read(panchangInitProvider.future);

    // 1. Resolve the viewed primary (lunar) month's Gregorian span.
    late DateTime spanStart;
    late DateTime spanEnd;
    if (primarySystem == cp.AppCalendarSystem.hindu) {
      final hinduService = ref.read(hinduCalendarServiceProvider);
      spanStart = await hinduService.monthStartContaining(date);
      final nextStart = await hinduService.nextMonthStartAfter(spanStart);
      spanEnd = nextStart.subtract(const Duration(days: 1));
    } else {
      final bengaliService = ref.read(bengaliCalendarServiceProvider);
      final bDate = await bengaliService.calculateDate(date);
      final monthIndex = bengaliService.bengaliMonths.indexOf(bDate.month);
      if (monthIndex < 0) return null;
      spanStart = await bengaliService.getMonthStart(bDate.year, monthIndex);
      var nextIndex = monthIndex + 1;
      var nextYear = bDate.year;
      if (nextIndex > 11) {
        nextIndex = 0;
        nextYear++;
      }
      final nextStart = await bengaliService.getMonthStart(
        nextYear,
        nextIndex,
      );
      spanEnd = nextStart.subtract(const Duration(days: 1));
    }

    // 2. Tapped tile inside the span narrows to that date's single
    // secondary month (out-of-span taps fall back to the range).
    if (selectedDate != null &&
        !selectedDate.isBefore(spanStart) &&
        !selectedDate.isAfter(spanEnd)) {
      if (secondarySystem == cp.AppCalendarSystem.bengali) {
        final service = ref.read(bengaliCalendarServiceProvider);
        final selectedBDate = await service.calculateDate(selectedDate);
        return (accent: selectedBDate.month, dim: '${selectedBDate.year}');
      } else {
        final service = ref.read(hinduCalendarServiceProvider);
        final selectedHDate = await service.calculateDate(selectedDate);
        final year = hinduYearEra == HinduYearEra.vikramSamvat
            ? selectedHDate.vsYear
            : selectedHDate.shakaYear;
        final masa = displayMasaName(
          selectedHDate.masa,
          selectedHDate.paksha,
          hinduMonthSystem,
        ).replaceAll('_', ' ');
        return (accent: masa, dim: '$year');
      }
    }

    // 3. Range: secondary months at the span's start and end days.
    if (secondarySystem == cp.AppCalendarSystem.bengali) {
      final service = ref.read(bengaliCalendarServiceProvider);
      final startBDate = await service.calculateDate(spanStart);
      final endBDate = await service.calculateDate(spanEnd);
      final startMonth = startBDate.month;
      final endMonth = endBDate.month;
      final startYear = startBDate.year;
      final endYear = endBDate.year;
      if (startMonth == endMonth && startYear == endYear) {
        return (accent: startMonth, dim: '$startYear');
      } else if (startYear == endYear) {
        return (accent: '$startMonth - $endMonth', dim: '$startYear');
      } else {
        return (
          accent: '$startMonth - $endMonth',
          dim: '$startYear - $endYear',
        );
      }
    } else {
      final service = ref.read(hinduCalendarServiceProvider);
      final startHDate = await service.calculateDate(spanStart);
      final endHDate = await service.calculateDate(spanEnd);
      final startMonth = displayMasaName(
        startHDate.masa,
        startHDate.paksha,
        hinduMonthSystem,
      ).replaceAll('_', ' ');
      final endMonth = displayMasaName(
        endHDate.masa,
        endHDate.paksha,
        hinduMonthSystem,
      ).replaceAll('_', ' ');
      final startYear = hinduYearEra == HinduYearEra.vikramSamvat
          ? startHDate.vsYear
          : startHDate.shakaYear;
      final endYear = hinduYearEra == HinduYearEra.vikramSamvat
          ? endHDate.vsYear
          : endHDate.shakaYear;
      if (startMonth == endMonth && startYear == endYear) {
        return (accent: startMonth, dim: '$startYear');
      } else if (startYear == endYear) {
        return (accent: '$startMonth - $endMonth', dim: '$startYear');
      } else {
        return (
          accent: '$startMonth - $endMonth',
          dim: '$startYear - $endYear',
        );
      }
    }
  } catch (e) {
    logCalError('lunar primary secondary range', e);
    return null;
  }
}

Future<String> getSystemHeaderTextForCalendar(
  Ref ref,
  AppLocalizations l10n,
  DateTime date,
  cp.AppCalendarSystem system,
  HinduYearEra hinduYearEra,
  HinduMonthSystem hinduMonthSystem,
) async {
  switch (system) {
    case cp.AppCalendarSystem.bengali:
      try {
        final service = ref.read(bengaliCalendarServiceProvider);
        await ref.read(panchangInitProvider.future);
        final bDate = await service.calculateDate(date);
        return '${bDate.month} ${bDate.year}';
      } catch (e) {
        logCalError('bengali header', e);
        return formatGregorianHeader(date, l10n);
      }

    case cp.AppCalendarSystem.hindu:
      try {
        final service = ref.read(hinduCalendarServiceProvider);
        await ref.read(panchangInitProvider.future);
        final hDate = await service.calculateDate(date);
        final displayYear = hinduYearEra == HinduYearEra.vikramSamvat
            ? hDate.vsYear
            : hDate.shakaYear;
        final displayMasa = displayMasaName(
          hDate.masa,
          hDate.paksha,
          hinduMonthSystem,
        ).replaceAll('_', ' ');
        return '$displayMasa $displayYear';
      } catch (e) {
        logCalError('hindu header', e);
        return formatGregorianHeader(date, l10n);
      }

    case cp.AppCalendarSystem.gregorian:
    default:
      return formatGregorianHeader(date, l10n);
  }
}

String formatGregorianHeader(DateTime date, [AppLocalizations? l10n]) {
  if (l10n == null) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${months[date.month - 1]} ${date.year}';
  }
  return '${gregorianMonthName(date.month, l10n)} ${date.year}';
}
