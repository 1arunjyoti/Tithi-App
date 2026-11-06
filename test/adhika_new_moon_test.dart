import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jyotish/jyotish.dart';

import 'package:tithi/core/location/location_defaults.dart';
import 'package:tithi/features/panchang/domain/panchang_crossings.dart';
import 'package:tithi/services/panchang/panchang_service.dart';

// Phase 3 regression: the new-moon instant decides the Adhika verdict, so a
// coarse (±3 h) estimate near a Sankranti could flip it. These tests run on the
// real ephemeris and pin both halves of that: the crossing resolves to the
// second, and the masa of one lunation does not change from day to day.
//
// Everything here is geocentric (masa is the Sun's rashi at the new moons), so
// the place only supplies the [GeographicLocation] the ephemeris call wants.
// The Delhi default keeps the test independent of the device.

void main() {
  late PanchangService service;
  late Directory tempDir;
  late GeographicLocation location;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    tempDir = await Directory.systemTemp.createTemp('tithi_new_moon');
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async => tempDir.path);
    service = PanchangService();
    await service.init();
    location = GeographicLocation(
      latitude: kDefaultLatitude,
      longitude: kDefaultLongitude,
    );
  });

  tearDownAll(() async {
    try {
      await tempDir.delete(recursive: true);
    } on FileSystemException {
      // The native ephemeris library keeps the copied .se1 files open on
      // Windows, so the OS temp directory is left for the OS to reclaim.
    }
  });

  Future<double> rawTithiAt(DateTime instant) =>
      service.calculateTithi(instant);

  Future<double> elapsedDegreesAt(DateTime instant) async =>
      (await rawTithiAt(instant) - 1) * 12;

  Future<double> sunLongitudeAt(DateTime instant) async {
    final sun = await Jyotish().getPlanetPosition(
      planet: Planet.sun,
      dateTime: instant,
      location: location,
    );
    return sun.longitude;
  }

  group('new-moon crossing precision', () {
    test('the refined instant is seconds past the wrap', () async {
      // Arrange: the same-day Simha Sankranti / new moon that the old
      // two-round estimate could not place reliably.
      final estimate = DateTime(2031, 8, 17, 12);

      // Act
      final newMoon = await findNewMoonInstant(
        estimate: estimate,
        elapsedDegreesAt: elapsedDegreesAt,
      );

      // Assert: at the returned instant the elapsed angle has just passed 0.
      // One second of lunar motion is 13.2 / 86400 degrees, so anything more
      // than a couple of seconds means the solver stopped short again.
      expect(newMoon, isNotNull);
      final elapsed = await elapsedDegreesAt(newMoon!);
      expect(elapsed, greaterThanOrEqualTo(0));
      expect(elapsed, lessThan(13.2 / 86400 * 2));
    });

    test('an estimate hours off still lands on the same new moon', () async {
      // Arrange
      final exact = await findNewMoonInstant(
        estimate: DateTime(2031, 8, 17, 12),
        elapsedDegreesAt: elapsedDegreesAt,
      );
      expect(exact, isNotNull);

      // Act: the mean-motion estimate can be hours off in either direction.
      final fromBefore = await findNewMoonInstant(
        estimate: exact!.subtract(const Duration(hours: 5)),
        elapsedDegreesAt: elapsedDegreesAt,
      );
      final fromAfter = await findNewMoonInstant(
        estimate: exact.add(const Duration(hours: 5)),
        elapsedDegreesAt: elapsedDegreesAt,
      );

      // Assert
      expect(fromBefore, isNotNull);
      expect(fromAfter, isNotNull);
      expect(
        fromBefore!.difference(exact).inSeconds.abs(),
        lessThanOrEqualTo(2),
      );
      expect(
        fromAfter!.difference(exact).inSeconds.abs(),
        lessThanOrEqualTo(2),
      );
    });
  });

  group('Adhika verdict stability', () {
    test('every day of one lunation reports the same masa', () async {
      // Arrange: 2031-08-17 has a new moon and the Simha Sankranti on the
      // same civil day - the case where a coarse new-moon instant lands on
      // the wrong side of the ingress and flips the verdict.
      final newMoon = await findNewMoonInstant(
        estimate: DateTime(2031, 8, 17, 12),
        elapsedDegreesAt: elapsedDegreesAt,
      );
      final nextNewMoon = await findNewMoonInstant(
        estimate: DateTime(2031, 8, 17, 12).add(const Duration(days: 29)),
        elapsedDegreesAt: elapsedDegreesAt,
      );
      expect(newMoon, isNotNull);
      expect(nextNewMoon, isNotNull);

      // Sample only whole days strictly inside the lunation: the days on
      // either side of a new moon belong to the neighbouring masa.
      final masas = <String>{};

      // Act
      var noon = DateTime(newMoon!.year, newMoon.month, newMoon.day + 2, 12);
      while (noon.isBefore(nextNewMoon!)) {
        final tithi = await rawTithiAt(noon);
        masas.add(await service.calculateMasa(noon, tithi));
        noon = noon.add(const Duration(days: 1));
      }

      // Assert: one lunation, one masa. Two entries here would mean the
      // verdict changed mid-lunation, which is exactly the reported bug.
      expect(masas, hasLength(1));
    });
  });

  group('Sankranti crossing precision', () {
    test('the Simha ingress resolves to the second', () async {
      // Arrange: the Sun enters Leo (120 degrees) around 2031-08-17.
      final estimate = DateTime(2031, 8, 17, 12);

      // Act
      final ingress = await findSankrantiInstant(
        estimate: estimate,
        sunLongitudeAt: sunLongitudeAt,
        boundaryDegrees: 120,
      );

      // Assert: the Sun is at most a second of motion (0.9856 / 86400
      // degrees) past the boundary.
      expect(ingress, isNotNull);
      final longitude = await sunLongitudeAt(ingress!);
      final past = (longitude - 120) % 360;
      expect(past, greaterThanOrEqualTo(0));
      expect(past, lessThan(0.9856 / 86400 * 2));
    });
  });
}
