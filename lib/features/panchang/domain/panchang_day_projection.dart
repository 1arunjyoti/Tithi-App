import '../../../models/festival.dart';
import '../../../models/hindu_month_system.dart';
import '../../../models/panchang_data.dart';
import 'panchang_day.dart';

/// Projects a canonical [PanchangDay] into the [PanchangData] the rest of the
/// app matches festivals against.
///
/// This is the only place a resolved day becomes matchable data. Every caller
/// that assembles its own [PanchangData.fromRawTithi] call drifts from the
/// others: the occurrence scan had already drifted, accepting a sunrise match
/// for a `timingOverride` festival that the UI grid rejects.
///
/// [masaNextSunrise] is the Amanta masa at [PanchangDay.solar.nextSunrise],
/// which the Kshaya and dominant-grace wrap branches compare against; pass an
/// empty string when there is no next sunrise. It is a parameter rather than a
/// read here because computing it needs a Sankranti search that the caller may
/// skip or cache.
///
/// [nakshatraAtSunrise] is read only by nakshatra-conditioned festivals; pass
/// null when the day's limbs were not computed.
PanchangData projectPanchangDay(
  PanchangDay day, {
  required List<Festival> festivals,
  HinduMonthSystem monthSystem = HinduMonthSystem.amanta,
  String masaNextSunrise = '',
  String? nakshatraAtSunrise,
  DateTime? tithiTransitionTime,
  int? transitionTithiIndex,
}) {
  return PanchangData.fromRawTithi(
    date: day.date,
    rawTithi: day.tithi.rawAtSample,
    masa: day.masa.amantaForMatching,
    allFestivals: festivals,
    monthSystem: monthSystem,
    sunrise: day.solar.sunrise,
    sunset: day.solar.sunset,
    rawTithiMadhyahna: day.checkpointTithis.madhyahna,
    rawTithiBrahmaMuhurtaStart: day.checkpointTithis.brahmaMuhurtaStart,
    rawTithiArunodaya: day.checkpointTithis.arunodaya,
    rawTithiPurvahna: day.checkpointTithis.purvahna,
    rawTithiSayahnaStart: day.checkpointTithis.sayahnaStart,
    rawTithiSayahnaCenter: day.checkpointTithis.sayahnaCenter,
    rawTithiSayahnaEnd: day.checkpointTithis.sayahnaEnd,
    rawTithiAparahna: day.checkpointTithis.aparahna,
    rawTithiNishita: day.checkpointTithis.nishita,
    rawTithiNishitaEnd: day.checkpointTithis.nishitaEnd,
    rawTithiPradosha: day.checkpointTithis.pradosha,
    rawTithiMoonrise: day.checkpointTithis.moonrise,
    rawTithiNextSunrise: day.checkpointTithis.nextSunrise,
    masaNextSunrise: masaNextSunrise,
    nakshatraAtSunrise: nakshatraAtSunrise,
    rawTithiDominant: day.checkpointTithis.dominant,
    tithiTransitionTime: tithiTransitionTime,
    transitionTithiIndex: transitionTithiIndex,
    sankrantiRashi: day.sankranti?.rashi,
    sankrantiInstant: day.sankranti?.instant,
    sankrantiShifted: day.sankranti?.shifted ?? false,
    sankrantiComputed: day.sankrantiComputed,
  );
}
