// ignore_for_file: avoid_print

// SCRATCH diagnostic: tithi curve + sun longitudes around Mar 2067.
// DELETE AFTER USE. Run with:
// flutter test integration_test/adhika_probe_test.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:jyotish/jyotish.dart';
import 'package:tithi/providers/panchang_provider.dart';
import 'package:tithi/services/panchang_service.dart';
import 'package:tithi/services/sunrise_calculator.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('probe Mar 2067 tithi curve and sun longitudes', (tester) async {
    final container = ProviderContainer(
      overrides: [
        resolvedCoordinatesProvider.overrideWithValue(
          (latitude: 28.6139, longitude: 77.2090),
        ),
      ],
    );
    addTearDown(container.dispose);

    final service = container.read(panchangServiceProvider);
    await service.init();
    const lat = 28.6139;
    const lng = 77.2090;
    final loc = GeographicLocation(latitude: lat, longitude: lng);

    for (int day = 10; day <= 25; day++) {
      final date = DateTime(2067, 3, day);
      final sunrise = SunriseCalculator.calculateSunriseIST(
        date: date,
        latitude: lat,
        longitude: lng,
      );
      final tithi = await service.calculateTithi(
        sunrise,
        latitude: lat,
        longitude: lng,
      );
      final masa = await service.calculateMasa(
        sunrise,
        tithi,
        latitude: lat,
        longitude: lng,
      );
      print('Mar $day sunrise=$sunrise tithi=$tithi masa=$masa');
    }

    for (final d in [13, 14, 15, 16]) {
      final sun = await Jyotish().getPlanetPosition(
        planet: Planet.sun,
        dateTime: DateTime(2067, 3, d, 12),
        location: loc,
      );
      print('sun Mar $d noon longitude=${sun.longitude}');
    }
    for (final d in [12, 13, 14]) {
      final sun = await Jyotish().getPlanetPosition(
        planet: Planet.sun,
        dateTime: DateTime(2067, 4, d, 12),
        location: loc,
      );
      print('sun Apr $d noon longitude=${sun.longitude}');
    }
  });
}
