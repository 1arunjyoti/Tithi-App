import '../../../l10n/app_localizations.dart';
import '../../../models/hindu_month_system.dart';
import '../../../services/bengali_calendar/bengali_calendar_data.dart';
import '../../../utils/tithi_localization.dart';

// Shared calendar label builders for sheet headers (hero card + tithi
// detail sheet). Both previously computed the same Bengali script branching
// and masa/tithi names inline with only variable names differing.

/// Bengali date labels honoring the app-language script rule.
typedef BengaliLabels = ({String compact, String title});

/// Compact is 'day month year'; title is 'day month'. Script form under
/// the Bengali app language, transliterated otherwise (month lookup falls
/// back as-is).
BengaliLabels bengaliDateLabels({
  required int day,
  required String month,
  required int year,
  required bool useBengaliScript,
}) {
  if (useBengaliScript) {
    final idx = bengaliMonthIndexOf(month);
    final monthBn = idx >= 0 ? kBengaliMonthsBn[idx] : month;
    return (
      compact:
          '${toBengaliDigits(day)} $monthBn ${toBengaliDigits(year)}',
      title: '${toBengaliDigits(day)} $monthBn',
    );
  }
  return (compact: '$day $month $year', title: '$day $month');
}

/// Localized masa + tithi names for a lunar date line (Purnimant-correct).
typedef MasaTithiNames = ({
  String localizedMasa,
  String tithiName,
  String joined,
});

MasaTithiNames masaTithiNames({
  required String masa,
  required String paksha,
  required HinduMonthSystem monthSystem,
  required int tithiNumber,
  required AppLocalizations l10n,
}) {
  final localizedMasa = localizedHinduMonthName(
    displayMasaName(masa, paksha, monthSystem).replaceAll('_', ' '),
    l10n,
  );
  final tithiName = localizedTithiName(tithiNumber, paksha, l10n);
  return (
    localizedMasa: localizedMasa,
    tithiName: tithiName,
    joined: '$localizedMasa $tithiName'.trim(),
  );
}
