import 'package:material_ui/material_ui.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/settings/widgets/region_settings.dart';
import '../l10n/app_localizations.dart';
import '../models/festival_filter.dart';
import '../models/festival_region.dart';
import '../core/feedback/app_haptics.dart';
import '../theme/app_metrics.dart';
import 'app_bottom_sheet.dart';
import 'app_buttons.dart';
import 'festival_filter_chip.dart';
import 'settings_widgets.dart';

/// Opens the category + region filter sheet for the all-festivals list.
///
/// Returns the chosen [FestivalFilterSelection], or `null` when the sheet is
/// dismissed without applying — the caller keeps its current filters in that
/// case. Choices are staged locally, so tapping chips does not disturb the
/// list behind the sheet.
Future<FestivalFilterSelection?> showFestivalFilterSheet(
  BuildContext context, {
  required FestivalFilterSelection initial,
}) {
  return AppBottomSheet.show<FestivalFilterSelection>(
    context,
    builder: (_) => _FestivalFilterSheet(initial: initial),
  );
}

class _FestivalFilterSheet extends ConsumerStatefulWidget {
  const _FestivalFilterSheet({required this.initial});

  final FestivalFilterSelection initial;

  @override
  ConsumerState<_FestivalFilterSheet> createState() =>
      _FestivalFilterSheetState();
}

class _FestivalFilterSheetState extends ConsumerState<_FestivalFilterSheet> {
  late FestivalCategoryFilter _category = widget.initial.category;
  late FestivalRegion _region = widget.initial.region;

  bool get _isActive =>
      _category != FestivalCategoryFilter.all || _region != FestivalRegion.all;

  void _haptic() {
    AppHaptics.tap(ref);
  }

  void _selectCategory(FestivalCategoryFilter category) {
    if (category == _category) return;
    _haptic();
    setState(() => _category = category);
  }

  void _selectRegion(FestivalRegion region) {
    if (region == _region) return;
    _haptic();
    setState(() => _region = region);
  }

  void _reset() {
    if (!_isActive) return;
    _haptic();
    setState(() {
      _category = FestivalCategoryFilter.all;
      _region = FestivalRegion.all;
    });
  }

  void _apply() {
    _haptic();
    Navigator.pop(
      context,
      FestivalFilterSelection(category: _category, region: _region),
    );
  }

  String _regionLabel(AppLocalizations? l10n, FestivalRegion region) {
    if (region == FestivalRegion.all) {
      return l10n?.festivalFilterAllRegions ?? 'All regions';
    }
    return festivalRegionLabel(l10n, region);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    Widget chip({
      required String label,
      required bool selected,
      required VoidCallback onTap,
    }) {
      return FestivalFilterChip(label: label, selected: selected, onTap: onTap);
    }

    final m3e = M3ETheme.of(context);
    return SingleChildScrollView(
      key: const Key('festival-filter-sheet'),
      primary: true,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.s20,
        AppSpacing.s12,
        AppSpacing.s20,
        AppSpacing.s24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n?.festivalFilterTitle ?? 'Filter festivals',
            textAlign: TextAlign.center,
            style: m3e.typeScale.headlineSmall.copyWith(
              color: m3e.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: AppSpacing.s6),
          Text(
            l10n?.festivalFilterSubtitle ??
                'Narrow the list by category and region',
            textAlign: TextAlign.center,
            style: m3e.typeScale.bodySmall.copyWith(
              color: m3e.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.s24),
          SettingsSectionHeader(l10n?.category ?? 'Category'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final filter in FestivalCategoryFilter.values)
                chip(
                  label: festivalCategoryFilterLabel(l10n, filter),
                  selected: _category == filter,
                  onTap: () => _selectCategory(filter),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.s24),
          SettingsSectionHeader(l10n?.festivalFilterRegion ?? 'Region'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final region in FestivalRegion.values)
                chip(
                  label: _regionLabel(l10n, region),
                  selected: _region == region,
                  onTap: () => _selectRegion(region),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.s28),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  style: M3EButtonStyle.text,
                  onPressed: _isActive ? _reset : null,
                  // _reset already buzzes through the shared haptic helper.
                  haptic: false,
                  child: Text(l10n?.reset ?? 'Reset'),
                ),
              ),
              const SizedBox(width: AppSpacing.s12),
              Expanded(
                child: AppButton(
                  onPressed: _apply,
                  // _apply already buzzes.
                  haptic: false,
                  child: Text(l10n?.done ?? 'Done'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
