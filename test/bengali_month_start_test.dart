import 'package:flutter_test/flutter_test.dart';
import 'package:tithi/services/bengali_calendar/bengali_month_start.dart';

// Phase 3: the Bengali month start used to fall back to a "historic
// approximation" (noon minus degrees-in-sign, Apr-14 anchor) when the
// Sankranti bracket failed, which could be a day off. The resolution is now a
// pure function over a Sun-longitude sampler, so it can be tested without FFI:
// no approximation branch, and a loud failure when the sampler cannot produce
// an ingress.

void main() {
  // Mesha Sankranti; the Sun then moves at its mean rate. Any instant can be
  // sampled, including instants before [epoch] (the modulo keeps 330..360).
  final epoch = DateTime(2026, 4, 14, 6);
  const rate = 0.9856;

  double sunLongitudeAt(DateTime instant) {
    final days =
        instant.difference(epoch).inMicroseconds /
        Duration.microsecondsPerDay;
    return (rate * days) % 360;
  }

  Future<double> sampler(DateTime instant) async => sunLongitudeAt(instant);

  group('resolveBengaliMonthStart', () {
    test('starts the month the day after the Sankranti', () async {
      // Arrange: two days after the Mesha ingress.
      final noon = DateTime(2026, 4, 16, 12);

      // Act
      final result = await resolveBengaliMonthStart(
        monthIndex: 0,
        noon: noon,
        sunLngNow: sunLongitudeAt(noon),
        sunLongitudeAt: sampler,
      );

      // Assert
      expect(result.index, equals(0));
      expect(result.start, equals(DateTime(2026, 4, 15)));
    });

    test('gives the Sankranti civil day to the outgoing month', () async {
      // Arrange: the Sun entered Mesha at 06:00, so noon is already in the
      // new sign while the Bengal rule still keeps the day in Choitro.
      final noon = DateTime(2026, 4, 14, 12);

      // Act
      final result = await resolveBengaliMonthStart(
        monthIndex: 0,
        noon: noon,
        sunLngNow: sunLongitudeAt(noon),
        sunLongitudeAt: sampler,
      );

      // Assert: one month back, not a second Boishakh 1.
      expect(result.index, equals(11));
      expect(result.start, equals(DateTime(2026, 3, 15)));
    });

    test('scans forward when noon is still before the boundary', () async {
      // Arrange: a probe one sign early (Sun at ~356 degrees), so the Mesha
      // ingress is four days ahead and the mean-motion estimate is invalid.
      final noon = DateTime(2026, 4, 10, 12);

      // Act
      final result = await resolveBengaliMonthStart(
        monthIndex: 0,
        noon: noon,
        sunLngNow: sunLongitudeAt(noon),
        sunLongitudeAt: sampler,
      );

      // Assert: the 35-day scan finds the ingress, then the civil day goes to
      // the outgoing month.
      expect(result.index, equals(11));
      expect(result.start, equals(DateTime(2026, 3, 15)));
    });

    test('throws instead of returning a day-off approximation', () async {
      // Arrange: a sampler that never moves cannot produce a Sankranti.
      final noon = DateTime(2026, 4, 16, 12);

      // Act + Assert
      await expectLater(
        resolveBengaliMonthStart(
          monthIndex: 0,
          noon: noon,
          sunLngNow: 0,
          sunLongitudeAt: (instant) async => 0,
        ),
        throwsA(isA<BengaliMonthStartException>()),
      );
    });
  });
}
