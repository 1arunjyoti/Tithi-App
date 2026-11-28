// material_ui and material_3_expressive both export these shape helpers;
// keep the expressive ones (the package re-exports material_new_shapes).
import 'package:material_ui/material_ui.dart'
    hide CornerRounding, RoundedPolygon;
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/app_theme.dart';
import '../theme/app_metrics.dart';
import '../theme/app_typography.dart';
import '../core/feedback/app_haptics.dart';
import 'app_bottom_sheet.dart';
import 'app_card.dart';
import 'app_switch.dart';
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
          // Expressive switch: spring-driven handle (16 -> 24 -> 28 pressed),
          // 52x32 track, state layer + focus ring, drag-to-toggle. Colours
          // resolve from M3ETheme (adapted from the ambient Material theme by
          // default), so the active accent still tracks the app palette.
          // AppSwitch is the single gate for Reduce Motion: M3E's spring
          // ignores MediaQuery.disableAnimations.
          AppSwitch(
            value: value,
            onChanged: isLoading
                ? null
                : (val) {
                    AppHaptics.tap(ref);
                    // The tile's callback owns its own async work/errors;
                    // M3ESwitch takes a void ValueChanged.
                    onChanged?.call(val);
                  },
            selectedIcon: const Icon(M3EIcons.check),
          ),
          if (isLoading) ...[
            const SizedBox(width: AppSpacing.s8),
            // The spinner ticks every frame. Without its own boundary the
            // repaint climbs to SettingsGroupCard's RepaintBoundary and
            // re-rasterizes the entire card (5 rows here), stuttering scroll
            // while a one-shot provider such as location init is pending.
            const RepaintBoundary(child: InlineSpinner()),
          ],
        ],
      ),
    );
  }
}

/// One choice in a settings picker sheet.
@immutable
class SettingsPickerOption {
  const SettingsPickerOption({
    required this.title,
    this.subtitle,
    required this.onSelected,
  });

  final String title;
  final String? subtitle;
  final VoidCallback onSelected;
}

/// Reusable bottom sheet container for settings pickers.
///
/// The chrome (28dp corners, drag handle, 640dp max width, scrim, spring
/// entrance and detents) comes from [M3EBottomSheet]. The choices live in an
/// [M3EList], which owns the segmented card surfaces and the spec gap between
/// them - the parent, not each row, paints the rest fill. [M3EList] also routes
/// taps by index and provides keyboard group navigation, so callers pass data
/// plus callbacks instead of prebuilt widgets with their own `onTap`.
class SettingsBottomSheet extends StatefulWidget {
  const SettingsBottomSheet({
    super.key,
    required this.title,
    this.subtitle,
    required this.options,
    this.selectedIndex,
    this.footer,
  });

  final String title;
  final String? subtitle;
  final List<SettingsPickerOption> options;
  final int? selectedIndex;

  /// Content below the choices, e.g. an explicit confirm button.
  final Widget? footer;

  @override
  State<SettingsBottomSheet> createState() => _SettingsBottomSheetState();

  /// Helper method to show the bottom sheet.
  static Future<void> show({
    required BuildContext context,
    required String title,
    String? subtitle,
    required List<SettingsPickerOption> options,
    int? selectedIndex,
    Widget? footer,
  }) {
    // Pickers carry all their choices at once (some with a trailing confirm
    // action), so the shared wrapper opens at the content-height detent.
    return AppBottomSheet.show<void>(
      context,
      builder: (_) => SettingsBottomSheet(
        title: title,
        subtitle: subtitle,
        options: options,
        selectedIndex: selectedIndex,
        footer: footer,
      ),
    );
  }
}

class _SettingsBottomSheetState extends State<SettingsBottomSheet> {
  // The parent M3EList paints the surfaces, so selection cannot live on the
  // embedded M3EListItem alone. `colorBuilder`/`borderRadiusBuilder` are the
  // list's documented per-index overrides. Do not turn on `selection`: once a
  // selection exists M3EList treats taps as selection toggles and drops the
  // picker's own onTap (its trigger is icon/double-tap, not single tap).
  late int? _selectedIndex = widget.selectedIndex;

  @override
  Widget build(BuildContext context) {
    final m3e = M3ETheme.of(context);
    final isLight = m3e.brightness == Brightness.light;
    // Light: the app's vermilion primary carries white selected text. The
    // default secondaryContainer is a pale lavender and white would vanish
    // on it. Dark: keep the spec container and its light on-container ink.
    final selectedFill = isLight
        ? m3e.colorScheme.primary
        : m3e.colorScheme.secondaryContainer;
    final itemTheme = m3e.listTheme.item;
    final sheetTheme = isLight
        ? m3e.copyWith(
            listTheme: m3e.listTheme.copyWith(
              item: itemTheme.copyWith(
                selectedContainerColor: selectedFill,
                selectedContentColor: m3e.colorScheme.onPrimary,
                selectedStateIconColor: m3e.colorScheme.onPrimary,
              ),
            ),
          )
        : m3e;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s24),
          child: Text(
            widget.title,
            textAlign: TextAlign.center,
            style: m3e.typeScale.headlineSmall.copyWith(
              color: m3e.colorScheme.onSurface,
            ),
          ),
        ),
        if (widget.subtitle != null) ...[
          const SizedBox(height: AppSpacing.s8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s24),
            child: Text(
              widget.subtitle!,
              textAlign: TextAlign.center,
              style: m3e.typeScale.bodySmall.copyWith(
                color: m3e.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.s16),
        // shrinkWrap keeps the sheet at content height; the list inherits the
        // sheet's PrimaryScrollController so scrolling grows the sheet first.
        Flexible(
          child: M3ETheme(
            data: sheetTheme,
            child: M3EList.scrollable(
              shrinkWrap: true,
              listPadding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.s8,
              ),
              itemCount: widget.options.length,
              colorBuilder: (index) =>
                  _selectedIndex == index ? selectedFill : null,
              borderRadiusBuilder: (index, _) => _selectedIndex == index
                  ? BorderRadius.circular(AppRadius.tile)
                  : null,
              onTap: (index) {
                setState(() => _selectedIndex = index);
                widget.options[index].onSelected();
              },
              itemBuilder: (context, index) {
                final option = widget.options[index];
                final selected = _selectedIndex == index;
                return M3EListItem(
                  headline: option.title,
                  supportingText: option.subtitle,
                  // The parent paints the fill via colorBuilder; this flag
                  // switches the row's text/icon tokens to the selected ones
                  // (white on light, from the scoped M3ETheme above).
                  selected: selected,
                  trailing: selected ? const Icon(M3EIcons.check) : null,
                );
              },
            ),
          ),
        ),
        if (widget.footer != null) ...[
          const SizedBox(height: AppSpacing.s16),
          widget.footer!,
        ],
        const SizedBox(height: AppSpacing.s16),
      ],
    );
  }
}
