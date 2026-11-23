import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/feedback/app_haptics.dart';
import '../../../l10n/app_localizations.dart';
import '../../../theme/app_metrics.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/app_typography.dart';
import '../../../utils/tithi_localization.dart';
import '../../../widgets/app_divider.dart';

/// Custom year picker dialog matching Flutter's native Material 3 year picker
/// design.
Future<int?> showCustomYearPickerDialog(
  BuildContext context,
  WidgetRef ref,
  int currentYear,
  int minYear,
  int maxYear,
  String eraName,
) async {
  final years = List.generate(maxYear - minYear + 1, (i) => minYear + i);
  final initialIndex = years.indexOf(currentYear);
  final scrollController = ScrollController(
    initialScrollOffset: ((initialIndex ~/ 3) * 52.0).clamp(0, double.infinity),
  );

  try {
    return await showDialog<int>(
      context: context,
      builder: (dialogContext) {
        final materialL10n = MaterialLocalizations.of(context);
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.card),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 328, maxHeight: 496),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header matching Material 3 date picker style
                Container(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.s24,
                    AppSpacing.s16,
                    AppSpacing.s24,
                    AppSpacing.s8,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppLocalizations.of(context)?.selectYear ??
                            'Select year',
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(color: context.secondaryInk),
                      ),
                      const SizedBox(height: AppSpacing.s4),
                      Text(
                        eraName,
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: AppTypography.regular),
                      ),
                    ],
                  ),
                ),
                const AppDivider(),
                // Year grid
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.s12,
                      vertical: AppSpacing.s8,
                    ),
                    child: GridView.builder(
                      controller: scrollController,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            childAspectRatio: 2.0,
                            crossAxisSpacing: 8,
                            mainAxisSpacing: 8,
                          ),
                      itemCount: years.length,
                      itemBuilder: (context, index) {
                        final year = years[index];
                        final isSelected = year == currentYear;
                        return Material(
                          color: isSelected
                              ? context.colors.primary
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(AppRadius.round),
                          child: InkWell(
                            onTap: () {
                              AppHaptics.tap(ref);
                              Navigator.of(dialogContext).pop(year);
                            },
                            borderRadius: BorderRadius.circular(
                              AppRadius.round,
                            ),
                            child: Container(
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(
                                  AppRadius.round,
                                ),
                                border: isSelected
                                    ? null
                                    : Border.all(
                                        color: context.colors.outline
                                            .withValues(alpha: 0.3),
                                      ),
                              ),
                              child: Text(
                                localizeDigits(
                                  '$year',
                                  Localizations.localeOf(context).languageCode,
                                ),
                                style: TextStyle(
                                  color: isSelected
                                      ? context.colors.onPrimary
                                      : context.colors.onSurface,
                                  fontWeight: isSelected
                                      ? AppTypography.semibold
                                      : AppTypography.regular,
                                  fontSize: AppTypography.sizeBody,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                // Action buttons
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.s8,
                    AppSpacing.s8,
                    AppSpacing.s8,
                    AppSpacing.s8,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(dialogContext).pop(),
                        child: Text(
                          materialL10n.cancelButtonLabel,
                          style: TextStyle(color: context.colors.primary),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  } finally {
    scrollController.dispose();
  }
}

/// Month picker dialog matching Material 3 design.
Future<int?> showAdaptiveMonthPickerDialog(
  BuildContext context,
  WidgetRef ref,
  List<String> months,
  int currentMonthIndex,
  String yearLabel,
) async {
  return showDialog<int>(
    context: context,
    builder: (dialogContext) {
      final materialL10n = MaterialLocalizations.of(context);
      return Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 328, maxHeight: 440),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.s24,
                  AppSpacing.s16,
                  AppSpacing.s24,
                  AppSpacing.s8,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppLocalizations.of(context)!.selectMonth,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: context.secondaryInk,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s4),
                    Text(
                      yearLabel,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: AppTypography.regular),
                    ),
                  ],
                ),
              ),
              const AppDivider(),
              // Month grid
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.s12,
                    vertical: AppSpacing.s8,
                  ),
                  child: GridView.builder(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          childAspectRatio: 2.0,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                        ),
                    itemCount: months.length,
                    itemBuilder: (context, index) {
                      final month = months[index];
                      final isSelected = index == currentMonthIndex;
                      return Material(
                        color: isSelected
                            ? context.colors.primary
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(AppRadius.round),
                        child: InkWell(
                          onTap: () {
                            AppHaptics.tap(ref);
                            Navigator.of(dialogContext).pop(index);
                          },
                          borderRadius: BorderRadius.circular(AppRadius.round),
                          child: Container(
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(
                                AppRadius.round,
                              ),
                              border: isSelected
                                  ? null
                                  : Border.all(
                                      color: context.colors.outline.withValues(
                                        alpha: 0.3,
                                      ),
                                    ),
                            ),
                            child: Text(
                              month,
                              style: TextStyle(
                                color: isSelected
                                    ? context.colors.onPrimary
                                    : context.colors.onSurface,
                                fontWeight: isSelected
                                    ? AppTypography.semibold
                                    : AppTypography.regular,
                                fontSize: AppTypography.sizeDetail,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              // Action buttons
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.s8,
                  AppSpacing.s8,
                  AppSpacing.s8,
                  AppSpacing.s8,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      child: Text(
                        materialL10n.cancelButtonLabel,
                        style: TextStyle(color: context.colors.primary),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
