import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../l10n/app_localizations.dart';
import '../../../providers/accessibility_provider.dart';
import '../../../widgets/settings_widgets.dart';

class AccessibilitySettings extends ConsumerWidget {
  const AccessibilitySettings({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final accessibility = ref.watch(accessibilityProvider);
    final notifier = ref.read(accessibilityProvider.notifier);

    return SettingsGroupCard(
      children: [
        SettingsSwitchTile(
          icon: Icons.motion_photos_off_outlined,
          title: l10n?.reduceMotion ?? 'Reduce Motion',
          subtitle: l10n?.disableAnimations ?? 'Disable animations & effects',
          value: accessibility.reduceMotion,
          onChanged: (v) async => notifier.toggleReduceMotion(v),
        ),
        const SettingsDivider(),
        if (!kIsWeb) ...[
          SettingsSwitchTile(
            icon: Icons.vibration_rounded,
            title: l10n?.hapticFeedback ?? 'Haptic Feedback',
            subtitle: l10n?.vibrateOnTouch ?? 'Vibrate on touch interactions',
            value: accessibility.hapticFeedback,
            onChanged: (v) async => notifier.toggleHapticFeedback(v),
          ),
          const SettingsDivider(),
        ],
        SettingsSwitchTile(
          icon: Icons.contrast_rounded,
          title: l10n?.highContrast ?? 'High Contrast',
          subtitle:
              l10n?.solidBackgrounds ??
              'Solid backgrounds for better readability',
          value: accessibility.highContrast,
          onChanged: (v) async => notifier.toggleHighContrast(v),
        ),
        const SettingsDivider(),
        SettingsSwitchTile(
          icon: Icons.text_fields_rounded,
          title: l10n?.largeText ?? 'Large Text',
          subtitle: l10n?.increaseTextSize ?? 'Increase text size globally',
          value: accessibility.largeText,
          onChanged: (v) async => notifier.toggleLargeText(v),
        ),
      ],
    );
  }
}
