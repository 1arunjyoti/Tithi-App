import 'package:flutter_test/flutter_test.dart';
import 'package:tithi/core/location/location_defaults.dart';
import 'package:tithi/services/location_service.dart';

void main() {
  group('LocationData', () {
    test('defaultLocation carries the Delhi altitude and zone', () {
      final location = LocationData.defaultLocation;

      expect(location.latitude, kDefaultLatitude);
      expect(location.longitude, kDefaultLongitude);
      expect(location.altitudeMeters, kDefaultAltitudeMeters);
      expect(location.timezoneId, kDefaultTimezoneId);
    });

    test('altitude and timezone stay optional for pre-existing callers', () {
      final location = LocationData(
        latitude: 0,
        longitude: 0,
        timestamp: DateTime(2026),
      );

      expect(location.altitudeMeters, isNull);
      expect(location.timezoneId, isNull);
    });
  });
}
