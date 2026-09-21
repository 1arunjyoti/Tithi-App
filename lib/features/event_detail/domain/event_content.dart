import '../../../core/format/festival_labels.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/festival.dart';
import '../../../models/hindu_month_system.dart';
import '../../../models/panchang_data.dart';
import '../../../utils/tithi_localization.dart';

export '../../../core/format/festival_labels.dart'
    show regionalNamesOf, capitalizedMasaLabel, localizedMasaLabel;

// Event-sheet view-model extracted from widgets/event_detail_sheet.dart.
// Pure data derived from (festival, panchang?, month system, display mode):
// observed-tithi resolution, labels, flags. No BuildContext (l10n is passed
// in, nullable like the widget's AppLocalizations.of) — unit-testable.

/// Festival-observed paksha/tithi resolution.
///
/// Festivals with a timingOverride (e.g. Ganesh Chaturthi at madhyahna) are
/// observed on a tithi that can differ from the sunrise tithi, so rows and
/// timings follow the festival's tithi, not the day's. Solar festivals (and
/// rules without a tithi) have no lunar observance: rows stay day-based.
/// Nakshatra-observed festivals (e.g. Saraswati Avahan on Mula): the stored
/// tithi is documentation only — rows stay day-based, a Nakshatra row is
/// added instead, and no tithi span is shown (it would mislead).
typedef ObservedTithi = ({
  String paksha,
  int index,
  bool showTimings,
  bool nakshatraObserved,
});

ObservedTithi observedTithi({
  required Festival festival,
  required PanchangData panchang,
}) {
  final isNakshatraObserved = festival.nakshatraCondition != null;
  final useObserved =
      !isNakshatraObserved &&
      festival.conditions != 'Solar' &&
      festival.tithi >= 1;
  return (
    paksha: useObserved
        ? festival.resolvePaksha(panchang.paksha)
        : panchang.paksha,
    index: useObserved
        ? festival.resolveTithiIndex(panchang.paksha)
        : panchang.tithiIndex,
    showTimings: useObserved && !isNakshatraObserved,
    nakshatraObserved: isNakshatraObserved,
  );
}

/// Trivial festival flags gating the optional sections.
typedef EventFlags = ({bool additionalDesc, bool fasting, bool mantra});

EventFlags eventFlags(Festival festival) {
  return (
    additionalDesc: festival.purpose.additionalDescription.isNotEmpty,
    fasting:
        festival.rituals.fasting != null &&
        festival.rituals.fasting!.isNotEmpty,
    mantra: festival.rituals.mantra.isNotEmpty,
  );
}

/// Category label, defaulting to localized General.
String categoryLabelFor({
  required Festival festival,
  required AppLocalizations? l10n,
}) {
  return festival.category.isEmpty
      ? (l10n?.general ?? 'General')
      : festival.category.toUpperCase();
}

/// Tithi label for the festival-rules fallback (no panchang available).
/// Rules store paksha-based 1-15, so Krishna tithis map to 16-30 in
/// continuous mode.
String ruleTithiLabel({
  required Festival festival,
  required bool continuous,
  required AppLocalizations? l10n,
}) {
  final num = continuous && festival.paksha == 'Krishna'
      ? festival.tithi + 15
      : festival.tithi;
  if (l10n == null) return 'Tithi $num';
  return localizeDigits(l10n.tithiWithNumber(num), l10n.localeName);
}

/// Resolved sheet content for a day with panchang data.
class EventSheetContent {
  const EventSheetContent({
    required this.regionalNames,
    required this.hasAdditionalDesc,
    required this.hasFasting,
    required this.hasMantra,
    required this.observedPaksha,
    required this.observedIndex,
    required this.observedNum,
    required this.displayTithiNum,
    required this.showTimings,
    required this.isNakshatraObserved,
    required this.masaLabel,
    required this.tithiLabel,
    required this.pakshaLabel,
    required this.categoryLabel,
  });

  final List<String> regionalNames;
  final bool hasAdditionalDesc;
  final bool hasFasting;
  final bool hasMantra;

  final String observedPaksha;
  final int observedIndex;
  final int observedNum;

  /// Observed tithi number honoring the Settings display mode
  /// (paksha-based 1-15 vs continuous 1-30).
  final int displayTithiNum;
  final bool showTimings;
  final bool isNakshatraObserved;

  /// Capitalized, localized masa label (null when the day has no masa).
  final String? masaLabel;

  /// Localized "Name (Tn)" tithi label.
  final String tithiLabel;

  /// "Paksha (Waxing/Waning)" label.
  final String pakshaLabel;
  final String categoryLabel;
}

EventSheetContent eventSheetContent({
  required Festival festival,
  required PanchangData panchang,
  required HinduMonthSystem monthSystem,
  required bool continuousTithi,
  required AppLocalizations? l10n,
}) {
  final observed = observedTithi(festival: festival, panchang: panchang);
  final observedNum = observed.index <= 15
      ? observed.index
      : observed.index - 15;
  final displayTithiNum = continuousTithi ? observed.index : observedNum;

  return EventSheetContent(
    regionalNames: regionalNamesOf(festival),
    hasAdditionalDesc: festival.purpose.additionalDescription.isNotEmpty,
    hasFasting:
        festival.rituals.fasting != null &&
        festival.rituals.fasting!.isNotEmpty,
    hasMantra: festival.rituals.mantra.isNotEmpty,
    observedPaksha: observed.paksha,
    observedIndex: observed.index,
    observedNum: observedNum,
    displayTithiNum: displayTithiNum,
    showTimings: observed.showTimings,
    isNakshatraObserved: observed.nakshatraObserved,
    masaLabel: panchang.masa.isEmpty
        ? null
        : localizedMasaLabel(
            masa: panchang.masa,
            paksha: panchang.paksha,
            monthSystem: monthSystem,
            locale: l10n?.localeName ?? 'en',
          ),
    tithiLabel: l10n == null
        ? '${PanchangData.tithiNameFor(observedNum, observed.paksha)} (T$displayTithiNum)'
        : localizeDigits(
            l10n.tithiNameWithNumber(
              localizedTithiName(observedNum, observed.paksha, l10n),
              displayTithiNum,
            ),
            l10n.localeName,
          ),
    pakshaLabel:
        '${observed.paksha} (${observed.paksha == 'Shukla' ? (l10n?.waxing ?? 'Waxing') : (l10n?.waning ?? 'Waning')})',
    categoryLabel: categoryLabelFor(festival: festival, l10n: l10n),
  );
}
