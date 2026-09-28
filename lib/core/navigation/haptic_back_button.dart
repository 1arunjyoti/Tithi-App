import 'package:flutter/material.dart';

import '../anim/press_scale.dart';

/// Framework back-button replacement with gated press haptic + press scale.
///
/// Drop-in for pushed screens: `automaticallyImplyLeading: false` plus
/// `leading: const HapticBackButton()`. Pops via [Navigator.maybePop] (same
/// as the framework button, so [PopScope] guards are honored). Renders
/// nothing when the route can't pop, so it's safe to leave in place
/// unconditionally.
class HapticBackButton extends StatelessWidget {
  const HapticBackButton({super.key});

  @override
  Widget build(BuildContext context) {
    if (!(ModalRoute.of(context)?.canPop ?? false)) {
      return const SizedBox.shrink();
    }
    return PressScale(
      child: IconButton(
        icon: const Icon(Icons.arrow_back_rounded),
        tooltip: MaterialLocalizations.of(context).backButtonTooltip,
        onPressed: () => Navigator.of(context).maybePop(),
      ),
    );
  }
}
