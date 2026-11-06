import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:tithi/providers/panchang_provider.dart';
import 'package:tithi/services/hindu_calendar_service.dart';
import 'package:tithi/services/panchang_service.dart';

// HinduCalendarService used to read sunrise itself and assemble the udaya
// tithi and masa inline, which threw at polar latitudes and duplicated the
// day logic. It now resolves a PanchangDay and reads only the parts it needs.

/// Counts the ephemeris reads so the "only tithi + masa" contract stays
/// explicit: this path runs once per day across month grids.
class _CountingPanchangService extends PanchangService {
  int tithiCalls = 0;
  int masaCalls = 0;
  int limbCalls = 0;

  @override
  Future<void> init() async {}

  @override
  Future<double> calculateTithi(
    DateTime date, {
    double latitude = 28.6139,
    double longitude = 77.2090,
  }) async {
    tithiCalls++;
    return 23.5;
  }

  @override
  Future<String> calculateMasa(
    DateTime date,
    double rawTithi, {
    double latitude = 28.6139,
    double longitude = 77.2090,
  }) async {
    masaCalls++;
    return 'Adhika_Shravana';
  }

  @override
  Future<({double sun, double moon})?> calculateSunMoonLongitudes(
    DateTime date, {
    double latitude = 28.6139,
    double longitude = 77.2090,
  }) async {
    limbCalls++;
    return (sun: 0.0, moon: 0.0);
  }
}

void main() {
  final libPath = Platform.environment['SWISSEPH_LIB_PATH'];
  final libraryAvailable =
      libPath != null && libPath.isNotEmpty && File(libPath).existsSync();
  final skipReason = libraryAvailable
      ? null
      : 'Set SWISSEPH_LIB_PATH to a host Swiss Ephemeris library to run the '
            'polar Hindu calendar test.';

  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    // PanchangService.init copies the bundled ephemeris into the app documents
    // directory, which does not exist in a test isolate.
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          channel,
          (call) async => Directory.systemTemp.path,
        );
  });

  late ProviderContainer container;
  late HinduCalendarService service;
  late Directory tempDir;

  Future<void> setUpContainer({
    required PanchangService panchang,
    required ({double latitude, double longitude}) coords,
  }) async {
    tempDir = await Directory.systemTemp.createTemp('tithi_hindu_day');
    Hive.init(tempDir.path);
    container = ProviderContainer(
      overrides: [
        panchangServiceProvider.overrideWithValue(panchang),
        resolvedCoordinatesProvider.overrideWithValue(coords),
        panchangInitProvider.overrideWith((ref) => Future.value()),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(() async => Hive.close());
    service = container.read(hinduCalendarServiceProvider);
  }

  group('HinduCalendarService.calculateDate', () {
    test('reads one tithi and one masa, no limbs or checkpoints', () async {
      final panchang = _CountingPanchangService();
      await setUpContainer(
        panchang: panchang,
        coords: (latitude: 28.6139, longitude: 77.2090),
      );

      final date = await service.calculateDate(DateTime(2026, 9, 4));

      expect(panchang.tithiCalls, equals(1));
      expect(panchang.masaCalls, equals(1));
      // Yoga/karana/nakshatra are not part of this result.
      expect(panchang.limbCalls, isZero);

      expect(date.paksha, equals('Krishna'));
      expect(date.tithi, equals(8));
      expect(date.fullTithi, equals(23));
      // The Adhika prefix survives: it is the matching basis, not a label.
      expect(date.masa, equals('Adhika_Shravana'));
      expect(date.vsYear, equals(2083));
      expect(date.shakaYear, equals(1948));
    });

    test('returns the day at a polar place instead of throwing', () async {
      final panchang = PanchangService();
      await panchang.init();
      await setUpContainer(
        panchang: panchang,
        coords: (latitude: 69.6492, longitude: 18.9553),
      );

      final date = await service.calculateDate(DateTime(2026, 12, 21));

      // No sunrise to sample: the tithi comes from civil noon, and the
      // calendar row still renders.
      expect(date.tithi, inInclusiveRange(1, 15));
      expect(date.fullTithi, inInclusiveRange(1, 30));
      expect(date.paksha, anyOf('Shukla', 'Krishna'));
      expect(date.masa, isNotEmpty);
      expect(date.vsYear, greaterThan(2000));
    }, skip: skipReason);
  });
}
