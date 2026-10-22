import 'dart:io' show Platform;

import 'package:android_intent_plus/android_intent.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../features/ai/domain/ai_app_target.dart';

/// How a hand-off ended, so the caller knows what to tell the user.
enum AiHandoffOutcome {
  /// The prompt went straight into the chosen app's composer.
  openedApp,

  /// The system share sheet was shown instead (or as the user's choice).
  openedChooser,

  /// The user's explicit choice could not be resolved, so nothing was opened.
  /// The caller confirms the share fallback instead of swapping in a chooser
  /// the user did not ask for.
  appUnavailable,

  /// Nothing accepted the text.
  failed,
}

class AiHandoffResult {
  const AiHandoffResult(this.outcome, {this.missingApp});

  final AiHandoffOutcome outcome;

  /// The user's explicit choice that could not be resolved, when [outcome] is
  /// [AiHandoffOutcome.appUnavailable]. Null for automatic hand-offs: the user
  /// never named an app, so there is nothing to report as missing.
  final AiAppTarget? missingApp;
}

/// Hand-off to whichever AI app the user has installed.
///
/// Tithi has no AI of its own: it assembles a prompt from the panchang it
/// already calculated and hands it to an assistant app. Nothing is sent by
/// Tithi itself, and no network call originates here.
///
/// The prompt is delivered the same way the share sheet delivers it
/// (`ACTION_SEND` + `text/plain`), only aimed at one package so Android does
/// not open a chooser first. The receiving app decides what to do with the
/// text; for the assistants listed in [kAiAppTargets] that means a new chat
/// with the prompt already in the composer.
class AiHandoffService {
  const AiHandoffService();

  /// Whether the package-targeted intent can be used on this platform.
  ///
  /// The share sheet and the clipboard work everywhere; only Android exposes
  /// the explicit `ACTION_SEND` that skips the chooser, which is also the only
  /// reason the app picker exists.
  static bool get supportsDirectOpen => Platform.isAndroid;

  /// Whether [target] can receive a text hand-off right now.
  ///
  /// Used by the settings picker so an uninstalled assistant is labelled
  /// instead of silently chosen. Always false off Android.
  Future<bool> canOpen(AiAppTarget target) async {
    if (!Platform.isAndroid) return false;
    try {
      return await _sendIntent(target).canResolveActivity() == true;
    } catch (e) {
      debugPrint('Resolving ${target.label} failed: $e');
      return false;
    }
  }

  /// Hands [prompt] to [preferredAppId], falling back to the share sheet.
  ///
  /// An explicit app is a promise: when it cannot be resolved this returns
  /// [AiHandoffOutcome.appUnavailable] **without** opening anything, so the
  /// caller can confirm the fallback. [kAiTargetAuto] has no such promise and
  /// falls through to the share sheet by itself.
  ///
  /// Never throws: a failed hand-off must not cost the user the prompt they
  /// already see in the preview.
  Future<AiHandoffResult> openAiApp({
    required String prompt,
    String preferredAppId = kAiTargetAuto,
    String? subject,
    Rect? sharePositionOrigin,
  }) async {
    // Only an explicit choice can be reported back as missing.
    final explicit = aiTargetById(preferredAppId);

    if (Platform.isAndroid) {
      for (final target in aiHandoffCandidates(preferredAppId)) {
        if (await _openInApp(target, prompt: prompt, subject: subject)) {
          return const AiHandoffResult(AiHandoffOutcome.openedApp);
        }
      }
      // Elsewhere the choice cannot exist, so there is nothing to confirm:
      // fall through to the share sheet like `auto`.
      if (explicit != null) {
        return AiHandoffResult(
          AiHandoffOutcome.appUnavailable,
          missingApp: explicit,
        );
      }
    }

    final shared = await openShareSheet(
      prompt: prompt,
      subject: subject,
      sharePositionOrigin: sharePositionOrigin,
    );
    if (!shared) return const AiHandoffResult(AiHandoffOutcome.failed);
    return const AiHandoffResult(AiHandoffOutcome.openedChooser);
  }

  /// The explicit `ACTION_SEND` aimed at [target].
  ///
  /// Extras are omitted when [prompt] is null: intent resolution depends on
  /// action/type/package, not on the payload.
  AndroidIntent _sendIntent(
    AiAppTarget target, {
    String? prompt,
    String? subject,
  }) {
    return AndroidIntent(
      action: 'android.intent.action.SEND',
      type: 'text/plain',
      package: target.packageName,
      arguments: <String, dynamic>{
        'android.intent.extra.TEXT': ?prompt,
        'android.intent.extra.SUBJECT': ?subject,
      },
    );
  }

  /// Sends the prompt to [target] and reports whether it was accepted.
  ///
  /// `AndroidIntent.launch()` silently drops the package restriction when the
  /// package cannot be resolved, which would open the chooser anyway - so
  /// resolve first and let the caller fall back deliberately.
  Future<bool> _openInApp(
    AiAppTarget target, {
    required String prompt,
    String? subject,
  }) async {
    try {
      final intent = _sendIntent(target, prompt: prompt, subject: subject);
      if (await intent.canResolveActivity() != true) return false;
      await intent.launch();
      return true;
    } catch (e) {
      debugPrint('Direct AI hand-off to ${target.label} failed: $e');
      return false;
    }
  }

  /// Opens the system share sheet, the path that always works.
  ///
  /// Public so the caller can offer it as a *confirmed* fallback after
  /// [AiHandoffOutcome.appUnavailable].
  Future<bool> openShareSheet({
    required String prompt,
    String? subject,
    Rect? sharePositionOrigin,
  }) async {
    try {
      final result = await SharePlus.instance.share(
        ShareParams(
          text: prompt,
          subject: subject,
          sharePositionOrigin: sharePositionOrigin,
        ),
      );
      return result.status != ShareResultStatus.unavailable;
    } catch (e) {
      debugPrint('AI hand-off failed: $e');
      return false;
    }
  }

  /// Copy-only path for users who would rather paste into an AI tool
  /// themselves. No intent leaves the app.
  ///
  /// Returns whether the text reached the clipboard, so the caller can say so
  /// instead of failing silently when the platform refuses.
  Future<bool> copyPrompt(String prompt) async {
    try {
      await Clipboard.setData(ClipboardData(text: prompt));
      return true;
    } catch (e) {
      debugPrint('Copying the AI prompt failed: $e');
      return false;
    }
  }
}
