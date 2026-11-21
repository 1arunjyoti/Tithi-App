import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../../models/festival.dart';
import '../../../theme/app_metrics.dart';
import '../../../theme/app_motion.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/app_typography.dart';
import '../../../widgets/app_divider.dart';
import '../../sheets/widgets/sheet_surface_card.dart';
import '../providers/event_detail_providers.dart';

/// Renders the `**bold**` segments used in the festival description data.
Widget buildFormattedText(String text, TextStyle? baseStyle) {
  final parts = text.split('**');
  if (parts.length == 1) {
    return Text(text, style: baseStyle);
  }

  final spans = <TextSpan>[];
  for (int i = 0; i < parts.length; i++) {
    if (parts[i].isEmpty && i == 0) continue;

    final isBold = i.isOdd;
    spans.add(
      TextSpan(
        text: parts[i],
        style: baseStyle?.copyWith(
          fontWeight: isBold ? AppTypography.bold : baseStyle.fontWeight,
        ),
      ),
    );
  }

  return Text.rich(TextSpan(children: spans), style: baseStyle);
}

/// Description surface card with read-more expansion for the additional
/// text (tithi-sheet surface style, 16pt radius).
class EventDescriptionCard extends ConsumerWidget {
  const EventDescriptionCard({
    super.key,
    required this.festival,
    required this.hasAdditionalDesc,
    required this.themeColor,
  });

  final Festival festival;
  final bool hasAdditionalDesc;
  final Color themeColor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SheetSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          buildFormattedText(
            festival.description,
            context.textTheme.bodyLarge?.copyWith(
              fontSize: AppTypography.sizeSubtitle,
              height: 1.5,
            ),
          ),
          if (hasAdditionalDesc) ...[
            const SizedBox(height: AppSpacing.s12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                InkWell(
                  onTap: () {
                    ref
                        .read(descExpandedProvider.notifier)
                        .update((state) => !state);
                  },
                  borderRadius: BorderRadius.circular(AppRadius.chip),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.s4,
                      horizontal: AppSpacing.s8,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          ref.watch(descExpandedProvider)
                              ? (AppLocalizations.of(
                                      context,
                                    )?.showLessTitleCase ??
                                    'Show Less')
                              : (AppLocalizations.of(context)?.readMore ??
                                    'Read More'),
                          style: context.textTheme.labelLarge?.copyWith(
                            color: themeColor,
                            fontWeight: AppTypography.bold,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.s4),
                        Icon(
                          ref.watch(descExpandedProvider)
                              ? Icons.keyboard_arrow_up
                              : Icons.keyboard_arrow_down,
                          color: themeColor,
                          size: AppIconSize.dense,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            AnimatedSize(
              duration: AppMotion.of(context, AppMotion.standard),
              curve: Curves.easeInOut,
              alignment: Alignment.topCenter,
              child: ref.watch(descExpandedProvider)
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: AppSpacing.s8),
                        const AppDivider(),
                        const SizedBox(height: AppSpacing.s8),
                        buildFormattedText(
                          festival.purpose.additionalDescription,
                          context.textTheme.bodyMedium?.copyWith(
                            fontSize: AppTypography.sizeBody,
                            height: 1.5,
                            color: context.colors.onSurface.withValues(
                              alpha: 0.8,
                            ),
                          ),
                        ),
                      ],
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ],
      ),
    );
  }
}
