import 'festival.dart';
import 'festival_region.dart';

/// Category filter options on the all-festivals screen. [all] filters nothing.
enum FestivalCategoryFilter { all, major, vrat, recurring }

/// Whether [festival] belongs under [filter].
///
/// `vrat` mirrors the app-wide vrat definition (`category == 'vrat'` OR
/// `recurring`), so monthly observances such as Ekadashi/Purnima appear in
/// both the vrat and recurring views. `recurring` is the narrower "repeats
/// every lunar month" view.
bool festivalMatchesCategoryFilter(
  Festival festival,
  FestivalCategoryFilter filter,
) {
  return switch (filter) {
    FestivalCategoryFilter.all => true,
    FestivalCategoryFilter.major => festival.category == 'major',
    FestivalCategoryFilter.vrat =>
      festival.category == 'vrat' || festival.recurring,
    FestivalCategoryFilter.recurring => festival.recurring,
  };
}

/// Whether [festival] is observed in [region].
///
/// [FestivalRegion.all] means "all regions" (no narrowing). A specific zone
/// keeps pan-India festivals (`regions` contains `all`, which is exclusive and
/// therefore means observed nationwide) plus festivals tagged with that zone,
/// and hides festivals rooted only in other zones.
bool festivalMatchesRegionFilter(Festival festival, FestivalRegion region) {
  if (region == FestivalRegion.all) return true;
  return festival.regions.contains('all') ||
      festival.regions.contains(region.tag);
}

/// Active category + region narrowing for the all-festivals list.
///
/// The default value filters nothing, so the screen behaves exactly as before
/// until the user opts in. Both dimensions compose: a festival must match the
/// category **and** the region.
class FestivalFilterSelection {
  const FestivalFilterSelection({
    this.category = FestivalCategoryFilter.all,
    this.region = FestivalRegion.all,
  });

  final FestivalCategoryFilter category;
  final FestivalRegion region;

  bool get isActive =>
      category != FestivalCategoryFilter.all || region != FestivalRegion.all;

  FestivalFilterSelection copyWith({
    FestivalCategoryFilter? category,
    FestivalRegion? region,
  }) {
    return FestivalFilterSelection(
      category: category ?? this.category,
      region: region ?? this.region,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FestivalFilterSelection &&
          other.category == category &&
          other.region == region;

  @override
  int get hashCode => Object.hash(category, region);
}

/// Whether [festival] passes both dimensions of [filters].
bool festivalMatchesFilters(
  Festival festival,
  FestivalFilterSelection filters,
) {
  return festivalMatchesCategoryFilter(festival, filters.category) &&
      festivalMatchesRegionFilter(festival, filters.region);
}
