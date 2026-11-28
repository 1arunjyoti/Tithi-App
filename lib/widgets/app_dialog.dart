import 'package:material_ui/material_ui.dart';
import 'package:material_3_expressive/material_3_expressive.dart';

/// Shared Material 3 Expressive dialog.
///
/// [M3EDialog] keeps the headline and action row pinned while [content]
/// scrolls, so long content (release notes, progress logs) needs no nested
/// `SingleChildScrollView`. Callers supply [AppButton] actions.
class AppDialog {
  const AppDialog._();

  /// Presents a dialog widget built lazily (e.g. a `ConsumerWidget` that
  /// needs to watch providers for its title, content and actions).
  static Future<T?> showWidget<T>(
    BuildContext context,
    WidgetBuilder builder, {
    bool barrierDismissible = true,
  }) {
    return M3EDialog.show<T>(
      context,
      barrierDismissible: barrierDismissible,
      dialog: Builder(builder: builder),
    );
  }

  static Future<T?> show<T>(
    BuildContext context, {
    required String title,
    String? subhead,
    Widget? content,
    required List<Widget> actions,
    Widget? icon,
    bool barrierDismissible = true,
  }) {
    return M3EDialog.show<T>(
      context,
      barrierDismissible: barrierDismissible,
      dialog: M3EDialog(
        title: title,
        subhead: subhead,
        content: content,
        actions: actions,
        icon: icon,
      ),
    );
  }
}
