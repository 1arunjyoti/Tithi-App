import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:jyotish/jyotish.dart';

/// This is the app-side contract for the package's data-range report: the
/// bundled `.se1` files must actually load, cover 1800-2399, and be the backend
/// that produced the position.
void main() {
  late Jyotish jyotish;

  setUpAll(() async {
    jyotish = Jyotish();
    await jyotish.initialize(
      ephemerisPath: Directory('assets/ephe').absolute.path,
    );
  });

  tearDownAll(() {
    jyotish.dispose();
  });

  test('loaded files cover the bundled 1800-2399 range', () async {
    final range = await jyotish.probeDataRange();

    expect(
      range.coversYears(1800, 2399),
      isTrue,
      reason: '$range',
    );
    expect(range.planets, isNotNull);
    expect(range.moon, isNotNull);
    expect(range.planets!.path, contains('sepl_18.se1'));
    expect(range.moon!.path, contains('semo_18.se1'));
  });

  test('a position reports Swiss Ephemeris rather than Moshier', () async {
    final position = await jyotish.getPlanetPosition(
      planet: Planet.sun,
      dateTime: DateTime.utc(2024, 1, 1, 12),
      location: GeographicLocation(latitude: 28.6139, longitude: 77.2090),
    );

    expect(position.provenance, isNotNull);
    expect(position.provenance!.isSwissEphemeris, isTrue,
        reason: '${position.provenance}');
    expect(position.provenance!.usedFallback, isFalse);
    expect(position.provenance!.warning, isNull);
  });
}
