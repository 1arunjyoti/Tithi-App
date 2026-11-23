import '../../../l10n/app_localizations.dart';
import '../../../models/panchang_data.dart';

/// Values shared by every section of the tithi detail sheet.
///
/// Resolved once in the sheet's build and passed down so each section stays a
/// focused renderer instead of re-watching the same providers.
class TithiSheetContext {
  final AppLocalizations l10n;
  final String locale;
  final PanchangData panchang;
  final bool highContrast;
  final ({double latitude, double longitude}) coords;

  const TithiSheetContext({
    required this.l10n,
    required this.locale,
    required this.panchang,
    required this.highContrast,
    required this.coords,
  });
}
