import 'package:flutter/material.dart';

/// Severity of an app message. Drives icon, tint and default duration —
/// callers never style SnackBars by hand.
enum AppMessageKind {
  /// Neutral confirmation (saved, copied, started).
  info,

  /// Success confirmation (export done, countdown added).
  success,

  /// Failure or blocked action (export failed, no network).
  error,
}

/// Single entry point for transient user feedback (replaces ~25 ad-hoc
/// `SnackBar(...)` call sites).
///
/// * Clears the current message first, so rapid taps never stack a queue.
/// * Floating rounded style on [ColorScheme.inverseSurface], so the look is
///   identical in every theme (light/dark/pure-black/high-contrast).
/// * [AppMessageKind.error] shows longer (5s vs 3s) and carries an error
///   icon; [success] a check icon; [info] no icon.
/// * Optional [action] (e.g. Undo/Retry/Settings) and [duration] override.
void showAppMessage(
  BuildContext context,
  String message, {
  AppMessageKind kind = AppMessageKind.info,
  SnackBarAction? action,
  Duration? duration,
}) {
  showAppMessageOn(
    ScaffoldMessenger.of(context),
    Theme.of(context).colorScheme,
    message,
    kind: kind,
    action: action,
    duration: duration,
  );
}

/// Variant that posts on an already-captured [ScaffoldMessengerState] with
/// already-resolved [colors] — for flows that pop their own route (e.g. the
/// drawer) before reporting, where the originating [BuildContext] is
/// unmounted by show time. Capture both before the pop/awaits.
void showAppMessageOn(
  ScaffoldMessengerState messenger,
  ColorScheme colors,
  String message, {
  AppMessageKind kind = AppMessageKind.info,
  SnackBarAction? action,
  Duration? duration,
}) {
  messenger.clearSnackBars();
  final IconData? icon = switch (kind) {
    AppMessageKind.success => Icons.check_circle_rounded,
    AppMessageKind.error => Icons.error_rounded,
    AppMessageKind.info => null,
  };
  final Color iconColor = switch (kind) {
    AppMessageKind.success => Colors.green.shade300,
    AppMessageKind.error => Colors.red.shade300,
    AppMessageKind.info => colors.onInverseSurface,
  };

  messenger.showSnackBar(
    SnackBar(
      content: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 20, color: iconColor),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: colors.onInverseSurface),
            ),
          ),
        ],
      ),
      action: action,
      duration:
          duration ??
          (kind == AppMessageKind.error
              ? const Duration(seconds: 5)
              : const Duration(seconds: 3)),
      behavior: SnackBarBehavior.floating,
      backgroundColor: colors.inverseSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    ),
  );
}
