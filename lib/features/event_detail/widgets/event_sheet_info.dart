import 'package:material_ui/material_ui.dart';

import '../../../l10n/app_localizations.dart';
import '../../../theme/app_metrics.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/app_typography.dart';

/// Info button beside the Panchang Details header. Opens the shared timing
/// note dialog instead of repeating the note inside every sheet.
Widget buildTimingInfoButton(BuildContext context) {
  return InkWell(
    onTap: () => showTimingDialog(context),
    borderRadius: BorderRadius.circular(AppRadius.dense),
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.s4),
      child: Icon(
        Icons.info_outline_rounded,
        size: AppIconSize.small,
        color: context.hintInk,
      ),
    ),
  );
}

void showTimingDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (context) {
      return AlertDialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 40),
        titlePadding: const EdgeInsets.fromLTRB(
          AppSpacing.s20,
          AppSpacing.s16,
          AppSpacing.s20,
          AppSpacing.s8,
        ),
        contentPadding: const EdgeInsets.fromLTRB(
          AppSpacing.s20,
          0,
          AppSpacing.s20,
          AppSpacing.s8,
        ),
        actionsPadding: const EdgeInsets.fromLTRB(
          AppSpacing.s20,
          0,
          AppSpacing.s16,
          AppSpacing.s12,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.tile),
        ),
        title: Row(
          children: [
            Icon(
              Icons.info_outline_rounded,
              color: Theme.of(context).colorScheme.primary,
              size: AppIconSize.medium,
            ),
            const SizedBox(width: AppSpacing.s8),
            Text(
              AppLocalizations.of(context)?.timingNote ?? 'Timing Note',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: AppTypography.bold),
            ),
          ],
        ),
        content: Text(
          AppLocalizations.of(context)?.timingNoteDescription ??
              'Timings are calculated astronomically based on coordinates and may vary by a few minutes from local temple calendars due to atmospheric refraction, elevation, or calculation methods.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            height: 1.35,
            fontSize: AppTypography.sizeBody,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(AppLocalizations.of(context)?.gotIt ?? 'Got it'),
          ),
        ],
      );
    },
  );
}

/// Demoted observance note: the rule sentence ("Observed on the day …") as a
/// muted caption under the Panchang Details header. It explains which tithi
/// checkpoint fixed the date; the tinted banner it replaces competed with
/// the description and repeated the sunrise default on almost every sheet.
class ObservanceCaption extends StatelessWidget {
  const ObservanceCaption({
    super.key,
    required this.highContrast,
    required this.rule,
  });

  final bool highContrast;
  final String rule;

  @override
  Widget build(BuildContext context) {
    return Text(
      rule,
      style: TextStyle(
        fontSize: AppTypography.sizeCaption,
        fontWeight: AppTypography.medium,
        height: 1.35,
        // High contrast keeps the caption readable without the banner's
        // primary-tinted fill; elsewhere it reads as secondary text.
        color: context.colors.onSurface.withValues(
          alpha: highContrast ? 0.9 : 0.6,
        ),
      ),
    );
  }
}
