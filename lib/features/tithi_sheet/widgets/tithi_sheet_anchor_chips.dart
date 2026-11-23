import 'package:material_ui/material_ui.dart';

import '../../../theme/app_metrics.dart';
import '../../../utils/tithi_localization.dart';
import '../../sheets/widgets/sheet_chip.dart';
import '../../sheets/widgets/sheet_time_format.dart';
import '../domain/tithi_sheet_context.dart';

/// Sunrise/sunset and moonrise/moonset chips, rendered as a two-up grid just
/// below the hero header. Moonrise/moonset labels carry their date when the
/// prevailing neighbouring event is used (a day with no rise or set).
class TithiSheetAnchorChips extends StatelessWidget {
  const TithiSheetAnchorChips({
    super.key,
    required this.ctx,
    required this.moonrise,
    required this.moonset,
  });

  final TithiSheetContext ctx;
  final DateTime? moonrise;
  final DateTime? moonset;

  @override
  Widget build(BuildContext context) {
    final l10n = ctx.l10n;
    final panchang = ctx.panchang;
    final highContrast = ctx.highContrast;
    final locale = ctx.locale;
    // Local copies so Dart promotes the nullable fields inside the checks.
    final mr = moonrise;
    final ms = moonset;

    final chips = <Widget>[
      if (panchang.sunrise != null)
        SheetChip(
          icon: Icons.wb_sunny_rounded,
          text:
              '${l10n.sunrise} '
              '${formatLocalizedDate(panchang.sunrise!, 'jm', locale)}',
          highContrast: highContrast,
          onSurface: true,
          centerContent: true,
        ),
      if (panchang.sunset != null)
        SheetChip(
          icon: Icons.nightlight_round,
          text:
              '${l10n.sunset} '
              '${formatLocalizedDate(panchang.sunset!, 'jm', locale)}',
          highContrast: highContrast,
          onSurface: true,
          centerContent: true,
        ),
      if (mr != null)
        SheetChip(
          icon: Icons.dark_mode_outlined,
          text: _moonChipText(mr, panchang.date, l10n.moonrise, locale),
          highContrast: highContrast,
          onSurface: true,
          centerContent: true,
        ),
      if (ms != null)
        SheetChip(
          icon: Icons.dark_mode,
          text: _moonChipText(ms, panchang.date, l10n.moonset, locale),
          highContrast: highContrast,
          onSurface: true,
          centerContent: true,
        ),
    ];

    if (chips.isEmpty) return const SizedBox.shrink();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _AnchorChipGrid(chips: chips),
        const SizedBox(height: AppSpacing.s16),
      ],
    );
  }
}

/// Moon chip text: clock time, plus the short Gregorian date when the event
/// falls on a neighbouring day (prevailing-event fallback), e.g.
/// "11:27 PM, Oct 3". Same-day events stay short, like the sun chips.
String _moonChipText(
  DateTime event,
  DateTime day,
  String label,
  String locale,
) => '$label ${sheetInstantLabel(event, day, locale)}';

/// Two-up grid for the sun/moon anchor chips: equal-width cells fill the
/// sheet width (sunrise | sunset, moonrise | moonset) instead of wrapping
/// into a ragged block with dead space on the right. An odd chip count
/// makes the last pill span the full row. [IntrinsicHeight] keeps both
/// pills of a row the same height when a long label (a prevailing moon
/// event carries its date) wraps to two lines.
class _AnchorChipGrid extends StatelessWidget {
  const _AnchorChipGrid({required this.chips});

  final List<Widget> chips;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < chips.length; i += 2)
          Padding(
            padding: EdgeInsets.only(top: i == 0 ? 0 : AppSpacing.s8),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: chips[i]),
                  if (i + 1 < chips.length) ...[
                    const SizedBox(width: AppSpacing.s8),
                    Expanded(child: chips[i + 1]),
                  ],
                ],
              ),
            ),
          ),
      ],
    );
  }
}
