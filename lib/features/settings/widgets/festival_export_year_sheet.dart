import 'package:material_ui/material_ui.dart';

import '../../../l10n/app_localizations.dart';
import '../../../theme/app_metrics.dart';
import '../../../widgets/settings_widgets.dart';

/// Year picker for the festival export flow.
///
/// A row tap only moves the checkmark; the export is started by the explicit
/// confirm button. This keeps "select a year" and "proceed" as two distinct,
/// visible steps instead of treating the highlighted year as an immediate
/// action that drops straight into a progress dialog and a save picker.
class FestivalExportYearSheet extends StatefulWidget {
  const FestivalExportYearSheet._({
    required this.initialYear,
    required this.onExport,
  });

  /// Current year, also the first preselected choice.
  final int initialYear;
  final ValueChanged<int> onExport;

  /// Shows the picker as a modal bottom sheet. [title] should name the format
  /// (JSON or Calendar) and [subtitle] should say what happens after confirm.
  static Future<void> show({
    required BuildContext context,
    required String title,
    required String subtitle,
    required ValueChanged<int> onExport,
  }) {
    final thisYear = DateTime.now().year;
    return SettingsBottomSheet.show(
      context: context,
      title: title,
      subtitle: subtitle,
      children: [
        FestivalExportYearSheet._(initialYear: thisYear, onExport: onExport),
      ],
    );
  }

  @override
  State<FestivalExportYearSheet> createState() =>
      _FestivalExportYearSheetState();
}

class _FestivalExportYearSheetState extends State<FestivalExportYearSheet> {
  late int _selectedYear = widget.initialYear;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final years = [
      widget.initialYear - 1,
      widget.initialYear,
      widget.initialYear + 1,
      widget.initialYear + 2,
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ...years.map(
          (year) => SettingsPickerItem(
            title: year.toString(),
            isSelected: year == _selectedYear,
            onTap: () => setState(() => _selectedYear = year),
          ),
        ),
        const SizedBox(height: AppSpacing.s16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s24),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () {
                Navigator.pop(context);
                widget.onExport(_selectedYear);
              },
              child: Text(
                l10n?.exportYearAction(_selectedYear.toString()) ??
                'Export $_selectedYear',
              ),
            ),
          ),
        ),
      ],
    );
  }
}
