/// AI apps Tithi can hand a prompt to directly.
///
/// Android has no public "default AI app" role: the system share sheet *is*
/// the chooser the platform exposes to third-party apps, and the assistant
/// role (`ACTION_ASSIST`) cannot receive arbitrary text. The closest public
/// equivalent is an explicit `ACTION_SEND` aimed at one package: the chooser
/// disappears and the receiving app fills its composer with the prompt.
///
/// Everything here is a plain package id, so a renamed or removed target can
/// never break the hand-off - it just stops resolving and the caller falls
/// back to the share sheet.
library;

class AiAppTarget {
  const AiAppTarget({
    required this.id,
    required this.label,
    required this.packageName,
  });

  /// Stable settings value. Never shown to the user.
  final String id;

  /// Brand name, left untranslated on purpose.
  final String label;

  /// Android application id passed to `Intent.setPackage`.
  final String packageName;
}

/// Settings value meaning "no explicit choice".
const String kAiTargetAuto = 'auto';

/// Known assistants, in the order `auto` tries them.
///
/// Gemini leads because it ships as the system assistant on the devices this
/// app targets; the rest follow so a user without Gemini still gets a direct
/// hand-off instead of the chooser.
const List<AiAppTarget> kAiAppTargets = <AiAppTarget>[
  AiAppTarget(
    id: 'gemini',
    label: 'Gemini',
    packageName: 'com.google.android.apps.bard',
  ),
  AiAppTarget(
    id: 'chatgpt',
    label: 'ChatGPT',
    packageName: 'com.openai.chatgpt',
  ),
  AiAppTarget(
    id: 'claude',
    label: 'Claude',
    packageName: 'com.anthropic.claude',
  ),
  AiAppTarget(
    id: 'copilot',
    label: 'Copilot',
    packageName: 'com.microsoft.copilot',
  ),
  AiAppTarget(
    id: 'perplexity',
    label: 'Perplexity',
    packageName: 'ai.perplexity.app.android',
  ),
  AiAppTarget(
    id: 'indus',
    label: 'Indus',
    packageName: 'ai.sarvam.indus',
  ),
];

/// The target stored under [id], or null for [kAiTargetAuto] and for values
/// written by a build that shipped a different list.
AiAppTarget? aiTargetById(String? id) {
  if (id == null || id == kAiTargetAuto) return null;
  for (final target in kAiAppTargets) {
    if (target.id == id) return target;
  }
  return null;
}

/// Ordered packages to try for [preferredId].
///
/// An explicit choice yields exactly that app. `auto` - and any unknown stored
/// id - yields the full list, so the first installed assistant wins.
List<AiAppTarget> aiHandoffCandidates(String preferredId) {
  final target = aiTargetById(preferredId);
  return target == null ? kAiAppTargets : <AiAppTarget>[target];
}
