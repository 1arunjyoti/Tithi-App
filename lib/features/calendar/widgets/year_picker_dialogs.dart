import 'package:material_ui/material_ui.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/feedback/app_haptics.dart';
import '../../../l10n/app_localizations.dart';
import '../../../theme/app_metrics.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/app_typography.dart';
import '../../../utils/tithi_localization.dart';
import '../../../widgets/app_buttons.dart';
import '../../../widgets/app_dialog.dart';

/// One cell in the year/month grid. The selection wash is the app's primary
/// with on-primary ink; M3E's dialog handles the surrounding chrome.
class _GridCell extends StatelessWidget {
  const _GridCell({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? context.colors.primary : Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadius.round),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.round),
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.round),
            border: selected
                ? null
                : Border.all(
                    color: context.colors.outline.withValues(alpha: 0.3),
                  ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected
                  ? context.colors.onPrimary
                  : context.colors.onSurface,
              fontWeight: selected
                  ? AppTypography.semibold
                  : AppTypography.regular,
              fontSize: AppTypography.sizeBody,
            ),
          ),
        ),
      ),
    );
  }
}

/// Shared M3E dialog shell for the calendar's year and month grids.
Future<int?> _showGridDialog(
  BuildContext context,
  WidgetRef ref, {
  required String title,
  required String subhead,
  required int itemCount,
  required int initialIndex,
  required String Function(int index) labelFor,
  ScrollController? scrollController,
}) {
  return AppDialog.showWidget<int>(context, (dialogContext) {
    final cancelLabel = MaterialLocalizations.of(context).cancelButtonLabel;
    return M3EDialog(
      title: title,
      subhead: subhead,
      topDivider: true,
      content: SizedBox(
        height: 320,
        child: GridView.builder(
          controller: scrollController,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            childAspectRatio: 2.0,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          itemCount: itemCount,
          itemBuilder: (context, index) => _GridCell(
            label: labelFor(index),
            selected: index == initialIndex,
            onTap: () {
              AppHaptics.tap(ref);
              Navigator.of(dialogContext).pop(index);
            },
          ),
        ),
      ),
      actions: [
        Builder(
          builder: (c) => AppButton(
            style: M3EButtonStyle.text,
            onPressed: () => Navigator.pop(c),
            child: Text(cancelLabel),
          ),
        ),
      ],
    );
  });
}

/// Custom year picker dialog matching the Material 3 year grid.
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
    return await _showGridDialog(
      context,
      ref,
      title: eraName,
      subhead: AppLocalizations.of(context)?.selectYear ?? 'Select year',
      itemCount: years.length,
      initialIndex: initialIndex,
      scrollController: scrollController,
      labelFor: (index) => localizeDigits(
        '${years[index]}',
        Localizations.localeOf(context).languageCode,
      ),
    );
  } finally {
    scrollController.dispose();
  }
}

/// Month picker dialog matching the Material 3 month grid.
Future<int?> showAdaptiveMonthPickerDialog(
  BuildContext context,
  WidgetRef ref,
  List<String> months,
  int currentMonthIndex,
  String yearLabel,
) {
  return _showGridDialog(
    context,
    ref,
    title: yearLabel,
    subhead: AppLocalizations.of(context)!.selectMonth,
    itemCount: months.length,
    initialIndex: currentMonthIndex,
    labelFor: (index) => months[index],
  );
}
