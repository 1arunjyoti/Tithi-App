import '../../../models/festival.dart';
import '../../../services/festival_matching_pipeline.dart';
import '../../../services/moonrise_calculator.dart';
import '../../../services/panchang_service.dart';
import '../../../services/solar_events_service.dart';
import 'panchang_day.dart';
import 'tithi_transitions.dart';

// Phase 2: the single computation pipeline for one Panchang day.
//
// Before this resolver the same day was assembled four times (provider
// path, notification scheduler, festival export, Hindu calendar service),
// each with its own sunrise handling and its own idea of which tithi a
// checkpoint samples. Every one of those call sites threw on a polar day,
// because `SolarEventsService` correctly rejects a missing sunrise and
// nobody caught it.
//
// The resolver's job is narrow: turn a place and a civil date into
// [PanchangDay]. It does not decide festivals, does not render, and does not
// touch Hive - callers keep their caches until they are migrated onto this
// type.

/// Reads the raw tithi at [instant].
///
/// [samplePoint] names the checkpoint the value is for (`''` for the day's
/// own sample, then `madhyahna`, `aparahna`, `nishita`, `pradosha`,
/// `nextSunrise`, `dominant`). Callers that cache key by that name; a sampler
/// must not cache instants whose sample point is empty unless the instant is
/// the day's sample point, because the cache key has no time component.
typedef PanchangTithiSampler =
    Future<double> Function(DateTime instant, String samplePoint);

/// Computes [PanchangDay] values from the Panchang and solar-event services.
class PanchangDayResolver {
  PanchangDayResolver({
    required PanchangService service,
    SolarEventsService? solarEvents,
  }) : _service = service,
       _solar = solarEvents ?? solarEventsService;

  final PanchangService _service;
  final SolarEventsService _solar;

  /// Resolves the canonical day for [date] at [place].
  ///
  /// [date] is normalized to midnight; only its civil date is used. Missing
  /// solar events become nulls on [PanchangDay.solar] instead of throwing.
  ///
  /// [tithiSampler] lets a caller keep its tithi cache (the provider path
  /// caches one value per date, place, and sample point). Bisection reads
  /// during the transition search always bypass it: those instants are not
  /// sample points and would collide with a cached value.
  ///
  /// [computeTransition] is false when the caller resolves the daytime
  /// transition itself (the provider path caches it separately). The day then
  /// reports no transition rather than paying for a search it discards.
  Future<PanchangDay> resolve({
    required DateTime date,
    required PanchangPlace place,
    PanchangTithiSampler? tithiSampler,
    bool computeTransition = true,
  }) async {
    final normalized = DateTime(date.year, date.month, date.day);
    final solar = _solarDay(normalized, place);
    final sampler =
        tithiSampler ??
        (instant, _) => _service.calculateTithi(
          instant,
          latitude: place.latitude,
          longitude: place.longitude,
        );

    // Sunrise is the canonical sample point. A polar day has none, so the
    // day still needs a documented instant: civil noon, recorded on the day
    // so a UI can label the tithi as "not sunrise-based" instead of
    // pretending.
    final sample = solar.sunrise == null
        ? PanchangTithiSample.civilNoon
        : PanchangTithiSample.sunrise;
    final sampledAt =
        solar.sunrise ??
        DateTime(normalized.year, normalized.month, normalized.day, 12);

    final rawTithi = await sampler(sampledAt, '');
    final masaValue = await _service.calculateMasa(
      sampledAt,
      rawTithi,
      latitude: place.latitude,
      longitude: place.longitude,
    );
    final adhika = masaValue.startsWith('Adhika_');
    final amanta = adhika
        ? masaValue.substring('Adhika_'.length)
        : masaValue;

    final limbs = await _limbs(sampledAt, place);
    final checkpoints = _checkpoints(solar);
    final checkpointTithis = await _checkpointTithis(
      checkpoints: checkpoints,
      nextSunrise: solar.nextSunrise,
      sampler: sampler,
    );
    final transition = computeTransition
        ? await _transition(
            solar: solar,
            checkpoints: checkpoints,
            checkpointTithis: checkpointTithis,
            rawTithiAtSunrise: rawTithi,
            place: place,
          )
        : null;

    return PanchangDay(
      date: normalized,
      place: place,
      solar: solar,
      tithi: PanchangTithiDay(
        rawAtSample: rawTithi,
        sample: sample,
        sampledAt: sampledAt,
        transitionAt: transition?.at,
        transitionIndex: transition?.index,
      ),
      limbs: limbs,
      masa: PanchangMasaDay(amanta: amanta, adhika: adhika),
      checkpoints: checkpoints,
      checkpointTithis: checkpointTithis,
      provenance: PanchangProvenance(
        engineVersion: kPanchangEngineVersion,
        ayanamsa: kPanchangAyanamsa,
        sunriseConvention: _solar.convention.name,
        ephemeris: _solar.usesNativeCalculator ? 'swiss' : 'noaa',
        computedAt: DateTime.now(),
      ),
    );
  }

  /// Reads every solar and lunar anchor, converting "does not occur" into
  /// null.
  ///
  /// The three solar reads are independent: a polar day can have a sunrise
  /// but no sunset (the day the polar night closes), so each is caught
  /// separately rather than one try/catch around all three.
  PanchangSolarDay _solarDay(DateTime normalized, PanchangPlace place) {
    final moon = MoonriseCalculator.calculateMoonriseSet(
      date: normalized,
      latitude: place.latitude,
      longitude: place.longitude,
    );
    return PanchangSolarDay(
      sunrise: _solarOrNull(
        () => _solar.sunrise(
          date: normalized,
          latitude: place.latitude,
          longitude: place.longitude,
          altitudeMeters: place.altitudeMeters,
          timezoneId: place.timezoneId,
        ),
      ),
      sunset: _solarOrNull(
        () => _solar.sunset(
          date: normalized,
          latitude: place.latitude,
          longitude: place.longitude,
          altitudeMeters: place.altitudeMeters,
          timezoneId: place.timezoneId,
        ),
      ),
      nextSunrise: _solarOrNull(
        () => _solar.sunrise(
          date: normalized.add(const Duration(days: 1)),
          latitude: place.latitude,
          longitude: place.longitude,
          altitudeMeters: place.altitudeMeters,
          timezoneId: place.timezoneId,
        ),
      ),
      moonrise: moon.moonrise,
      moonset: moon.moonset,
    );
  }

  static DateTime? _solarOrNull(DateTime Function() read) {
    try {
      return read();
    } on SolarEventUnavailable {
      return null;
    }
  }

  Future<PanchangLimbDay> _limbs(
    DateTime sampledAt,
    PanchangPlace place,
  ) async {
    final longitudes = await _service.calculateSunMoonLongitudes(
      sampledAt,
      latitude: place.latitude,
      longitude: place.longitude,
    );
    if (longitudes == null) return const PanchangLimbDay();
    return PanchangLimbDay(
      nakshatra: nakshatraForLongitude(longitudes.moon),
      yoga: yogaNames[yogaIndexFor(longitudes.sun, longitudes.moon)],
      karana: karanaNameForIndex(
        karanaIndexFor(longitudes.sun, longitudes.moon),
      ),
    );
  }

  /// Solar-anchored checkpoints, each derived only from anchors that exist.
  static PanchangCheckpoints _checkpoints(PanchangSolarDay solar) {
    final sunrise = solar.sunrise;
    final sunset = solar.sunset;
    final nextSunrise = solar.nextSunrise;

    DateTime? madhyahna;
    DateTime? aparahna;
    if (sunrise != null && sunset != null) {
      final dayLength = sunset.difference(sunrise);
      madhyahna = sunrise.add(
        Duration(minutes: dayLength.inMinutes ~/ 2),
      );
      aparahna = sunrise.add(
        Duration(minutes: dayLength.inMinutes * 3 ~/ 4),
      );
    }

    DateTime? nishita;
    DateTime? pradosha;
    if (sunset != null && nextSunrise != null) {
      final nightLength = nextSunrise.difference(sunset);
      nishita = sunset.add(
        Duration(minutes: nightLength.inMinutes ~/ 2),
      );
      pradosha = sunset.add(
        Duration(minutes: nightLength.inMinutes ~/ 10),
      );
    }

    return PanchangCheckpoints(
      madhyahna: madhyahna,
      aparahna: aparahna,
      nishita: nishita,
      pradosha: pradosha,
      dominant: sunrise?.add(kDominantTithiGrace),
    );
  }

  /// Samples the tithi at each checkpoint that exists.
  ///
  /// A missing checkpoint stays null: it was never reached, so a timing rule
  /// anchored to it must not match.
  static Future<PanchangCheckpointTithis> _checkpointTithis({
    required PanchangCheckpoints checkpoints,
    required DateTime? nextSunrise,
    required PanchangTithiSampler sampler,
  }) async {
    Future<double?> at(DateTime? instant, String name) async {
      if (instant == null) return null;
      return sampler(instant, name);
    }

    return PanchangCheckpointTithis(
      madhyahna: await at(checkpoints.madhyahna, 'madhyahna'),
      aparahna: await at(checkpoints.aparahna, 'aparahna'),
      nishita: await at(checkpoints.nishita, 'nishita'),
      pradosha: await at(checkpoints.pradosha, 'pradosha'),
      nextSunrise: await at(nextSunrise, 'nextSunrise'),
      dominant: await at(checkpoints.dominant, 'dominant'),
    );
  }

  /// Daytime transition search, skipped when the solar window is missing.
  Future<({DateTime at, int index})?> _transition({
    required PanchangSolarDay solar,
    required PanchangCheckpoints checkpoints,
    required PanchangCheckpointTithis checkpointTithis,
    required double rawTithiAtSunrise,
    required PanchangPlace place,
  }) async {
    final sunrise = solar.sunrise;
    final nextSunrise = solar.nextSunrise;
    final madhyahna = checkpoints.madhyahna;
    final aparahna = checkpoints.aparahna;
    final nishita = checkpoints.nishita;
    final rawMadhyahna = checkpointTithis.madhyahna;
    final rawAparahna = checkpointTithis.aparahna;
    final rawNishita = checkpointTithis.nishita;
    final rawNextSunrise = checkpointTithis.nextSunrise;
    if (sunrise == null ||
        nextSunrise == null ||
        madhyahna == null ||
        aparahna == null ||
        nishita == null ||
        rawMadhyahna == null ||
        rawAparahna == null ||
        rawNishita == null ||
        rawNextSunrise == null) {
      return null;
    }

    // Bisection instants are not sample points, so this read bypasses any
    // caller cache on purpose.
    Future<double> tithiAt(DateTime time) => _service.calculateTithi(
      time,
      latitude: place.latitude,
      longitude: place.longitude,
    );

    final found = await findSunriseTithiTransition(
      sunrise: sunrise,
      nextSunrise: nextSunrise,
      rawTithiAtSunrise: rawTithiAtSunrise,
      segments: [
        (time: sunrise, rawTithi: rawTithiAtSunrise),
        (time: madhyahna, rawTithi: rawMadhyahna),
        (time: aparahna, rawTithi: rawAparahna),
        (time: nishita, rawTithi: rawNishita),
        (time: nextSunrise, rawTithi: rawNextSunrise),
      ],
      getRawTithi: tithiAt,
    );
    if (found == null) return null;
    return (at: found.at, index: found.toIndex);
  }
}
