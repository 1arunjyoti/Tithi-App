import 'package:material_ui/material_ui.dart';
import 'package:material_3_expressive/material_3_expressive.dart';

/// Shared Material 3 Expressive search bar for inline searches.
///
/// Both search screens keep their own results list and debounce; this wrapper
/// owns only the expressive bar (56dp pill, spring focus, clear affordance).
/// Callers must not wrap it in the old `AppCard`/glassmorphism box.
class AppSearchField extends StatelessWidget {
  const AppSearchField({
    super.key,
    this.controller,
    this.focusNode,
    required this.hintText,
    this.trailing,
    this.textInputAction = TextInputAction.search,
    this.onChanged,
    this.onSubmitted,
    this.showClearButton = false,
  });

  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String hintText;
  final Iterable<Widget>? trailing;
  final TextInputAction textInputAction;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool showClearButton;

  @override
  Widget build(BuildContext context) {
    return M3ESearchBar(
      controller: controller,
      focusNode: focusNode,
      hintText: hintText,
      leading: const Icon(M3EIcons.search),
      trailing: trailing,
      showClearButton: showClearButton,
      textInputAction: textInputAction,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      // These bars live inside a screen with its own gutters, so keep the
      // spec pill but disable the standalone 24->12 focus margin animation.
      margin: 0,
      focusedMargin: 0,
      expandOnFocus: false,
    );
  }
}
