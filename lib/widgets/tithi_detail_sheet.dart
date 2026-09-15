import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../l10n/app_localizations.dart';
import '../models/hindu_month_system.dart';
import '../models/panchang_data.dart';
import '../providers/calendar_provider.dart';
import '../providers/locale_provider.dart';
import '../providers/panchang_provider.dart';
import '../services/bengali_calendar/bengali_calendar_data.dart';
import '../services/bengali_calendar_service.dart';
import '../services/hindu_calendar_service.dart';
import '../services/moon_phase_service.dart';
import '../theme/app_theme.dart';
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
        final hDate = await service.calculateDate(arg.instant);
        final paksha = arg.tithiIndex <= 15 ? 'Shukla' : 'Krishna';
        final num = arg.tithiIndex <= 15 ? arg.tithiIndex : arg.tithiIndex - 15;
        final masa = displayMasaName(
          hDate.masa,
          paksha,
          monthSystem,
        ).replaceAll('_', ' ');
        return '$masa ${PanchangData.tithiNameFor(num, paksha)}';
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

/// Full timing value for an instant: clock time plus the primary-calendar
/// date label, falling back to the Gregorian date while resolving (or when
/// Gregorian is primary).
String _instantValue(WidgetRef ref, DateTime instant, int tithiIndex) {
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
  return '${TithiDetailSheet._timeFormat.format(instant)}, '
      '${label ?? TithiDetailSheet._dateShortFormat.format(instant)}';
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
/// tinted Transition card, and a gray explainer card.
///
/// Shows the sunrise (udaya) tithi's beginning and end, the transition to
/// the next tithi when one occurs before the next sunrise, and the
/// sunrise/sunset anchors — so squeeze cases where a short tithi touches
/// no sunrise (e.g. Navami on Oct 4 2026) are fully visible instead of
/// being skipped over between the surrounding days.
class TithiDetailSheet extends ConsumerWidget {
  final PanchangData panchang;

  const TithiDetailSheet({super.key, required this.panchang});

  static final DateFormat _timeFormat = DateFormat('h:mm a');
  static final DateFormat _dateShortFormat = DateFormat('MMM d');
  static final DateFormat _gregFullFormat = DateFormat('d MMMM y');
  static final DateFormat _weekdayFormat = DateFormat.EEEE();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final coords = ref.watch(resolvedCoordinatesProvider);
    final timingsAsync = ref.watch(
      tithiTimingsProvider((
        date: panchang.date,
        tithiIndex: panchang.tithiIndex,
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
    final displayMasa = displayMasaName(
      panchang.masa,
      panchang.paksha,
      ref.watch(hinduMonthSystemProvider),
    ).replaceAll('_', ' ');
    final bengali = ref
        .watch(bengaliDateForSheetProvider(panchang.date))
        .valueOrNull;
    final hinduYear = ref
        .watch(hinduYearForSheetProvider(panchang.date))
        .valueOrNull;
    final isShukla = panchang.isShukla;
    final illumination = MoonPhaseService.illuminationFractionForDay(
      tithiNumber: panchang.tithiNumber,
      isShukla: isShukla,
      rawTithi: panchang.rawTithi,
    );
    final illuminationPct = (illumination * 100).toStringAsFixed(1);
    final phaseWord = isShukla
        ? (l10n?.waxing ?? 'Waxing')
        : (l10n?.waning ?? 'Waning');

    // Header date line follows the primary calendar (date, month, year) in
    // hero-title styling. Gregorian/Hindu slots are sync; the Hindu year and
    // Bengali date resolve async and join when ready (weekday alone meanwhile).
    final weekday = _weekdayFormat.format(panchang.date);
    final dateBaseStyle = TextStyle(
      fontSize: 22,
      fontWeight: FontWeight.w600,
      color: highContrast ? context.colors.onSurface : AppTheme.heroInk,
    );
    final dateAccentStyle = dateBaseStyle.copyWith(
      fontStyle: FontStyle.italic,
      color: highContrast
          ? context.colors.primary
          : AppTheme.heroMoonFill(context),
    );
    final dateSpans = <InlineSpan>[];
    switch (primarySystem) {
      case AppCalendarSystem.gregorian:
        dateSpans.add(
          TextSpan(
            text: _gregFullFormat.format(panchang.date),
            style: dateBaseStyle,
          ),
        );
      case AppCalendarSystem.hindu:
        dateSpans.add(
          TextSpan(
            text: '$displayMasa ${panchang.tithiName}'.trim(),
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

    return Container(
      decoration: BoxDecoration(
        color: context.theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: SafeArea(
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
                          // Drag handle.
                          Center(
                            child: Container(
                              width: 40,
                              height: 4,
                              decoration: BoxDecoration(
                                color: highContrast
                                    ? context.colors.onSurface.withValues(
                                        alpha: 0.35,
                                      )
                                    : Colors.white.withValues(alpha: 0.6),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
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
                                      '${l10n?.pakshaWithName(panchang.paksha) ?? '${panchang.paksha} Paksha'}'
                                      ' · ${panchang.tithiName}',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w600,
                                        color: highContrast
                                            ? context.colors.onSurface
                                            : AppTheme.heroInk,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '$phaseWord · $illuminationPct% illuminated',
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w500,
                                        color: highContrast
                                            ? context.colors.onSurface
                                                  .withValues(alpha: 0.7)
                                            : AppTheme.heroInk,
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
                                        : AppTheme.heroMoonFill(
                                            context,
                                          ).withValues(alpha: 0.7),
                                  ),
                                ),
                                child: Text(
                                  '$displayNum',
                                  style: TextStyle(
                                    color: highContrast
                                        ? context.colors.primary
                                        : AppTheme.heroMoonFill(context),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          // Sun chips.
                          if (panchang.sunrise != null ||
                              panchang.sunset != null) ...[
                            const SizedBox(height: 14),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                if (panchang.sunrise != null)
                                  _SheetChip(
                                    icon: Icons.wb_sunny_rounded,
                                    text:
                                        '${l10n?.sunrise ?? 'Sunrise'} '
                                        '${_timeFormat.format(panchang.sunrise!)}',
                                    highContrast: highContrast,
                                  ),
                                if (panchang.sunset != null)
                                  _SheetChip(
                                    icon: Icons.nightlight_round,
                                    text:
                                        '${l10n?.sunset ?? 'Sunset'} '
                                        '${_timeFormat.format(panchang.sunset!)}',
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
                    Row(
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
                          'TITHI TIMINGS',
                          style: TextStyle(
                            fontSize: 11,
                            letterSpacing: 1.5,
                            fontWeight: FontWeight.bold,
                            color: context.colors.onSurface,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    // Begins/Ends card (exact start/end via binary search).
                    timingsAsync.when(
                      data: (timings) {
                        // Kshaya edge (no nearby occurrence): hide rather
                        // than show a wrong-lunation span.
                        if (timings == null) {
                          return const SizedBox.shrink();
                        }
                        // Prefer the precomputed transition instant when the
                        // tithi ends before the next sunrise; otherwise the
                        // searched end (next boundary, usually tomorrow).
                        // Date fragments follow the primary calendar.
                        final end = panchang.tithiTransitionTime ?? timings.end;
                        return _TimingsCard(
                          highContrast: highContrast,
                          begins: _instantValue(
                            ref,
                            timings.start,
                            panchang.tithiIndex,
                          ),
                          ends: _instantValue(ref, end, panchang.tithiIndex),
                        );
                      },
                      loading: () => _TimingsCard(highContrast: highContrast),
                      error: (err, stack) => const SizedBox.shrink(),
                    ),
                    // Transition into the next tithi (squeeze-case visibility).
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
                                headline:
                                    '${panchang.transitionTithiName} begins at '
                                    '${_timeFormat.format(panchang.tithiTransitionTime!)}',
                                subline:
                                    '${panchang.transitionTithiName} ends '
                                    '${_instantValue(ref, nextTimings.end, panchang.transitionTithiIndex!)}',
                              );
                            },
                            loading: () =>
                                _TransitionCard(highContrast: highContrast),
                            error: (err, stack) => const SizedBox.shrink(),
                          );
                        },
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
                              'Udaya tithi: the tithi prevailing at sunrise. A short tithi '
                              'can begin and end between two sunrises — both tithis are '
                              'shown above so none is skipped.',
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
    );
  }
}

/// Hero-style sun pill for the sheet header (same treatment as the home
/// hero chips: white-bold on the gradient, primary tint in high contrast).
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
            color: highContrast ? context.colors.primary : AppTheme.heroInk,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12,
                color: highContrast
                    ? context.colors.onSurface
                    : AppTheme.heroInk,
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
            cell(icon: Icons.access_time, label: 'BEGINS', value: begins),
            Container(width: 1, color: border),
            cell(icon: Icons.access_time_filled, label: 'ENDS', value: ends),
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
                      'TRANSITION',
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
