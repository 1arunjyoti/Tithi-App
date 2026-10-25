import 'dart:io';

import 'package:jyotish/jyotish.dart';
import 'package:test/test.dart';

void main() {
  group('Ephemeris provenance', () {
    late Directory emptyDirectory;
    late EphemerisService service;

    final dateTime = DateTime.utc(2024, 1, 1, 12);
    final location = GeographicLocation(latitude: 0, longitude: 0);

    setUpAll(() async {
      emptyDirectory = await Directory.systemTemp.createTemp('jyotish_no_ephe');
      service = EphemerisService();
      await service.initialize(ephemerisPath: emptyDirectory.path);
    });

    tearDownAll(() {
      service.dispose();
      emptyDirectory.deleteSync(recursive: true);
    });

    test('records the requested and actual backend', () async {
      final position = await service.calculatePlanetPosition(
        planet: Planet.sun,
        dateTime: dateTime,
        location: location,
        flags: CalculationFlags.defaultFlags(),
      );

      final provenance = position.provenance;
      expect(provenance, isNotNull);
      expect(provenance!.requestedBackend, EphemerisBackend.swiss);
      expect(provenance.backend, isNot(EphemerisBackend.unknown));
      expect(provenance.returnedFlags, greaterThan(0));

      // An empty ephemeris path must fall back to Moshier rather than pretend
      // the result came from the bundled .se1 files.
      expect(provenance.backend, EphemerisBackend.moshier);
      expect(provenance.usedFallback, isTrue);
      expect(provenance.isHighPrecision, isFalse);
      expect(provenance.warning, isNotNull);
    });

    test('requireSwissEphemeris rejects a Moshier fallback', () async {
      await expectLater(
        service.calculatePlanetPosition(
          planet: Planet.sun,
          dateTime: dateTime,
          location: location,
          flags: const CalculationFlags(requireSwissEphemeris: true),
        ),
        throwsA(isA<EphemerisBackendException>()),
      );
    });

    test('requireSwissEphemeris also rejects a cached fallback', () async {
      // Prime the cache with a Moshier result under the same key.
      await service.calculatePlanetPosition(
        planet: Planet.moon,
        dateTime: dateTime,
        location: location,
        flags: CalculationFlags.defaultFlags(),
      );

      await expectLater(
        service.calculatePlanetPosition(
          planet: Planet.moon,
          dateTime: dateTime,
          location: location,
          flags: const CalculationFlags(requireSwissEphemeris: true),
        ),
        throwsA(isA<EphemerisBackendException>()),
      );
    });

    test('reports no loaded file range when running on Moshier', () async {
      final range = await service.probeDataRange();

      expect(range.hasPlanetsAndMoon, isFalse);
      expect(range.planets, isNull);
      expect(range.moon, isNull);
    });

    test('concurrent initialization is idempotent', () async {
      final other = EphemerisService();
      final first = other.initialize(ephemerisPath: emptyDirectory.path);
      final second = other.initialize(ephemerisPath: emptyDirectory.path);

      await Future.wait([first, second]);
      expect(other.isInitialized, isTrue);
      other.dispose();
    });

    test('Jyotish shares one in-flight future across concurrent calls',
        () async {
      final jyotish = Jyotish();
      final first = jyotish.initialize();
      final second = jyotish.initialize();

      expect(identical(first, second), isTrue);
      await Future.wait([first, second]);
      expect(jyotish.isInitialized, isTrue);
      jyotish.dispose();
    });
  });

  group('EphemerisDataRange', () {
    EphemerisFileRange file(int ifno, int startYear, int endYear) {
      return EphemerisFileRange(
        ifno: ifno,
        path: '/tmp/file.se1',
        startUtc: DateTime.utc(startYear),
        endUtc: DateTime.utc(endYear, 12, 31),
        denum: 0,
      );
    }

    test('accepts a range that covers the requested years', () {
      final range = EphemerisDataRange(
        planets: file(0, 1800, 2399),
        moon: file(1, 1800, 2399),
      );

      expect(range.hasPlanetsAndMoon, isTrue);
      expect(range.coversYears(1800, 2399), isTrue);
      expect(range.files, hasLength(2));
    });

    test('rejects a range that stops short', () {
      final range = EphemerisDataRange(
        planets: file(0, 1800, 2398),
        moon: file(1, 1800, 2399),
      );

      expect(range.hasPlanetsAndMoon, isTrue);
      expect(range.coversYears(1800, 2399), isFalse);
    });

    test('rejects a missing moon file', () {
      final range = EphemerisDataRange(planets: file(0, 1800, 2399));

      expect(range.hasPlanetsAndMoon, isFalse);
      expect(range.coversYears(1800, 2399), isFalse);
    });
  });
}
