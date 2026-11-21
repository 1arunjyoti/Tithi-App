import 'package:material_ui/material_ui.dart';

import '../../../models/festival.dart';
import '../../../theme/app_metrics.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/app_typography.dart';
import '../../sheets/widgets/sheet_surface_card.dart';

/// Numbered ritual-steps timeline surface card.
class EventRitualsCard extends StatelessWidget {
  const EventRitualsCard({
    super.key,
    required this.festival,
    required this.themeColor,
  });

  final Festival festival;
  final Color themeColor;

  @override
  Widget build(BuildContext context) {
    return SheetSurfaceCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s20,
        vertical: AppSpacing.s20,
      ),
      child: Column(
        children: festival.rituals.steps.asMap().entries.map((entry) {
          final index = entry.key;
          final ritual = entry.value;
          final totalSteps = festival.rituals.steps.length;

          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Column(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: themeColor.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: themeColor.withValues(alpha: 0.8),
                          width: 1.5,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '${index + 1}',
                        style: context.textTheme.bodySmall?.copyWith(
                          color: themeColor,
                          fontWeight: AppTypography.bold,
                          fontSize: AppTypography.sizeCaption,
                        ),
                      ),
                    ),
                    if (index < totalSteps - 1)
                      Expanded(
                        child: Container(
                          width: 1.5,
                          color: themeColor.withValues(alpha: 0.25),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: AppSpacing.s16),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      bottom: index < totalSteps - 1
                          ? AppSpacing.s20
                          : AppSpacing.s4,
                    ),
                    child: Text(
                      ritual,
                      style: context.textTheme.bodyMedium?.copyWith(
                        fontSize: AppTypography.sizeProse,
                        height: 1.5,
                        color: context.colors.onSurface.withValues(alpha: 0.9),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

/// Centered serif mantra surface card with accent border.
class EventMantraCard extends StatelessWidget {
  const EventMantraCard({
    super.key,
    required this.festival,
    required this.themeColor,
  });

  final Festival festival;
  final Color themeColor;

  @override
  Widget build(BuildContext context) {
    return SheetSurfaceCard(
      border: Border.all(color: themeColor.withValues(alpha: 0.25)),
      child: Text(
        festival.rituals.mantra,
        style: AppTypography.shloka(
          fontSize: AppTypography.sizeProse,
          height: 1.8,
          fontWeight: AppTypography.medium,
          color: themeColor,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}
