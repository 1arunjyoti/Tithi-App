import 'package:timezone/timezone.dart' as tz;

import 'location_defaults.dart';
import 'timezone_resolver.dart';

/// Which clock the app runs on for civil days and reminder wall times.
///
/// Product rule:
/// - live location (auto) -> the device clock: the user is where the panchang
///   is, so the phone's own clock is the least surprising one;
/// - a place picked on the map (manual) -> that place's clock;
/// - neither -> the default place's clock (Delhi), matching the panchang the
///   app is already showing.
///
/// The zone itself is still resolved from the coordinates (see
/// [resolvePlaceTimezone]); this type only decides *which* clock the day label
/// and reminder times use.
enum PlaceClockMode { device, place }

/// A resolved clock. [zoneId] is the IANA zone to render in; null means the
/// device zone (and no lookup at all).
typedef PlaceClock = ({PlaceClockMode mode, String? zoneId});

/// Device-clock value, used as the default in schedulers and tests.
const PlaceClock kDeviceClock = (mode: PlaceClockMode.device, zoneId: null);

/// Derives the clock from how the place was chosen.
///
/// [locationEnabled] is the "use current location" switch; [homeTimezoneId] is
/// the zone persisted for a place picked on the map. A manual pick turns that
/// switch off (see `LocationService.setHomeLocation`), so this derivation has
/// one unambiguous answer at any time.
PlaceClock resolvePlaceClock({
  required bool locationEnabled,
  String? homeTimezoneId,
}) {
  if (locationEnabled) return kDeviceClock;
  final home = canonicalTimezoneId(homeTimezoneId ?? '');
  return (
    mode: PlaceClockMode.place,
    zoneId: home.isEmpty ? kDefaultTimezoneId : home,
  );
}

/// tz location for [clock], or null when the device zone applies.
///
/// Unknown identifiers fall back to null (device zone) instead of throwing:
/// an identifier can disappear from tzdata between releases.
tz.Location? placeClockLocation(PlaceClock clock) {
  final id = clock.zoneId;
  if (id == null) return null;
  try {
    return tz.getLocation(id);
  } catch (_) {
    return null;
  }
}

/// Wall-clock "now" in [clock].
///
/// The returned instant is the same as `DateTime.now()`; only the wall fields
/// differ. Callers that compare instants (countdowns, `isBefore`) are
/// unaffected; callers that read `.year/.month/.day` get the clock's day.
DateTime nowInPlaceClock(PlaceClock clock) {
  final location = placeClockLocation(clock);
  return location == null ? DateTime.now() : tz.TZDateTime.now(location);
}

/// The next civil midnight in [clock], as an absolute instant.
///
/// Build the timer delay with `nextMidnightInPlaceClock(c).difference(nowInPlaceClock(c))`;
/// both are absolute, so a DST-shifted midnight stays correct.
DateTime nextMidnightInPlaceClock(PlaceClock clock) {
  final now = nowInPlaceClock(clock);
  final location = placeClockLocation(clock);
  if (location == null) return DateTime(now.year, now.month, now.day + 1);
  return tz.TZDateTime(location, now.year, now.month, now.day + 1);
}

/// Civil date of [instant] in [clock], as a zone-free [DateTime].
DateTime civilDateInPlaceClock(PlaceClock clock, DateTime instant) {
  final location = placeClockLocation(clock);
  if (location == null) {
    return DateTime(instant.year, instant.month, instant.day);
  }
  final wall = tz.TZDateTime.from(instant, location);
  return DateTime(wall.year, wall.month, wall.day);
}

/// Zone abbreviation to show beside the place name ("IST"), or null when the
/// clock is the device's own zone (nothing to disambiguate).
String? placeClockZoneLabel(PlaceClock clock) {
  final location = placeClockLocation(clock);
  if (location == null || location.name == tz.local.name) return null;
  final name = tz.TZDateTime.now(location).timeZoneName.trim();
  if (name.isEmpty || name == location.name) return null;
  return name;
}
