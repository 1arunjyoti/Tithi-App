import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import 'package:tithi/core/location/place_clock.dart';

void main() {
  setUpAll(() {
    if (!tz.timeZoneDatabase.isInitialized) {
      tz_data.initializeTimeZones();
    }
  });

  group('resolvePlaceClock', () {
    test('live location uses the device clock', () {
      // Arrange / Act
      final clock = resolvePlaceClock(
        locationEnabled: true,
        homeTimezoneId: 'Asia/Kolkata',
      );

      // Assert: the stored home zone is ignored while live tracking is on.
      expect(clock.mode, PlaceClockMode.device);
      expect(clock.zoneId, isNull);
    });

    test('a manually picked place uses its own zone', () {
      // Arrange / Act
      final clock = resolvePlaceClock(
        locationEnabled: false,
        homeTimezoneId: 'America/New_York',
      );

      // Assert
      expect(clock.mode, PlaceClockMode.place);
      expect(clock.zoneId, 'America/New_York');
    });

    test('a manual place without a resolved zone falls back to Delhi', () {
      // Arrange / Act
      final clock = resolvePlaceClock(locationEnabled: false);

      // Assert
      expect(clock.mode, PlaceClockMode.place);
      expect(clock.zoneId, 'Asia/Kolkata');
    });

    test('legacy zone aliases are canonicalized', () {
      // Arrange / Act
      final clock = resolvePlaceClock(
        locationEnabled: false,
        homeTimezoneId: 'Asia/Calcutta',
      );

      // Assert: the same zone the tzdb lookup and the cache key use.
      expect(clock.zoneId, 'Asia/Kolkata');
    });
  });

  group('place clock helpers', () {
    test('civilDateInPlaceClock maps an instant to the place civil date', () {
      // 20:30 UTC is already the next day in India, still the same day in
      // New York. This is the off-by-one the clock exists to prevent.
      final instant = DateTime.utc(2026, 10, 24, 20, 30);

      expect(
        civilDateInPlaceClock(
          (mode: PlaceClockMode.place, zoneId: 'Asia/Kolkata'),
          instant,
        ),
        DateTime(2026, 10, 25),
      );
      expect(
        civilDateInPlaceClock(
          (mode: PlaceClockMode.place, zoneId: 'America/New_York'),
          instant,
        ),
        DateTime(2026, 10, 24),
      );
    });

    test('device clock keeps the instant own civil date', () {
      final instant = DateTime.utc(2026, 10, 24, 20, 30);

      expect(civilDateInPlaceClock(kDeviceClock, instant), DateTime(2026, 10, 24));
    });

    test('nextMidnightInPlaceClock lands on the clock next midnight', () {
      // Arrange
      const clock = (mode: PlaceClockMode.place, zoneId: 'Asia/Kolkata');

      // Act
      final now = nowInPlaceClock(clock);
      final midnight = nextMidnightInPlaceClock(clock);

      // Assert
      expect(midnight.isAfter(now), isTrue);
      expect(midnight.hour, 0);
      expect(midnight.minute, 0);
      expect(
        midnight.difference(now),
        lessThanOrEqualTo(const Duration(hours: 24)),
      );
    });

    test('unknown zone identifiers fall back to the device clock', () {
      // Arrange
      const clock = (mode: PlaceClockMode.place, zoneId: 'Not/AZone');

      // Assert: no throw, no lookup - the device zone applies.
      expect(placeClockLocation(clock), isNull);
    });

    test('zone label only appears when the place zone differs', () {
      // Arrange / Act
      final deviceLabel = placeClockZoneLabel(kDeviceClock);
      final placeLabel = placeClockZoneLabel((
        mode: PlaceClockMode.place,
        zoneId: 'Asia/Kolkata',
      ));

      // Assert
      expect(deviceLabel, isNull);
      if (tz.local.name == 'Asia/Kolkata') {
        expect(placeLabel, isNull);
      } else {
        expect(placeLabel, isNotNull);
        expect(placeLabel!.isNotEmpty, isTrue);
      }
    });
  });
}
