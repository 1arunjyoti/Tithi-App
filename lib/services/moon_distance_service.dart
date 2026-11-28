import 'package:flutter/foundation.dart';
import 'package:jyotish/jyotish.dart';

import '../features/moon/domain/moon_distance.dart';

/// Moon distance at one instant, in kilometres.
class MoonDistanceInfo {
  const MoonDistanceInfo({required this.distanceKm, required this.kind});

  final double distanceKm;
  final MoonDistanceKind kind;
}

/// Reads the geocentric Earth-Moon distance from Swiss Ephemeris.
///
/// Geocentric and tropical on purpose: heliocentric would return the distance
/// to the Sun and topocentric would pull in the observer's position. The app's
/// ephemeris files are installed by `PanchangService.init`; callers must await
/// `panchangInitProvider` first. Failure is not fatal - the card is hidden.
class MoonDistanceService {
  MoonDistanceService({Jyotish? jyotish}) : _jyotish = jyotish ?? Jyotish();

  final Jyotish _jyotish;

  static final CalculationFlags _flags =
      CalculationFlags.astronomical(heliocentric: false).copyWith(
        useSwissEphemeris: true,
        useTopocentric: false,
        calculateSpeed: false,
        requireSwissEphemeris: true,
      );

  Future<MoonDistanceInfo?> distanceAt(DateTime instant) async {
    try {
      final position = await _jyotish.getPlanetPosition(
        planet: Planet.moon,
        dateTime: instant.toUtc(),
        // Ignored for a geocentric calculation; the constructor requires one.
        location: GeographicLocation(latitude: 0, longitude: 0),
        flags: _flags,
      );
      final km = moonDistanceKm(position.distance);
      if (!km.isFinite || km <= 0) return null;
      return MoonDistanceInfo(distanceKm: km, kind: classifyMoonDistance(km));
    } on JyotishException catch (error) {
      debugPrint('Moon distance unavailable: $error');
      return null;
    }
  }
}
