import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tithi/features/panchang/domain/panchang_day.dart';
import 'package:tithi/features/panchang/domain/panchang_day_resolver.dart';
import 'package:tithi/services/panchang_service.dart';
import 'package:tithi/services/solar_events_service.dart';

// Phase 2 canonical day: proves the resolver turns "the Sun does not rise"
// into data instead of an exception, and that an ordinary day is
// value-identical to the pre-Phase-2 reads it replaces.

void main() {
  final libPath = Platform.environment['SWISSEPH_LIB_PATH'];
  final libraryAvailable =
      libPath != null && libPath.isNotEmpty && File(libPath).existsSync();
  final skipReason = libraryAvailable
      ? null
      : 'Set SWISSEPH_LIB_PATH to a host Swiss Ephemeris library to run the '
            'canonical day tests.';

  TestWidgetsFlutterBinding.ensureInitialized();

  late PanchangService service;
  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('tithi_panchang_day');
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async => tempDir.path);
    service = PanchangService();
    await service.init();
  });

  // The native ephemeris library keeps the copied files mapped, so the temp
  // directory is intentionally left to the OS (same as the golden harness).

  group('PanchangDayResolver', () {
    test('a polar-night day is data: no solar anchors, tithi still resolved', () async {
      // Tromso, winter solstice: the Sun never clears the horizon.
      const place = PanchangPlace(
        latitude: 69.6492,
        longitude: 18.9553,
        timezoneId: 'Europe/Oslo',
        label: 'Tromso',
      );
      final resolver = PanchangDayResolver(service: service);

      final day = await resolver.resolve(
        date: DateTime(2026, 12, 21),
        place: place,
      );

      expect(day.isPolar, isTrue);
      expect(day.solar.hasPolarNight, isTrue);
      expect(day.solar.sunrise, isNull);
      expect(day.solar.sunset, isNull);
      expect(day.solar.nextSunrise, isNull);
      expect(day.solar.dayLength, isNull);
      expect(day.solar.nightLength, isNull);

      // Solar-anchored checkpoints cannot be invented.
      expect(day.checkpoints.isEmpty, isTrue);

      // The day still describes itself.
      expect(day.tithi.sample, PanchangTithiSample.civilNoon);
      expect(day.tithi.sampledAt.hour, 12);
      expect(day.tithi.index, inInclusiveRange(1, 30));
      expect(day.tithi.name, isNotEmpty);
      expect(day.masa.amanta, isNotEmpty);
      expect(day.tithi.transitionAt, isNull);
      expect(day.provenance.engineVersion, kPanchangEngineVersion);
      expect(day.provenance.ayanamsa, kPanchangAyanamsa);
    }, skip: skipReason);

    test('a polar-day (midnight sun) day is data too', () async {
      const place = PanchangPlace(
        latitude: 69.6492,
        longitude: 18.9553,
        timezoneId: 'Europe/Oslo',
      );
      final resolver = PanchangDayResolver(service: service);

      final day = await resolver.resolve(
        date: DateTime(2026, 6, 21),
        place: place,
      );

      expect(day.isPolar, isTrue);
      expect(day.solar.hasPolarDay, isTrue);
      expect(day.solar.sunset, isNull);
      expect(day.tithi.index, inInclusiveRange(1, 30));
    }, skip: skipReason);

    test('a day with a sunrise but no sunset keeps the anchors it has', () async {
      // The first day of the polar night: the Sun rises and does not set.
      // Each solar read is caught separately, so sunrise and the
      // sunrise-derived checkpoints must survive.
      final resolver = PanchangDayResolver(
        service: service,
        solarEvents: SolarEventsService(calculator: _NoSunsetCalculator()),
      );

      final day = await resolver.resolve(
        date: DateTime(2026, 9, 4),
        place: const PanchangPlace(latitude: 78.2232, longitude: 15.6469),
      );

      expect(day.solar.sunrise, isNotNull);
      expect(day.solar.sunset, isNull);
      expect(day.solar.nextSunrise, isNotNull);
      expect(day.solar.lacksSolarAnchors, isTrue);
      expect(day.tithi.sample, PanchangTithiSample.sunrise);
      expect(day.checkpoints.dominant, isNotNull);
      expect(day.checkpoints.madhyahna, isNull);
      expect(day.checkpoints.aparahna, isNull);
      expect(day.checkpoints.nishita, isNull);
      expect(day.checkpoints.pradosha, isNull);
    }, skip: skipReason);

    test('an ordinary day matches the direct service reads', () async {
      const place = PanchangPlace(
        latitude: 28.6139,
        longitude: 77.2090,
        altitudeMeters: 216,
        timezoneId: 'Asia/Kolkata',
        label: 'Delhi',
      );
      final date = DateTime(2026, 9, 4);
      final resolver = PanchangDayResolver(service: service);

      final day = await resolver.resolve(date: date, place: place);

      final sunrise = solarEventsService.sunrise(
        date: date,
        latitude: place.latitude,
        longitude: place.longitude,
        altitudeMeters: place.altitudeMeters,
        timezoneId: place.timezoneId,
      );
      final sunset = solarEventsService.sunset(
        date: date,
        latitude: place.latitude,
        longitude: place.longitude,
        altitudeMeters: place.altitudeMeters,
        timezoneId: place.timezoneId,
      );
      final nextSunrise = solarEventsService.sunrise(
        date: date.add(const Duration(days: 1)),
        latitude: place.latitude,
        longitude: place.longitude,
        altitudeMeters: place.altitudeMeters,
        timezoneId: place.timezoneId,
      );

      expect(day.isPolar, isFalse);
      expect(day.solar.sunrise, sunrise);
      expect(day.solar.sunset, sunset);
      expect(day.solar.nextSunrise, nextSunrise);
      expect(day.solar.dayLength, sunset.difference(sunrise));
      expect(day.solar.nightLength, nextSunrise.difference(sunset));

      // Tithi, masa, and nakshatra must equal the pre-Phase-2 reads exactly;
      // this is the parity guarantee for the projection that follows.
      final rawTithi = await service.calculateTithi(
        sunrise,
        latitude: place.latitude,
        longitude: place.longitude,
      );
      expect(day.tithi.rawAtSample, rawTithi);
      expect(day.tithi.sample, PanchangTithiSample.sunrise);
      expect(day.tithi.sampledAt, sunrise);

      final masa = await service.calculateMasa(
        sunrise,
        rawTithi,
        latitude: place.latitude,
        longitude: place.longitude,
      );
      expect(day.masa.amantaForMatching, masa);
      expect(day.masa.adhika, masa.startsWith('Adhika_'));

      final nakshatra = await service.calculateNakshatra(
        sunrise,
        latitude: place.latitude,
        longitude: place.longitude,
      );
      expect(day.limbs.nakshatra, nakshatra);
      expect(day.limbs.yoga, isNotNull);
      expect(day.limbs.karana, isNotNull);

      // Checkpoints are the same arithmetic the provider already used.
      final dayLength = sunset.difference(sunrise).inMinutes;
      expect(
        day.checkpoints.madhyahna,
        sunrise.add(Duration(minutes: dayLength ~/ 2)),
      );
      expect(
        day.checkpoints.aparahna,
        sunrise.add(Duration(minutes: dayLength * 3 ~/ 4)),
      );
      final nightLength = nextSunrise.difference(sunset).inMinutes;
      // Nishita is the 7/15 - 8/15 night window, in microseconds so its edges
      // are not rounded by a whole minute.
      final nightMicros = nextSunrise.difference(sunset).inMicroseconds;
      expect(
        day.checkpoints.nishita,
        sunset.add(Duration(microseconds: nightMicros * 7 ~/ 15)),
      );
      expect(
        day.checkpoints.nishitaEnd,
        sunset.add(Duration(microseconds: nightMicros * 8 ~/ 15)),
      );
      expect(
        day.checkpoints.pradosha,
        sunset.add(Duration(minutes: nightLength ~/ 10)),
      );
      expect(day.provenance.ephemeris, 'swiss');
    }, skip: skipReason);

    test('provenance records the convention actually used', () async {
      final resolver = PanchangDayResolver(service: service);
      final day = await resolver.resolve(
        date: DateTime(2026, 9, 4),
        place: const PanchangPlace(
          latitude: 28.6139,
          longitude: 77.2090,
          timezoneId: 'Asia/Kolkata',
        ),
      );

      expect(day.provenance.sunriseConvention, 'hindu');
      expect(day.provenance.cacheKey, contains(kPanchangEngineVersion));
    }, skip: skipReason);
  });
}

/// Sun rises but never sets: the polar-night boundary case.
class _NoSunsetCalculator implements SolarEventCalculator {
  @override
  bool get isNative => false;

  @override
  DateTime rise({
    required DateTime date,
    required double latitude,
    required double longitude,
    double altitudeMeters = 0,
    String? timezoneId,
  }) => DateTime(date.year, date.month, date.day, 8);

  @override
  DateTime set({
    required DateTime date,
    required double latitude,
    required double longitude,
    double altitudeMeters = 0,
    String? timezoneId,
  }) => throw SolarEventUnavailable(
    event: 'sunset',
    date: date,
    latitude: latitude,
    longitude: longitude,
  );
}
