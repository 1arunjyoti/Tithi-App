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
import '../../../widgets/skeleton.dart';
import '../../sheets/widgets/info_row.dart';
import '../../sheets/widgets/sheet_surface_card.dart';
import '../../sheets/widgets/sheet_time_format.dart';
import '../domain/event_content.dart';
import '../domain/puja_moonrise.dart';
import '../domain/puja_samay.dart';

/// Thematic icon per puja kala, mirroring the tithi sheet's sun/moon chips.
IconData _pujaKalaIcon(String kala) {
  return switch (kala) {
    'sunrise' => Icons.wb_sunny_rounded,
    'sunset' => Icons.nightlight_round,
    'moonrise' || 'chandrodaya' => Icons.dark_mode_outlined,
    'sandhi_junction' => Icons.swap_horiz,
    'nishita' => Icons.dark_mode,
    'pradosh' || 'pradosha' => Icons.wb_twilight,
    // Godhuli is the sunset-adjacent cow-dust hour; punya kala is the
    // Sankranti merit window (a solar, daylight observance).
    'godhuli' => Icons.wb_twilight,
    'punya_kala' => Icons.brightness_5_outlined,
    _ => Icons.access_time,
  };
}

/// Two-cell span card in the YogaKarana idiom: kala instant (+ date) left,
/// "PUJA WINDOW" range (+ ghati duration note) right. Null strings render
/// a spinner in place (loading state).
Widget _pujaWindowCard({
  required BuildContext context,
  required bool highContrast,
  required String kalaName,
  required String windowLabel,
  String? instant,
  String? date,
  String? range,
  String? note,
}) {
  final border = context.colors.onSurface.withValues(
    alpha: highContrast ? 0.2 : 0.1,
  );
  final cardColor = Theme.of(context).cardTheme.color ?? context.colors.surface;
  final dim = context.secondaryInk;
  final faint = context.secondaryInk;
  Widget valueOrSpinner(String? value, TextStyle style) {
    if (value == null) {
      return const InlineSpinner(size: AppIconSize.medium);
    }
    return Text(value, style: style);
  }

  Widget cell({
    required String label,
    required String? primary,
    String? secondary,
    String? tertiary,
  }) {
    return Expanded(
      child: Container(
        color: cardColor,
        padding: const EdgeInsets.all(AppSpacing.s16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: AppTypography.sizeMicro,
                letterSpacing: 1.0,
                fontWeight: AppTypography.semibold,
                color: dim,
              ),
            ),
            const SizedBox(height: AppSpacing.s6),
            valueOrSpinner(
              primary,
              TextStyle(
                fontSize: AppTypography.sizeSubtitle,
                fontWeight: AppTypography.bold,
                color: context.colors.onSurface,
              ),
            ),
            if (secondary != null) ...[
              const SizedBox(height: AppSpacing.s2),
              Text(
                secondary,
                style: TextStyle(
                  fontSize: AppTypography.sizeDetail,
                  color: faint,
                ),
              ),
            ],
            if (tertiary != null) ...[
              const SizedBox(height: AppSpacing.s2),
              Text(
                tertiary,
                style: TextStyle(
                  fontSize: AppTypography.sizeDetail,
                  color: faint,
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
      borderRadius: BorderRadius.circular(AppRadius.tile),
    ),
    clipBehavior: Clip.antiAlias,
    child: IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          cell(label: kalaName, primary: instant, secondary: date),
          Container(width: 1, color: border),
          cell(label: windowLabel, primary: range, secondary: note),
        ],
      ),
    ),
  );
}

/// Puja Samay ritual card: the two-cell span card for window kalas
/// (madhyahna/nishita/pradosha/moonrise/sandhi_junction), a single "at"
/// row for exact instants (sunrise/sunset). Hides when its inputs are
/// missing (no anchors, no moonrise, sandhi without a span).
class EventPujaSamaySection extends ConsumerWidget {
  const EventPujaSamaySection({
    super.key,
    required this.festival,
    required this.panchang,
    required this.content,
    required this.kala,
  });

  final Festival festival;
  final PanchangData panchang;
  final EventSheetContent content;
  final String kala;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final locale = l10n?.localeName ?? 'en';
    final highContrast =
        AppTheme.highContrastOf(context) ||
        ref.watch(glassmorphismConfigProvider).isHighContrast;
    final coords = ref.watch(resolvedCoordinatesProvider);
    final timingsAsync = ref.watch(
      tithiTimingsProvider((
        date: panchang.date,
        tithiIndex: content.observedIndex,
        latitude: coords.latitude,
        longitude: coords.longitude,
      )),
    );

    if (!isPujaWindowKala(kala)) {
      // Exact instants (Chhath arghya at sunrise/sunset): single "at" row.
      final instant = resolvePujaInstant(
        kala: kala,
        sunrise: panchang.sunrise,
        sunset: panchang.sunset,
      );
      if (instant == null) return const SizedBox.shrink();
      return SheetSurfaceCard(
        child: buildInfoRow(
          context,
          _pujaKalaIcon(kala),
          pujaKalaLabel(kala, l10n),
          sheetInstantValue(ref, instant, content.observedIndex, locale),
        ),
      );
    }

    // Window kala: needs the day's anchors. The observed span only feeds
    // sandhi (and the clipToTithi cut), so a Kshaya null still leaves the
    // day-anchored windows standing.
    if (panchang.sunrise == null || panchang.sunset == null) {
      return const SizedBox.shrink();
    }
    return timingsAsync.when(
      data: (timings) {
        final span = resolvePujaKala(
          kala: kala,
          date: panchang.date,
          sunrise: panchang.sunrise,
          sunset: panchang.sunset,
          nextSunrise: solarEventsService.sunrise(
            date: panchang.date.add(const Duration(days: 1)),
            latitude: coords.latitude,
            longitude: coords.longitude,
          ),
          moonrise: pujaMoonrise(
            date: panchang.date,
            latitude: coords.latitude,
            longitude: coords.longitude,
          ),
          tithiEnd: timings?.end,
          clipToTithi: festival.panchangRules.clipToTithi,
          sankrantiInstant: panchang.sankranti?.instant,
          bhadraWindows: panchang.bhadraWindows,
          avoidBhadra: festival.panchangRules.avoidBhadra,
        );
        if (span == null) return const SizedBox.shrink();
        final kalaName = pujaKalaLabel(kala, l10n);
        final ghatis = ghatikasBetween(span.start, span.end);
        return _pujaWindowCard(
          context: context,
          highContrast: highContrast,
          kalaName: kalaName.toUpperCase(),
          windowLabel: l10n?.pujaWindow ?? 'PUJA WINDOW',
          instant: formatLocalizedDate(span.instant, 'jm', locale),
          date: formatLocalizedDate(span.instant, 'MMM d', locale),
          range: sheetTimeRange(span.start, span.end, panchang.date, locale),
          note: localizeDigits(
            l10n?.pujaWindowDuration(ghatis, kalaName) ??
                '$ghatis ghatikas around $kalaName',
            locale,
          ),
        );
      },
      loading: () => _pujaWindowCard(
        context: context,
        highContrast: highContrast,
        kalaName: pujaKalaLabel(kala, l10n).toUpperCase(),
        windowLabel: l10n?.pujaWindow ?? 'PUJA WINDOW',
      ),
      error: (err, stack) => const SizedBox.shrink(),
    );
  }
}
