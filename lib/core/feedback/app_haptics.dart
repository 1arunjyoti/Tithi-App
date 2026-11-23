import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/accessibility_provider.dart';

/// Every buzz in the app goes through here.
///
/// Haptic Feedback is a user setting (Settings > Accessibility), but each call
/// site used to open-code the same gate -
/// `if (ref.read(accessibilityProvider).hapticFeedback) { HapticFeedback
/// .lightImpact(); }` - twenty times over. A call site that forgot the gate
/// still buzzed with the setting off, and the reader had to re-verify the same
/// three lines on every review.
///
/// Two weights only, so a screen cannot quietly invent a third:
///
/// - [tap]: light tick for taps, selection changes and toggles.
/// - [impact]: heavier confirming thump, reserved for deliberate actions
///   (the Paksha hero's manual page turn).
///
/// Pass `haptic: false` to `PressScale` where the tap callback already buzzes -
/// the callback owns the one buzz, the scale only animates.
abstract final class AppHaptics {
  /// Light tick: taps, selection changes, toggles.
  static void tap(WidgetRef ref) => _fire(ref, HapticFeedback.lightImpact);

  /// Medium thump: deliberate actions only.
  static void impact(WidgetRef ref) => _fire(ref, HapticFeedback.mediumImpact);

  static void _fire(WidgetRef ref, Future<void> Function() feedback) {
    if (!ref.read(accessibilityProvider).hapticFeedback) return;
    feedback();
  }
}
