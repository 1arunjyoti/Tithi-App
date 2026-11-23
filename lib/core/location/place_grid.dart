// Place identity shared by the panchang caches and the "is this still the same
// place?" check that decides whether a fresh GPS fix may restart the day
// computation.
//
// One definition, because the two must agree: if a fix is considered the same
// place, the cached day records it would reuse must have the same identity.

/// Grid used to decide that two fixes describe the same place.
///
/// 2 decimals ≈ 1.1 km. Ordinary GPS jitter between launches stays inside one
/// cell, so a stationary device keeps its cached panchang; an actual move of a
/// kilometre or more lands in a new cell and invalidates it.
const int kPlaceGridDecimals = 2;

/// Stable string for the grid cell containing ([latitude], [longitude]).
String placeGridKey(double latitude, double longitude) =>
    '${latitude.toStringAsFixed(kPlaceGridDecimals)}'
    '_${longitude.toStringAsFixed(kPlaceGridDecimals)}';

/// True when both fixes fall in the same [placeGridKey] cell.
bool samePlaceGrid({
  required double latitudeA,
  required double longitudeA,
  required double latitudeB,
  required double longitudeB,
}) =>
    placeGridKey(latitudeA, longitudeA) == placeGridKey(latitudeB, longitudeB);
