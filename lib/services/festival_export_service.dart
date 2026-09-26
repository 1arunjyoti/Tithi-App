import 'dart:convert';

import '../features/countdown/domain/target_resolution.dart';
import '../models/festival.dart';
import '../models/hindu_month_system.dart';
import '../models/panchang_data.dart';
import 'hindu_calendar_service.dart';
import 'panchang_service.dart';
import 'sunrise_calculator.dart';

/// Exports the full festival dataset with computed Panchang details as JSON.
///
/// Schema (per festival):
/// ```json
/// {
///   "id": "ganesh_chaturthi",
///   "name": "Ganesh Chaturthi",
///   "nameHindi": "...",
///   "category": "major",
///   "rule": {"masa": "Bhadrapada", "paksha": "Shukla",
///            "tithi": 4, "conditions": "Chaturthi"},
///   "occurrence": {
///     "date": "2026-09-14",
///     "paksha": "Shukla", "tithiNumber": 4, "tithiIndex": 4,
///     "tithiName": "Chaturthi",
///     "masa": "Bhadrapada",
///     "masaDisplay": "Bhadrapada",
///     "vsYear": 2083,
///     "shakaYear": 1948,
///     "tithiBegins": "2026-09-14T07:06:00.000",
///     "tithiEnds": "2026-09-15T07:44:00.000",
///     "sunrise": "2026-09-14T06:07:00.000",
///     "sunset": "2026-09-14T18:28:00.000"
///   }
/// }
/// ```
///
/// Semantics:
/// - `occurrence` is the FIRST occurrence on/after Jan 1 of [year].
///   A lunisolar year holds ~one occurrence per festival; it is null when
///   none falls inside the year (e.g. a Kshaya tithi).
/// - Festival dates come from Amanta matching, so they are identical under
///   both month systems; only `masaDisplay` follows [monthSystem].
/// - `masa` is the Amanta matching basis; `masaDisplay` is the label in the
///   user's month system (equal for Shukla, next-month for Krishna Purnimant).
/// - `vsYear`/`shakaYear` are the traditional lunisolar era numbers for the
///   occurrence (VS = Gregorian +57/+56 around Chaitra Shukla Pratipada,
///   Shaka = VS - 135); the selected `yearEra` is recorded in the header.
/// - `tithiBegins`/`tithiEnds` belong to the festival's OBSERVED tithi
///   (timingOverride-aware). They are null for Solar festivals (fixed
///   Gregorian dates, no tithi span), for nakshatra-observed festivals
///   (their stored tithi is documentation only), and for Kshaya tithis.
/// - All instants are local wall-clock ISO-8601; see `location` in the
///   document header for the coordinates they were computed for.
class FestivalExportService {
  FestivalExportService();

  /// Builds the complete export document for [year].
  ///
  /// Returns the JSON string, or null when cancelled via [isCancelled].
  /// Reports progress through [onProgress] and yields to the event loop
  /// after each festival so progress UI stays responsive.
  Future<String?> exportYearJson({
    required List<Festival> festivals,
    required PanchangService service,
    required double latitude,
    required double longitude,
    required HinduMonthSystem monthSystem,
    required HinduYearEra yearEra,
    required int year,
    void Function(int done, int total)? onProgress,
    bool Function()? isCancelled,
  }) async {
    final startOfYear = DateTime(year);
    final entries = <Map<String, dynamic>>[];

    for (var i = 0; i < festivals.length; i++) {
      if (isCancelled != null && isCancelled()) return null;

      entries.add(
        await _exportOne(
          festivals[i],
          service,
          latitude,
          longitude,
          monthSystem,
          startOfYear,
          year,
        ),
      );
      onProgress?.call(i + 1, festivals.length);
      // Let progress UI paint between festivals.
      await Future<void>.delayed(Duration.zero);
    }

    final document = {
      'app': 'Tithi',
      'exportedAt': DateTime.now().toIso8601String(),
      'year': year,
      'location': {'latitude': latitude, 'longitude': longitude},
      'monthSystem': monthSystem.name,
      'yearEra': yearEra.name,
      'festivalCount': entries.length,
      'festivals': entries,
    };
    return const JsonEncoder.withIndent('  ').convert(document);
  }

  Future<Map<String, dynamic>> _exportOne(
    Festival festival,
    PanchangService service,
    double latitude,
    double longitude,
    HinduMonthSystem monthSystem,
    DateTime startOfYear,
    int year,
  ) async {
    DateTime? occurrence;
    try {
      final found = await resolveOccurrenceDate(
        service: service,
        festival: festival,
        baseDate: startOfYear,
        latitude: latitude,
        longitude: longitude,
        monthSystem: monthSystem,
      );
      if (found != null && found.year == year) {
        occurrence = DateTime(found.year, found.month, found.day);
      }
    } catch (_) {
      occurrence = null;
    }

    if (occurrence == null) {
      return buildEntry(festival: festival);
    }

    final sunrise = SunriseCalculator.calculateSunriseIST(
      date: occurrence,
      latitude: latitude,
      longitude: longitude,
    );
    final sunset = SunriseCalculator.calculateSunsetIST(
      date: occurrence,
      latitude: latitude,
      longitude: longitude,
    );
    final rawTithi = await service.calculateTithi(
      sunrise,
      latitude: latitude,
      longitude: longitude,
    );
    final masa = await service.calculateMasa(
      sunrise,
      rawTithi,
      latitude: latitude,
      longitude: longitude,
    );
    // Nakshatra at sunrise for the occurrence record (null on web).
    final nakshatraAtSunrise = festival.nakshatraCondition != null
        ? await service.calculateNakshatra(
            sunrise,
            latitude: latitude,
            longitude: longitude,
          )
        : null;
    final panchang = PanchangData.fromRawTithi(
      date: occurrence,
      rawTithi: rawTithi,
      masa: masa,
      sunrise: sunrise,
      sunset: sunset,
      nakshatraAtSunrise: nakshatraAtSunrise,
    );

    DateTime? begins;
    DateTime? ends;
    // No tithi span for Solar festivals — or for nakshatra-observed ones
    // (their stored tithi is documentation only; a tithi span would mislead).
    if (festival.conditions != 'Solar' &&
        festival.tithi >= 1 &&
        festival.nakshatraCondition == null) {
      final observedIndex = festival.resolveTithiIndex(panchang.paksha);
      begins = await service.calculateTithiStartTime(
        occurrence,
        observedIndex,
        latitude: latitude,
        longitude: longitude,
      );
      ends = await service.calculateTithiEndTime(
        occurrence,
        observedIndex,
        latitude: latitude,
        longitude: longitude,
      );
      // Kshaya guard: a span further than 2 days out belongs to another
      // lunation — report null rather than a wrong-month span.
      if (begins.difference(occurrence).inDays.abs() > 2 ||
          ends.difference(occurrence).inDays.abs() > 2) {
        begins = null;
        ends = null;
      }
    }

    final isNakshatraObserved = festival.nakshatraCondition != null;
    final observedIndex =
        !isNakshatraObserved &&
            festival.conditions != 'Solar' &&
            festival.tithi >= 1
        ? festival.resolveTithiIndex(panchang.paksha)
        : panchang.tithiIndex;
    final observedPaksha =
        !isNakshatraObserved &&
            festival.conditions != 'Solar' &&
            festival.tithi >= 1
        ? festival.resolvePaksha(panchang.paksha)
        : panchang.paksha;
    final observedNum =
        observedIndex <= 15 ? observedIndex : observedIndex - 15;

    // Era years from the AMANTA masa (the +56/+57 boundary is defined by
    // Amanta Chaitra; feeding the Purnimant display label here would flip
    // March Phalguna-Krishna days, displayed as Chaitra, into the new year).
    // Shaka is VS - 135 by construction (same traditional New Year).
    final vsYear = HinduCalendarService.vikramSamvatYear(
      gregorianYear: occurrence.year,
      gregorianMonth: occurrence.month,
      masa: masa,
    );

    return buildEntry(
      festival: festival,
      date: occurrence,
      paksha: observedPaksha,
      tithiNumber: observedNum,
      tithiIndex: observedIndex,
      tithiName: PanchangData.tithiNameFor(observedNum, observedPaksha),
      masa: panchang.masa,
      masaDisplay: displayMasaName(panchang.masa, panchang.paksha, monthSystem),
      vsYear: vsYear,
      shakaYear: vsYear - 135,
      tithiBegins: begins,
      tithiEnds: ends,
      sunrise: sunrise,
      sunset: sunset,
    );
  }

  /// Pure entry builder (no ephemeris) — unit-testable.
  ///
  /// Pass only [festival] to encode a year with no occurrence.
  static Map<String, dynamic> buildEntry({
    required Festival festival,
    DateTime? date,
    String? paksha,
    int? tithiNumber,
    int? tithiIndex,
    String? tithiName,
    String? masa,
    String? masaDisplay,
    int? vsYear,
    int? shakaYear,
    DateTime? tithiBegins,
    DateTime? tithiEnds,
    DateTime? sunrise,
    DateTime? sunset,
  }) {
    String? day(DateTime? dt) => dt == null
        ? null
        : '${dt.year.toString().padLeft(4, '0')}-'
            '${dt.month.toString().padLeft(2, '0')}-'
            '${dt.day.toString().padLeft(2, '0')}';
    String? instant(DateTime? dt) => dt?.toIso8601String();

    return {
      'id': festival.id,
      'name': festival.name,
      'nameHindi': festival.nameHindi,
      'category': festival.category,
      'rule': {
        'masa': festival.masa,
        'paksha': festival.paksha,
        'tithi': festival.tithi,
        'conditions': festival.conditions,
      },
      'occurrence': date == null
          ? null
          : {
              'date': day(date),
              'paksha': paksha,
              'tithiNumber': tithiNumber,
              'tithiIndex': tithiIndex,
              'tithiName': tithiName,
              'masa': masa,
              'masaDisplay': masaDisplay,
              'vsYear': vsYear,
              'shakaYear': shakaYear,
              'tithiBegins': instant(tithiBegins),
              'tithiEnds': instant(tithiEnds),
              'sunrise': instant(sunrise),
              'sunset': instant(sunset),
            },
    };
  }
}
