import 'package:jyotish/jyotish.dart';

import '../../../models/panchang_school.dart';
import 'surya_siddhanta_engine.dart';

/// Sidereal ecliptic longitudes of the Sun and Moon, in degrees `[0, 360)`.
typedef SunMoonLongitudes = ({double sun, double moon});

/// Source of the sidereal Sun/Moon longitudes a Panchang is built from.
///
/// Everything downstream of this interface - tithi, nakshatra, yoga, karana,
/// sankranti, the Bengali calendar - is a function of these two numbers. That
/// is why the calculation school is expressed here and nowhere else.
///
/// Implementations return *sidereal* longitudes in a single consistent frame.
/// Mixing frames is a silent correctness bug: tithi is a difference (the
/// ayanamsa cancels) but yoga is a sum (it enters twice).
abstract class PanchangEphemeris {
  const PanchangEphemeris();

  /// School this implementation serves.
  PanchangSchool get school;

  /// Stable tag for cache keys and provenance records.
  String get tag;

  /// Longitudes at [instant].
  ///
  /// [latitude] and [longitude] are the observer position. The Drik path uses
  /// them for its topocentric/Swiss configuration; the Surya Siddhanta path is
  /// geocentric and ignores them, which is correct for the classical model.
  Future<SunMoonLongitudes> longitudesAt(
    DateTime instant, {
    required double latitude,
    required double longitude,
  });
}

/// Raised when a position read fails in a way the caller cannot paper over.
class PanchangEphemerisException implements Exception {
  PanchangEphemerisException(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() => 'PanchangEphemerisException: $message'
      '${cause == null ? '' : ' ($cause)'}';
}

/// Drik Ganita via the native Swiss Ephemeris binding, reduced with Lahiri.
///
/// This is the shipped default and must stay behaviour-identical to the
/// pre-school code path: same call, same flags, same location handling.
class DrikPanchangEphemeris extends PanchangEphemeris {
  const DrikPanchangEphemeris();

  @override
  PanchangSchool get school => PanchangSchool.bisuddha;

  @override
  String get tag => 'drik-lahiri';

  @override
  Future<SunMoonLongitudes> longitudesAt(
    DateTime instant, {
    required double latitude,
    required double longitude,
  }) async {
    final positions = await Jyotish().getSunMoonPositions(
      dateTime: instant,
      location: GeographicLocation(latitude: latitude, longitude: longitude),
    );
    return (
      sun: positions.sun.longitude,
      moon: positions.moon.longitude,
    );
  }
}

/// Traditional Surya Siddhanta mean-motion theory, computed in pure Dart.
///
/// Needs no ephemeris files and no FFI. Positions are geocentric sidereal
/// longitudes, so the observer position is ignored.
class SuryaSiddhantaEphemeris extends PanchangEphemeris {
  const SuryaSiddhantaEphemeris({
    this.engine = const SuryaSiddhantaEngine(),
  });

  final SuryaSiddhantaEngine engine;

  @override
  PanchangSchool get school => PanchangSchool.suryasiddhanta;

  @override
  String get tag => engine.tuning.tag;

  @override
  Future<SunMoonLongitudes> longitudesAt(
    DateTime instant, {
    required double latitude,
    required double longitude,
  }) async {
    // Synchronous math, but the interface is async so callers can await one
    // shape regardless of school.
    return engine.longitudesAt(instant);
  }
}

/// Returns the ephemeris for [school].
///
/// [tuning] only applies to [PanchangSchool.suryasiddhanta]; the Drik path
/// ignores it because its frame is the Swiss Ephemeris Lahiri mode.
PanchangEphemeris ephemerisFor(
  PanchangSchool school, {
  SuryaSiddhantaTuning tuning = kSuryaSiddhantaTuning,
}) {
  return switch (school) {
    PanchangSchool.bisuddha => const DrikPanchangEphemeris(),
    PanchangSchool.suryasiddhanta => SuryaSiddhantaEphemeris(
      engine: SuryaSiddhantaEngine(tuning: tuning),
    ),
  };
}
