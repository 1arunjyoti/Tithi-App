import 'package:material_ui/material_ui.dart';

import 'app_divider.dart';

/// 1px hairline between two rows that share one card surface.
///
/// Starts at [leadingInset] instead of the card edge, so it lines up with the
/// text column (past the row's leading icon/day badge) rather than cutting
/// under it. Rows are transparent on the card (see
/// `AppTheme.festivalRowDecoration`), so this line is the only separator;
/// callers leave it off after the last row.
///
/// Thin delegate to [AppDivider.row] - kept as its own type because the inset
/// is the point of the widget and the card tests look it up by type.
class InsetRowDivider extends StatelessWidget {
  const InsetRowDivider({super.key, required this.leadingInset});

  /// Distance from the card's content edge to the first glyph of the text
  /// column: leading tile width + the gap after it.
  final double leadingInset;

  @override
  Widget build(BuildContext context) {
    return AppDivider.row(indent: leadingInset);
  }
}
