import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/locale/app_locale.dart';
import '../../../l10n/app_localizations.dart';
import '../../../l10n/app_localizations_en.dart';
import '../../../models/festival_region.dart';
import '../../../models/panchang_data.dart';
import '../../../providers/calendar_provider.dart';
import '../../../providers/locale_provider.dart';
import '../../../providers/panchang_provider.dart';
import '../../../services/auspicious_timings.dart';
import '../../../services/inauspicious_timings.dart';
import '../../../services/moon_events_service.dart';
import '../../../services/moon_phase_service.dart';
import '../../../services/solar_events_service.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/tithi_localization.dart';
import '../../ai/providers/ai_providers.dart';
import '../../sheets/domain/sheet_labels.dart';
import '../../sheets/widgets/sheet_explainer_card.dart';
import '../../sheets/widgets/sheet_scaffold.dart';
import '../domain/tithi_sheet_context.dart';
import '../providers/sheet_providers.dart';
import 'tithi_sheet_anchor_chips.dart';
import 'tithi_sheet_day_windows_sections.dart';
import 'tithi_sheet_footer.dart';
import 'tithi_sheet_hero.dart';
import 'tithi_sheet_timings_sections.dart';

/// Bottom sheet with full tithi timing details for a day.
///
/// Layout follows assets/redesign assets/tithi-redesign-v3-faithful.html:
/// a hero-gradient header matching [PakshaHeroCard] (same [AppTheme] hero
/// colors), a sun/moon anchor chip row just below the header, a dotted
/// section label, a side-by-side Begins/Ends card, a
/// tinted Transition card, a Nakshatra section (dotted header + span card
/// with elapsed progress), a Yoga & Karana section (dotted header +
/// side-by-side card in the timings-card idiom), an Auspicious Timings
/// section (Abhijit/Brahma/Madhyahna/Nishita/Godhuli/Pradosha rows),
/// an Inauspicious Timings section (Rahu/Yamaganda/Gulika timeline),
/// all from pure sunrise/sunset arithmetic, and a gray explainer card.
///
/// Shows the sunrise (udaya) tithi's beginning and end, the transition to
/// the next tithi when one occurs before the next sunrise, and the
/// sunrise/sunset anchors — so squeeze cases where a short tithi touches
/// no sunrise (e.g. Navami on Oct 4 2026) are fully visible instead of
/// being skipped over between the surrounding days.
class TithiDetailSheet extends ConsumerWidget {
  final PanchangData panchang;

  const TithiDetailSheet({super.key, required this.panchang});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context) ?? AppLocalizationsEn();
    final locale = l10n.localeName;
    // Opt-in gate: every AI affordance is hidden (not disabled) until the
    // user turns the feature on in Settings.
    final aiAssistEnabled = ref.watch(aiAssistEnabledProvider);
    final coords = ref.watch(resolvedCoordinatesProvider);
    final timingsAsync = ref.watch(
      tithiTimingsProvider((
        date: panchang.date,
        tithiIndex: panchang.tithiIndex,
        latitude: coords.latitude,
        longitude: coords.longitude,
      )),
    );
    final nakshatraAsync = ref.watch(
      nakshatraTimingsProvider((
        date: panchang.date,
        latitude: coords.latitude,
        longitude: coords.longitude,
      )),
    );
    final yogaKaranaAsync = ref.watch(
      yogaKaranaTimingsProvider((
        date: panchang.date,
        latitude: coords.latitude,
        longitude: coords.longitude,
      )),
    );
    final displayNum =
        ref.watch(tithiDisplayModeProvider) == TithiDisplayMode.continuous30
        ? panchang.tithiIndex
        : panchang.tithiNumber;
    final highContrast =
        AppTheme.highContrastOf(context) ||
        ref.watch(glassmorphismConfigProvider).isHighContrast;
    // Primary-calendar date for the header (date, month, year). Masa is
    // Purnimant-correct; Bengali follows the app-language script rule.
    final primarySystem = ref.watch(primaryCalendarSystemProvider);
    final useBengaliScript =
        resolveAppLocale(ref.watch(localeProvider)).languageCode == 'bn';
    final names = masaTithiNames(
      masa: panchang.masa,
      paksha: panchang.paksha,
      monthSystem: ref.watch(hinduMonthSystemProvider),
      tithiNumber: panchang.tithiNumber,
      l10n: l10n,
    );
    final displayMasa = names.localizedMasa;
    final displayTithiName = names.tithiName;
    // Display-only region ordering: the cached panchang record keeps its
    // canonical displayPriority order so switching region never needs a
    // cache invalidation.
    final dayFestivals = sortedFestivalsForRegion(
      panchang.festivals,
      ref.watch(festivalRegionProvider),
    );
    final bengali = ref
        .watch(bengaliDateForSheetProvider(panchang.date))
        .valueOrNull;
    final hinduYear = ref
        .watch(hinduYearForSheetProvider(panchang.date))
        .valueOrNull;
    // Prevailing-event fallback: on days with no rise/set (about once a
    // month) show the neighbouring event — the previous evening's rise,
    // the next morning's set — instead of hiding the chip. The label then
    // carries its date (see TithiSheetAnchorChips).
    final moonTimes = moonEventsService.forDate(
      date: panchang.date,
      latitude: coords.latitude,
      longitude: coords.longitude,
    );
    final moonrise =
        moonTimes.moonrise ??
        moonEventsService.findPreviousRise(
          date: panchang.date,
          latitude: coords.latitude,
          longitude: coords.longitude,
        );
    final moonset =
        moonTimes.moonset ??
        moonEventsService.findNextSet(
          date: panchang.date,
          latitude: coords.latitude,
          longitude: coords.longitude,
        );
    // Inauspicious day windows: pure sunrise/sunset arithmetic (no FFI),
    // so this resolves synchronously. Hidden when anchors are missing.
    final inauspicious = panchang.sunrise != null && panchang.sunset != null
        ? InauspiciousTimings.calculate(
            date: panchang.date,
            sunrise: panchang.sunrise!,
            sunset: panchang.sunset!,
          )
        : null;
    // Auspicious windows: same pure arithmetic over sunrise, sunset and
    // the next sunrise. The Pradosh-vrata clip reuses the displayed
    // tithi's end (transition-aware, like the Begins/Ends card); while
    // timings resolve the clip is best-effort (null = unclipped).
    final tithiEndForClip =
        (panchang.transitionExitsLabel ? panchang.tithiTransitionTime : null) ??
        timingsAsync.valueOrNull?.end;
    final auspicious = panchang.sunrise != null && panchang.sunset != null
        ? AuspiciousTimings.calculate(
            date: panchang.date,
            sunrise: panchang.sunrise!,
            sunset: panchang.sunset!,
            nextSunrise: solarEventsService.sunrise(
              date: panchang.date.add(const Duration(days: 1)),
              latitude: coords.latitude,
              longitude: coords.longitude,
            ),
            tithiNumber: panchang.tithiNumber,
            tithiEnd: tithiEndForClip,
          )
        : null;
    final isShukla = panchang.isShukla;
    final illumination = MoonPhaseService.illuminationFractionForDay(
      tithiNumber: panchang.tithiNumber,
      isShukla: isShukla,
      rawTithi: panchang.rawTithi,
    );
    final illuminationPct = (illumination * 100).toStringAsFixed(1);
    final phaseWord = isShukla ? l10n.waxing : l10n.waning;
    final weekday = formatLocalizedDate(panchang.date, 'EEEE', locale);

    final ctx = TithiSheetContext(
      l10n: l10n,
      locale: locale,
      panchang: panchang,
      highContrast: highContrast,
      coords: coords,
    );

    // Shared sheet scaffold (85% cap + gradient hero header + scroll
    // body, same kit as the festival event sheet): the card stack keeps
    // growing, so beyond the cap the scroll view takes over instead of
    // pushing the sheet taller. Below the cap the column shrink-wraps.
    return SheetScaffold(
      highContrast: highContrast,
      hero: TithiSheetHero(
        ctx: ctx,
        primarySystem: primarySystem,
        bengali: bengali,
        hinduYear: hinduYear,
        displayMasa: displayMasa,
        displayTithiName: displayTithiName,
        displayNum: displayNum,
        illumination: illumination,
        isShukla: isShukla,
        illuminationPct: illuminationPct,
        phaseWord: phaseWord,
        weekday: weekday,
        useBengaliScript: useBengaliScript,
      ),
      body: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TithiSheetAnchorChips(ctx: ctx, moonrise: moonrise, moonset: moonset),
          TithiTimingsSection(ctx: ctx, timingsAsync: timingsAsync),
          TithiTransitionSection(ctx: ctx),
          NakshatraSection(ctx: ctx, nakshatraAsync: nakshatraAsync),
          YogaKaranaSection(ctx: ctx, yogaKaranaAsync: yogaKaranaAsync),
          AuspiciousTimingsSection(ctx: ctx, auspicious: auspicious),
          InauspiciousTimingsSection(ctx: ctx, inauspicious: inauspicious),
          TithiSheetFestivalsSection(ctx: ctx, festivals: dayFestivals),
          TithiSheetAiLink(
            ctx: ctx,
            enabled: aiAssistEnabled,
            auspicious: auspicious,
            inauspicious: inauspicious,
          ),
          SheetExplainerCard(text: l10n.udayaTithiExplanation),
        ],
      ),
    );
  }
}
