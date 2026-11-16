import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_theme.dart';
import '../theme/app_metrics.dart';
import '../theme/app_typography.dart';
import '../theme/app_motion.dart';
import '../core/feedback/app_haptics.dart';
import 'app_card.dart';
import 'skeleton.dart';

class SettingsSectionHeader extends StatelessWidget {
  final String title;

  const SettingsSectionHeader(this.title, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        left: AppSpacing.s8,
        bottom: AppSpacing.s12,
      ),
      child: Text(
        title,
        style: context.textTheme.labelSmall?.copyWith(
          letterSpacing: 2,
          fontWeight: AppTypography.bold,
          color: context.colors.primary,
        ),
      ),
    );
  }
}

class SettingsGroupCard extends StatelessWidget {
  final List<Widget> children;

  const SettingsGroupCard({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    // RepaintBoundary: the glass shadow (blur 20) would otherwise repaint
    // on every scroll frame and flicker on the GPU thread. Isolated here
    // it caches as a display list and just translates while scrolling.
    return RepaintBoundary(
      // The group card owns no padding: each tile brings its own, so the
      // row dividers can run edge to edge like the home cards.
      //
      // Clip to the card shape: the rows are Material InkWell/ListTile lifts
      // whose hover wash is a square, so without the clip it paints past the
      // rounded corners. The RepaintBoundary above keeps the clip cheap.
      child: AppCard(
        padding: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        child: Column(mainAxisSize: MainAxisSize.min, children: children),
      ),
    );
  }
}

class SettingsActionTile extends ConsumerWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  const SettingsActionTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    required this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Material(
      color: Colors.transparent,
      child: ListTile(
        enabled: onTap != null,
        onTap: onTap == null
            ? null
            : () {
                AppHaptics.tap(ref);
                onTap!.call();
              },
        contentPadding: const EdgeInsets.all(AppSpacing.s16),
        leading: Container(
          padding: const EdgeInsets.all(AppSpacing.s10),
          decoration: BoxDecoration(
            color: context.colors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AppRadius.dense),
          ),
          child: Icon(
            icon,
            color: context.colors.primary,
            size: AppIconSize.large,
          ),
        ),
        title: Text(
          title,
          style: context.textTheme.bodyLarge?.copyWith(
            fontWeight: AppTypography.semibold,
          ),
        ),
        subtitle: subtitle == null
            ? null
            : Text(
                subtitle!,
                style: context.textTheme.labelSmall?.copyWith(
                  color: context.secondaryInk,
                ),
              ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // build_runner's analyzer predates null-aware elements
            // (hive_generator pins analyzer <7): keep the collection-if.
            // ignore: use_null_aware_elements
            if (trailing != null) trailing!,
            const SizedBox(width: AppSpacing.s8),
            Icon(Icons.chevron_right_rounded, color: context.hintInk),
          ],
        ),
      ),
    );
  }
}

class SettingsSwitchTile extends ConsumerWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final Future<void> Function(bool)? onChanged;
  final bool isLoading;

  const SettingsSwitchTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.s16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.s10),
            decoration: BoxDecoration(
              color: context.colors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppRadius.dense),
            ),
            child: Icon(
              icon,
              color: context.colors.primary,
              size: AppIconSize.large,
            ),
          ),
          const SizedBox(width: AppSpacing.s16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: context.textTheme.bodyLarge?.copyWith(
                    fontWeight: AppTypography.semibold,
                  ),
                ),
                Text(
                  subtitle,
                  style: context.textTheme.labelSmall?.copyWith(
                    color: context.secondaryInk,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: isLoading
                ? null
                : (val) {
                    AppHaptics.tap(ref);
                    onChanged?.call(val);
                  },
            activeThumbColor: context.colors.primary,
          ),
          if (isLoading) ...[
            const SizedBox(width: AppSpacing.s8),
            const InlineSpinner(),
          ],
        ],
      ),
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
        AppHaptics.tap(ref);
        onTap();
      },
      child: AnimatedContainer(
        duration: AppMotion.of(context, AppMotion.standard),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s20,
          vertical: AppSpacing.s12,
        ),
        decoration: BoxDecoration(
          color: isSelected ? context.colors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.tile),
          border: Border.all(
            color: context.colors.primary.withValues(alpha: 0.2),
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected
                  ? context.colors.onPrimary
                  : context.secondaryInk,
            ),
            const SizedBox(height: AppSpacing.s4),
            Text(
              label,
              style: context.textTheme.labelSmall?.copyWith(
                fontWeight: isSelected
                    ? AppTypography.bold
                    : AppTypography.regular,
                color: isSelected
                    ? context.colors.onPrimary
                    : context.secondaryInk,
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
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppRadius.card),
        ),
      ),
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.s24),
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
                fontWeight: AppTypography.bold,
                color: context.colors.onSurface,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: AppSpacing.s8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s24),
                child: Text(
                  subtitle!,
                  textAlign: TextAlign.center,
                  style: context.textTheme.bodySmall?.copyWith(
                    color: context.secondaryInk,
                  ),
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.s16),
            ...children,
            const SizedBox(height: AppSpacing.s16),
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
      sheetAnimationStyle: AppTheme.sheetAnimationStyleOf(context),
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
    return Material(
      color: Colors.transparent,
      child: ListTile(
        title: Text(
          title,
          style: TextStyle(
            fontWeight: isSelected ? AppTypography.bold : AppTypography.regular,
            color: isSelected
                ? context.colors.primary
                : context.colors.onSurface,
          ),
        ),
        subtitle: subtitle != null
            ? Text(
                subtitle!,
                style: context.textTheme.bodySmall?.copyWith(
                  color: context.secondaryInk,
                ),
              )
            : null,
        trailing: isSelected
            ? Icon(Icons.check_circle_rounded, color: context.colors.primary)
            : null,
        onTap: onTap,
      ),
    );
  }
}
