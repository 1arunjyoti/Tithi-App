import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:tithi/features/panchang/domain/panchang_day.dart';
import 'package:tithi/features/panchang/domain/tithi_transitions.dart';
import 'package:tithi/models/hindu_month_system.dart';
import 'package:tithi/models/panchang_data.dart';
import 'package:tithi/services/panchang_service.dart';

// Phase 2 acceptance criterion: a day whose Sun never rises must produce a
// PanchangData with null sunrise/sunset, not a thrown SolarEventUnavailable.
// This exercises the real provider path (computePanchangData ->
// resolveTithiCheckpoints -> resolveDayTransition), not the resolver alone.

void main() {
  final libPath = Platform.environment['SWISSEPH_LIB_PATH'];
  final libraryAvailable =
      libPath != null && libPath.isNotEmpty && File(libPath).existsSync();
  final skipReason = libraryAvailable
      ? null
      : 'Set SWISSEPH_LIB_PATH to a host Swiss Ephemeris library to run the '
            'polar day tests.';

  TestWidgetsFlutterBinding.ensureInitialized();

  late PanchangService service;
  late Directory tempDir;
  late Box<dynamic> cacheBox;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('tithi_polar_day');
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async => tempDir.path);
    service = PanchangService();
    await service.init();
    Hive.init(tempDir.path);
    cacheBox = await Hive.openBox<dynamic>('polar_cache');
  });

  group('polar day through the provider path', () {
    const latitude = 69.6492;
    const longitude = 18.9553;
    const timezoneId = 'Europe/Oslo';
    final date = DateTime(2026, 12, 21);

    test('checkpoints report missing anchors instead of throwing', () async {
      final checkpoints = await resolveTithiCheckpoints(
        normalizedDate: date,
        service: service,
        latitude: latitude,
        longitude: longitude,
        cacheBox: cacheBox,
        timezoneId: timezoneId,
      );

      expect(checkpoints.sunriseTime, isNull);
      expect(checkpoints.sunsetTime, isNull);
      expect(checkpoints.nextSunriseTime, isNull);
      expect(checkpoints.madhyahnaTime, isNull);
      expect(checkpoints.aparahnaTime, isNull);
      expect(checkpoints.nishitaTime, isNull);
      expect(checkpoints.pradoshaTime, isNull);
      expect(checkpoints.dominantTime, isNull);
      expect(checkpoints.rawTithiMadhyahna, isNull);
      expect(checkpoints.rawTithiNishita, isNull);
      expect(checkpoints.rawTithiNextSunrise, isNull);

      // The day still has a tithi, sampled at civil noon and labelled so.
      expect(checkpoints.tithiSample, PanchangTithiSample.civilNoon);
      expect(checkpoints.tithiSampledAt.hour, 12);
      expect(checkpoints.rawTithi, inInclusiveRange(1.0, 30.99));
    }, skip: skipReason);

    test('the daytime transition search is skipped, not attempted', () async {
      final checkpoints = await resolveTithiCheckpoints(
        normalizedDate: date,
        service: service,
        latitude: latitude,
        longitude: longitude,
        cacheBox: cacheBox,
        timezoneId: timezoneId,
      );

      final transition = await resolveDayTransition(
        normalizedDate: date,
        service: service,
        latitude: latitude,
        longitude: longitude,
        cacheBox: cacheBox,
        checkpoints: checkpoints,
      );

      expect(transition.at, isNull);
      expect(transition.index, isNull);
    }, skip: skipReason);

    test('computePanchangData returns a renderable day', () async {
      final data = await computePanchangData(
        normalizedDate: date,
        service: service,
        festivals: const [],
        monthSystem: HinduMonthSystem.amanta,
        latitude: latitude,
        longitude: longitude,
        cacheBox: cacheBox,
        includeTransition: true,
        timezoneId: timezoneId,
      );

      expect(data, isA<PanchangData>());
      expect(data.sunrise, isNull);
      expect(data.sunset, isNull);
      expect(data.hasTithiTransition, isFalse);
      expect(data.paksha, anyOf('Shukla', 'Krishna'));
      expect(data.tithiNumber, inInclusiveRange(1, 15));
      expect(data.tithiName, isNotEmpty);
      expect(data.masa, isNotEmpty);
      expect(data.festivals, isEmpty);
    }, skip: skipReason);
  });
}
