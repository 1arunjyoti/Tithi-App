import '../../l10n/app_localizations.dart';
import '../../models/festival.dart';
import '../../models/hindu_month_system.dart';
import '../../utils/tithi_localization.dart';

// Festival label helpers shared by sheets (event detail sheet today;
// extracted from features/event_detail/domain/event_content.dart).

// Hoisted: festivalDisplayName runs on every card/tile/semantics build, so the
// locale separator must not be recompiled per call.
final RegExp _localeSeparator = RegExp('[-_]');

bool _nameContains(String? name, String needle) =>
    name != null && (name.contains(needle) || name.toLowerCase().contains(needle));

/// Two catalog strings that differ only in case or edge whitespace are the
/// same name for display purposes — showing both would read as a duplicate.
bool _sameName(String a, String b) =>
    a.trim().toLowerCase() == b.trim().toLowerCase();

/// The single resolver for a festival's user-facing name: the catalog's
/// regional name for the app language, falling back to English when that
/// name is missing or empty.
///
/// Accepts a bare language code or a full locale (`hi-IN`, `bn_BD`, …); only
/// the language subtag selects the name. Regional names outside the app's
/// four UI languages are mapped too, so adding a locale never silently puts
/// the catalog back in English.
String festivalDisplayName({
  required Festival festival,
  required String locale,
}) {
  final regional = festival.nameRegional;
  final language = locale.trim().toLowerCase().split(_localeSeparator).first;
  final localized = switch (language) {
    'bn' => regional.nameBengali,
    'hi' => regional.nameHindi,
    'sa' => regional.nameSanskrith,
    'te' => regional.nameTelugu,
    'kn' => regional.nameKannada,
    'ta' => regional.nameTamil,
    'ml' => regional.nameMalayalam,
    _ => null,
  };
  if (localized != null) {
    final trimmed = localized.trim();
    if (trimmed.isNotEmpty) return trimmed;
  }
  return festival.name;
}

/// Secondary name for a card/tile whose title already uses [festivalDisplayName].
///
/// Returns English when the title is a regional name (so the canonical name
/// stays discoverable), otherwise the Hindi name these cards have always
/// shown underneath the English title. Empty when there is nothing to add —
/// callers should skip the line rather than render a duplicate of the title.
String festivalAlternateName({
  required Festival festival,
  required String locale,
}) {
  final displayName = festivalDisplayName(festival: festival, locale: locale);
  if (!_sameName(displayName, festival.name)) return festival.name;
  final hindi = festival.nameRegional.nameHindi?.trim();
  if (hindi != null &&
      hindi.isNotEmpty &&
      !_sameName(hindi, festival.name)) {
    return hindi;
  }
  return '';
}

/// Every catalogued name (English + all regional scripts), lowercased and
/// newline-joined. Search screens cache this once per catalog change instead
/// of lowercasing names on every keystroke.
String festivalSearchHaystack(Festival festival) {
  final regional = festival.nameRegional;
  return <String?>[
    festival.name,
    regional.nameSanskrith,
    regional.nameEnglish,
    regional.nameHindi,
    regional.nameBengali,
    regional.nameTelugu,
    regional.nameKannada,
    regional.nameTamil,
    regional.nameMalayalam,
  ].whereType<String>().join('\n').toLowerCase();
}

/// Whether any catalogued name (English or regional) contains [query],
/// case-insensitively. Search stays useful in the app language without giving
/// up the canonical English terms.
bool festivalMatchesName(Festival festival, String query) {
  final needle = query.trim().toLowerCase();
  if (needle.isEmpty) return false;
  final regional = festival.nameRegional;
  // Short-circuit direct checks: search runs on every keystroke, so avoid the
  // list + join allocation of festivalSearchHaystack here (that one is for
  // screens that cache it once per catalog change).
  return _nameContains(festival.name, needle) ||
      _nameContains(regional.nameSanskrith, needle) ||
      _nameContains(regional.nameEnglish, needle) ||
      _nameContains(regional.nameHindi, needle) ||
      _nameContains(regional.nameBengali, needle) ||
      _nameContains(regional.nameTelugu, needle) ||
      _nameContains(regional.nameKannada, needle) ||
      _nameContains(regional.nameTamil, needle) ||
      _nameContains(regional.nameMalayalam, needle);
}

/// Normalized observance checkpoint for the banner: the festival's
/// [timingOverride], defaulting to 'udaya' (sunrise) when absent; unknown
/// values fall back to 'udaya' rather than rendering a wrong rule.
String observanceRuleKey(Festival festival) {
  // 'udaya' is the implicit sunrise rule; every other value comes from the
  // single shared checkpoint set so a new checkpoint cannot render as sunrise
  // just because this file forgot to list it.
  const known = {'udaya', ...timingOverrideCheckpoints};
  final raw = festival.panchangRules.timingOverride;
  return raw != null && known.contains(raw) ? raw : 'udaya';
}

/// Localized "the tithi prevailing at …" fragment for [ruleKey], with an
/// English fallback like the sheet widgets (nullable l10n).
String observanceRuleLabel(String ruleKey, AppLocalizations? l10n) {
  return switch (ruleKey) {
    'brahma_muhurta_start' =>
      l10n?.brahmaMuhurta ?? 'the tithi prevailing at Brahma Muhurta',
    'arunodaya_start' || 'arunodaya' => 'the tithi prevailing at Arunodaya',
    'purvahna' => 'the tithi prevailing at Purvahna (forenoon)',
    'sayahna_start' ||
    'sayahna_center' ||
    'sayahna_end' => 'the tithi prevailing at Sayahna (late afternoon)',
    'madhyahna' =>
      l10n?.observanceRuleMadhyahna ??
          'the tithi prevailing at Madhyahna (midday)',
    'aparahna' =>
      l10n?.observanceRuleAparahna ??
          'the tithi prevailing at Aparahna (afternoon)',
    'nishita' =>
      l10n?.observanceRuleNishita ??
          'the tithi prevailing at Nishita (midnight)',
    'pradosh' || 'pradosha' =>
      l10n?.observanceRulePradosha ?? 'the tithi prevailing at Pradosha (dusk)',
    'moonrise' || 'chandrodaya' =>
      l10n?.observanceRuleMoonrise ?? 'the tithi prevailing at moonrise',
    _ => l10n?.observanceRuleUdaya ?? 'the tithi prevailing at sunrise',
  };
}

/// Whether the observance rule applies: lunar tithi-observed festivals
/// only (shown even for the default sunrise rule). Solar fixed-date and
/// nakshatra-observed festivals — and rules without a tithi — follow no
/// tithi checkpoint, so the rule sentence would mislead.
bool showsObservanceRule(Festival festival) {
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
    if (!_sameName(displayName, festival.name)) festival.name,
    ...regionalNamesOf(festival).where((name) => !_sameName(name, displayName)),
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
      .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
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
