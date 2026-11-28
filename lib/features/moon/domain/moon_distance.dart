/// One astronomical unit in kilometres (IAU definition).
const double kAstronomicalUnitKm = 149597870.7;

/// Conventional "Supermoon" cut-off: a full/new moon closer than ~360,000 km.
const double kSupermoonDistanceKm = 360000.0;

/// Beyond ~405,000 km the Moon is commonly called a "Micromoon".
const double kMicromoonDistanceKm = 405000.0;

/// Converts the FFI distance in AU to kilometres.
double moonDistanceKm(double distanceAu) => distanceAu * kAstronomicalUnitKm;

enum MoonDistanceKind { supermoon, normal, micromoon }

/// Distance-based label. This is a threshold label, not an orbital-extremum
/// claim: the Moon is near perigee at <360,000 km and near apogee at >405,000.
MoonDistanceKind classifyMoonDistance(double distanceKm) {
  if (distanceKm < kSupermoonDistanceKm) return MoonDistanceKind.supermoon;
  if (distanceKm > kMicromoonDistanceKm) return MoonDistanceKind.micromoon;
  return MoonDistanceKind.normal;
}
