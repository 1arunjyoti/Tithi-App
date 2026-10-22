import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';

import '../../../services/ai_handoff_service.dart';
import '../../../services/storage_service.dart';
import '../domain/ai_app_target.dart';

/// Settings-box key for the AI assist opt-in.
///
/// Defaults to false everywhere: the feature is off until the user turns it
/// on, and nothing is shared before that.
const String aiAssistEnabledKey = 'ai_assist_enabled';

/// Whether the manual "ask your AI app" hand-off is enabled.
class AiAssistEnabledNotifier extends Notifier<bool> {
  @override
  bool build() {
    try {
      final box = StorageService().getSettingsBox();
      return box.get(aiAssistEnabledKey, defaultValue: false) as bool;
    } catch (e) {
      // Storage not ready (e.g. a widget test pumping a sheet in isolation):
      // stay opt-out rather than showing an unpersisted enabled state.
      debugPrint('AI assist state unavailable, defaulting to off: $e');
      return false;
    }
  }

  /// Persists [enabled] and returns whether the write succeeded.
  ///
  /// The caller reverts the UI on false so the switch never claims a state
  /// that was not stored.
  Future<bool> setEnabled(bool enabled) async {
    state = enabled;
    try {
      final box = StorageService().getSettingsBox();
      await box.put(aiAssistEnabledKey, enabled);
      return true;
    } catch (e) {
      debugPrint('Failed to persist AI assist state: $e');
      // Revert only our own optimistic write: a newer toggle may have landed
      // while the box write was in flight, and rolling that one back would
      // make the switch lie in the other direction.
      if (state == enabled) state = !enabled;
      return false;
    }
  }
}

final aiAssistEnabledProvider =
    NotifierProvider<AiAssistEnabledNotifier, bool>(
      AiAssistEnabledNotifier.new,
    );

/// Settings-box key for the assistant Tithi opens directly.
const String aiTargetAppKey = 'ai_target_app';

/// Which assistant the "Open" action targets.
///
/// [kAiTargetAuto] keeps the old behaviour of trying the known assistants and
/// falling back to the share sheet. An explicit id skips the chooser
/// entirely. Unknown stored values (an app list that changed between builds)
/// degrade to [kAiTargetAuto] rather than blocking the hand-off.
class AiTargetAppNotifier extends Notifier<String> {
  @override
  String build() {
    try {
      final box = StorageService().getSettingsBox();
      final raw = box.get(aiTargetAppKey, defaultValue: kAiTargetAuto) as String;
      return aiTargetById(raw) == null ? kAiTargetAuto : raw;
    } catch (e) {
      debugPrint('AI target app unavailable, defaulting to automatic: $e');
      return kAiTargetAuto;
    }
  }

  /// Persists [id] and returns whether the write succeeded.
  Future<bool> setTarget(String id) async {
    if (id != kAiTargetAuto && aiTargetById(id) == null) return false;
    final previous = state;
    state = id;
    try {
      final box = StorageService().getSettingsBox();
      await box.put(aiTargetAppKey, id);
      return true;
    } catch (e) {
      debugPrint('Failed to persist AI target app: $e');
      // Same rule as setEnabled: do not undo a newer choice.
      if (state == id) state = previous;
      return false;
    }
  }
}

final aiTargetAppProvider = NotifierProvider<AiTargetAppNotifier, String>(
  AiTargetAppNotifier.new,
);

/// Whether this platform can hand the prompt to a specific package.
///
/// The share sheet and the clipboard work everywhere, but the direct open (and
/// therefore the app picker that configures it) is an Android `ACTION_SEND`
/// with `setPackage`. Elsewhere the sheet falls back to the share sheet, so it
/// must not promise "Open Gemini".
final aiDirectOpenSupportedProvider = Provider<bool>(
  (ref) => AiHandoffService.supportsDirectOpen,
);

/// Device IANA time zone for the prompt, so the assistant can reason about
/// "7pm" without assuming a country.
///
/// `autoDispose` on purpose: the sheet is the only consumer, and a device can
/// change zones between sessions (travel), so the value is re-resolved on each
/// open instead of being frozen until the next app start.
///
/// Falls back to Asia/Kolkata, matching the app's primary audience (same rule
/// as `NotificationService._getDeviceTimezone`).
final aiDeviceTimeZoneProvider = FutureProvider.autoDispose<String>((ref) async {
  try {
    final info = await FlutterTimezone.getLocalTimezone();
    if (info.identifier.isNotEmpty) return info.identifier;
  } catch (e) {
    debugPrint('flutter_timezone unavailable for AI prompt: $e');
  }
  return 'Asia/Kolkata';
});

final aiHandoffServiceProvider = Provider<AiHandoffService>(
  (ref) => const AiHandoffService(),
);
