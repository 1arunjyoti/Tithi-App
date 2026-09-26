import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../models/festival.dart';
import '../../../models/hindu_month_system.dart';
import '../../../models/panchang_data.dart';
import '../../../providers/calendar_provider.dart';
import '../../../services/moon_phase_service.dart';
import '../../../utils/tithi_localization.dart';
import '../../sheets/domain/sheet_labels.dart';

// Hero view-model extracted from widgets/paksha_hero_card.dart (_HeroBody).
// Pure data: every string, chip spec, and artwork descriptor the hero
// renders, computed from (panchang, l10n, calendar settings, Bengali date).
// No BuildContext — unit-testable without widgets.

/// Secondary-title content kind for the hero title line.
enum HeroSecondaryKind {
  /// No secondary label: title is just the weekday.
  none,

  /// Gregorian full date.
  gregorian,

  /// Hindu masa+tithi (accent style).
  hindu,

  /// Bengali short date (accent style, Bengali typeface iff [HeroContent.bengaliScript]).
  bengali,
}

/// One pill-chip spec for the hero's transition row.
typedef HeroChipData = ({
  IconData icon,
  String text,
  String? highlight,
  String? suffix,
  bool inlineIcon,
});

/// Festival artwork descriptor for the hero's right-side slot (null keeps
/// the text-only layout).
typedef HeroArtwork = ({String source, String label});

/// Resolved hero content. Split from the widget so formatting is testable
/// and the body rebuild is pure composition.
class HeroContent {
  const HeroContent({
    required this.tagLabel,
    required this.weekday,
    required this.secondaryKind,
    required this.secondaryText,
    required this.bengaliScript,
    required this.illumination,
    required this.illuminationPct,
    required this.isShukla,
    required this.title,
    required this.subLabel,
    required this.chips,
    required this.artwork,
  });

  /// Tag row label, e.g. "TODAY · 14 SEPTEMBER 2026".
  final String tagLabel;

  /// Weekday name, always shown.
  final String weekday;

  /// Which secondary label follows the weekday (none = weekday alone).
  final HeroSecondaryKind secondaryKind;

  /// Secondary label text (null when [secondaryKind] is none).
  final String? secondaryText;

  /// Bengali typeface iff the app language is Bengali (transliterated text
  /// keeps the hero typeface).
  final bool bengaliScript;

  /// Moon illumination 0..1 and its one-decimal percent string.
  final double illumination;
  final String illuminationPct;

  final bool isShukla;

  /// Moon-row title (paksha + tithi) and waxing/illumination sublabel.
  final String title;
  final String subLabel;

  /// Transition chips (empty when no intraday transition).
  final List<HeroChipData> chips;

  /// Right-side artwork slot (null = text-only layout).
  final HeroArtwork? artwork;
}

/// Festival artwork for the hero's right-side slot.
///
/// Resolves the day's primary festival ([primaryFestival]) image
/// ([Visuals.image], asset path or http(s) URL). Returns null when the day
/// has no festival or the festival ships no image.
HeroArtwork? heroArtwork(PanchangData panchang) {
  if (panchang.festivals.isEmpty) return null;
  final festival = primaryFestival(panchang.festivals);
  final source = festival.visuals.image.trim();
  if (source.isEmpty) return null;
  return (source: source, label: festival.name);
}

/// Computes [HeroContent] for [panchang].
///
/// [bengali] is the asynchronously resolved Bengali date (null while
/// loading or when Bengali is not shown); [monthSystem] converts the masa
/// name (Purnimant-correct); [useBengaliScript] selects Bengali script +
/// digits for Bengali labels.
HeroContent heroContentData({
  required PanchangData panchang,
  required AppLocalizations l10n,
  required AppCalendarSystem primarySystem,
  required AppCalendarSystem secondarySystem,
  required HinduMonthSystem monthSystem,
  required ({int day, String month, int year})? bengali,
  required bool useBengaliScript,
  required bool isToday,
}) {
  final isShukla = panchang.isShukla;

  final illumination = MoonPhaseService.illuminationFractionForDay(
    tithiNumber: panchang.tithiNumber,
    isShukla: isShukla,
    rawTithi: panchang.rawTithi,
  );
  // One decimal, matching the Moon Phases screen's
  // 'Illumination: x.x%' exactly (same inputs, same formatting).
  final illuminationPct = (illumination * 100).toStringAsFixed(1);

  // Bengali month + digits (shared sheet-labels helper).
  final bn = bengali == null
      ? null
      : bengaliDateLabels(
          day: bengali.day,
          month: bengali.month,
          year: bengali.year,
          useBengaliScript: useBengaliScript,
        );
  final bnCompact = bn?.compact;
  final bnTitle = bn?.title;

  final names = masaTithiNames(
    masa: panchang.masa,
    paksha: panchang.paksha,
    monthSystem: monthSystem,
    tithiNumber: panchang.tithiNumber,
    l10n: l10n,
  );
  final displayTithiName = names.tithiName;
  final masaTithi = names.joined;
  final gregFull = formatLocalizedDate(
    panchang.date,
    'd MMMM y',
    l10n.localeName,
  );
  final gregCompact = formatLocalizedDate(
    panchang.date,
    'd MMM y',
    l10n.localeName,
  ).toUpperCase();

  // Same system in both slots: title takes the full format, tag drops the
  // date to just Today/Selected (no duplication).
  final bool sameSystem =
      primarySystem == secondarySystem &&
      primarySystem != AppCalendarSystem.none;
  final String? tagDate = sameSystem
      ? null
      : switch (primarySystem) {
          AppCalendarSystem.gregorian => gregCompact,
          AppCalendarSystem.hindu => masaTithi.toUpperCase(),
          AppCalendarSystem.bengali => bnCompact,
          AppCalendarSystem.none => null,
        };
  final tagPrefix = isToday ? l10n.today : l10n.selected;
  final tagLabel = tagDate == null ? tagPrefix : '$tagPrefix · $tagDate';

  // Title = weekday + secondary full. Bengali secondary waits for its
  // async date (weekday alone meanwhile); other slots are sync.
  final weekday = formatLocalizedDate(panchang.date, 'EEEE', l10n.localeName);
  final bool isNoneSecondary = secondarySystem == AppCalendarSystem.none;
  final HeroSecondaryKind secondaryKind;
  final String? secondaryText;
  switch (secondarySystem) {
    case AppCalendarSystem.gregorian:
      secondaryKind = HeroSecondaryKind.gregorian;
      secondaryText = gregFull;
    case AppCalendarSystem.hindu:
      secondaryKind = HeroSecondaryKind.hindu;
      secondaryText = masaTithi;
    case AppCalendarSystem.bengali:
      secondaryKind = HeroSecondaryKind.bengali;
      secondaryText = bnTitle;
    case AppCalendarSystem.none:
      // Deliberately no label: title is just the weekday.
      secondaryKind = HeroSecondaryKind.none;
      secondaryText = null;
  }

  final pakshaName = panchang.isShukla ? l10n.themeShukla : l10n.themeKrishna;
  final title = '${l10n.pakshaWithName(pakshaName)} · $displayTithiName';
  final phaseWord = isShukla ? l10n.waxing : l10n.waning;
  final subLabel = '$phaseWord · ${l10n.illuminatedPercent(illuminationPct)}';

  // Daytime-transition chip. When the transition exits the displayed
  // label it is genuinely "next" ("Next tithi: Ashtami at 1:02 PM"). Once
  // a live flip has made the transition's tithi current, calling it next
  // would contradict the title — the chip instead states when it began.
  final chips = <HeroChipData>[
    if (panchang.hasTithiTransition && panchang.tithiTransitionTime != null)
      if (panchang.transitionExitsLabel)
        (
          icon: Icons.arrow_forward_rounded,
          text: l10n.nextTithi,
          highlight: localizedTithiName(
            panchang.transitionTithiNumber,
            panchang.transitionPaksha,
            l10n,
          ),
          suffix:
              ' ${l10n.atTime(formatLocalizedDate(panchang.tithiTransitionTime!, 'jm', l10n.localeName))}',
          inlineIcon: true,
        )
      else
        (
          icon: Icons.arrow_forward_rounded,
          text: l10n.tithiBeginsAt(
            localizedTithiName(
              panchang.transitionTithiNumber,
              panchang.transitionPaksha,
              l10n,
            ),
            formatLocalizedDate(
              panchang.tithiTransitionTime!,
              'jm',
              l10n.localeName,
            ),
          ),
          highlight: null,
          suffix: null,
          inlineIcon: false,
        ),
  ];

  return HeroContent(
    tagLabel: tagLabel,
    weekday: weekday,
    secondaryKind: isNoneSecondary ? HeroSecondaryKind.none : secondaryKind,
    secondaryText: isNoneSecondary ? null : secondaryText,
    bengaliScript: useBengaliScript,
    illumination: illumination,
    illuminationPct: illuminationPct,
    isShukla: isShukla,
    title: title,
    subLabel: subLabel,
    chips: chips,
    artwork: heroArtwork(panchang),
  );
}
