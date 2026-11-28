import 'package:material_ui/material_ui.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/feedback/app_haptics.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/hindu_month_system.dart';
import '../../../providers/calendar_provider.dart' as cp;
import '../../../providers/panchang_provider.dart';
import '../../../services/bengali_calendar_service.dart';
import '../../../services/hindu_calendar_service.dart';
import '../../../utils/tithi_localization.dart';
import 'year_picker_dialogs.dart';

/// Show year picker dialog for quick navigation.
/// Supports Gregorian, Hindu (Vikram Samvat/Shaka), and Bengali calendar
/// years.
Future<void> showCalendarYearPicker(
  BuildContext context,
  WidgetRef ref,
  DateTime focusedMonth,
) async {
  AppHaptics.tap(ref);
  if (!context.mounted) return;

  final primarySystem = ref.read(cp.primaryCalendarSystemProvider);

  if (primarySystem == cp.AppCalendarSystem.hindu) {
    await _showHinduYearPicker(context, ref, focusedMonth);
  } else if (primarySystem == cp.AppCalendarSystem.bengali) {
    await _showBengaliYearPicker(context, ref, focusedMonth);
  } else {
    await _showGregorianYearPicker(context, ref, focusedMonth);
  }
}

/// Gregorian year picker using the expressive date picker.
Future<void> _showGregorianYearPicker(
  BuildContext context,
  WidgetRef ref,
  DateTime focusedMonth,
) async {
  final selectedDate = await M3EDatePicker.show(
    context,
    initialDate: focusedMonth,
    firstDate: DateTime(1976),
    lastDate: DateTime(2076, 12, 31),
    initialCalendarMode: M3EDatePickerMode.year,
  );

  if (selectedDate != null) {
    cp.setCalendarMonth(ref, DateTime(selectedDate.year, focusedMonth.month));
  }
}

/// Hindu calendar year picker (Vikram Samvat or Shaka Era) with month
/// selection.
Future<void> _showHinduYearPicker(
  BuildContext context,
  WidgetRef ref,
  DateTime focusedMonth,
) async {
  final yearEra = ref.read(cp.hinduYearEraProvider);
  final service = ref.read(hinduCalendarServiceProvider);
  await ref.read(panchangInitProvider.future);

  // Get current Hindu year for the focused month
  final hDate = await service.calculateDate(focusedMonth);
  final currentYear = yearEra == HinduYearEra.vikramSamvat
      ? hDate.vsYear
      : hDate.shakaYear;
  final currentMonthIndex = service.hinduMonths.indexOf(
    service.baseMasaName(hDate.masa),
  );

  // Calculate era years for 1976 and 2076 (matching Gregorian range)
  int minYear;
  int maxYear;
  String eraName;

  if (!context.mounted) return;
  final l10n = AppLocalizations.of(context);
  if (yearEra == HinduYearEra.vikramSamvat) {
    minYear = 1976 + 57; // 2033 VS
    maxYear = 2076 + 57; // 2133 VS
    eraName = l10n?.vikramSamvat ?? 'Vikram Samvat';
  } else {
    minYear = 1976 - 78; // 1898 Shaka
    maxYear = 2076 - 78; // 1998 Shaka
    eraName = l10n?.shakaEra ?? 'Shaka Era';
  }

  // Step 1: Select Year
  final selectedYear = await showCustomYearPickerDialog(
    context,
    ref,
    currentYear,
    minYear,
    maxYear,
    eraName,
  );

  if (selectedYear == null) return;
  if (!context.mounted) return;

  // Step 2: Select Month
  final selectedMonthIndex = await _showHinduMonthPickerDialog(
    context,
    ref,
    service.hinduMonths,
    selectedYear == currentYear ? currentMonthIndex : 0,
    selectedYear,
    eraName,
  );

  if (selectedMonthIndex != null) {
    // Calculate the year difference
    final yearDiff = selectedYear - currentYear;
    final targetVsYear = hDate.vsYear + yearDiff;

    // Get the Gregorian date for the selected Hindu month
    final newDate = await service.getMonthStart(
      targetVsYear,
      selectedMonthIndex,
    );
    cp.setCalendarMonth(ref, newDate);
  }
}

/// Bengali calendar year picker with month selection.
Future<void> _showBengaliYearPicker(
  BuildContext context,
  WidgetRef ref,
  DateTime focusedMonth,
) async {
  final service = ref.read(bengaliCalendarServiceProvider);
  await ref.read(panchangInitProvider.future);

  // Get current Bengali year for the focused month
  final bDate = await service.calculateDate(focusedMonth);
  final currentYear = bDate.year;
  final currentMonthIndex = service.bengaliMonths.indexOf(bDate.month);

  // Calculate Bengali years for 1976 and 2076 (matching Gregorian range)
  // Bengali Era = Gregorian - 594 (approximately, Bengali new year in mid-April)
  const minYear = 1976 - 594; // 1382 BE
  const maxYear = 2076 - 594; // 1482 BE

  if (!context.mounted) return;

  // Step 1: Select Year
  final selectedYear = await showCustomYearPickerDialog(
    context,
    ref,
    currentYear,
    minYear,
    maxYear,
    AppLocalizations.of(context)?.bengaliEra ?? 'Bengali Era',
  );

  if (selectedYear == null) return;
  if (!context.mounted) return;

  // Step 2: Select Month (Bengali script names for the Bengali UI locale,
  // transliterated names otherwise — same rule as the header labels).
  final useBnMonths = Localizations.localeOf(context).languageCode == 'bn';
  final selectedMonthIndex = await _showBengaliMonthPickerDialog(
    context,
    ref,
    useBnMonths ? service.bengaliMonthsBn : service.bengaliMonths,
    selectedYear == currentYear ? currentMonthIndex : 0,
    selectedYear,
  );

  if (selectedMonthIndex != null) {
    // Get the Gregorian date for the selected Bengali month
    final newDate = await service.getMonthStart(
      selectedYear,
      selectedMonthIndex,
    );
    cp.setCalendarMonth(ref, newDate);
  }
}

/// Hindu month picker dialog matching Material 3 design.
Future<int?> _showHinduMonthPickerDialog(
  BuildContext context,
  WidgetRef ref,
  List<String> months,
  int currentMonthIndex,
  int selectedYear,
  String eraName,
) async {
  return showAdaptiveMonthPickerDialog(
    context,
    ref,
    months,
    currentMonthIndex,
    '${localizeDigits('$selectedYear', Localizations.localeOf(context).languageCode)} $eraName',
  );
}

/// Bengali month picker dialog matching Material 3 design.
Future<int?> _showBengaliMonthPickerDialog(
  BuildContext context,
  WidgetRef ref,
  List<String> months,
  int currentMonthIndex,
  int selectedYear,
) async {
  final l10n = AppLocalizations.of(context);
  final localeCode = Localizations.localeOf(context).languageCode;
  return showAdaptiveMonthPickerDialog(
    context,
    ref,
    months,
    currentMonthIndex,
    localizeDigits(
      l10n?.bengaliEraYear(selectedYear) ?? '$selectedYear বঙ্গাব্দ',
      localeCode,
    ),
  );
}
