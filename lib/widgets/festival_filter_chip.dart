import 'package:material_ui/material_ui.dart';
import 'package:material_3_expressive/material_3_expressive.dart';

import '../l10n/app_localizations.dart';
import '../models/festival_filter.dart';

/// Localized label for a category filter, shared by the filter sheet and the
/// inline chip strip under the all-festivals search field so the two entry
/// points cannot name the same option differently.
String festivalCategoryFilterLabel(
  AppLocalizations? l10n,
  FestivalCategoryFilter filter,
) {
  return switch (filter) {
    FestivalCategoryFilter.all => l10n?.festivalFilterAll ?? 'All',
    FestivalCategoryFilter.major => l10n?.festivalFilterMajor ?? 'Major',
    FestivalCategoryFilter.vrat => l10n?.festivalFilterVrat ?? 'Vrat',
    FestivalCategoryFilter.recurring =>
      l10n?.festivalFilterRecurring ?? 'Recurring',
    FestivalCategoryFilter.featured =>
      l10n?.festivalFilterFeatured ?? 'Featured',
  };
}

/// One filter chip for the festival filters.
///
/// Used both inside the filter sheet and on the screen's inline category
/// strip; keeping one widget means the expressive filter treatment stays
/// identical in the two places.
class FestivalFilterChip extends StatelessWidget {
  const FestivalFilterChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return M3EChip(
      label: label,
      type: M3EChipType.filter,
      selected: selected,
      onPressed: onTap,
    );
  }
}
