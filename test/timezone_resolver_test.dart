import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import 'package:tithi/core/location/location_defaults.dart';
import 'package:tithi/core/location/timezone_resolver.dart';

void main() {
  setUpAll(() {
    // The boundary lookup needs the full tzdb: `latest` omits 106 of the 419
    // identifiers the boundary data can return.
    if (!tz.timeZoneDatabase.isInitialized) {
      tz_data.initializeTimeZones();
    }
  });

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

  group('TimezoneSource', () {
    test('round-trips every value through its stored form', () {
      for (final source in TimezoneSource.values) {
        expect(TimezoneSource.parse(source.storageValue), source);
      }
    });

    test('treats a missing or unknown marker as legacy', () {
      expect(TimezoneSource.parse(null), isNull);
      expect(TimezoneSource.parse(''), isNull);
      expect(TimezoneSource.parse('planet'), isNull);
      expect(TimezoneSource.parse(3), isNull);
    });
  });

  group('resolvePlaceTimezone', () {
    test('resolves the zone of the place, not the device', () async {
      var deviceAsked = false;

      final resolved = await resolvePlaceTimezone(
        25.3176, // Varanasi
        82.9739,
        deviceTimezone: () async {
          deviceAsked = true;
          return 'America/New_York';
        },
      );

      expect(resolved.id, 'Asia/Kolkata');
      expect(resolved.source, TimezoneSource.place);
      expect(
        deviceAsked,
        isFalse,
        reason: 'A land coordinate must not consult the device zone.',
      );
    });

    test('resolves zones across the world', () async {
      final expectations = <(double, double, String)>[
        (28.6139, 77.2090, 'Asia/Kolkata'), // Delhi
        (27.7172, 85.3240, 'Asia/Kathmandu'), // Kathmandu (+05:45)
        (51.5074, -0.1278, 'Europe/London'), // London
        (40.7128, -74.0060, 'America/New_York'), // New York
      ];

      for (final (latitude, longitude, expected) in expectations) {
        final resolved = await resolvePlaceTimezone(
          latitude,
          longitude,
          deviceTimezone: () async => 'Asia/Kolkata',
        );
        expect(resolved.id, expected, reason: 'at $latitude, $longitude');
        expect(resolved.source, TimezoneSource.place);
      }
    });

    test('falls back to the device zone over open ocean', () async {
      // No land polygon here: the boundary data returns no location.
      final resolved = await resolvePlaceTimezone(
        0.0, // latitude
        -140.0, // longitude: Pacific Ocean, no land polygon
        deviceTimezone: () async => 'Europe/Paris',
      );

      expect(resolved.id, 'Europe/Paris');
      expect(resolved.source, TimezoneSource.device);
    });

    test('canonicalizes a legacy device zone', () async {
      final resolved = await resolvePlaceTimezone(
        0.0, // latitude
        -140.0, // longitude: Pacific Ocean, no land polygon
        deviceTimezone: () async => 'Asia/Calcutta',
      );

      expect(resolved.id, 'Asia/Kolkata');
      expect(resolved.source, TimezoneSource.device);
    });

    test('falls back to the app default when the plugin fails', () async {
      final resolved = await resolvePlaceTimezone(
        0.0, // latitude
        -140.0, // longitude: Pacific Ocean, no land polygon
        deviceTimezone: () async => throw StateError('plugin unavailable'),
      );

      expect(resolved.id, kDefaultTimezoneId);
      expect(resolved.source, TimezoneSource.device);
    });

    test('falls back to the app default for a blank device zone', () async {
      final resolved = await resolvePlaceTimezone(
        0.0, // latitude
        -140.0, // longitude: Pacific Ocean, no land polygon
        deviceTimezone: () async => '   ',
      );

      expect(resolved.id, kDefaultTimezoneId);
      expect(resolved.source, TimezoneSource.device);
    });

    test('rejects invalid coordinates without asking the platform', () async {
      var called = false;

      final resolved = await resolvePlaceTimezone(
        95,
        200,
        deviceTimezone: () async {
          called = true;
          return 'Europe/Paris';
        },
      );

      expect(resolved.id, kDefaultTimezoneId);
      expect(resolved.source, TimezoneSource.device);
      expect(called, isFalse);
    });
  });
}
