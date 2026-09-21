import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';

/// Auspicious-windows rows card in the legend idiom: surface fill, one row
/// per window (medium name + right-aligned dim range, e.g. "11:06 –
/// 11:54 AM"), with an optional small subnote under the name — warning
/// colored for [warn] rows (Abhijit avoided), dim otherwise.
class AuspiciousCard extends StatelessWidget {
  const AuspiciousCard({super.key, required this.rows, required this.highContrast});

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
