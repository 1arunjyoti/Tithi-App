import 'package:material_ui/material_ui.dart';
import 'package:material_3_expressive/material_3_expressive.dart';

/// Severity of an app message. Drives the default duration — callers never
/// style snackbars by hand.
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
/// * One snackbar at a time via [M3ESnackbar.defaultController], so rapid taps
///   never stack a queue.
/// * Material 3 Expressive surface, motion and optional action styling — the
///   look is identical across light/dark/pure-black/high-contrast.
/// * [AppMessageKind.error] shows longer (5s vs 3s).
/// * Optional [action] (e.g. Undo/Retry/Settings) and [duration] override.
void showAppMessage(
  BuildContext context,
  String message, {
  AppMessageKind kind = AppMessageKind.info,
  SnackBarAction? action,
  Duration? duration,
}) {
  // Use the live context: M3ESnackbar needs a context with an Overlay, and a
  // captured ScaffoldMessengerState may sit above the Navigator in tests and
  // after route pops.
  M3ESnackbar.show(
    context,
    message: message,
    actionLabel: action?.label,
    onAction: action?.onPressed,
    duration: duration ?? _defaultDuration(kind),
  );
}

Duration _defaultDuration(AppMessageKind kind) => kind == AppMessageKind.error
    ? const Duration(seconds: 5)
    : const Duration(seconds: 3);

/// Variant that posts through an already-captured [ScaffoldMessengerState]
/// with already-resolved [colors] — for flows that pop their own route (e.g.
/// the drawer) before reporting, where the originating [BuildContext] is
/// unmounted by show time. Capture both before the pop/awaits.
void showAppMessageOn(
  ScaffoldMessengerState messenger,
  ColorScheme colors,
  String message, {
  AppMessageKind kind = AppMessageKind.info,
  SnackBarAction? action,
  Duration? duration,
}) {
  M3ESnackbar.show(
    messenger.context,
    message: message,
    actionLabel: action?.label,
    onAction: action?.onPressed,
    // M3ESnackbar does not auto-dismiss an actionable bar unless a duration
    // is given, so always resolve one to keep the old 3s/5s behaviour.
    duration: duration ?? _defaultDuration(kind),
  );
}
