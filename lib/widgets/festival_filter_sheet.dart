import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/settings/widgets/region_settings.dart';
import '../l10n/app_localizations.dart';
import '../models/festival_filter.dart';
import '../models/festival_region.dart';
import '../providers/accessibility_provider.dart';
import '../theme/app_theme.dart';
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
  return showModalBottomSheet<FestivalFilterSelection>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    sheetAnimationStyle: AppTheme.sheetAnimationStyleOf(context),
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
    if (ref.read(accessibilityProvider).hapticFeedback) {
      HapticFeedback.lightImpact();
    }
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

  String _categoryLabel(AppLocalizations? l10n, FestivalCategoryFilter filter) {
    return switch (filter) {
      FestivalCategoryFilter.all => l10n?.festivalFilterAll ?? 'All',
      FestivalCategoryFilter.major => l10n?.festivalFilterMajor ?? 'Major',
      FestivalCategoryFilter.vrat => l10n?.festivalFilterVrat ?? 'Vrat',
      FestivalCategoryFilter.recurring =>
        l10n?.festivalFilterRecurring ?? 'Recurring',
    };
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
    final highContrast = ref.watch(accessibilityProvider).highContrast;
    final hairline = AppTheme.sheetHairline(
      context,
      highContrast: highContrast,
    );

    Widget chip({
      required String label,
      required bool selected,
      required VoidCallback onTap,
    }) {
      return ChoiceChip(
        label: Text(label),
        selected: selected,
        showCheckmark: false,
        onSelected: (_) => onTap(),
        selectedColor: context.colors.primary.withValues(alpha: 0.16),
        backgroundColor: Colors.transparent,
        side: BorderSide(
          color: selected
              ? context.colors.primary.withValues(alpha: 0.45)
              : hairline,
        ),
        labelStyle: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: selected
              ? context.colors.primary
              : context.colors.onSurface.withValues(alpha: 0.75),
        ),
        shape: const StadiumBorder(),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.85,
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: context.colors.onSurface.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                l10n?.festivalFilterTitle ?? 'Filter festivals',
                textAlign: TextAlign.center,
                style: context.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: context.colors.onSurface,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                l10n?.festivalFilterSubtitle ??
                    'Narrow the list by category and region',
                textAlign: TextAlign.center,
                style: context.textTheme.bodySmall?.copyWith(
                  color: context.colors.onSurface.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 24),
              SettingsSectionHeader(l10n?.category ?? 'Category'),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final filter in FestivalCategoryFilter.values)
                    chip(
                      label: _categoryLabel(l10n, filter),
                      selected: _category == filter,
                      onTap: () => _selectCategory(filter),
                    ),
                ],
              ),
              const SizedBox(height: 24),
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
              const SizedBox(height: 28),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: _isActive ? _reset : null,
                      child: Text(l10n?.reset ?? 'Reset'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: _apply,
                      child: Text(l10n?.done ?? 'Done'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
