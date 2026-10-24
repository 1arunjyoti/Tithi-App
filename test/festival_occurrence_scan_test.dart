import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tithi/core/location/location_defaults.dart';
import 'package:tithi/features/panchang/domain/panchang_day.dart';
import 'package:tithi/features/panchang/domain/panchang_day_projection.dart';
import 'package:tithi/features/panchang/domain/panchang_day_resolver.dart';
import 'package:tithi/models/festival.dart';
import 'package:tithi/services/panchang_service.dart';

// The forward scan used to carry its own copy of the festival-match rules
// (sunrise probe, timing checkpoints, dominant grace, Kshaya). Two definitions
// of "matches today" drift, and this one already had: it accepted a sunrise
// match for a `timingOverride` festival that the UI grid rejects.
//
// Phase 2 resolves one canonical day per scanned date and projects it through
// the same `PanchangData.fromRawTithi` the grid uses, so the assertions here
// are parity assertions - the scan returns a date, and the projected day lists
// the festival - not a second opinion about the astronomy.

void main() {
  final libPath = Platform.environment['SWISSEPH_LIB_PATH'];
  final libraryAvailable =
      libPath != null && libPath.isNotEmpty && File(libPath).existsSync();
  final skipReason = libraryAvailable
      ? null
      : 'Set SWISSEPH_LIB_PATH to a host Swiss Ephemeris library to run the '
            'festival occurrence scan tests.';

  TestWidgetsFlutterBinding.ensureInitialized();

  late PanchangService service;
  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('tithi_occurrence_scan');
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async => tempDir.path);
    service = PanchangService();
    await service.init();
  });

  // Every non-polar case below is a Delhi golden case, and Delhi is the
  // service's default place, so the projection uses the same defaults the scan
  // falls back to instead of repeating the coordinates.
  const delhiPlace = PanchangPlace(
    latitude: kDefaultLatitude,
    longitude: kDefaultLongitude,
    altitudeMeters: kDefaultAltitudeMeters,
    timezoneId: kDefaultTimezoneId,
  );

  /// The festivals the UI grid would list for [date], computed through the
  /// canonical day exactly like the scan does.
  Future<List<String>> gridFestivals(Festival festival, DateTime date) async {
    final day = await PanchangDayResolver(service: service).resolve(
      date: date,
      place: delhiPlace,
    );
    final nextSunrise = day.solar.nextSunrise;
    final rawNext = day.checkpointTithis.nextSunrise;
    final masaNextSunrise = nextSunrise != null && rawNext != null
        ? await service.calculateMasa(nextSunrise, rawNext)
        : '';
    final projected = projectPanchangDay(
      day,
      festivals: [festival],
      masaNextSunrise: masaNextSunrise,
    );
    return projected.festivals.map((f) => f.id).toList();
  }

  Future<DateTime?> scan(Festival festival, DateTime from) =>
      service.findNextFestivalOccurrence(festival, startDate: from);

  group('findNextFestivalOccurrence', () {
    test('finds a nishita observance at the Nishita window', () async {
      // Golden case delhi-2026-09-04: Ashtami prevails at the 23:57 window
      // opening (raw 23.987) even though it ends before the night midpoint.
      final janmashtami = Festival.fromJson({
        'id': 'janmashtami',
        'name': 'Krishna Janmashtami',
        'panchang_rules': {
          'masa': 'Shravana',
          'paksha': 'Krishna',
          'tithi': 8,
          'conditions': 'Ashtami',
          'timingOverride': 'nishita',
        },
      });

      final found = await scan(janmashtami, DateTime(2026, 8));

      expect(found, equals(DateTime(2026, 9, 4)));
      expect(await gridFestivals(janmashtami, found!), equals(['janmashtami']));
    }, skip: skipReason);

    test('finds a madhyahna observance at midday', () async {
      // Golden case delhi-2026-09-14: Ganesh Chaturthi is observed at
      // madhyahna, so the scan must sample midday rather than sunrise.
      final ganesh = Festival.fromJson({
        'id': 'ganesh_chaturthi',
        'name': 'Ganesh Chaturthi',
        'panchang_rules': {
          'masa': 'Bhadrapada',
          'paksha': 'Shukla',
          'tithi': 4,
          'conditions': 'Chaturthi',
          'timingOverride': 'madhyahna',
        },
      });

      final found = await scan(ganesh, DateTime(2026, 9));

      expect(found, equals(DateTime(2026, 9, 14)));
      expect(await gridFestivals(ganesh, found!), equals(['ganesh_chaturthi']));
    }, skip: skipReason);

    test('keeps a moonrise-puja festival on its sunrise date', () async {
      // Golden case delhi-2026-10-29. Karva Chauth's puja window follows
      // moonrise, but its date rule is still the sunrise tithi, so the scan
      // must not move the observance to the moonrise checkpoint.
      final karvaChauth = Festival.fromJson({
        'id': 'karva_chauth',
        'name': 'Karva Chauth',
        'panchang_rules': {
          'masa': 'Ashwin',
          'paksha': 'Krishna',
          'tithi': 4,
          'conditions': 'Chaturthi',
          'pujaKala': 'moonrise',
          'paranRule': 'moonrise',
        },
      });

      final found = await scan(karvaChauth, DateTime(2026, 10));

      expect(found, equals(DateTime(2026, 10, 29)));
      expect(await gridFestivals(karvaChauth, found!), equals(['karva_chauth']));
    }, skip: skipReason);

    test('finds a Kshaya tithi that no sunrise ever holds', () async {
      // Delhi 2026-12-23: sunrise is Shukla Chaturdashi (raw 14.825) and the
      // next sunrise is Krishna Pratipada (16.014), so Purnima (raw index 15)
      // begins after sunrise and ends before the next one. It is also outside
      // the 60-minute dominant grace, so only the Kshaya fallback can match
      // it - without that fallback the scan would jump to the next Purnima.
      final purnima = Festival.fromJson({
        'id': 'purnima',
        'name': 'Purnima',
        'panchang_rules': {
          'masa': '*',
          'paksha': 'Shukla',
          'tithi': 15,
          'conditions': 'Purnima',
        },
      });

      final found = await scan(purnima, DateTime(2026, 12, 20));

      expect(found, equals(DateTime(2026, 12, 23)));
      expect(await gridFestivals(purnima, found!), equals(['purnima']));
    }, skip: skipReason);

    test('a polar day without a sunrise does not throw', () async {
      // Tromso, polar night: the canonical day has no sunrise, so the tithi is
      // sampled at civil noon. The old scan called `solarEventsService.sunrise`
      // directly and threw `SolarEventUnavailable` out of the search.
      const latitude = 69.6492;
      const longitude = 18.9553;
      final purnima = Festival.fromJson({
        'id': 'purnima',
        'name': 'Purnima',
        'panchang_rules': {
          'masa': '*',
          'paksha': 'Shukla',
          'tithi': 15,
          'conditions': 'Purnima',
        },
      });

      final found = await service.findNextFestivalOccurrence(
        purnima,
        startDate: DateTime(2026, 12, 20),
        latitude: latitude,
        longitude: longitude,
      );

      expect(found, isNotNull);
      final day = await PanchangDayResolver(service: service).resolve(
        date: found!,
        place: const PanchangPlace(
          latitude: latitude,
          longitude: longitude,
          timezoneId: 'Europe/Oslo',
        ),
      );
      expect(day.solar.sunrise, isNull);
    }, skip: skipReason);
  });
}
