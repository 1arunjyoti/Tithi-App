import 'package:material_ui/material_ui.dart';

import '../../../services/auspicious_timings.dart';
import '../../../services/inauspicious_timings.dart';
import '../../../theme/app_metrics.dart';
import '../../../utils/tithi_localization.dart';
import '../../sheets/widgets/section_header.dart';
import '../../sheets/widgets/sheet_time_format.dart';
import '../domain/tithi_sheet_context.dart';
import 'auspicious_card.dart';
import 'inauspicious_card.dart';

/// Auspicious windows (Abhijit/Brahma/Madhyahna/Nishita/Godhuli/Pradosha)
/// as name + right-aligned range rows. Hidden with the sun anchors above.
class AuspiciousTimingsSection extends StatelessWidget {
  const AuspiciousTimingsSection({
    super.key,
    required this.ctx,
    required this.auspicious,
  });

  final TithiSheetContext ctx;
  final AuspiciousTimings? auspicious;

  @override
  Widget build(BuildContext context) {
    final a = auspicious;
    if (a == null) return const SizedBox.shrink();
    final l10n = ctx.l10n;
    final date = ctx.panchang.date;
    final locale = ctx.locale;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: AppSpacing.s12),
        SectionHeader(text: l10n.auspiciousTimings),
        const SizedBox(height: AppSpacing.s10),
        AuspiciousCard(
          highContrast: ctx.highContrast,
          rows: [
            (
              name: l10n.abhijit,
              time: sheetTimeRange(
                a.abhijit.start,
                a.abhijit.end,
                date,
                locale,
              ),
              note: AuspiciousTimings.abhijitAvoided(date)
                  ? l10n.abhijitAvoided
                  : AuspiciousTimings.abhijitBoosted(date)
                  ? l10n.abhijitAuspicious
                  : null,
              warn: AuspiciousTimings.abhijitAvoided(date),
            ),
            (
              name: l10n.brahmaMuhurta,
              time: sheetTimeRange(
                a.brahmaMuhurta.start,
                a.brahmaMuhurta.end,
                date,
                locale,
              ),
              note: null,
              warn: false,
            ),
            (
              name: l10n.madhyahna,
              time: sheetTimeRange(
                a.madhyahnaWindow.start,
                a.madhyahnaWindow.end,
                date,
                locale,
              ),
              note: l10n.midpointAt(
                formatLocalizedDate(a.madhyahnaInstant, 'jm', locale),
              ),
              warn: false,
            ),
            (
              name: l10n.nishita,
              time: sheetTimeRange(
                a.nishita.start,
                a.nishita.end,
                date,
                locale,
              ),
              note: null,
              warn: false,
            ),
            (
              name: l10n.godhuli,
              time: sheetTimeRange(
                a.godhuli.start,
                a.godhuli.end,
                date,
                locale,
              ),
              note: null,
              warn: false,
            ),
            (
              name: l10n.pradosha,
              time: sheetTimeRange(
                a.pradosha.start,
                a.pradosha.end,
                date,
                locale,
              ),
              note: null,
              warn: false,
            ),
          ],
        ),
      ],
    );
  }
}

/// Inauspicious windows (Rahu/Yamaganda/Gulika) over a sunrise-to-sunset
/// timeline with per-row ranges. Hidden when the sun anchors are missing.
class InauspiciousTimingsSection extends StatelessWidget {
  const InauspiciousTimingsSection({
    super.key,
    required this.ctx,
    required this.inauspicious,
  });

  final TithiSheetContext ctx;
  final InauspiciousTimings? inauspicious;

  @override
  Widget build(BuildContext context) {
    final i = inauspicious;
    if (i == null) return const SizedBox.shrink();
    final l10n = ctx.l10n;
    final date = ctx.panchang.date;
    final locale = ctx.locale;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: AppSpacing.s12),
        SectionHeader(text: l10n.inauspiciousTimings),
        const SizedBox(height: AppSpacing.s10),
        InauspiciousCard(
          highContrast: ctx.highContrast,
          axisStart: formatLocalizedDate(i.sunrise, 'jm', locale),
          axisMid: formatLocalizedDate(
            i.sunrise.add(
              Duration(
                microseconds:
                    i.sunset.difference(i.sunrise).inMicroseconds ~/ 2,
              ),
            ),
            'jm',
            locale,
          ),
          axisEnd: formatLocalizedDate(i.sunset, 'jm', locale),
          rahuSegment: i.rahuSegment,
          yamagandaSegment: i.yamagandaSegment,
          gulikaSegment: i.gulikaSegment,
          rows: [
            (
              kind: WindowKind.rahu,
              name: l10n.rahuKalam,
              time: sheetTimeRange(i.rahu.start, i.rahu.end, date, locale),
            ),
            (
              kind: WindowKind.yamaganda,
              name: l10n.yamaganda,
              time: sheetTimeRange(
                i.yamaganda.start,
                i.yamaganda.end,
                date,
                locale,
              ),
            ),
            (
              kind: WindowKind.gulika,
              name: l10n.gulikaKalam,
              time: sheetTimeRange(i.gulika.start, i.gulika.end, date, locale),
            ),
          ],
        ),
      ],
    );
  }
}
