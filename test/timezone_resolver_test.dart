import 'package:flutter_test/flutter_test.dart';
import 'package:tithi/core/location/location_defaults.dart';
import 'package:tithi/core/location/timezone_resolver.dart';

void main() {
  group('canonicalTimezoneId', () {
    test('maps the legacy Asia/Calcutta alias', () {
      expect(canonicalTimezoneId('Asia/Calcutta'), 'Asia/Kolkata');
    });

    test('trims surrounding whitespace', () {
      expect(canonicalTimezoneId('  Europe/Paris  '), 'Europe/Paris');
    });

    test('returns an empty string for blank input', () {
      expect(canonicalTimezoneId('   '), '');
    });

    test('passes through zones it does not know', () {
      expect(canonicalTimezoneId('Etc/GMT+5'), 'Etc/GMT+5');
    });
  });

  group('resolvePlaceTimezoneId', () {
    test('uses the injected device zone for a non-India place', () async {
      final zone = await resolvePlaceTimezoneId(
        48.8566,
        2.3522,
        deviceTimezone: () async => 'Europe/Paris',
      );

      expect(zone, 'Europe/Paris');
    });

    test('canonicalizes a legacy device zone', () async {
      final zone = await resolvePlaceTimezoneId(
        48.8566,
        2.3522,
        deviceTimezone: () async => 'Asia/Calcutta',
      );

      expect(zone, 'Asia/Kolkata');
    });

    test('falls back to the app default when the plugin fails', () async {
      final zone = await resolvePlaceTimezoneId(
        48.8566,
        2.3522,
        deviceTimezone: () async => throw StateError('plugin unavailable'),
      );

      expect(zone, kDefaultTimezoneId);
    });

    test('falls back to the app default for a blank zone', () async {
      final zone = await resolvePlaceTimezoneId(
        48.8566,
        2.3522,
        deviceTimezone: () async => '   ',
      );

      expect(zone, kDefaultTimezoneId);
    });

    test('rejects invalid coordinates without asking the platform', () async {
      var called = false;

      final zone = await resolvePlaceTimezoneId(
        95,
        200,
        deviceTimezone: () async {
          called = true;
          return 'Europe/Paris';
        },
      );

      expect(zone, kDefaultTimezoneId);
      expect(called, isFalse);
    });
  });
}
