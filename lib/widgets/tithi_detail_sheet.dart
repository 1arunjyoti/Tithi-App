import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../l10n/app_localizations.dart';
import '../l10n/app_localizations_en.dart';
import '../models/festival.dart';
import '../models/hindu_month_system.dart';
import '../models/panchang_data.dart';
import '../providers/calendar_provider.dart';
import '../providers/locale_provider.dart';
import '../providers/panchang_provider.dart';
import '../services/bengali_calendar/bengali_calendar_data.dart';
import '../services/bengali_calendar_service.dart';
import '../services/auspicious_timings.dart';
import '../services/hindu_calendar_service.dart';
import '../services/inauspicious_timings.dart';
import '../services/sunrise_calculator.dart';
import '../services/moon_phase_service.dart';
import '../services/moonrise_calculator.dart';
import '../theme/app_theme.dart';
import '../utils/tithi_localization.dart';
import 'moon_animation_widget.dart';

/// Bengali date for the sheet header. Only resolves when Bengali is the
/// primary calendar; null otherwise (and on failure) — same guarded pattern
/// as the schedule view and the home hero.
final bengaliDateForSheetProvider = FutureProvider.autoDispose
    .family<({int day, String month, int year})?, DateTime>((ref, date) async {
      if (ref.watch(primaryCalendarSystemProvider) !=
          AppCalendarSystem.bengali) {
        return null;
      }
      try {
        return await ref
            .read(bengaliCalendarServiceProvider)
            .calculateDate(date);
      } catch (_) {
        return null;
      }
    });

/// Hindu date label for a timing instant: Purnimant-correct masa + the exact
/// tithi that instant belongs to (passed in — the service is only queried
/// for the masa, so month boundaries stay correct). Resolves only when Hindu
/// is the primary calendar; null otherwise (and on failure), in which case
/// callers fall back to the Gregorian date.
final hinduInstantLabelProvider = FutureProvider.autoDispose
    .family<String?, ({DateTime instant, int tithiIndex})>((ref, arg) async {
      if (ref.watch(primaryCalendarSystemProvider) != AppCalendarSystem.hindu) {
        return null;
      }
      try {
        final service = ref.read(hinduCalendarServiceProvider);
        final monthSystem = ref.watch(hinduMonthSystemProvider);
        final locale =
            ref.watch(localeProvider) ??
            WidgetsBinding.instance.platformDispatcher.locale;
        final l10n = await AppLocalizations.delegate.load(locale);
        final hDate = await service.calculateDate(arg.instant);
        final paksha = arg.tithiIndex <= 15 ? 'Shukla' : 'Krishna';
        final num = arg.tithiIndex <= 15 ? arg.tithiIndex : arg.tithiIndex - 15;
        final masa = localizedHinduMonthName(
          displayMasaName(hDate.masa, paksha, monthSystem).replaceAll('_', ' '),
          l10n,
        );
        return '$masa ${localizedTithiName(num, paksha, l10n)}';
      } catch (_) {
        return null;
      }
    });

/// Bengali date label for a timing instant, honoring the app-language script
/// rule. Resolves only when Bengali is the primary calendar; null otherwise
/// (and on failure).
final bengaliInstantLabelProvider = FutureProvider.autoDispose
    .family<String?, DateTime>((ref, instant) async {
      if (ref.watch(primaryCalendarSystemProvider) !=
          AppCalendarSystem.bengali) {
        return null;
      }
      try {
        final b = await ref
            .read(bengaliCalendarServiceProvider)
            .calculateDate(instant);
        final selectedLocale = ref.watch(localeProvider);
        final useBn =
            (selectedLocale ??
                    WidgetsBinding.instance.platformDispatcher.locale)
                .languageCode ==
            'bn';
        if (useBn) {
          final idx = bengaliMonthIndexOf(b.month);
          final monthBn = idx >= 0 ? kBengaliMonthsBn[idx] : b.month;
          return '${toBengaliDigits(b.day)} $monthBn ${toBengaliDigits(b.year)}';
        }
        return '${b.day} ${b.month} ${b.year}';
      } catch (_) {
        return null;
      }
    });

bool _isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// Time range with a shared day period ("8:27 – 9:59 AM"): the start drops
/// its own period, matching almanac convention. When the ends fall in
/// different halves (Nishita spans midnight), both periods are shown
/// ("11:26 PM – 12:16 AM"). Either end outside the sheet's civil [day]
/// gains a short date of its own ("11:26 PM, Oct 3 – 12:16 AM, Oct 4"),
/// so previous/next-day spans stay unambiguous; same-day pairs render
/// exactly as before.
String _timeRange(DateTime start, DateTime end, DateTime day, String locale) {
  String stamp(DateTime t, {required bool withPeriod}) {
    final time = withPeriod
        ? formatLocalizedDate(t, 'jm', locale)
        : formatLocalizedDate(t, 'h:mm', locale);
    return _isSameDay(t, day)
        ? time
        : '$time, ${formatLocalizedDate(t, 'MMM d', locale)}';
  }

  final sharedPeriod =
      formatLocalizedDate(start, 'a', locale) ==
      formatLocalizedDate(end, 'a', locale);
  // The shortened start applies only when it carries no date of its own;
  // an off-day start keeps its full stamp (and date) instead.
  if (sharedPeriod && _isSameDay(start, day)) {
    return '${stamp(start, withPeriod: false)} – '
        '${stamp(end, withPeriod: true)}';
  }
  return '${stamp(start, withPeriod: true)} – '
      '${stamp(end, withPeriod: true)}';
}

/// Moon chip text: clock time, plus the short Gregorian date when the event
/// falls on a neighbouring day (prevailing-event fallback), e.g.
/// "11:27 PM, Oct 3". Same-day events stay short, like the sun chips.
String _moonChipText(DateTime event, DateTime day, String label, String locale) {
  final time = formatLocalizedDate(event, 'jm', locale);
  final sameDay =
      event.year == day.year &&
      event.month == day.month &&
      event.day == day.day;
  if (sameDay) return '$label $time';
  return '$label $time, ${formatLocalizedDate(event, 'MMM d', locale)}';
}

/// Full timing value for an instant: clock time plus the primary-calendar
/// date label, falling back to the Gregorian date while resolving (or when
/// Gregorian is primary).
String _instantValue(
  WidgetRef ref,
  DateTime instant,
  int tithiIndex,
  String locale,
) {
  final label =
      ref
          .watch(
            hinduInstantLabelProvider((
              instant: instant,
              tithiIndex: tithiIndex,
            )),
          )
          .valueOrNull ??
      ref.watch(bengaliInstantLabelProvider(instant)).valueOrNull;
  return '${formatLocalizedDate(instant, 'jm', locale)}, '
      '${label ?? formatLocalizedDate(instant, 'MMM d', locale)}';
}

/// Hindu era year for the sheet's primary-calendar date line. Only resolves
/// when Hindu is the primary calendar; null otherwise (and on failure), in
/// which case the date line omits the year.
final hinduYearForSheetProvider = FutureProvider.autoDispose
    .family<({int year, String eraLabel})?, DateTime>((ref, date) async {
      if (ref.watch(primaryCalendarSystemProvider) != AppCalendarSystem.hindu) {
        return null;
      }
      try {
        final service = ref.read(hinduCalendarServiceProvider);
        final yearEra = ref.watch(hinduYearEraProvider);
        final hDate = await service.calculateDate(date);
        return (
          year: yearEra == HinduYearEra.vikramSamvat
              ? hDate.vsYear
              : hDate.shakaYear,
          eraLabel: yearEra.shortLabel,
        );
      } catch (_) {
        return null;
      }
    });

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
    final selectedLocale = ref.watch(localeProvider);
    final useBengaliScript =
        (selectedLocale ?? WidgetsBinding.instance.platformDispatcher.locale)
            .languageCode ==
        'bn';
    final displayMasa = localizedHinduMonthName(
      displayMasaName(
        panchang.masa,
        panchang.paksha,
        ref.watch(hinduMonthSystemProvider),
      ).replaceAll('_', ' '),
      l10n,
    );
    final displayTithiName = localizedTithiName(
      panchang.tithiNumber,
      panchang.paksha,
      l10n,
    );
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
          if (useBengaliScript) {
            final idx = bengaliMonthIndexOf(b.month);
            final monthBn = idx >= 0 ? kBengaliMonthsBn[idx] : b.month;
            dateSpans.add(
              TextSpan(
                text:
                    '${toBengaliDigits(b.day)} $monthBn ${toBengaliDigits(b.year)}',
                style: GoogleFonts.notoSansBengali(textStyle: dateAccentStyle),
              ),
            );
          } else {
            dateSpans.add(
              TextSpan(
                text: '${b.day} ${b.month} ${b.year}',
                style: dateAccentStyle,
              ),
            );
          }
        }
      case AppCalendarSystem.none:
        break;
    }

    // Cap the sheet at 85% of the screen height: the card stack keeps
    // growing (timings, transition, nakshatra, yoga/karana, explainer),
    // so beyond the cap the existing SingleChildScrollView takes over and
    // the contents scroll instead of pushing the sheet taller. Below the
    // cap the column still shrink-wraps (min height is unconstrained).
    final maxHeight = MediaQuery.sizeOf(context).height * 0.85;
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: Container(
        decoration: BoxDecoration(
          color: context.theme.scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: SafeArea(
          // Drag-down-to-dismiss, mirroring EventDetailSheet: a sustained
          // downward touch-drag past the top edge (e.g. from the handle)
          // pops the route. Overscroll fires only for touch drags via
          // dragDetails, so ballistic flings can't mis-dismiss; pixels
          // accumulate until a ~120px drag. Scrim-tap dismissal is
          // untouched (route level).
          child: NotificationListener<ScrollNotification>(
            onNotification: (() {
              var edgeDrag = 0.0;
              return (ScrollNotification notification) {
                if (notification is ScrollStartNotification) {
                  edgeDrag = 0;
                } else if (notification is OverscrollNotification &&
                    notification.dragDetails != null &&
                    notification.overscroll < 0) {
                  edgeDrag += -notification.overscroll;
                  if (edgeDrag >= 120 && Navigator.of(context).canPop()) {
                    Navigator.of(context).pop();
                    return true;
                  }
                } else if (notification is ScrollUpdateNotification &&
                    notification.metrics.pixels > 0) {
                  // Left the edge: finger moved back into content.
                  edgeDrag = 0;
                }
                return false;
              };
            })(),
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Hero header: tag + title + moon row + sun chips.
              Container(
                decoration: AppTheme.heroSheetHeaderDecoration(
                  context,
                  highContrast: highContrast,
                ),
                child: Stack(
                  children: [
                    if (!highContrast)
                      Positioned.fill(
                        child: Container(
                          decoration: AppTheme.heroGlowBackdrop(context),
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Drag handle. The taller transparent zone makes
                          // the drag-to-dismiss target easier to grab (same
                          // geometry as the festival sheet); visuals
                          // unchanged (pill stays centered). A downward drag
                          // here overscrolls the scroll view at offset zero
                          // and dismisses the sheet (listener below).
                          Container(
                            height: 32,
                            alignment: Alignment.center,
                            child: Container(
                              width: 40,
                              height: 4,
                              decoration: BoxDecoration(
                                color: highContrast
                                    ? context.colors.onSurface.withValues(
                                        alpha: 0.35,
                                      )
                                    : AppTheme.heroForeground(
                                        context,
                                      ).withValues(alpha: 0.3),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
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
                              Container(
                                width: 46,
                                height: 46,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(14),
                                  color: highContrast
                                      ? context.colors.primary.withValues(
                                          alpha: 0.1,
                                        )
                                      : AppTheme.heroChipBackground(context),
                                  border: Border.all(
                                    color: highContrast
                                        ? context.colors.primary.withValues(
                                            alpha: 0.2,
                                          )
                                        : AppTheme.heroChipBorder(context),
                                  ),
                                ),
                                alignment: Alignment.center,
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
                                  _SheetChip(
                                    icon: Icons.wb_sunny_rounded,
                                    text:
                                        '${l10n.sunrise} '
                                        '${formatLocalizedDate(panchang.sunrise!, 'jm', locale)}',
                                    highContrast: highContrast,
                                  ),
                                if (panchang.sunset != null)
                                  _SheetChip(
                                    icon: Icons.nightlight_round,
                                    text:
                                        '${l10n.sunset} '
                                        '${formatLocalizedDate(panchang.sunset!, 'jm', locale)}',
                                    highContrast: highContrast,
                                  ),
                                if (moonrise != null)
                                  _SheetChip(
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
                                  _SheetChip(
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
                    ),
                  ],
                ),
              ),
              // Body.
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Dotted section label.
                    _SectionLabel(text: l10n.tithiTimings),
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
                        return _TimingsCard(
                          highContrast: highContrast,
                          begins: _instantValue(
                            ref,
                            timings.start,
                            panchang.tithiIndex,
                            locale,
                          ),
                          ends: _instantValue(
                            ref,
                            end,
                            panchang.tithiIndex,
                            locale,
                          ),
                        );
                      },
                      loading: () => _TimingsCard(highContrast: highContrast),
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
                              return _TransitionCard(
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
                                        _instantValue(
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
                                        _instantValue(
                                          ref,
                                          panchang.tithiTransitionTime!,
                                          panchang.sunriseTithiIndex,
                                          locale,
                                        ),
                                      ),
                              );
                            },
                            loading: () =>
                                _TransitionCard(highContrast: highContrast),
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
                            _SectionLabel(text: l10n.nakshatraTimings),
                            const SizedBox(height: 10),
                            _NakshatraCard(
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
                          _SectionLabel(text: l10n.nakshatraTimings),
                          const SizedBox(height: 10),
                          _NakshatraCard(highContrast: highContrast),
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
                            _SectionLabel(text: l10n.yogaKaranaTimings),
                            const SizedBox(height: 10),
                            _YogaKaranaCard(
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
                          _SectionLabel(text: l10n.yogaKaranaTimings),
                          const SizedBox(height: 10),
                          _YogaKaranaCard(
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
                      _SectionLabel(text: l10n.auspiciousTimings),
                      const SizedBox(height: 10),
                      _AuspiciousCard(
                        highContrast: highContrast,
                        rows: [
                          (
                            name: l10n.abhijit,
                            time: _timeRange(
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
                            time: _timeRange(
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
                            time: _timeRange(
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
                            time: _timeRange(
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
                            time: _timeRange(
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
                            time: _timeRange(
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
                      _SectionLabel(text: l10n.inauspiciousTimings),
                      const SizedBox(height: 10),
                      _InauspiciousCard(
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
                            kind: _WindowKind.rahu,
                            name: l10n.rahuKalam,
                            time: _timeRange(
                              inauspicious.rahu.start,
                              inauspicious.rahu.end,
                              panchang.date,
                              locale,
                            ),
                          ),
                          (
                            kind: _WindowKind.yamaganda,
                            name: l10n.yamaganda,
                            time: _timeRange(
                              inauspicious.yamaganda.start,
                              inauspicious.yamaganda.end,
                              panchang.date,
                              locale,
                            ),
                          ),
                          (
                            kind: _WindowKind.gulika,
                            name: l10n.gulikaKalam,
                            time: _timeRange(
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
                    // Explainer card.
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: context.colors.onSurface.withValues(
                          alpha: highContrast ? 0.1 : 0.05,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.info_outline,
                            size: 18,
                            color: context.colors.onSurface.withValues(
                              alpha: 0.5,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              l10n.udayaTithiExplanation,
                              style: TextStyle(
                                fontSize: 12.5,
                                color: context.colors.onSurface.withValues(
                                  alpha: 0.65,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
          ),
      ),
    ),
    );
  }
}

/// Hero-style sun pill for the sheet header (same treatment as the home
/// hero chips: hero-foreground ink on the gradient, primary tint in high
/// contrast).
class _SheetChip extends StatelessWidget {
  const _SheetChip({
    required this.icon,
    required this.text,
    required this.highContrast,
  });

  final IconData icon;
  final String text;
  final bool highContrast;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: highContrast
            ? context.colors.primary.withValues(alpha: 0.1)
            : AppTheme.heroChipBackground(context),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: highContrast
              ? context.colors.primary.withValues(alpha: 0.2)
              : AppTheme.heroChipBorder(context),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: highContrast
                ? context.colors.primary
                : AppTheme.heroForeground(context),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12,
                color: highContrast
                    ? context.colors.onSurface
                    : AppTheme.heroForeground(context),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Side-by-side Begins/Ends card with a center divider. Null values render
/// a spinner (loading state).
class _TimingsCard extends StatelessWidget {
  const _TimingsCard({this.begins, this.ends, required this.highContrast});

  final String? begins;
  final String? ends;
  final bool highContrast;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context) ?? AppLocalizationsEn();
    final border = context.colors.onSurface.withValues(
      alpha: highContrast ? 0.2 : 0.1,
    );
    Widget cell({
      required IconData icon,
      required String label,
      String? value,
    }) {
      return Expanded(
        child: Container(
          color: Theme.of(context).cardTheme.color ?? context.colors.surface,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(icon, size: 16, color: context.colors.primary),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 10.5,
                      letterSpacing: 1.0,
                      fontWeight: FontWeight.w600,
                      color: context.colors.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              if (value == null)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: context.colors.onSurface,
                  ),
                ),
            ],
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: border,
        borderRadius: BorderRadius.circular(16),
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            cell(
              icon: Icons.access_time,
              label: l10n.beginsUppercase,
              value: begins,
            ),
            Container(width: 1, color: border),
            cell(
              icon: Icons.access_time_filled,
              label: l10n.endsUppercase,
              value: ends,
            ),
          ],
        ),
      ),
    );
  }
}

/// Tinted transition card: orange label row, bold primary headline, dim
/// subline. Null strings render a spinner (loading state).
class _TransitionCard extends StatelessWidget {
  const _TransitionCard({
    this.headline,
    this.subline,
    required this.highContrast,
  });

  final String? headline;
  final String? subline;
  final bool highContrast;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context) ?? AppLocalizationsEn();
    final primary = context.colors.primary;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: primary.withValues(alpha: highContrast ? 0.15 : 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: primary.withValues(alpha: 0.35)),
      ),
      child: (headline == null)
          ? const Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.swap_horiz, size: 16, color: primary),
                    const SizedBox(width: 6),
                    Text(
                      l10n.transition,
                      style: TextStyle(
                        fontSize: 11,
                        letterSpacing: 1.5,
                        fontWeight: FontWeight.w600,
                        color: primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  headline!,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: primary,
                  ),
                ),
                if (subline != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subline!,
                    style: TextStyle(
                      fontSize: 13,
                      color: context.colors.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ],
            ),
    );
  }
}

/// Dotted section label shown above the timings and nakshatra cards
/// (primary dot + letterspaced onSurface caption, e.g. TITHI TIMINGS).
class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: context.colors.primary,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          text,
          style: TextStyle(
            fontSize: 11,
            letterSpacing: 1.5,
            fontWeight: FontWeight.bold,
            color: context.colors.onSurface,
          ),
        ),
      ],
    );
  }
}

/// Nakshatra span card in the tithi-timings visual language: surface fill
/// (no tinted outline), bold onSurface headline ("Rohini until 3:42 PM"),
/// dim lord/elapsed subline, a slim progress bar for the elapsed share of
/// the span, and the upcoming mansion below it ("Next: Mrigashira at
/// 3:42 PM"). The NAKSHATRA caption lives in a [_SectionLabel] above the
/// card. Null strings render a spinner (loading state); a null [progress]
/// hides the bar, a null [nextline] hides the upcoming line.
class _NakshatraCard extends StatelessWidget {
  const _NakshatraCard({
    this.headline,
    this.subline,
    this.progress,
    this.nextline,
    required this.highContrast,
  });

  final String? headline;
  final String? subline;
  final double? progress;
  final String? nextline;
  final bool highContrast;

  @override
  Widget build(BuildContext context) {
    final track = context.colors.onSurface.withValues(
      alpha: highContrast ? 0.2 : 0.1,
    );
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color ?? context.colors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: (headline == null)
          ? const Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  headline!,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: context.colors.onSurface,
                  ),
                ),
                if (subline != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subline!,
                    style: TextStyle(
                      fontSize: 13,
                      color: context.colors.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                ],
                if (progress != null) ...[
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: progress!.clamp(0.0, 1.0),
                      minHeight: 6,
                      backgroundColor: track,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        context.colors.primary,
                      ),
                    ),
                  ),
                ],
                if (nextline != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    nextline!,
                    style: TextStyle(
                      fontSize: 13,
                      color: context.colors.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ],
            ),
    );
  }
}

/// Runs of [text] matching [emphasis] render in full onSurface while the
/// rest stays in [style] (dim). Used for the Yoga/Karana sublines so the
/// time portion ("3:42 PM, Oct 5") is never dimmed, regardless of each
/// language's word order. Falls back to plain dim text when [emphasis] is
/// null or absent.
class _EmphasizedText extends StatelessWidget {
  const _EmphasizedText({
    required this.text,
    required this.emphasis,
    required this.style,
  });

  final String text;
  final String? emphasis;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final e = emphasis;
    if (e == null || e.isEmpty || !text.contains(e)) {
      return Text(text, style: style);
    }
    final parts = text.split(e);
    final children = <InlineSpan>[];
    for (var i = 0; i < parts.length; i++) {
      if (parts[i].isNotEmpty) children.add(TextSpan(text: parts[i]));
      if (i < parts.length - 1) {
        children.add(
          TextSpan(
            text: e,
            style: TextStyle(color: context.colors.onSurface),
          ),
        );
      }
    }
    return Text.rich(TextSpan(style: style, children: children));
  }
}

/// Auspicious-windows rows card in the legend idiom: surface fill, one row
/// per window (medium name + right-aligned dim range, e.g. "11:06 –
/// 11:54 AM"), with an optional small subnote under the name — warning
/// colored for [warn] rows (Abhijit avoided), dim otherwise.
class _AuspiciousCard extends StatelessWidget {
  const _AuspiciousCard({required this.rows, required this.highContrast});

  final List<({String name, String time, String? note, bool warn})> rows;
  final bool highContrast;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color ?? context.colors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < rows.length; i++)
            Padding(
              padding: EdgeInsets.only(bottom: i < rows.length - 1 ? 12 : 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Text(
                        rows[i].name,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: context.colors.onSurface,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        rows[i].time,
                        style: TextStyle(
                          fontSize: 14,
                          color: context.colors.onSurface.withValues(
                            alpha: 0.7,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (rows[i].note != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      rows[i].note!,
                      style: TextStyle(
                        fontSize: 12,
                        color: rows[i].warn
                            ? AppTheme.warningTextColor(isDark)
                            : context.colors.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Side-by-side Yoga/Karana card in the tithi-timings visual language:
/// border-tone outer background with a center divider, surface cells each
/// holding a primary icon, a dim letterspaced label, a bold onSurface name,
/// and an "until {time}, then {next}" subline whose time portion stays
/// undimmed ([yogaTime]/[karanaTime]). Null values render a spinner in
/// place (loading state).
class _YogaKaranaCard extends StatelessWidget {
  const _YogaKaranaCard({
    required this.yogaLabel,
    required this.karanaLabel,
    this.yogaValue,
    this.yogaSubline,
    this.yogaTime,
    this.karanaValue,
    this.karanaSubline,
    this.karanaTime,
    required this.highContrast,
  });

  final String yogaLabel;
  final String karanaLabel;
  final String? yogaValue;
  final String? yogaSubline;
  final String? yogaTime;
  final String? karanaValue;
  final String? karanaSubline;
  final String? karanaTime;
  final bool highContrast;

  @override
  Widget build(BuildContext context) {
    final border = context.colors.onSurface.withValues(
      alpha: highContrast ? 0.2 : 0.1,
    );
    Widget cell({
      required IconData icon,
      required String label,
      String? value,
      String? subline,
      String? highlight,
    }) {
      return Expanded(
        child: Container(
          color: Theme.of(context).cardTheme.color ?? context.colors.surface,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(icon, size: 16, color: context.colors.primary),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 10.5,
                      letterSpacing: 1.0,
                      fontWeight: FontWeight.w600,
                      color: context.colors.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              if (value == null)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: context.colors.onSurface,
                  ),
                ),
              if (subline != null) ...[
                const SizedBox(height: 2),
                _EmphasizedText(
                  text: subline,
                  emphasis: highlight,
                  style: TextStyle(
                    fontSize: 13,
                    color: context.colors.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: border,
        borderRadius: BorderRadius.circular(16),
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            cell(
              icon: Icons.star_outline,
              label: yogaLabel,
              value: yogaValue,
              subline: yogaSubline,
              highlight: yogaTime,
            ),
            Container(width: 1, color: border),
            cell(
              icon: Icons.timelapse,
              label: karanaLabel,
              value: karanaValue,
              subline: karanaSubline,
              highlight: karanaTime,
            ),
          ],
        ),
      ),
    );
  }
}

/// Inauspicious day-window slot kinds, each with its timeline color.
/// Yamaganda follows onSurface so the slot stays legible in dark themes;
/// Rahu (striped red) and Gulika (green) are fixed semantic colors.
enum _WindowKind { rahu, yamaganda, gulika }

/// Diagonal-stripe overlay marking the Rahu Kalam slot (dark-red lines on
/// the red base). Static decoration: never repaints.
class _DiagonalStripesPainter extends CustomPainter {
  const _DiagonalStripesPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.5;
    const gap = 8.0;
    for (var x = -size.height; x < size.width + size.height; x += gap) {
      canvas.drawLine(
        Offset(x, size.height),
        Offset(x + size.height, 0),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_DiagonalStripesPainter oldDelegate) => false;
}

/// Inauspicious timeline card: sunrise/mid/sunset axis labels, an 8-segment
/// bar from sunrise to sunset with the three inauspicious slots colored
/// (striped red Rahu, dark Yamaganda, green Gulika), and one legend row per
/// slot (dot + name + right-aligned "8:27 – 9:59 AM" range).
class _InauspiciousCard extends StatelessWidget {
  const _InauspiciousCard({
    required this.axisStart,
    required this.axisMid,
    required this.axisEnd,
    required this.rahuSegment,
    required this.yamagandaSegment,
    required this.gulikaSegment,
    required this.rows,
    required this.highContrast,
  });

  final String axisStart;
  final String axisMid;
  final String axisEnd;
  final int rahuSegment;
  final int yamagandaSegment;
  final int gulikaSegment;
  final List<({ _WindowKind kind, String name, String time })> rows;
  final bool highContrast;

  static const _rahuColor = Color(0xFFD32F2F);
  static const _rahuStripeColor = Color(0xFF9E1F1F);
  static const _gulikaColor = Color(0xFF7CB342);

  Color _slotColor(_WindowKind kind, BuildContext context) {
    return switch (kind) {
      _WindowKind.rahu => _rahuColor,
      _WindowKind.yamaganda => context.colors.onSurface,
      _WindowKind.gulika => _gulikaColor,
    };
  }

  _WindowKind? _kindForSegment(int segment) {
    if (segment == rahuSegment) return _WindowKind.rahu;
    if (segment == yamagandaSegment) return _WindowKind.yamaganda;
    if (segment == gulikaSegment) return _WindowKind.gulika;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final neutral = context.colors.onSurface.withValues(alpha: 0.1);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color ?? context.colors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                axisStart,
                style: TextStyle(
                  fontSize: 12,
                  color: context.colors.onSurface.withValues(alpha: 0.6),
                ),
              ),
              Text(
                axisMid,
                style: TextStyle(
                  fontSize: 12,
                  color: context.colors.onSurface.withValues(alpha: 0.6),
                ),
              ),
              Text(
                axisEnd,
                style: TextStyle(
                  fontSize: 12,
                  color: context.colors.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              for (var i = 1; i <= 8; i++)
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(right: i < 8 ? 6 : 0),
                    child: _slot(i, neutral, context),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          for (var j = 0; j < rows.length; j++)
            Padding(
              padding: EdgeInsets.only(bottom: j < rows.length - 1 ? 12 : 0),
              child: Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: _slotColor(rows[j].kind, context),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    rows[j].name,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: context.colors.onSurface,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    rows[j].time,
                    style: TextStyle(
                      fontSize: 14,
                      color: context.colors.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _slot(int segment, Color neutral, BuildContext context) {
    final kind = _kindForSegment(segment);
    final base = kind == null ? neutral : _slotColor(kind, context);
    return Container(
      height: 36,
      decoration: BoxDecoration(
        color: base,
        borderRadius: BorderRadius.circular(8),
      ),
      clipBehavior: Clip.antiAlias,
      child: kind == _WindowKind.rahu
          ? const CustomPaint(
              painter: _DiagonalStripesPainter(
                color: _rahuStripeColor,
              ),
            )
          : null,
    );
  }
}
