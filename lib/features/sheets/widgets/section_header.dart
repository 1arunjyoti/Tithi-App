import 'package:material_ui/material_ui.dart';

import '../../../theme/app_theme.dart';
import '../../../theme/app_metrics.dart';
import '../../../theme/app_typography.dart';

// Canonical dotted section label extracted from
// widgets/tithi_detail_sheet.dart (_SectionLabel, finalized design):
// primary dot + letterspaced onSurface caption, e.g. TITHI TIMINGS.
class SectionHeader extends StatelessWidget {
  const SectionHeader({super.key, required this.text});

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
        const SizedBox(width: AppSpacing.s6),
        // Flexible: callers put this label in a Row next to a trailing action
        // (e.g. "Show all"), and at large text scales the unwrapped Text used
        // to overflow that Row.
        Flexible(
          child: Text(
            text,
            style: TextStyle(
              fontSize: AppTypography.sizeFootnote,
              letterSpacing: 1.5,
              fontWeight: AppTypography.bold,
              color: context.colors.onSurface,
            ),
          ),
        ),
      ],
    );
  }
}
