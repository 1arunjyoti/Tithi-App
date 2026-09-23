import '../../l10n/app_localizations.dart';
import '../../models/festival.dart';
import '../../models/hindu_month_system.dart';
import '../../utils/tithi_localization.dart';

// Festival label helpers shared by sheets (event detail sheet today;
// extracted from features/event_detail/domain/event_content.dart).

/// Hero title name following the app language: the Bengali/Hindi/Sanskrit
/// name under those locales, English otherwise. Falls back to English when
/// the locale's name is missing or empty.
String festivalDisplayName({
  required Festival festival,
  required String locale,
}) {
  final regional = festival.nameRegional;
  final localized = switch (locale) {
    'bn' => regional.nameBengali,
    'hi' => regional.nameHindi,
    'sa' => regional.nameSanskrith,
    _ => null,
  };
  if (localized != null && localized.isNotEmpty) return localized;
  return festival.name;
}

/// Normalized observance checkpoint for the banner: the festival's
/// [timingOverride], defaulting to 'udaya' (sunrise) when absent; unknown
/// values fall back to 'udaya' rather than rendering a wrong rule.
String observanceRuleKey(Festival festival) {
  const known = {
    'udaya',
    'madhyahna',
    'aparahna',
    'nishita',
    'pradosha',
    'moonrise',
  };
  final raw = festival.panchangRules.timingOverride;
  return raw != null && known.contains(raw) ? raw : 'udaya';
}

/// Localized "the tithi prevailing at …" fragment for [ruleKey], with an
/// English fallback like the sheet widgets (nullable l10n).
String observanceRuleLabel(String ruleKey, AppLocalizations? l10n) {
  return switch (ruleKey) {
    'madhyahna' =>
      l10n?.observanceRuleMadhyahna ??
          'the tithi prevailing at Madhyahna (midday)',
    'aparahna' =>
      l10n?.observanceRuleAparahna ??
          'the tithi prevailing at Aparahna (afternoon)',
    'nishita' =>
      l10n?.observanceRuleNishita ??
          'the tithi prevailing at Nishita (midnight)',
    'pradosha' =>
      l10n?.observanceRulePradosha ??
          'the tithi prevailing at Pradosha (dusk)',
    'moonrise' =>
      l10n?.observanceRuleMoonrise ?? 'the tithi prevailing at moonrise',
    _ => l10n?.observanceRuleUdaya ?? 'the tithi prevailing at sunrise',
  };
}

/// Whether the observance banner applies: lunar tithi-observed festivals
/// only (shown even for the default sunrise rule). Solar fixed-date and
/// nakshatra-observed festivals — and rules without a tithi — follow no
/// tithi checkpoint, so the rule sentence would mislead.
bool showsObservanceBanner(Festival festival) {
  if (festival.nakshatraCondition != null) return false;
  if (festival.conditions == 'Solar') return false;
  return festival.tithi >= 1;
}

/// Chip-row names for the sheet hero: [regionalNamesOf] minus the title
/// language, plus English up front when the title shows another language.
/// English has no chip slot of its own, so this keeps it visible when it
/// is displaced from the title; Sanskrit never takes a chip (it is the
/// hero subtitle).
List<String> heroLanguageChips({
  required Festival festival,
  required String locale,
}) {
  final displayName = festivalDisplayName(festival: festival, locale: locale);
  return <String>[
    if (displayName != festival.name) festival.name,
    ...regionalNamesOf(festival).where((name) => name != displayName),
  ];
}

/// Non-null, non-empty regional names for chip rows, in display order:
/// Hindi first, then Bengali, Telugu, Kannada, Tamil, Malayalam.
List<String> regionalNamesOf(Festival festival) {
  final regional = festival.nameRegional;
  final names = <String>[];
  if (regional.nameHindi?.isNotEmpty == true) {
    names.add(regional.nameHindi!);
  }
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
