import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_theme.dart';
import '../providers/accessibility_provider.dart';

class SettingsSectionHeader extends StatelessWidget {
  final String title;

  const SettingsSectionHeader(this.title, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 12),
      child: Text(
        title,
        style: context.textTheme.labelSmall?.copyWith(
          letterSpacing: 2,
          fontWeight: FontWeight.bold,
          color: context.colors.primary,
        ),
      ),
    );
  }
}

class SettingsGroupCard extends ConsumerWidget {
  final List<Widget> children;

  const SettingsGroupCard({super.key, required this.children});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Use cached config that only rebuilds on accessibility changes
    final config = ref.watch(glassmorphismConfigProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isPureDark = theme.scaffoldBackgroundColor == Colors.black;

    return Container(
      decoration: config.getDecoration(
        isDark: isDark,
        isPureDark: isPureDark,
        primaryColor: theme.primaryColor,
        opacity: 0.1,
        borderRadius: 24,
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: children),
    );
  }
}

class SettingsActionTile extends ConsumerWidget {
  final IconData icon;
  final String title;
  final Widget? trailing;
  final VoidCallback onTap;

  const SettingsActionTile({
    super.key,
    required this.icon,
    required this.title,
    required this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      onTap: () {
        if (ref.read(accessibilityProvider).hapticFeedback) {
          HapticFeedback.lightImpact();
        }
        onTap();
      },
      contentPadding: const EdgeInsets.all(16),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: context.colors.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: context.colors.primary, size: 22),
      ),
      title: Text(
        title,
        style: context.textTheme.bodyLarge?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (trailing != null) trailing!,
          const SizedBox(width: 8),
          Icon(
            Icons.chevron_right_rounded,
            color: context.colors.onSurface.withValues(alpha: 0.4),
          ),
        ],
      ),
    );
  }
}

class SettingsSwitchTile extends ConsumerWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const SettingsSwitchTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: context.colors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: context.colors.primary, size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: context.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  subtitle,
                  style: context.textTheme.labelSmall?.copyWith(
                    color: context.colors.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: (val) {
              if (ref.read(accessibilityProvider).hapticFeedback) {
                HapticFeedback.lightImpact();
              }
              onChanged(val);
            },
            activeThumbColor: context.colors.primary,
          ),
        ],
      ),
    );
  }
}

class SettingsDivider extends StatelessWidget {
  const SettingsDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      color: context.colors.onSurface.withValues(alpha: 0.1),
    );
  }
}

class ThemeOptionButton extends ConsumerWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const ThemeOptionButton({
    super.key,
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () {
        if (ref.read(accessibilityProvider).hapticFeedback) {
          HapticFeedback.selectionClick();
        }
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? context.colors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: context.colors.primary.withValues(alpha: 0.2),
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected
                  ? Colors.white
                  : context.colors.onSurface.withValues(alpha: 0.6),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: context.textTheme.labelSmall?.copyWith(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected
                    ? Colors.white
                    : context.colors.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Reusable bottom sheet container for settings pickers
class SettingsBottomSheet extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget> children;

  const SettingsBottomSheet({
    super.key,
    required this.title,
    this.subtitle,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 24),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: context.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: context.colors.onSurface,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  subtitle!,
                  textAlign: TextAlign.center,
                  style: context.textTheme.bodySmall?.copyWith(
                    color: context.colors.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            ...children,
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  /// Helper method to show the bottom sheet
  static Future<void> show({
    required BuildContext context,
    required String title,
    String? subtitle,
    required List<Widget> children,
  }) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => SettingsBottomSheet(
        title: title,
        subtitle: subtitle,
        children: children,
      ),
    );
  }
}

/// Reusable picker item for settings bottom sheets
class SettingsPickerItem extends StatelessWidget {
  final String title;
  final String? subtitle;
  final bool isSelected;
  final VoidCallback onTap;

  const SettingsPickerItem({
    super.key,
    required this.title,
    this.subtitle,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(
        title,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? context.colors.primary : context.colors.onSurface,
        ),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle!,
              style: context.textTheme.bodySmall?.copyWith(
                color: context.colors.onSurface.withValues(alpha: 0.6),
              ),
            )
          : null,
      trailing: isSelected
          ? Icon(Icons.check_circle_rounded, color: context.colors.primary)
          : null,
      onTap: onTap,
    );
  }
}
