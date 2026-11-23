import 'package:material_ui/material_ui.dart';

import '../theme/app_theme.dart';

/// The shared 1px rule, in two weights derived from `onSurface`.
///
/// Before this each site picked its own alpha (0.06 / 0.08 / 0.1 / 0.15) and
/// its own height, so rules stacked on the same screen rarely matched and none
/// of them followed High Contrast. Pick by job:
///
/// - `AppDivider()` (0.1): separates sections and panels - settings groups, a
///   header from the list below it, the boundary in a detail sheet.
/// - `AppDivider.row()` (0.08): the quieter rule between rows that share one
///   card surface, so a long list does not read as a table.
///
/// Both stay a 1px hairline in High Contrast (0.22, see
/// [AppTheme.hairlineAlpha]) rather than jumping to full ink: an opaque rule
/// reads as a hard border. Card and sheet edges keep using
/// [AppTheme.sheetHairline]; this is only for rules drawn inside a surface.
class AppDivider extends StatelessWidget {
  const AppDivider({super.key, this.indent = 0, this.endIndent = 0})
    : tight = false;

  /// Row-weight rule: same hairline, 0.08 instead of 0.1.
  const AppDivider.row({super.key, this.indent = 0, this.endIndent = 0})
    : tight = true;

  /// Space before the rule, e.g. to line up with a row's text column.
  final double indent;

  /// Space after the rule.
  final double endIndent;

  /// Row-weight (0.08) rather than section-weight (0.1).
  final bool tight;

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      thickness: 1,
      indent: indent,
      endIndent: endIndent,
      color: context.colors.onSurface.withValues(
        alpha: AppTheme.hairlineAlpha(context, tight ? 0.08 : 0.1),
      ),
    );
  }
}
