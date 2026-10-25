import 'package:flutter/foundation.dart';

import 'planet_position.dart';

/// The Sun and Moon at one instant, calculated as a single batch.
///
/// Panchang work needs both longitudes (tithi, yoga, karana) and used to issue
/// two independent calls, each of which re-applied global Swiss Ephemeris
/// state. A paired result preserves each body's provenance while sharing one
/// state setup and one native error buffer.
@immutable
class SunMoonPositions {
  /// Creates a paired Sun/Moon result.
  const SunMoonPositions({
    required this.sun,
    required this.moon,
  });

  /// Sidereal (or tropical, per the request) Sun position.
  final PlanetPosition sun;

  /// Sidereal (or tropical, per the request) Moon position.
  final PlanetPosition moon;

  @override
  String toString() => 'SunMoonPositions(sun: $sun, moon: $moon)';
}
