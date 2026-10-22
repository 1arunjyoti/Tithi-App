import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/feedback/app_messages.dart';
import '../../../l10n/app_localizations.dart';
import '../../../l10n/app_localizations_en.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/settings_widgets.dart';
import '../domain/ai_app_target.dart';
import '../providers/ai_providers.dart';

/// Settings group for the optional AI hand-off.
///
/// Turns the feature on only after an explicit consent dialog that states
/// what leaves the device, and keeps a "How it works" explainer next to the
/// switch so the rule ("Tithi calculates, the assistant explains") is never
/// more than one tap away.
class AiSection extends ConsumerWidget {
  const AiSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context) ?? AppLocalizationsEn();
    final enabled = ref.watch(aiAssistEnabledProvider);
    final targetId = ref.watch(aiTargetAppProvider);
    // The app picker configures a package-targeted intent, which only Android
    // can send. Elsewhere the hand-off is the share sheet, so the picker would
    // offer choices that can never resolve.
    final directOpen = ref.watch(aiDirectOpenSupportedProvider);
    final selectedTarget = directOpen ? aiTargetById(targetId) : null;

    return Column(
      children: [
        SettingsSwitchTile(
          icon: Icons.auto_awesome_outlined,
          title: l10n.aiAssist,
          subtitle: l10n.aiAssistSubtitle,
          value: enabled,
          onChanged: (value) async {
            if (value) {
              final confirmed = await _showConsentDialog(context, l10n);
              if (!confirmed) return;
            }
            if (!context.mounted) return;
            final saved = await ref
                .read(aiAssistEnabledProvider.notifier)
                .setEnabled(value);
            if (!saved && context.mounted) {
              showAppMessage(
                context,
                l10n.aiToggleFailed,
                kind: AppMessageKind.error,
              );
            }
          },
        ),
        if (directOpen) ...[
          const SettingsDivider(),
          SettingsActionTile(
            icon: Icons.open_in_new_rounded,
            title: l10n.aiAppSetting,
            subtitle: selectedTarget?.label ?? l10n.aiAppAutomatic,
            onTap: () => _showAppPicker(context, ref, l10n),
          ),
        ],
        const SettingsDivider(),
        SettingsActionTile(
          icon: Icons.info_outline_rounded,
          title: l10n.aiHowItWorks,
          subtitle: l10n.aiHowItWorksSubtitle,
          onTap: () => _showHowItWorks(context, l10n),
        ),
      ],
    );
  }

  /// Lets the user pick the app the "Open" action targets.
  ///
  /// Android has no default-assistant role for text, so the choice is
  /// explicit; "Automatic" still tries the known apps in turn and ends at the
  /// share sheet. Availability is resolved up front so an app that is not
  /// installed is labelled instead of silently chosen.
  Future<void> _showAppPicker(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
  ) async {
    final current = ref.read(aiTargetAppProvider);
    final handoff = ref.read(aiHandoffServiceProvider);
    final resolved = await Future.wait(kAiAppTargets.map(handoff.canOpen));
    final available = <String, bool>{
      for (var i = 0; i < kAiAppTargets.length; i++)
        kAiAppTargets[i].id: resolved[i],
    };
    if (!context.mounted) return;

    final chosen = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.aiAppPickerTitle),
        contentPadding: const EdgeInsets.symmetric(vertical: 8),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _AppOption(
                label: l10n.aiAppAutomatic,
                subtitle: l10n.aiAppAutomaticSubtitle,
                selected: current == kAiTargetAuto,
                onTap: () => Navigator.of(dialogContext).pop(kAiTargetAuto),
              ),
              for (final target in kAiAppTargets)
                _AppOption(
                  label: target.label,
                  subtitle: available[target.id] == true
                      ? null
                      : l10n.aiAppNotInstalled,
                  selected: current == target.id,
                  onTap: available[target.id] == true
                      ? () => Navigator.of(dialogContext).pop(target.id)
                      : null,
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l10n.cancel),
          ),
        ],
      ),
    );
    if (chosen == null || !context.mounted) return;
    final saved = await ref.read(aiTargetAppProvider.notifier).setTarget(chosen);
    if (!saved && context.mounted) {
      // Not `aiToggleFailed`: the switch is not what failed to save here.
      showAppMessage(
        context,
        l10n.aiAppPickerFailed,
        kind: AppMessageKind.error,
      );
    }
  }

  Future<bool> _showConsentDialog(
    BuildContext context,
    AppLocalizations l10n,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Row(
          children: [
            Icon(
              Icons.auto_awesome_outlined,
              color: Theme.of(dialogContext).colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(l10n.aiConsentTitle)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.aiConsentBody,
              style: const TextStyle(fontSize: 15),
            ),
            const SizedBox(height: 12),
            _ConsentBullet(text: l10n.aiConsentBulletSend),
            _ConsentBullet(text: l10n.aiConsentBulletLocation),
            _ConsentBullet(text: l10n.aiConsentBulletWhere),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.aiConsentEnable),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  Future<void> _showHowItWorks(
    BuildContext context,
    AppLocalizations l10n,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.aiHowItWorks),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.aiHowItWorksRule),
              const SizedBox(height: 12),
              Text(l10n.aiHowItWorksBody),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l10n.gotIt),
          ),
        ],
      ),
    );
  }
}

/// One row in the AI-app picker.
class _AppOption extends StatelessWidget {
  const _AppOption({
    required this.label,
    required this.selected,
    required this.onTap,
    this.subtitle,
  });

  final String label;
  final String? subtitle;
  final bool selected;

  /// Null when the app cannot take a hand-off (not installed): the row is
  /// shown but disabled so the reason stays visible.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    // MergeSemantics + selected: without it the check icon is the only signal,
    // which a screen reader cannot see.
    return MergeSemantics(
      child: Semantics(
        selected: selected,
        inMutuallyExclusiveGroup: true,
        child: ListTile(
          enabled: onTap != null,
          onTap: onTap,
          leading: Icon(
            selected ? Icons.check_circle_rounded : Icons.circle_outlined,
            color: selected
                ? context.colors.primary
                : context.colors.onSurface.withValues(alpha: 0.35),
          ),
          title: Text(
            label,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
          subtitle: subtitle == null
              ? null
              : Text(subtitle!, style: const TextStyle(fontSize: 12.5)),
        ),
      ),
    );
  }
}

/// One "what leaves the device" line in the consent dialog.
class _ConsentBullet extends StatelessWidget {
  const _ConsentBullet({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '•  ',
            style: TextStyle(
              color: context.colors.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13.5,
                height: 1.4,
                color: context.colors.onSurface.withValues(alpha: 0.75),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
