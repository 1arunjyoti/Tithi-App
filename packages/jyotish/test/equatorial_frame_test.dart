import 'package:jyotish/jyotish.dart';
import 'package:test/test.dart';

void main() {
  group('Equatorial coordinate frame', () {
    late Jyotish jyotish;

    setUpAll(() async {
      jyotish = Jyotish();
      await jyotish.initialize();
    });

    tearDownAll(() {
      jyotish.dispose();
    });

    test('rejects a sidereal equatorial request', () async {
      await expectLater(
        jyotish.getPlanetPosition(
          planet: Planet.sun,
          dateTime: DateTime.utc(2024, 1, 1, 12),
          location: GeographicLocation(latitude: 0, longitude: 0),
          flags: const CalculationFlags(useEquatorial: true),
        ),
        throwsA(
          isA<JyotishException>().having(
            (error) => error.originalError,
            'originalError',
            isA<ArgumentError>(),
          ),
        ),
      );
    });

    test('allows tropical equatorial coordinates', () async {
      final position = await jyotish.getPlanetPosition(
        planet: Planet.sun,
        dateTime: DateTime.utc(2024, 1, 1, 12),
        location: GeographicLocation(latitude: 0, longitude: 0),
        flags: const CalculationFlags(
          useEquatorial: true,
          useTropical: true,
        ),
      );

      expect(position.longitude, inInclusiveRange(0, 360));
      expect(position.latitude, inInclusiveRange(-90, 90));
    });
  });
}
