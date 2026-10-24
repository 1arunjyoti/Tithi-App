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
  Future<PanchangDay> resolve({
    required DateTime date,
    required PanchangPlace place,
  }) async {
    final normalized = DateTime(date.year, date.month, date.day);
    final solar = _solarDay(normalized, place);

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

    final rawTithi = await _service.calculateTithi(
      sampledAt,
      latitude: place.latitude,
      longitude: place.longitude,
    );
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
    final transition = await _transition(
      solar: solar,
      checkpoints: checkpoints,
      rawTithiAtSunrise: rawTithi,
      place: place,
    );

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

  /// Daytime transition search, skipped when the solar window is missing.
  Future<({DateTime at, int index})?> _transition({
    required PanchangSolarDay solar,
    required PanchangCheckpoints checkpoints,
    required double rawTithiAtSunrise,
    required PanchangPlace place,
  }) async {
    final sunrise = solar.sunrise;
    final nextSunrise = solar.nextSunrise;
    final madhyahna = checkpoints.madhyahna;
    final aparahna = checkpoints.aparahna;
    final nishita = checkpoints.nishita;
    if (sunrise == null ||
        nextSunrise == null ||
        madhyahna == null ||
        aparahna == null ||
        nishita == null) {
      return null;
    }

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
        (time: madhyahna, rawTithi: await tithiAt(madhyahna)),
        (time: aparahna, rawTithi: await tithiAt(aparahna)),
        (time: nishita, rawTithi: await tithiAt(nishita)),
        (
          time: nextSunrise,
          rawTithi: await tithiAt(nextSunrise),
        ),
      ],
      getRawTithi: tithiAt,
    );
    if (found == null) return null;
    return (at: found.at, index: found.toIndex);
  }
}
