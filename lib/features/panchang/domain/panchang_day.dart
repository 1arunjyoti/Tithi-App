import '../../../models/hindu_month_system.dart';
import '../../../models/panchang_data.dart';

// Phase 2: the canonical Panchang day.
//
// One immutable value object for the astronomical and calendar facts of one
// civil day at one place. It deliberately carries no UI labels, no festival
// list, and no cache handles: those are projections (`PanchangData` today),
// so the day can be computed once and rendered, scheduled, exported, or
// searched without four copies of the assembly logic drifting apart.
//
// Nullable solar anchors are the point of this type. `SolarEventsService`
// throws `SolarEventUnavailable` when the Sun does not rise or set, which is
// correct at the astronomy layer but must not escape into a day: a polar day
// is a day with a missing event, not a failed computation.

/// Engine identifier recorded in [PanchangProvenance].
///
/// Bump this whenever a change can move a boundary result; the golden
/// fixtures and every cache keyed by it must be recaptured in the same
/// commit.
const String kPanchangEngineVersion = 'panchang-v2';

/// Ayanamsa the engine computes sidereal positions in.
const String kPanchangAyanamsa = 'lahiri';

/// Place a day was computed for.
///
/// Carried explicitly rather than read from a global so one process can hold
/// days for several places at once - the notification scheduler, the month
/// grid, and an open detail sheet do exactly that.
class PanchangPlace {
  const PanchangPlace({
    required this.latitude,
    required this.longitude,
    this.timezoneId,
    this.altitudeMeters = 0,
    this.label,
  });

  final double latitude;
  final double longitude;

  /// IANA zone of the place. Null means "resolve civil time in the device
  /// zone"; only acceptable before the location layer has published a zone.
  final String? timezoneId;

  /// Observer altitude. Required for topocentric lunar events.
  final double altitudeMeters;

  /// Human label for provenance and debugging only; never used in matching.
  final String? label;
}

/// Why the tithi of a day was sampled where it was.
///
/// Ordinary days sample at sunrise. A polar day has no sunrise, so the day
/// still needs a documented sample point instead of silently reusing the
/// previous day's value.
enum PanchangTithiSample { sunrise, civilNoon }

/// Solar and lunar anchors of one civil day.
///
/// Every field is nullable: at polar latitudes the Sun may not rise or set,
/// and the Moon may not rise or set on a given civil day. Null is the explicit
/// "does not occur" signal - callers skip or label the event, and never
/// substitute 06:00/18:00.
class PanchangSolarDay {
  const PanchangSolarDay({
    this.sunrise,
    this.sunset,
    this.nextSunrise,
    this.moonrise,
    this.moonset,
  });

  final DateTime? sunrise;
  final DateTime? sunset;
  final DateTime? nextSunrise;
  final DateTime? moonrise;
  final DateTime? moonset;

  /// The Sun does not rise on this civil day (polar night).
  bool get hasPolarNight => sunrise == null;

  /// The Sun does not set on this civil day (polar day).
  bool get hasPolarDay => sunset == null;

  /// At least one solar anchor is missing, so solar-derived spans and
  /// checkpoints cannot be produced.
  bool get lacksSolarAnchors =>
      sunrise == null || sunset == null || nextSunrise == null;

  /// Sunrise-to-sunset span, or null when either anchor is missing.
  Duration? get dayLength {
    final rise = sunrise;
    final set = sunset;
    if (rise == null || set == null) return null;
    return set.difference(rise);
  }

  /// Sunset-to-next-sunrise span, or null when either anchor is missing.
  Duration? get nightLength {
    final set = sunset;
    final next = nextSunrise;
    if (set == null || next == null) return null;
    return next.difference(set);
  }
}

/// The tithi that owns the day, plus the daytime transition out of it.
class PanchangTithiDay {
  const PanchangTithiDay({
    required this.rawAtSample,
    required this.sample,
    required this.sampledAt,
    this.transitionAt,
    this.transitionIndex,
  });

  /// Raw tithi (1.0-30.99) sampled at [sampledAt]; the integer part is the
  /// 1-30 index.
  final double rawAtSample;

  final PanchangTithiSample sample;
  final DateTime sampledAt;

  /// First tithi boundary after the sample, when it falls before the next
  /// sunrise. Null on a day with no daytime transition, and on a day whose
  /// solar anchors are missing (no window to search).
  final DateTime? transitionAt;
  final int? transitionIndex;

  /// 1-30 tithi index at the sample point.
  int get index => rawAtSample.floor().clamp(1, 30);

  String get paksha => index <= 15 ? 'Shukla' : 'Krishna';

  /// 1-15 number within [paksha].
  int get number => index <= 15 ? index : index - 15;

  String get name => PanchangData.tithiNameFor(number, paksha);

  /// Whether the day shows two tithis ("Ashtami -> Navami").
  bool get hasTransition =>
      transitionAt != null &&
      transitionIndex != null &&
      transitionIndex! >= 1 &&
      transitionIndex! <= 30 &&
      transitionIndex != index;
}

/// Nakshatra, yoga, and karana prevailing at the day's tithi sample point.
///
/// Each is nullable because the ephemeris read can fail independently of the
/// tithi read; one missing limb hides one row instead of failing the day.
class PanchangLimbDay {
  const PanchangLimbDay({this.nakshatra, this.yoga, this.karana});

  final String? nakshatra;
  final String? yoga;
  final String? karana;
}

/// Amanta masa and Adhika verdict for the lunation containing the day.
class PanchangMasaDay {
  const PanchangMasaDay({required this.amanta, required this.adhika});

  /// Plain Amanta month name (e.g. `Shravana`), never prefixed.
  final String amanta;

  /// True when this lunation has no solar Sankranti.
  final bool adhika;

  /// Value festival rules match against: Adhika months are prefixed so
  /// ordinary festivals do not match them.
  String get amantaForMatching => adhika ? 'Adhika_$amanta' : amanta;

  /// Masa under a display system. Purnimanta shifts Krishna-paksha months;
  /// Adhika names pass through unchanged.
  String displayName(HinduMonthSystem system, {required String paksha}) =>
      displayMasaName(amanta, paksha, system);
}

/// Raw tithi values sampled at the solar-anchored checkpoints.
///
/// Festival rules match against these (a Madhyahna rule samples the tithi at
/// midday, a Nishita rule at the night midpoint). Each is null when its
/// checkpoint instant does not exist, so a polar day cannot silently match a
/// timing rule it never reached.
class PanchangCheckpointTithis {
  const PanchangCheckpointTithis({
    this.madhyahna,
    this.aparahna,
    this.nishita,
    this.pradosha,
    this.nextSunrise,
    this.dominant,
  });

  final double? madhyahna;
  final double? aparahna;
  final double? nishita;
  final double? pradosha;
  final double? nextSunrise;
  final double? dominant;
}

/// Solar-anchored checkpoint instants used by festival timing overrides.
///
/// Each is null when the anchors it needs are missing, so a polar day can
/// still answer "which tithi is this" without inventing a Nishita window.
class PanchangCheckpoints {
  const PanchangCheckpoints({
    this.madhyahna,
    this.aparahna,
    this.nishita,
    this.pradosha,
    this.dominant,
  });

  final DateTime? madhyahna;
  final DateTime? aparahna;
  final DateTime? nishita;
  final DateTime? pradosha;
  final DateTime? dominant;

  /// True when no solar-anchored checkpoint could be derived.
  bool get isEmpty =>
      madhyahna == null &&
      aparahna == null &&
      nishita == null &&
      pradosha == null &&
      dominant == null;
}

/// How a day was computed, so a cache can be invalidated and a UI can state
/// its method.
class PanchangProvenance {
  const PanchangProvenance({
    required this.engineVersion,
    required this.ayanamsa,
    required this.sunriseConvention,
    required this.ephemeris,
    required this.computedAt,
  });

  final String engineVersion;
  final String ayanamsa;

  /// Solar event convention actually used (`hindu` for the native
  /// `SE_BIT_HINDU_RISING` path).
  final String sunriseConvention;

  /// `swiss` when the native calculator served the day, `noaa` when the
  /// labelled fallback did.
  final String ephemeris;

  final DateTime computedAt;

  /// Stable string for cache keys: two days with the same key are computed by
  /// the same method and can be compared.
  String get cacheKey =>
      '$engineVersion|$ayanamsa|$sunriseConvention|$ephemeris';
}

/// Canonical facts for one Panchang civil day at one place.
class PanchangDay {
  const PanchangDay({
    required this.date,
    required this.place,
    required this.solar,
    required this.tithi,
    required this.limbs,
    required this.masa,
    required this.checkpoints,
    required this.checkpointTithis,
    required this.provenance,
  });

  /// Civil date (midnight in the place zone) the day describes.
  final DateTime date;
  final PanchangPlace place;
  final PanchangSolarDay solar;
  final PanchangTithiDay tithi;
  final PanchangLimbDay limbs;
  final PanchangMasaDay masa;
  final PanchangCheckpoints checkpoints;

  /// Raw tithi at each checkpoint, for festival timing rules.
  final PanchangCheckpointTithis checkpointTithis;

  final PanchangProvenance provenance;

  /// The day has no usable solar anchor, so solar-anchored UI must be
  /// labelled or skipped.
  bool get isPolar => solar.lacksSolarAnchors;

  /// Convenience accessor used by the `PanchangData` projection.
  double get rawTithi => tithi.rawAtSample;

  /// Convenience accessor used by the `PanchangData` projection.
  String? get nakshatra => limbs.nakshatra;
}
