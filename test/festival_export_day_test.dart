import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:tithi/models/festival.dart';
import 'package:tithi/models/hindu_month_system.dart';
import 'package:tithi/services/festival_export_service.dart';
import 'package:tithi/services/panchang_service.dart';
import 'package:tithi/services/solar_events_service.dart';

// The year export used to assemble its own day and read sunset directly, so a
// place with sunrise but no sunset (midnight sun) threw out of _exportOne and
// failed the whole document. It now projects the canonical Panchang day, whose
// missing anchors are nulls.

void main() {
  final libPath = Platform.environment['SWISSEPH_LIB_PATH'];
  final libraryAvailable =
      libPath != null && libPath.isNotEmpty && File(libPath).existsSync();
  final skipReason = libraryAvailable
      ? null
      : 'Set SWISSEPH_LIB_PATH to a host Swiss Ephemeris library to run the '
            'festival export day tests.';

  TestWidgetsFlutterBinding.ensureInitialized();

  late PanchangService service;
  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('tithi_export_day');
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async => tempDir.path);
    service = PanchangService();
    await service.init();
    Hive.init(tempDir.path);
  });

  /// Ganesh Chaturthi: Bhadrapada Shukla Chaturthi, madhyahna observed.
  Festival ganesh() => Festival.fromJson({
        'id': 'ganesh_chaturthi',
        'name': 'Ganesh Chaturthi',
        'category': 'major',
        'panchang_rules': {
          'masa': 'Bhadrapada',
          'paksha': 'Shukla',
          'tithi': 4,
          'conditions': 'Chaturthi',
          'timingOverride': 'madhyahna',
        },
      });

  /// Jagannath Rath Yatra: Ashadha Shukla Dwitiya. Used to drive the polar
  /// case, where the day has no solar anchors to export.
  Festival rathYatra() => Festival.fromJson({
        'id': 'jagannath_rath_yatra',
        'name': 'Jagannath Rath Yatra',
        'category': 'major',
        'panchang_rules': {
          'masa': 'Ashadha',
          'paksha': 'Shukla',
          'tithi': 2,
          'conditions': 'Dwitiya',
        },
      });

  Future<Map<String, dynamic>?> exportOne({
    required Festival festival,
    required int year,
    required double latitude,
    required double longitude,
  }) async {
    final json = await FestivalExportService().exportYearJson(
      festivals: [festival],
      service: service,
      latitude: latitude,
      longitude: longitude,
      monthSystem: HinduMonthSystem.amanta,
      yearEra: HinduYearEra.vikramSamvat,
      year: year,
    );
    final document = jsonDecode(json!) as Map<String, dynamic>;
    final festivals = document['festivals'] as List<dynamic>;
    return (festivals.single as Map<String, dynamic>)['occurrence']
        as Map<String, dynamic>?;
  }

  group('FestivalExportService occurrence day', () {
    test('projects sunrise and sunset from the canonical day', () async {
      const latitude = 28.6139;
      const longitude = 77.2090;

      final occurrence = await exportOne(
        festival: ganesh(),
        year: 2026,
        latitude: latitude,
        longitude: longitude,
      );

      expect(occurrence, isNotNull);
      expect(occurrence!['date'], equals('2026-09-14'));
      expect(occurrence['paksha'], equals('Shukla'));
      expect(occurrence['tithiName'], equals('Chaturthi'));
      expect(occurrence['masa'], equals('Bhadrapada'));

      final date = DateTime(2026, 9, 14);
      final sunrise = solarEventsService.sunrise(
        date: date,
        latitude: latitude,
        longitude: longitude,
      );
      final sunset = solarEventsService.sunset(
        date: date,
        latitude: latitude,
        longitude: longitude,
      );
      expect(occurrence['sunrise'], equals(sunrise.toIso8601String()));
      expect(occurrence['sunset'], equals(sunset.toIso8601String()));
    }, skip: skipReason);

    test('a polar location exports null anchors instead of no row', () async {
      // Occurrence resolution used to throw on a place where the Sun does not
      // set (midnight sun), so the row was dropped. The scan now reads the
      // canonical day, whose missing anchors are nulls, so the occurrence
      // resolves and only sunrise/sunset are absent.
      final occurrence = await exportOne(
        festival: rathYatra(),
        year: 2026,
        latitude: 69.6492,
        longitude: 18.9553,
      );

      expect(occurrence, isNotNull);
      expect(occurrence!['date'], equals('2026-07-15'));
      expect(occurrence['sunrise'], isNull);
      expect(occurrence['sunset'], isNull);
    }, skip: skipReason);
  });
}
