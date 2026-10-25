import 'package:jyotish/jyotish.dart';
import 'package:test/test.dart';

void main() {
  group('GeographicLocation validation', () {
    test('rejects non-finite coordinates and altitude', () {
      expect(
        () => GeographicLocation(latitude: double.nan, longitude: 0),
        throwsArgumentError,
      );
      expect(
        () => GeographicLocation(latitude: 0, longitude: double.infinity),
        throwsArgumentError,
      );
      expect(
        () =>
            GeographicLocation(latitude: 0, longitude: 0, altitude: double.nan),
        throwsArgumentError,
      );
    });

    test('rejects out-of-range decimal coordinates', () {
      expect(
        () => GeographicLocation(latitude: 90.0001, longitude: 0),
        throwsArgumentError,
      );
      expect(
        () => GeographicLocation(latitude: 0, longitude: -180.0001),
        throwsArgumentError,
      );
    });

    test('rejects invalid DMS components', () {
      GeographicLocation build({
        int latDegrees = 0,
        int latMinutes = 0,
        double latSeconds = 0,
        int lonDegrees = 0,
        int lonMinutes = 0,
        double lonSeconds = 0,
      }) =>
          GeographicLocation.fromDMS(
            latDegrees: latDegrees,
            latMinutes: latMinutes,
            latSeconds: latSeconds,
            isNorth: true,
            lonDegrees: lonDegrees,
            lonMinutes: lonMinutes,
            lonSeconds: lonSeconds,
            isEast: true,
          );

      expect(() => build(latDegrees: 91), throwsArgumentError);
      expect(() => build(latMinutes: 60), throwsArgumentError);
      expect(() => build(latMinutes: -1), throwsArgumentError);
      expect(() => build(latSeconds: 60), throwsArgumentError);
      expect(() => build(latSeconds: -0.1), throwsArgumentError);
      expect(() => build(latSeconds: double.nan), throwsArgumentError);
      expect(() => build(lonDegrees: 181), throwsArgumentError);
      expect(() => build(lonMinutes: 60), throwsArgumentError);
      expect(() => build(lonSeconds: 60), throwsArgumentError);
    });

    test('accepts southern and western DMS', () {
      final location = GeographicLocation.fromDMS(
        latDegrees: 22,
        latMinutes: 54,
        latSeconds: 24.48,
        isNorth: false,
        lonDegrees: 43,
        lonMinutes: 10,
        lonSeconds: 22.44,
        isEast: false,
      );

      expect(location.latitude, closeTo(-22.9068, 1e-6));
      expect(location.longitude, closeTo(-43.1729, 1e-6));
    });

    test('toString labels S and W correctly', () {
      final location = GeographicLocation(
        latitude: -22.9068,
        longitude: -43.1729,
      );

      expect(location.toString(), contains('"S'));
      expect(location.toString(), contains('"W'));
    });
  });
}
