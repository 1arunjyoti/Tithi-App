import 'package:material_ui/material_ui.dart';

import '../../../l10n/app_localizations.dart';
import '../../../theme/app_metrics.dart';
import '../../../widgets/app_buttons.dart';
import '../../../widgets/settings_widgets.dart';

/// Year picker for the festival export flow.
///
/// A row tap only moves the checkmark; the export is started by the explicit
/// confirm button. This keeps "select a year" and "proceed" as two distinct,
/// visible steps instead of treating the highlighted year as an immediate
/// action that drops straight into a progress dialog and a save picker.
class FestivalExportYearSheet {
  const FestivalExportYearSheet._();

  /// Shows the picker as a modal bottom sheet. [title] should name the format
  /// (JSON or Calendar) and [subtitle] should say what happens after confirm.
  static Future<void> show({
    required BuildContext context,
    required String title,
    required String subtitle,
    required ValueChanged<int> onExport,
  }) {
    final l10n = AppLocalizations.of(context);
    final thisYear = DateTime.now().year;
    final years = [thisYear - 1, thisYear, thisYear + 1, thisYear + 2];
    final selection = ValueNotifier<int>(thisYear);

    return SettingsBottomSheet.show(
      context: context,
      title: title,
      subtitle: subtitle,
      selectedIndex: years.indexOf(thisYear),
      options: [
        for (final year in years)
          SettingsPickerOption(
            title: year.toString(),
            onSelected: () => selection.value = year,
          ),
      ],
      // The footer is rebuilt when the selection changes so the confirm label
      // always names the year that will actually be exported.
      footer: ValueListenableBuilder<int>(
        valueListenable: selection,
        builder: (context, year, _) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s24),
          child: SizedBox(
            width: double.infinity,
            child: AppButton(
              onPressed: () {
                Navigator.pop(context);
                onExport(year);
              },
              child: Text(
                l10n?.exportYearAction(year.toString()) ?? 'Export $year',
              ),
            ),
          ),
        ),
      ),
    );
  }
}
