import 'package:jyotish/jyotish.dart';
import 'package:test/test.dart';

/// Verifies the opt-in native sidereal frame:
/// - `SEFLG_SIDEREAL` is only requested when asked for,
/// - the native and historical manual paths agree closely,
/// - the cache does not mix the two frames.
void main() {
  group('Native sidereal positions', () {
    late Jyotish jyotish;

    final location = GeographicLocation(latitude: 28.6139, longitude: 77.2090);
    final dateTime = DateTime.utc(2024, 1, 1, 12);

    setUpAll(() async {
      jyotish = Jyotish();
      await jyotish.initialize();
    });

    tearDownAll(() {
      jyotish.dispose();
    });

    test('manual and native Lahiri Sun agree within an arcminute', () async {
      final manual = await jyotish.getPlanetPosition(
        planet: Planet.sun,
        dateTime: dateTime,
        location: location,
      );
      final native = await jyotish.getPlanetPosition(
        planet: Planet.sun,
        dateTime: dateTime,
        location: location,
        flags: CalculationFlags.nativeSidereal(SiderealMode.lahiri),
      );

      final separation =
          (native.longitude - manual.longitude + 540) % 360 - 180;
      expect(separation.abs(), lessThan(1 / 60));

      expect(
        manual.provenance!.requestedFlags & SwissEphBindings.SEFLG_SIDEREAL,
        0,
      );
      expect(
        native.provenance!.requestedFlags & SwissEphBindings.SEFLG_SIDEREAL,
        SwissEphBindings.SEFLG_SIDEREAL,
      );
    });

    test('native sidereal Moon uses the same frame', () async {
      final manual = await jyotish.getPlanetPosition(
        planet: Planet.moon,
        dateTime: dateTime,
        location: location,
      );
      final native = await jyotish.getPlanetPosition(
        planet: Planet.moon,
        dateTime: dateTime,
        location: location,
        flags: CalculationFlags.nativeSidereal(SiderealMode.lahiri),
      );

      final separation =
          (native.longitude - manual.longitude + 540) % 360 - 180;
      expect(separation.abs(), lessThan(1 / 60));
    });

    test('rejects native sidereal together with tropical', () async {
      await expectLater(
        jyotish.getPlanetPosition(
          planet: Planet.sun,
          dateTime: dateTime,
          location: location,
          flags: const CalculationFlags(
            useTropical: true,
            useNativeSidereal: true,
          ),
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

    test('cache keeps manual and native frames apart', () async {
      final manual = await jyotish.getPlanetPosition(
        planet: Planet.sun,
        dateTime: DateTime.utc(2024, 2, 1, 12),
        location: location,
      );
      final native = await jyotish.getPlanetPosition(
        planet: Planet.sun,
        dateTime: DateTime.utc(2024, 2, 1, 12),
        location: location,
        flags: CalculationFlags.nativeSidereal(SiderealMode.lahiri),
      );

      expect(identical(manual, native), isFalse);
      expect(
        native.provenance!.requestedFlags,
        isNot(manual.provenance!.requestedFlags),
      );
    });
  });
}
