import 'package:jyotish/jyotish.dart';
import 'package:test/test.dart';

/// This file verifies the house calculation contract:
/// - the requested house system is the one calculated and labelled,
/// - cusps and angles come from Swiss Ephemeris' native sidereal path,
/// - no ayanamsa is subtracted a second time from right ascensions or cusps.
void main() {
  group('Vedic houses', () {
    late Jyotish jyotish;

    final location = GeographicLocation(latitude: 28.6139, longitude: 77.2090);
    final dateTime = DateTime.utc(1990, 5, 15, 9);

    setUpAll(() async {
      jyotish = Jyotish();
      await jyotish.initialize();
    });

    tearDownAll(() {
      jyotish.dispose();
    });

    test('defaults to whole sign with equal 30 degree cusps', () async {
      final chart = await jyotish.calculateVedicChart(
        dateTime: dateTime,
        location: location,
      );

      expect(chart.houses.system, 'Whole Sign');
      expect(chart.houses.cusps, hasLength(12));
      for (var i = 0; i < 12; i++) {
        final span =
            (chart.houses.cusps[(i + 1) % 12] - chart.houses.cusps[i] + 360) %
                360;
        expect(span, closeTo(30, 1e-6), reason: 'cusp ${i + 1} span');
      }
    });

    test('whole sign cusps match native sidereal swe_houses_ex', () async {
      final expected = _nativeHouses(
        dateTime: dateTime,
        location: location,
        houseSystem: 'W',
      );
      final chart = await jyotish.calculateVedicChart(
        dateTime: dateTime,
        location: location,
      );

      for (var i = 0; i < 12; i++) {
        expect(
          chart.houses.cusps[i],
          closeTo(expected['cusps']![i], 1e-9),
          reason: 'cusp ${i + 1}',
        );
      }
      expect(
        chart.houses.ascendant,
        closeTo(expected['ascmc']![0], 1e-9),
      );
      expect(
        chart.houses.midheaven,
        closeTo(expected['ascmc']![1], 1e-9),
      );
    });

    test('honours the requested Placidus system', () async {
      final expected = _nativeHouses(
        dateTime: dateTime,
        location: location,
        houseSystem: 'P',
      );
      final chart = await jyotish.calculateVedicChart(
        dateTime: dateTime,
        location: location,
        houseSystem: 'P',
      );

      expect(chart.houses.system, 'Placidus');
      for (var i = 0; i < 12; i++) {
        expect(
          chart.houses.cusps[i],
          closeTo(expected['cusps']![i], 1e-9),
          reason: 'cusp ${i + 1}',
        );
      }
      expect(
        chart.houses.ascendant,
        closeTo(expected['ascmc']![0], 1e-9),
      );
      expect(
        chart.houses.midheaven,
        closeTo(expected['ascmc']![1], 1e-9),
      );

      // Placidus is not a whole-sign chart; at Delhi the spans are unequal.
      final spans = <double>[
        for (var i = 0; i < 12; i++)
          (chart.houses.cusps[(i + 1) % 12] - chart.houses.cusps[i] + 360) %
              360,
      ];
      expect(spans.any((span) => (span - 30).abs() > 0.5), isTrue);
    });

    test('rejects an unsupported house system', () async {
      await expectLater(
        jyotish.calculateVedicChart(
          dateTime: dateTime,
          location: location,
          houseSystem: 'Z',
        ),
        throwsA(isA<JyotishException>()),
      );
    });

    test('describes southern and western coordinates', () async {
      final chart = await jyotish.calculateVedicChart(
        dateTime: dateTime,
        location: GeographicLocation(
          latitude: -22.9068,
          longitude: -43.1729,
        ),
      );

      expect(chart.location, '22.9068°S, 43.1729°W');
    });
  });
}

Map<String, List<double>> _nativeHouses({
  required DateTime dateTime,
  required GeographicLocation location,
  required String houseSystem,
}) {
  final bindings = SwissEphBindings();
  bindings.setSiderealMode(SwissEphConstants.sidmLahiri, 0.0, 0.0);

  final utc = dateTime.toUtc();
  final hour = utc.hour +
      (utc.minute / 60.0) +
      (utc.second / 3600.0) +
      (utc.millisecond / 3600000.0);
  final julianDay = bindings.julianDay(
    year: utc.year,
    month: utc.month,
    day: utc.day,
    hour: hour,
  );

  final result = bindings.calculateHouses(
    julianDay: julianDay,
    latitude: location.latitude,
    longitude: location.longitude,
    houseSystem: houseSystem,
    flags: SwissEphBindings.SEFLG_SIDEREAL,
  );
  return result!;
}
