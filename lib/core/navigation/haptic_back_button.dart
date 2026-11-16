import 'package:flutter/material.dart';

import '../anim/press_scale.dart';
import '../../theme/app_metrics.dart';

/// Framework back-button replacement with gated press haptic + press scale.
///
/// Drop-in for pushed screens: `automaticallyImplyLeading: false` plus
/// `leading: const HapticBackButton()`. Pops via [Navigator.maybePop] (same
/// as the framework button, so [PopScope] guards are honored). Renders
/// nothing when the route can't pop, so it's safe to leave in place
/// unconditionally.
///
/// [circled] puts the glyph on the app's translucent surface circle. It is
/// reserved for bars that float over imagery (the map picker), where a bare
/// glyph washes out; everywhere else the plain icon is the app-wide look.
class HapticBackButton extends StatelessWidget {
  const HapticBackButton({super.key, this.circled = false});

  /// Draw the glyph on a translucent `surface` circle.
  final bool circled;

  @override
  Widget build(BuildContext context) {
    if (!(ModalRoute.of(context)?.canPop ?? false)) {
      return const SizedBox.shrink();
    }
    return PressScale(
      child: IconButton(
        icon: circled
            ? Container(
                padding: const EdgeInsets.all(AppSpacing.s8),
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.surface.withValues(alpha: 0.5),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.arrow_back_rounded),
              )
            : const Icon(Icons.arrow_back_rounded),
        tooltip: MaterialLocalizations.of(context).backButtonTooltip,
        onPressed: () => Navigator.of(context).maybePop(),
      ),
    );
  }
}
