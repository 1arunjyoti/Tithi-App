import 'package:material_ui/material_ui.dart';
import 'package:material_3_expressive/material_3_expressive.dart';

/// Shared Material 3 Expressive modal sheet.
///
/// The chrome (28dp corners, 32x4 drag handle, scrim, 640dp max width, spring
/// entrance and resizable detents) belongs to [M3EBottomSheet]. This wrapper
/// fixes the app-wide convention of opening at content height and is the only
/// place that should call `M3EBottomSheet.show`.
class AppBottomSheet {
  const AppBottomSheet._();

  static Future<T?> show<T>(
    BuildContext context, {
    required WidgetBuilder builder,
    M3EBottomSheetValue initialValue = M3EBottomSheetValue.expanded,
  }) {
    return M3EBottomSheet.show<T>(
      context,
      initialValue: initialValue,
      builder: builder,
    );
  }
}
