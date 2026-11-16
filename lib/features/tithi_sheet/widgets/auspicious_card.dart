import 'package:material_ui/material_ui.dart';

import '../../../theme/app_theme.dart';
import '../../../theme/app_metrics.dart';
import '../../../theme/app_typography.dart';

/// Auspicious-windows rows card in the legend idiom: surface fill, one row
/// per window (medium name + right-aligned dim range, e.g. "11:06 –
/// 11:54 AM"), with an optional small subnote under the name — warning
/// colored for [warn] rows (Abhijit avoided), dim otherwise.
class AuspiciousCard extends StatelessWidget {
  const AuspiciousCard({
    super.key,
    required this.rows,
    required this.highContrast,
  });

  final List<({String name, String time, String? note, bool warn})> rows;
  final bool highContrast;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.s18),
      decoration: AppTheme.sheetCardDecoration(
        context,
        highContrast: highContrast,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < rows.length; i++)
            Padding(
              padding: EdgeInsets.only(
                bottom: i < rows.length - 1 ? AppSpacing.s12 : 0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Text(
                        rows[i].name,
                        style: TextStyle(
                          fontSize: AppTypography.sizeProse,
                          fontWeight: AppTypography.medium,
                          color: context.colors.onSurface,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        rows[i].time,
                        style: TextStyle(
                          fontSize: AppTypography.sizeBody,
                          color: context.secondaryInk,
                        ),
                      ),
                    ],
                  ),
                  if (rows[i].note != null) ...[
                    const SizedBox(height: AppSpacing.s2),
                    Text(
                      rows[i].note!,
                      style: TextStyle(
                        fontSize: AppTypography.sizeCaption,
                        color: rows[i].warn
                            ? AppTheme.warningTextColor(isDark)
                            : context.secondaryInk,
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
