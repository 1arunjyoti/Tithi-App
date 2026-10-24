import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tithi/core/notifications/scheduler.dart';
import 'package:tithi/models/hindu_month_system.dart';
import 'package:tithi/services/panchang_service.dart';
import 'package:tithi/services/solar_events_service.dart';

// The notification scheduler used to assemble its own day and pre-read
// sunrise at both call sites, so a polar location threw before any
// notification was scheduled. It now reads the canonical day.

void main() {
  final libPath = Platform.environment['SWISSEPH_LIB_PATH'];
  final libraryAvailable =
      libPath != null && libPath.isNotEmpty && File(libPath).existsSync();
  final skipReason = libraryAvailable
      ? null
      : 'Set SWISSEPH_LIB_PATH to a host Swiss Ephemeris library to run the '
            'scheduler day tests.';

  TestWidgetsFlutterBinding.ensureInitialized();

  late PanchangService service;
  late NotificationScheduler scheduler;
  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('tithi_scheduler_day');
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async => tempDir.path);
    service = PanchangService();
    await service.init();
    scheduler = NotificationScheduler(
      plugin: FlutterLocalNotificationsPlugin(),
      box: null,
    );
  });

  group('NotificationScheduler.computePanchangForDate', () {
    test('matches the direct reads for an ordinary day', () async {
      const latitude = 28.6139;
      const longitude = 77.2090;
      final date = DateTime(2026, 9, 4);

      final data = await scheduler.computePanchangForDate(
        date: date,
        service: service,
        latitude: latitude,
        longitude: longitude,
        festivals: const [],
        monthSystem: HinduMonthSystem.amanta,
      );

      final sunrise = solarEventsService.sunrise(
        date: date,
        latitude: latitude,
        longitude: longitude,
        timezoneId: 'Asia/Kolkata',
      );
      expect(data.sunrise, sunrise);
      expect(data.sunset, isNotNull);
      expect(data.tithiNumber, inInclusiveRange(1, 15));
      expect(data.paksha, anyOf('Shukla', 'Krishna'));
      expect(data.masa, isNotEmpty);
      expect(data.hasFestivals, isFalse);
      expect(data.hasTithiTransition, isFalse);
    }, skip: skipReason);

    test('returns a day, not an exception, at polar latitudes', () async {
      final data = await scheduler.computePanchangForDate(
        date: DateTime(2026, 12, 21),
        service: service,
        latitude: 69.6492,
        longitude: 18.9553,
        festivals: const [],
        monthSystem: HinduMonthSystem.amanta,
      );

      expect(data.sunrise, isNull);
      expect(data.sunset, isNull);
      expect(data.tithiNumber, inInclusiveRange(1, 15));
      expect(data.tithiName, isNotEmpty);
      expect(data.masa, isNotEmpty);
    }, skip: skipReason);
  });
}
