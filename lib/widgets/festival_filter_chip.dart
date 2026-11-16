import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/festival_filter.dart';
import '../theme/app_theme.dart';
import '../theme/app_typography.dart';

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

/// One choice chip for the festival filters.
///
/// Used both inside the filter sheet and on the screen's inline category
/// strip; keeping one widget means the selected tint, hairline and label style
/// stay identical in the two places. Only the selection fill differs from a
/// plain `ChoiceChip`: a primary wash instead of a solid block, matching the
/// floating nav bar's selected destination.
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
    final colors = context.colors;
    final selectedFill = colors.primary.withValues(alpha: 0.16);
    final hairline = AppTheme.sheetHairline(
      context,
      highContrast: AppTheme.highContrastOf(context),
    );
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      onSelected: (_) => onTap(),
      // Set `color` instead of `selectedColor`. `RawChip` only takes the
      // `selectedColor` path for the *end* of the selection fade: the fill
      // it fades *from* is resolved through the chip's `color` (defaulting to
      // the Material 3 `colorScheme.secondaryContainer`, an opaque purple in
      // every palette here). Setting only `selectedColor` therefore animated
      // a solid block down to this wash on every tap - the "flash" seen in
      // both the strip and the sheet. Resolving `color` directly keeps both
      // ends of the fill inside the accent wash, so the chip switches without
      // an off-palette frame.
      color: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? selectedFill
            : Colors.transparent,
      ),
      side: BorderSide(
        color: selected ? colors.primary.withValues(alpha: 0.45) : hairline,
      ),
      labelStyle: TextStyle(
        fontSize: AppTypography.sizeDetail,
        fontWeight: AppTypography.semibold,
        color: selected
            ? colors.primary
            : colors.onSurface.withValues(alpha: 0.75),
      ),
      shape: const StadiumBorder(),
    );
  }
}
