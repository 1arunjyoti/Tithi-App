import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../../models/festival.dart';
import '../../../models/panchang_data.dart';
import '../../../providers/panchang_provider.dart';
import '../../../services/solar_events_service.dart';
import '../../../theme/app_metrics.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/app_typography.dart';
import '../../../utils/tithi_localization.dart';
import '../../../widgets/app_divider.dart';
import '../../sheets/widgets/sheet_surface_card.dart';
import '../../sheets/widgets/sheet_time_format.dart';
import '../domain/event_content.dart';
import '../domain/puja_moonrise.dart';
import '../domain/puja_samay.dart';

/// Fasting / Vrat surface card (tithi-sheet surface style) with the paran
/// line when the breaking time is critical.
class EventFastingSection extends ConsumerWidget {
  const EventFastingSection({
    super.key,
    required this.festival,
    required this.panchang,
    required this.content,
    required this.paranRule,
  });

  final Festival festival;
  final PanchangData? panchang;
  final EventSheetContent? content;
  final String? paranRule;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Locals promote null checks below (fields don't promote).
    final dayPanchang = panchang;
    final sheetContent = content;
    final rule = paranRule;
    final fasting = festival.rituals.fasting;
    final showFasting = fasting != null && fasting.isNotEmpty;
    return SheetSurfaceCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showFasting)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(width: AppSpacing.s12),
                Expanded(
                  child: Text(
                    fasting,
                    style: context.textTheme.bodyMedium?.copyWith(height: 1.5),
                  ),
                ),
              ],
            ),
          if (rule != null && dayPanchang != null && sheetContent != null) ...[
            if (showFasting) ...[
              const SizedBox(height: AppSpacing.s8),
              const AppDivider(),
              const SizedBox(height: AppSpacing.s8),
            ],
            EventParanSection(
              festival: festival,
              panchang: dayPanchang,
              content: sheetContent,
              paranRule: rule,
            ),
          ],
        ],
      ),
    );
  }
}

/// Paran (fast-breaking) block: red label plus reason and time. Ranges
/// render almanac-style ("8:07 – 8:55 PM"); the puja kala shows its end
/// approximately ("~12:46 AM"). Hides when the instant can't be resolved
/// (Kshaya span, no moonrise).
class EventParanSection extends ConsumerWidget {
  const EventParanSection({
    super.key,
    required this.festival,
    required this.panchang,
    required this.content,
    required this.paranRule,
  });

  final Festival festival;
  final PanchangData panchang;
  final EventSheetContent content;
  final String paranRule;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final locale = l10n?.localeName ?? 'en';
    final coords = ref.watch(resolvedCoordinatesProvider);
    final warnRed = AppTheme.warningTextColor(
      Theme.of(context).brightness == Brightness.dark,
    );

    Widget paranBlock({required String reason, required String detail}) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            l10n?.paranLabel ?? 'Paran (breaking the fast):',
            style: TextStyle(
              fontSize: AppTypography.sizeBody,
              fontWeight: AppTypography.bold,
              color: warnRed,
            ),
          ),
          const SizedBox(height: AppSpacing.s2),
          Text(
            '$reason — $detail',
            style: context.textTheme.bodyMedium?.copyWith(
              fontSize: AppTypography.sizeProse,
              height: 1.5,
              color: context.colors.onSurface.withValues(alpha: 0.9),
            ),
          ),
        ],
      );
    }

    // Almanac-style range anchored on its own start day, so next-morning
    // spans stay short ("5:29 – 7:29 AM") while midnight crossings keep
    // both periods (and the far date when off-day).
    String range(DateTime start, DateTime end) =>
        sheetTimeRange(start, end, start, locale);
    String jm(DateTime instant) => formatLocalizedDate(instant, 'jm', locale);

    switch (paranRule) {
      case 'moonrise':
        // 48-minute grace window from the rise itself.
        final rise = pujaMoonrise(
          date: panchang.date,
          latitude: coords.latitude,
          longitude: coords.longitude,
        );
        if (rise == null) return const SizedBox.shrink();
        return paranBlock(
          reason: l10n?.paranReasonMoonrise ?? 'after moonrise',
          detail: range(rise, rise.add(const Duration(minutes: 48))),
        );
      case 'next_sunrise':
        // Typical morning eat window: two hours from sunrise.
        final rise = solarEventsService.sunrise(
          date: panchang.date.add(const Duration(days: 1)),
          latitude: coords.latitude,
          longitude: coords.longitude,
        );
        return paranBlock(
          reason: l10n?.paranReasonSunrise ?? 'after sunrise',
          detail: range(rise, rise.add(const Duration(hours: 2))),
        );
      case 'after_puja_kala':
        final kala = normalizedPujaKala(festival);
        if (kala == null) return const SizedBox.shrink();
        final kalaName = pujaKalaLabel(kala, l10n);
        final reason =
            l10n?.paranReasonPujaKala(kalaName) ?? 'after the $kalaName puja';
        if (!isPujaWindowKala(kala)) {
          final instant = resolvePujaInstant(
            kala: kala,
            sunrise: panchang.sunrise,
            sunset: panchang.sunset,
          );
          if (instant == null) return const SizedBox.shrink();
          return paranBlock(reason: reason, detail: '~${jm(instant)}');
        }
        // Window kala: synchronous unless the sandhi (or a flagged clip)
        // needs the observed tithi end.
        DateTime? moonrise;
        DateTime? nextSunrise;
        if (kala == 'moonrise') {
          moonrise = pujaMoonrise(
            date: panchang.date,
            latitude: coords.latitude,
            longitude: coords.longitude,
          );
          if (moonrise == null) return const SizedBox.shrink();
        } else if (kala != 'sandhi_junction') {
          if (panchang.sunrise == null || panchang.sunset == null) {
            return const SizedBox.shrink();
          }
          nextSunrise = solarEventsService.sunrise(
            date: panchang.date.add(const Duration(days: 1)),
            latitude: coords.latitude,
            longitude: coords.longitude,
          );
        }
        if (kala != 'sandhi_junction' && !festival.panchangRules.clipToTithi) {
          final span = resolvePujaKala(
            kala: kala,
            date: panchang.date,
            sunrise: panchang.sunrise,
            sunset: panchang.sunset,
            nextSunrise: nextSunrise,
            moonrise: moonrise,
            tithiEnd: null,
            clipToTithi: false,
            sankrantiInstant: panchang.sankranti?.instant,
            bhadraWindows: panchang.bhadraWindows,
            avoidBhadra: festival.panchangRules.avoidBhadra,
          );
          if (span == null) return const SizedBox.shrink();
          return paranBlock(reason: reason, detail: '~${jm(span.end)}');
        }
        final timingsAsync = ref.watch(
          tithiTimingsProvider((
            date: panchang.date,
            tithiIndex: content.observedIndex,
            latitude: coords.latitude,
            longitude: coords.longitude,
          )),
        );
        return timingsAsync.when(
          data: (timings) {
            if (timings == null) return const SizedBox.shrink();
            final span = resolvePujaKala(
              kala: kala,
              date: panchang.date,
              sunrise: panchang.sunrise,
              sunset: panchang.sunset,
              // Null unless the pre-pass computed it for m/n/p: moonrise
              // and sandhi spans ignore it, so no wasted calculation.
              nextSunrise: nextSunrise,
              moonrise: moonrise,
              tithiEnd: timings.end,
              clipToTithi: festival.panchangRules.clipToTithi,
              sankrantiInstant: panchang.sankranti?.instant,
              bhadraWindows: panchang.bhadraWindows,
              avoidBhadra: festival.panchangRules.avoidBhadra,
            );
            if (span == null) return const SizedBox.shrink();
            return paranBlock(reason: reason, detail: '~${jm(span.end)}');
          },
          loading: () => const SizedBox.shrink(),
          error: (err, stack) => const SizedBox.shrink(),
        );
      case 'dwadashi_window':
        // Ekadashi fasts break the next morning inside Dwadashi: Hari
        // Vasara (the first quarter of the day) is avoided, so the window
        // runs from sunrise + D/4 until Dwadashi ends. The observed index
        // + 1 is the same-paksha Dwadashi (index 30 has no successor, so a
        // misconfigured rule hides instead of querying index 31); Kshaya
        // hides the line.
        if (content.observedIndex >= 30) return const SizedBox.shrink();
        final nextDay = panchang.date.add(const Duration(days: 1));
        final rise = solarEventsService.sunrise(
          date: nextDay,
          latitude: coords.latitude,
          longitude: coords.longitude,
        );
        final set = solarEventsService.sunset(
          date: nextDay,
          latitude: coords.latitude,
          longitude: coords.longitude,
        );
        final start = rise.add(
          Duration(microseconds: set.difference(rise).inMicroseconds ~/ 4),
        );
        final dwadashiAsync = ref.watch(
          tithiTimingsProvider((
            date: nextDay,
            tithiIndex: content.observedIndex + 1,
            latitude: coords.latitude,
            longitude: coords.longitude,
          )),
        );
        return dwadashiAsync.when(
          data: (timings) {
            if (timings == null || !timings.end.isAfter(start)) {
              return const SizedBox.shrink();
            }
            return paranBlock(
              reason: l10n?.paranReasonDwadashi ?? 'in the Dwadashi window',
              detail: range(start, timings.end),
            );
          },
          loading: () => const SizedBox.shrink(),
          error: (err, stack) => const SizedBox.shrink(),
        );
      default:
        return const SizedBox.shrink();
    }
  }
}
