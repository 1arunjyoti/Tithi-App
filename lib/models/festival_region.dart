import 'festival.dart';

/// User-selectable festival region.
///
/// Drives same-day display ordering only: when several festivals fall on one
/// day, festivals rooted in the selected region sort above pan-India ones,
/// which sort above festivals rooted in other regions. Stored by index in the
/// settings box, so **append new values at the end** — reordering or removing
/// an entry would silently remap existing user preferences.
enum FestivalRegion { all, north, south, east, west, central, northeast }

/// Settings-box key for the stored [FestivalRegion] index.
///
/// Shared by the foreground notifier and the background notification
/// scheduler so the key cannot drift between them.
const String kFestivalRegionPrefKey = 'festival_region';

extension FestivalRegionExt on FestivalRegion {
  /// The matching `Festival.regions` tag.
  String get tag {
    switch (this) {
      case FestivalRegion.all:
        return 'all';
      case FestivalRegion.north:
        return 'north';
      case FestivalRegion.south:
        return 'south';
      case FestivalRegion.east:
        return 'east';
      case FestivalRegion.west:
        return 'west';
      case FestivalRegion.central:
        return 'central';
      case FestivalRegion.northeast:
        return 'northeast';
    }
  }
}

/// Parses the stored settings index into a [FestivalRegion].
///
/// Shared by the Riverpod notifier (foreground) and the notification
/// scheduler (background isolate, no Riverpod) so both read the same key.
FestivalRegion parseFestivalRegion(Object? raw) {
  final index = raw is int ? raw : (raw is num ? raw.toInt() : -1);
  if (index < 0 || index >= FestivalRegion.values.length) {
    return FestivalRegion.all;
  }
  return FestivalRegion.values[index];
}

/// Sort tier for [festival] under [region]:
///
/// - `0`: rooted in the selected region (rise to the top)
/// - `1`: pan-India (`regions: ['all']`)
/// - `2`: rooted in other regions (fall to the bottom)
///
/// [FestivalRegion.all] leaves every festival at tier 0.
int festivalRegionTier(Festival festival, FestivalRegion region) {
  if (region == FestivalRegion.all) return 0;
  final selected = region.tag;
  if (festival.regions.contains(selected)) return 0;
  if (festival.regions.contains('all')) return 1;
  return 2;
}

/// Returns [festivals] reordered for [region], preserving the incoming order
/// inside each tier.
///
/// The incoming list is already ordered by `displayPriority` (see
/// `PanchangData.fromRawTithi`), so an index tie-break keeps that ranking
/// intact while only lifting/lowering whole region tiers. [FestivalRegion.all]
/// is a no-op and returns the same list, i.e. current behaviour.
List<Festival> sortedFestivalsForRegion(
  List<Festival> festivals,
  FestivalRegion region,
) {
  if (region == FestivalRegion.all || festivals.length < 2) return festivals;

  final indexed = List.generate(
    festivals.length,
    (i) => (index: i, festival: festivals[i]),
    growable: false,
  );
  indexed.sort((a, b) {
    final byTier = festivalRegionTier(
      a.festival,
      region,
    ).compareTo(festivalRegionTier(b.festival, region));
    if (byTier != 0) return byTier;
    return a.index.compareTo(b.index);
  });
  return [for (final entry in indexed) entry.festival];
}

/// Region-aware [primaryFestival]: the headline pick after region ordering.
///
/// A festival rooted in [region] always outranks a pan-India one, even when
/// the latter carries a better `displayPriority` — region is the primary key.
/// Pan-India festivals likewise outrank festivals rooted in other regions,
/// so the headline always matches the first row of the ordered list. Inside
/// the winning tier the usual priority/major-first rule applies, and when
/// every festival is out-of-region the legacy pick is used unchanged.
Festival primaryFestivalForRegion(
  List<Festival> festivals,
  FestivalRegion region,
) {
  assert(festivals.isNotEmpty);
  if (region == FestivalRegion.all) return primaryFestival(festivals);

  // Best non-empty tier: selected region (0), then pan-India (1). Tier 2
  // needs no special case — `primaryFestival(festivals)` is exactly the
  // legacy behaviour when no better tier exists.
  for (final tier in const [0, 1]) {
    final group = festivals
        .where((festival) => festivalRegionTier(festival, region) == tier)
        .toList(growable: false);
    if (group.isNotEmpty) return primaryFestival(group);
  }
  return primaryFestival(festivals);
}
