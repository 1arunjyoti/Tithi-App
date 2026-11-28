import 'package:material_ui/material_ui.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/feedback/app_haptics.dart';
import '../theme/app_typography.dart';

/// Shared expressive button.
///
/// Every action button in the app goes through here so the M3E variant and
/// size vocabulary stays consistent. The haptic is restored through
/// [AppHaptics] — the old `PressScale` wrapper owned it, and M3E buttons do
/// not buzz on their own.
class AppButton extends ConsumerWidget {
  const AppButton({
    super.key,
    required this.onPressed,
    this.child,
    this.icon,
    this.label,
    this.style = M3EButtonStyle.filled,
    this.size = M3EButtonSize.md,
    this.semanticLabel,
    this.tooltip,
    this.padding,
    this.minimumSize,
    this.tapTargetSize,
    this.haptic = true,
  });

  final VoidCallback? onPressed;
  final Widget? child;

  /// Leading icon. Pair with [label] for an icon-and-label action.
  final Widget? icon;
  final Widget? label;
  final M3EButtonStyle style;
  final M3EButtonSize size;
  final String? semanticLabel;
  final String? tooltip;
  final EdgeInsetsGeometry? padding;
  final Size? minimumSize;
  final MaterialTapTargetSize? tapTargetSize;

  /// Set false only when the callback already calls [AppHaptics.tap].
  final bool haptic;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m3e = M3ETheme.of(context);
    return M3EButton(
      onPressed: onPressed == null
          ? null
          : () {
              if (haptic) AppHaptics.tap(ref);
              onPressed!();
            },
      icon: icon,
      label: label,
      style: style,
      size: size,
      semanticLabel: semanticLabel,
      tooltip: tooltip,
      // AppHaptics owns the one gated buzz; disable M3E/platform feedback
      // so a press never double-buzzes.
      enableFeedback: false,
      // M3E's default label is regular weight; the app's buttons have always
      // been semibold, and the heavier label keeps filled buttons from
      // reading as flat. Foreground colour still comes from M3E's style.
      decoration: M3EButtonDecoration(
        textStyle: m3e.typeScale.labelLarge.copyWith(
          fontWeight: AppTypography.semibold,
        ),
        padding: padding,
        minimumSize: minimumSize,
        tapTargetSize: tapTargetSize,
      ),
      child: child,
    );
  }
}

/// Shared expressive icon-only action.
class AppIconButton extends ConsumerWidget {
  const AppIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.tooltip,
    this.semanticLabel,
    this.variant = M3EIconButtonVariant.standard,
    this.size = M3EIconButtonSize.sm,
    this.haptic = true,
  });

  final Widget icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final String? semanticLabel;
  final M3EIconButtonVariant variant;
  final M3EIconButtonSize size;
  final bool haptic;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return M3EIconButton(
      icon: icon,
      onPressed: onPressed == null
          ? null
          : () {
              if (haptic) AppHaptics.tap(ref);
              onPressed!();
            },
      tooltip: tooltip,
      semanticLabel: semanticLabel,
      variant: variant,
      size: size,
      enableFeedback: false,
    );
  }
}
