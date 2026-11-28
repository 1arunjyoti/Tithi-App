import 'package:flutter/widgets.dart';
import 'package:material_3_expressive/material_3_expressive.dart';

import '../theme/app_theme.dart';

/// Shared expressive switch for settings and other toggles.
///
/// `M3ESwitch` drives its handle with `motor` springs that do **not** read
/// `MediaQuery.disableAnimations`, and its track fade uses a fixed duration.
/// Reduce Motion therefore needs an explicit gate: when it is on the switch is
/// remounted with its final value, so both springs start settled and the track
/// has no previous colour to animate from.
///
/// The focus node lives here (outside the remounted child) so toggling by
/// keyboard does not drop focus when Reduce Motion replaces the switch.
class AppSwitch extends StatefulWidget {
  const AppSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    this.selectedIcon,
    this.semanticLabel,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;
  final Widget? selectedIcon;
  final String? semanticLabel;

  @override
  State<AppSwitch> createState() => _AppSwitchState();
}

class _AppSwitchState extends State<AppSwitch> {
  final FocusNode _focusNode = FocusNode();

  @override
  void didUpdateWidget(covariant AppSwitch oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value && _focusNode.hasFocus) {
      final node = _focusNode;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && node.canRequestFocus) node.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final instant = AppTheme.reduceMotionOf(context);
    return M3ESwitch(
      // A fresh key creates controllers initialised at the new value: the
      // handle jumps to the settled position instead of springing across.
      key: instant ? ValueKey<bool>(widget.value) : null,
      focusNode: _focusNode,
      value: widget.value,
      onChanged: widget.onChanged,
      selectedIcon: widget.selectedIcon,
      semanticLabel: widget.semanticLabel,
    );
  }
}
