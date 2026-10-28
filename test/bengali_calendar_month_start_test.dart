import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tithi/providers/calendar_provider.dart';
import 'package:tithi/providers/panchang_provider.dart';
import 'package:tithi/models/panchang_school.dart';
import 'package:tithi/services/bengali_calendar_service.dart';
import 'package:tithi/services/panchang_service.dart';

// The Bengal rule starts a solar month on the day AFTER the sankranti civil
// date. The Sun enters Mesha on the sankranti day, so the rashi at noon is
// already the new month while the civil day still belongs to the outgoing one.
// `_resolveMonthStart` used to return the noon date in that case, which made
// 2026-04-14 claim day 1 of a month that starts on 2026-04-15 - two Boishakh 1s.
//
// These tests lock the month-start resolution itself, independent of the
// golden fixture: the fixture records one day per city, this records the
// transition and the "one start per month" invariant.

void main() {
  final libPath = Platform.environment['SWISSEPH_LIB_PATH'];
  final libraryAvailable =
      libPath != null && libPath.isNotEmpty && File(libPath).existsSync();
  final skipReason = libraryAvailable
      ? null
      : 'Set SWISSEPH_LIB_PATH to a host Swiss Ephemeris library to run the '
            'Bengali month-start tests.';

  TestWidgetsFlutterBinding.ensureInitialized();

  late ProviderContainer container;
  late BengaliCalendarService bengali;
  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('tithi_bengali_start');
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async => tempDir.path);
    await PanchangService().init();

    container = ProviderContainer(
      overrides: [
        panchangInitProvider.overrideWith((ref) async {}),
        // The Bengali calendar follows the persisted calculation school, so
        // without this the provider chain would read the closed settings box.
        panchangSchoolProvider.overrideWithValue(PanchangSchool.bisuddha),
      ],
    );
    bengali = container.read(bengaliCalendarServiceProvider);
  });

  tearDownAll(() async {
    container.dispose();
    try {
      await tempDir.delete(recursive: true);
    } on FileSystemException {
      // The native library keeps the copied ephemeris files open on Windows.
    }
  });

  Future<({int day, String month, int year})> dateAt(DateTime date) async {
    final value = await bengali.calculateDate(date);
    return (day: value.day, month: value.month, year: value.year);
  }

  test('the sankranti civil day belongs to the outgoing month', () async {
    expect(
      await dateAt(DateTime(2026, 4, 13)),
      equals((day: 29, month: 'Choitro', year: 1432)),
    );
    // Mesha sankranti is 2026-04-14, so Poila Boishakh 1433 is 2026-04-15 and
    // the sankranti day is Choitro 30 - not a second Boishakh 1.
    expect(
      await dateAt(DateTime(2026, 4, 14)),
      equals((day: 30, month: 'Choitro', year: 1432)),
    );
    expect(
      await dateAt(DateTime(2026, 4, 15)),
      equals((day: 1, month: 'Boishakh', year: 1433)),
    );
  }, skip: skipReason);

  test('month starts resolve to the day after the sankranti', () async {
    expect(await bengali.getMonthStart(1433, 0), equals(DateTime(2026, 4, 15)));
    expect(
      await bengali.getMonthStart(1432, 11),
      equals(DateTime(2026, 3, 16)),
    );
  }, skip: skipReason);

  test('resolving backwards gives the same transition', () async {
    // The month-start cache must not let the first resolved day decide the
    // month for an earlier day. Walk the same window in reverse.
    final results = <DateTime, ({int day, String month, int year})>{};
    for (var day = 17; day >= 10; day--) {
      final date = DateTime(2026, 4, day);
      results[date] = await dateAt(date);
    }

    expect(
      results[DateTime(2026, 4, 14)],
      equals((day: 30, month: 'Choitro', year: 1432)),
    );
    expect(
      results[DateTime(2026, 4, 15)],
      equals((day: 1, month: 'Boishakh', year: 1433)),
    );
  }, skip: skipReason);

  test('every day advances the Bengali date by exactly one', () async {
    var previous = await dateAt(DateTime(2026, 4));
    var starts = 0;

    for (var day = 2; day <= 30; day++) {
      final current = await dateAt(DateTime(2026, 4, day));
      if (current.month != previous.month || current.year != previous.year) {
        expect(current.day, equals(1), reason: 'a new month must start at 1');
        starts++;
      } else {
        expect(current.day, equals(previous.day + 1));
      }
      previous = current;
    }

    expect(starts, equals(1), reason: 'April 2026 crosses one month boundary');
  }, skip: skipReason);

  test('a year has exactly one Boishakh 1', () async {
    for (final year in [2025, 2026, 2027]) {
      final starts = <DateTime>[];
      for (var day = 10; day <= 20; day++) {
        final date = DateTime(year, 4, day);
        final value = await dateAt(date);
        if (value.month == 'Boishakh' && value.day == 1) starts.add(date);
      }
      expect(
        starts,
        hasLength(1),
        reason: 'Poila Boishakh $year must appear exactly once in Apr 10-20',
      );
      if (year == 2026) {
        expect(starts.single, equals(DateTime(2026, 4, 15)));
      }
    }
  }, skip: skipReason);
}
