import '../../models/festival.dart';
import '../../models/hindu_month_system.dart';
import '../../utils/tithi_localization.dart';

// Festival label helpers shared by sheets (event detail sheet today;
// extracted from features/event_detail/domain/event_content.dart).

/// Non-null, non-empty regional names for chips rows.
List<String> regionalNamesOf(Festival festival) {
  final regional = festival.nameRegional;
  final names = <String>[];
  if (regional.nameBengali?.isNotEmpty == true) {
    names.add(regional.nameBengali!);
  }
  if (regional.nameTelugu?.isNotEmpty == true) {
    names.add(regional.nameTelugu!);
  }
  if (regional.nameKannada?.isNotEmpty == true) {
    names.add(regional.nameKannada!);
  }
  if (regional.nameTamil?.isNotEmpty == true) {
    names.add(regional.nameTamil!);
  }
  if (regional.nameMalayalam?.isNotEmpty == true) {
    names.add(regional.nameMalayalam!);
  }
  return names;
}

/// Hindu month label converted for display (Purnimant-aware) with each word
/// capitalized (e.g. 'Adhika Jyeshtha'). Masa is stored Amanta; Krishna days
/// take the next month's name in Purnimant (Shukla unchanged).
String capitalizedMasaLabel({
  required String masa,
  required String paksha,
  required HinduMonthSystem monthSystem,
}) {
  return displayMasaName(masa, paksha, monthSystem)
      .replaceAll('_', ' ')
      .split(' ')
      .map(
        (w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}',
      )
      .join(' ');
}

/// Capitalized masa label localized to [locale] (script conversion).
String localizedMasaLabel({
  required String masa,
  required String paksha,
  required HinduMonthSystem monthSystem,
  required String locale,
}) {
  return localizeMasaName(
    capitalizedMasaLabel(masa: masa, paksha: paksha, monthSystem: monthSystem),
    locale,
  );
}
