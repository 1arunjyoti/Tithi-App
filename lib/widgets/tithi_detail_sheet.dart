import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../l10n/app_localizations.dart';
import '../l10n/app_localizations_en.dart';
import '../models/festival.dart';
import '../models/panchang_data.dart';
import '../core/locale/app_locale.dart';
import '../providers/calendar_provider.dart';
import '../providers/locale_provider.dart';
import '../providers/panchang_provider.dart';
import '../services/auspicious_timings.dart';
import '../services/inauspicious_timings.dart';
import '../services/sunrise_calculator.dart';
import '../services/moon_phase_service.dart';
import '../services/moonrise_calculator.dart';
import '../theme/app_theme.dart';
import '../utils/tithi_localization.dart';
import '../features/tithi_sheet/providers/sheet_providers.dart';
import '../features/tithi_sheet/widgets/auspicious_card.dart';
import '../features/tithi_sheet/widgets/inauspicious_card.dart';
import '../features/tithi_sheet/widgets/nakshatra_card.dart';
import '../features/tithi_sheet/widgets/timings_cards.dart';
import '../features/tithi_sheet/widgets/yoga_karana_card.dart';
import '../features/sheets/domain/sheet_labels.dart';
import '../features/sheets/widgets/section_header.dart';
import '../features/sheets/widgets/sheet_chip.dart';
import '../features/sheets/widgets/sheet_explainer_card.dart';
import '../features/sheets/widgets/sheet_hero_tile.dart';
import '../features/sheets/widgets/sheet_scaffold.dart';
import '../features/sheets/widgets/sheet_time_format.dart';
import 'moon_animation_widget.dart';

export '../features/tithi_sheet/providers/sheet_providers.dart'
    show
        bengaliDateForSheetProvider,
        hinduInstantLabelProvider,
        bengaliInstantLabelProvider,
        hinduYearForSheetProvider;

/// Moon chip text: clock time, plus the short Gregorian date when the event
/// falls on a neighbouring day (prevailing-event fallback), e.g.
/// "11:27 PM, Oct 3". Same-day events stay short, like the sun chips.
/// (Timing ranges/values live in the shared sheet kit: [sheetTimeRange] and
/// [sheetInstantValue], reused by the festival event sheet for the same
/// observed-tithi span.)
String _moonChipText(DateTime event, DateTime day, String label, String locale) {
  final time = formatLocalizedDate(event, 'jm', locale);
  final sameDay =
      event.year == day.year &&
      event.month == day.month &&
      event.day == day.day;
  if (sameDay) return '$label $time';
  return '$label $time, ${formatLocalizedDate(event, 'MMM d', locale)}';
}

/// Bottom sheet with full tithi timing details for a day.
///
/// Layout follows assets/redesign assets/tithi-redesign-v3-faithful.html:
/// a hero-gradient header matching [PakshaHeroCard] (same [AppTheme] hero
/// colors), a dotted section label, a side-by-side Begins/Ends card, a
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
    final useBengaliScript = resolveAppLocale(ref.watch(localeProvider)).languageCode == 'bn';
    final names = masaTithiNames(
      masa: panchang.masa,
      paksha: panchang.paksha,
      monthSystem: ref.watch(hinduMonthSystemProvider),
      tithiNumber: panchang.tithiNumber,
      l10n: l10n,
    );
    final displayMasa = names.localizedMasa;
    final displayTithiName = names.tithiName;
    final bengali = ref
        .watch(bengaliDateForSheetProvider(panchang.date))
        .valueOrNull;
    final hinduYear = ref
        .watch(hinduYearForSheetProvider(panchang.date))
        .valueOrNull;
    final moonTimes = MoonriseCalculator.calculateMoonriseSet(
      date: panchang.date,
      latitude: coords.latitude,
      longitude: coords.longitude,
    );
    // Prevailing-event fallback: on days with no rise/set (about once a
    // month) show the neighbouring event — the previous evening's rise,
    // the next morning's set — instead of hiding the chip. The label then
    // carries its date (see [_moonChipText]).
    final moonrise =
        moonTimes.moonrise ??
        MoonriseCalculator.findPreviousMoonrise(
          date: panchang.date,
          latitude: coords.latitude,
          longitude: coords.longitude,
        );
    final moonset =
        moonTimes.moonset ??
        MoonriseCalculator.findNextMoonset(
          date: panchang.date,
          latitude: coords.latitude,
          longitude: coords.longitude,
        );
    // Inauspicious day windows: pure sunrise/sunset arithmetic (no FFI),
    // so this resolves synchronously. Hidden when anchors are missing.
    final inauspicious =
        panchang.sunrise != null && panchang.sunset != null
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
    final auspicious =
        panchang.sunrise != null && panchang.sunset != null
        ? AuspiciousTimings.calculate(
            date: panchang.date,
            sunrise: panchang.sunrise!,
            sunset: panchang.sunset!,
            nextSunrise: SunriseCalculator.calculateSunriseIST(
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

    // Header date line follows the primary calendar (date, month, year) in
    // hero-title styling. Gregorian/Hindu slots are sync; the Hindu year and
    // Bengali date resolve async and join when ready (weekday alone meanwhile).
    final weekday = formatLocalizedDate(panchang.date, 'EEEE', locale);
    final dateBaseStyle = TextStyle(
      fontSize: 22,
      fontWeight: FontWeight.w600,
      color: highContrast
          ? context.colors.onSurface
          : AppTheme.heroForeground(context),
    );
    final dateAccentStyle = dateBaseStyle.copyWith(
      fontStyle: FontStyle.italic,
      color: highContrast
          ? context.colors.primary
          : AppTheme.heroAccent(context),
    );
    final dateSpans = <InlineSpan>[];
    switch (primarySystem) {
      case AppCalendarSystem.gregorian:
        dateSpans.add(
          TextSpan(
            text: formatLocalizedDate(panchang.date, 'd MMMM y', locale),
            style: dateBaseStyle,
          ),
        );
      case AppCalendarSystem.hindu:
        dateSpans.add(
          TextSpan(
            text: '$displayMasa $displayTithiName'.trim(),
            style: dateAccentStyle,
          ),
        );
        final hy = hinduYear;
        if (hy != null) {
          dateSpans.add(
            TextSpan(
              text: ' · ${hy.eraLabel} ${hy.year}',
              style: dateAccentStyle.copyWith(fontSize: 16),
            ),
          );
        }
      case AppCalendarSystem.bengali:
        final b = bengali;
        if (b != null) {
          final labels = bengaliDateLabels(
            day: b.day,
            month: b.month,
            year: b.year,
            useBengaliScript: useBengaliScript,
          );
          dateSpans.add(
            TextSpan(
              text: labels.compact,
              style: useBengaliScript
                  ? GoogleFonts.notoSansBengali(textStyle: dateAccentStyle)
                  : dateAccentStyle,
            ),
          );
        }
      case AppCalendarSystem.none:
        break;
    }

    // Shared sheet scaffold (85% cap + gradient hero header + scroll
    // body, same kit as the festival event sheet): the card stack keeps
    // growing, so beyond the cap the scroll view takes over instead of
    // pushing the sheet taller. Below the cap the column shrink-wraps.
    return SheetScaffold(
      highContrast: highContrast,
      hero: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
                          // Header date: primary calendar date, month, year.
                          Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(
                                  text: dateSpans.isEmpty
                                      ? weekday
                                      : '$weekday, ',
                                  style: dateBaseStyle,
                                ),
                                ...dateSpans,
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          // Moon row: tile + paksha/tithi + illumination +
                          // number badge.
                          Row(
                            children: [
                              SheetHeroTile(
                                highContrast: highContrast,
                                child: MoonAnimationWidget(
                                  phase: illumination,
                                  isWaxing: isShukla,
                                  size: 28,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${l10n.pakshaWithName(panchang.isShukla ? l10n.themeShukla : l10n.themeKrishna)} · $displayTithiName',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w600,
                                        color: highContrast
                                            ? context.colors.onSurface
                                            : AppTheme.heroForeground(context),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '$phaseWord · ${l10n.illuminatedPercent(illuminationPct)}',
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w500,
                                        color: highContrast
                                            ? context.colors.onSurface
                                                  .withValues(alpha: 0.7)
                                            : AppTheme.heroForeground(context),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.transparent,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: highContrast
                                        ? context.colors.primary.withValues(
                                            alpha: 0.4,
                                          )
                                        : AppTheme.heroAccent(
                                            context,
                                          ).withValues(alpha: 0.7),
                                  ),
                                ),
                                child: Text(
                                  '$displayNum',
                                  style: TextStyle(
                                    color: highContrast
                                        ? context.colors.primary
                                        : AppTheme.heroAccent(context),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          // Sun + moon chips. Moonrise/moonset are computed
                          // synchronously (pure-Dart lunar theory, no FFI)
                          // for the sheet's date and resolved coordinates,
                          // falling back to the prevailing neighbouring
                          // event (with its date) on no-rise/set days.
                          if (panchang.sunrise != null ||
                              panchang.sunset != null ||
                              moonrise != null ||
                              moonset != null) ...[
                            const SizedBox(height: 14),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                if (panchang.sunrise != null)
                                  SheetChip(
                                    icon: Icons.wb_sunny_rounded,
                                    text:
                                        '${l10n.sunrise} '
                                        '${formatLocalizedDate(panchang.sunrise!, 'jm', locale)}',
                                    highContrast: highContrast,
                                  ),
                                if (panchang.sunset != null)
                                  SheetChip(
                                    icon: Icons.nightlight_round,
                                    text:
                                        '${l10n.sunset} '
                                        '${formatLocalizedDate(panchang.sunset!, 'jm', locale)}',
                                    highContrast: highContrast,
                                  ),
                                if (moonrise != null)
                                  SheetChip(
                                    icon: Icons.dark_mode_outlined,
                                    text: _moonChipText(
                                      moonrise,
                                      panchang.date,
                                      l10n.moonrise,
                                      locale,
                                    ),
                                    highContrast: highContrast,
                                  ),
                                if (moonset != null)
                                  SheetChip(
                                    icon: Icons.dark_mode,
                                    text: _moonChipText(
                                      moonset,
                                      panchang.date,
                                      l10n.moonset,
                                      locale,
                                    ),
                                    highContrast: highContrast,
                                  ),
                              ],
                            ),
                          ],
                        ],
                      ),
      body: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
                    // Dotted section label.
                    SectionHeader(text: l10n.tithiTimings),
                    const SizedBox(height: 10),
                    // Begins/Ends card (exact start/end via binary search).
                    timingsAsync.when(
                      data: (timings) {
                        // Kshaya edge (no nearby occurrence): hide rather
                        // than show a wrong-lunation span.
                        if (timings == null) {
                          return const SizedBox.shrink();
                        }
                        // Prefer the precomputed transition instant when it ENDS
                        // the displayed label (it exits into a later tithi
                        // before the next sunrise); otherwise the searched
                        // end (next boundary, usually tomorrow). After a
                        // live flip the instant is the label's beginning —
                        // using it as the end would collapse the span.
                        // Date fragments follow the primary calendar.
                        final end = (panchang.transitionExitsLabel
                                ? panchang.tithiTransitionTime
                                : null) ??
                            timings.end;
                        return TimingsCard(
                          highContrast: highContrast,
                          begins: sheetInstantValue(
                            ref,
                            timings.start,
                            panchang.tithiIndex,
                            locale,
                          ),
                          ends: sheetInstantValue(
                            ref,
                            end,
                            panchang.tithiIndex,
                            locale,
                          ),
                        );
                      },
                      loading: () => TimingsCard(highContrast: highContrast),
                      error: (err, stack) => const SizedBox.shrink(),
                    ),
                    // Daytime-transition history (squeeze-case visibility).
                    // Shown whenever a boundary falls inside the day — both
                    // before the flip ("Ashtami begins at 1:02 PM" + its
                    // end) and after it. Post-flip the subline keeps the
                    // morning's context ("Saptami ends …") so a user opening
                    // the sheet at 3 PM still learns what the day started
                    // as; the incoming tithi's own end already stands in
                    // the Begins/Ends card above.
                    if (panchang.hasTithiTransition) ...[
                      const SizedBox(height: 12),
                      Consumer(
                        builder: (context, ref, child) {
                          final nextTimingsAsync = ref.watch(
                            tithiTimingsProvider((
                              date: panchang.date,
                              tithiIndex: panchang.transitionTithiIndex!,
                              latitude: coords.latitude,
                              longitude: coords.longitude,
                            )),
                          );
                          return nextTimingsAsync.when(
                            data: (nextTimings) {
                              if (nextTimings == null) {
                                return const SizedBox.shrink();
                              }
                              return TransitionCard(
                                highContrast: highContrast,
                                headline: l10n.tithiBeginsAt(
                                  localizedTithiName(
                                    panchang.transitionTithiNumber,
                                    panchang.transitionPaksha,
                                    l10n,
                                  ),
                                  formatLocalizedDate(
                                    panchang.tithiTransitionTime!,
                                    'jm',
                                    locale,
                                  ),
                                ),
                                subline: panchang.transitionExitsLabel
                                    ? l10n.tithiEndsAtDateTime(
                                        localizedTithiName(
                                          panchang.transitionTithiNumber,
                                          panchang.transitionPaksha,
                                          l10n,
                                        ),
                                        sheetInstantValue(
                                          ref,
                                          nextTimings.end,
                                          panchang.transitionTithiIndex!,
                                          locale,
                                        ),
                                      )
                                    : l10n.tithiEndsAtDateTime(
                                        localizedTithiName(
                                          panchang.sunriseTithiNumber,
                                          panchang.sunrisePaksha,
                                          l10n,
                                        ),
                                        sheetInstantValue(
                                          ref,
                                          panchang.tithiTransitionTime!,
                                          panchang.sunriseTithiIndex,
                                          locale,
                                        ),
                                      ),
                              );
                            },
                            loading: () =>
                                TransitionCard(highContrast: highContrast),
                            error: (err, stack) => const SizedBox.shrink(),
                          );
                        },
                      ),
                    ],
                    // Nakshatra section: dotted header (like TITHI TIMINGS)
                    // above the span card. Hidden when the span can't be
                    // resolved (web fallback has no ephemeris) — same
                    // hide-on-null contract as the timings card above.
                    nakshatraAsync.when(
                      data: (nak) {
                        if (nak == null) return const SizedBox.shrink();
                        final endTime = formatLocalizedDate(
                          nak.end,
                          'jm',
                          locale,
                        );
                        final endSameDay =
                            nak.end.year == panchang.date.year &&
                            nak.end.month == panchang.date.month &&
                            nak.end.day == panchang.date.day;
                        final endLabel = endSameDay
                            ? endTime
                            : '$endTime, ${formatLocalizedDate(nak.end, 'MMM d', locale)}';
                        final now = DateTime.now();
                        final progress = now.isBefore(nak.start)
                            ? 0.0
                            : now.isAfter(nak.end)
                            ? 1.0
                            : (now
                                          .difference(nak.start)
                                          .inSeconds /
                                      nak.end
                                          .difference(nak.start)
                                          .inSeconds)
                                  .clamp(0.0, 1.0);
                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 12),
                            SectionHeader(text: l10n.nakshatraTimings),
                            const SizedBox(height: 10),
                            NakshatraCard(
                              highContrast: highContrast,
                              headline: l10n.nakshatraUntil(
                                nak.nakshatra,
                                endLabel,
                              ),
                              subline:
                                  '${l10n.nakshatraLord(localizedNakshatraLord(nak.index, l10n))} · '
                                  '${l10n.nakshatraElapsed((progress * 100).toStringAsFixed(0))}',
                              progress: progress,
                              // The Moon's longitude advances monotonically,
                              // so the upcoming mansion is always the next
                              // Vedic-order index — no extra search needed.
                              nextline: l10n.nakshatraNext(
                                hinduNakshatras[(nak.index + 1) % 27],
                                endLabel,
                              ),
                            ),
                          ],
                        );
                      },
                      loading: () => Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 12),
                          SectionHeader(text: l10n.nakshatraTimings),
                          const SizedBox(height: 10),
                          NakshatraCard(highContrast: highContrast),
                        ],
                      ),
                      error: (err, stack) => const SizedBox.shrink(),
                    ),
                    // Yoga & karana section: dotted header above a
                    // side-by-side card (timings-card idiom). Hidden when
                    // the spans can't be resolved (web fallback has no
                    // ephemeris) — same hide-on-null contract as above.
                    yogaKaranaAsync.when(
                      data: (yk) {
                        if (yk == null) return const SizedBox.shrink();
                        String endLabel(DateTime end) {
                          final time = formatLocalizedDate(end, 'jm', locale);
                          final sameDay =
                              end.year == panchang.date.year &&
                              end.month == panchang.date.month &&
                              end.day == panchang.date.day;
                          return sameDay
                              ? time
                              : '$time, ${formatLocalizedDate(end, 'MMM d', locale)}';
                        }

                        // Both sequences advance by exactly one per
                        // boundary (elongation and Sun+Moon sum grow
                        // monotonically), so the followers need no search.
                        final yogaEndLabel = endLabel(yk.yogaEnd);
                        final karanaEndLabel = endLabel(yk.karanaEnd);
                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 12),
                            SectionHeader(text: l10n.yogaKaranaTimings),
                            const SizedBox(height: 10),
                            YogaKaranaCard(
                              highContrast: highContrast,
                              yogaLabel: l10n.yogaLabel,
                              yogaValue: yk.yoga,
                              yogaSubline: l10n.untilThen(
                                yogaEndLabel,
                                yogaNames[(yk.yogaIndex + 1) % 27],
                              ),
                              yogaTime: yogaEndLabel,
                              karanaLabel: l10n.karanaLabel,
                              karanaValue: yk.karana,
                              karanaSubline: l10n.untilThen(
                                karanaEndLabel,
                                karanaNameForIndex(yk.karanaIndex + 1),
                              ),
                              karanaTime: karanaEndLabel,
                            ),
                          ],
                        );
                      },
                      loading: () => Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 12),
                          SectionHeader(text: l10n.yogaKaranaTimings),
                          const SizedBox(height: 10),
                          YogaKaranaCard(
                            highContrast: highContrast,
                            yogaLabel: l10n.yogaLabel,
                            karanaLabel: l10n.karanaLabel,
                          ),
                        ],
                      ),
                      error: (err, stack) => const SizedBox.shrink(),
                    ),
                    // Auspicious windows: dotted header above a rows card
                    // (name + right-aligned range, optional dim subnote).
                    // Hidden with the anchors above.
                    if (auspicious != null) ...[
                      const SizedBox(height: 12),
                      SectionHeader(text: l10n.auspiciousTimings),
                      const SizedBox(height: 10),
                      AuspiciousCard(
                        highContrast: highContrast,
                        rows: [
                          (
                            name: l10n.abhijit,
                            time: sheetTimeRange(
                              auspicious.abhijit.start,
                              auspicious.abhijit.end,
                              panchang.date,
                              locale,
                            ),
                            note: AuspiciousTimings.abhijitAvoided(
                              panchang.date,
                            )
                                ? l10n.abhijitAvoided
                                : AuspiciousTimings.abhijitBoosted(
                                    panchang.date,
                                  )
                                ? l10n.abhijitAuspicious
                                : null,
                            warn: AuspiciousTimings.abhijitAvoided(
                              panchang.date,
                            ),
                          ),
                          (
                            name: l10n.brahmaMuhurta,
                            time: sheetTimeRange(
                              auspicious.brahmaMuhurta.start,
                              auspicious.brahmaMuhurta.end,
                              panchang.date,
                              locale,
                            ),
                            note: null,
                            warn: false,
                          ),
                          (
                            name: l10n.madhyahna,
                            time: sheetTimeRange(
                              auspicious.madhyahnaWindow.start,
                              auspicious.madhyahnaWindow.end,
                              panchang.date,
                              locale,
                            ),
                            note: l10n.midpointAt(
                              formatLocalizedDate(
                                auspicious.madhyahnaInstant,
                                'jm',
                                locale,
                              ),
                            ),
                            warn: false,
                          ),
                          (
                            name: l10n.nishita,
                            time: sheetTimeRange(
                              auspicious.nishita.start,
                              auspicious.nishita.end,
                              panchang.date,
                              locale,
                            ),
                            note: null,
                            warn: false,
                          ),
                          (
                            name: l10n.godhuli,
                            time: sheetTimeRange(
                              auspicious.godhuli.start,
                              auspicious.godhuli.end,
                              panchang.date,
                              locale,
                            ),
                            note: null,
                            warn: false,
                          ),
                          (
                            name: l10n.pradosha,
                            time: sheetTimeRange(
                              auspicious.pradosha.start,
                              auspicious.pradosha.end,
                              panchang.date,
                              locale,
                            ),
                            note: null,
                            warn: false,
                          ),
                        ],
                      ),
                    ],
                    // Inauspicious timings: dotted header above a timeline
                    // card (8 sunrise-to-sunset segments with the three
                    // slots colored, plus per-row time ranges).
                    if (inauspicious != null) ...[
                      const SizedBox(height: 12),
                      SectionHeader(text: l10n.inauspiciousTimings),
                      const SizedBox(height: 10),
                      InauspiciousCard(
                        highContrast: highContrast,
                        axisStart: formatLocalizedDate(
                          inauspicious.sunrise,
                          'jm',
                          locale,
                        ),
                        axisMid: formatLocalizedDate(
                          inauspicious.sunrise.add(
                            Duration(
                              microseconds:
                                  inauspicious.sunset
                                      .difference(inauspicious.sunrise)
                                      .inMicroseconds ~/
                                  2,
                            ),
                          ),
                          'jm',
                          locale,
                        ),
                        axisEnd: formatLocalizedDate(
                          inauspicious.sunset,
                          'jm',
                          locale,
                        ),
                        rahuSegment: inauspicious.rahuSegment,
                        yamagandaSegment: inauspicious.yamagandaSegment,
                        gulikaSegment: inauspicious.gulikaSegment,
                        rows: [
                          (
                            kind: WindowKind.rahu,
                            name: l10n.rahuKalam,
                            time: sheetTimeRange(
                              inauspicious.rahu.start,
                              inauspicious.rahu.end,
                              panchang.date,
                              locale,
                            ),
                          ),
                          (
                            kind: WindowKind.yamaganda,
                            name: l10n.yamaganda,
                            time: sheetTimeRange(
                              inauspicious.yamaganda.start,
                              inauspicious.yamaganda.end,
                              panchang.date,
                              locale,
                            ),
                          ),
                          (
                            kind: WindowKind.gulika,
                            name: l10n.gulikaKalam,
                            time: sheetTimeRange(
                              inauspicious.gulika.start,
                              inauspicious.gulika.end,
                              panchang.date,
                              locale,
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 12),
                    // Explainer card (shared kit with the event sheet).
                    SheetExplainerCard(text: l10n.udayaTithiExplanation),
        ],
      ),
    );
  }
}

