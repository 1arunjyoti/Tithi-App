import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tithi/providers/panchang_provider.dart';
import 'package:tithi/services/hindu_calendar_service.dart';
import 'package:tithi/models/hindu_month_system.dart';
import 'package:tithi/services/panchang_service.dart';

/// Scripted lunation data modelling a synthetic Adhika year:
///
/// Vaishakha      Apr 18 – May 16 2026
/// Adhika Jyeshtha May 17 – Jun 14 2026
/// Nija Jyeshtha   Jun 15 – Jul 13 2026 (Kshaya Pratipada: no sunrise
///                 observes tithi 1 — first sunrise is Dwitiya)
/// Ashadha         Jul 14 – Aug 11 2026
///
/// Regression coverage for the Hindu-primary calendar mixing Adhika and Nija
/// days into one grid: month slicing used baseMasaName (prefix stripped) +
/// index arithmetic, which merged both masas (~59-day span) and skipped Nija
/// on navigation. The Kshaya Pratipada in Nija additionally guards the
/// masa-transition boundary model (tithi-1 scans cannot resolve it).
class _FakeAdhikaPanchangService extends PanchangService {
  static final List<({DateTime start, DateTime end, String masa})> _masas = [
    (
      start: DateTime(2026, 2, 19),
      end: DateTime(2026, 3, 20),
      masa: 'Phalguna',
    ),
    (
      start: DateTime(2026, 3, 21),
      end: DateTime(2026, 4, 17),
      masa: 'Chaitra',
    ),
    (
      start: DateTime(2026, 4, 18),
      end: DateTime(2026, 5, 16),
      masa: 'Vaishakha',
    ),
    (
      start: DateTime(2026, 5, 17),
      end: DateTime(2026, 6, 14),
      masa: 'Adhika_Jyeshtha',
    ),
    (
      start: DateTime(2026, 6, 15),
      end: DateTime(2026, 7, 13),
      masa: 'Nija_Jyeshtha',
    ),
    (
      start: DateTime(2026, 7, 14),
      end: DateTime(2026, 8, 11),
      masa: 'Ashadha',
    ),
    (
      start: DateTime(2026, 8, 12),
      end: DateTime(2026, 9, 9),
      masa: 'Shravana',
    ),
  ];

  static ({DateTime start, String masa}) _rangeFor(DateTime day) {
    for (final range in _masas) {
      if (!day.isBefore(range.start) && !day.isAfter(range.end)) {
        return (start: range.start, masa: range.masa);
      }
    }
    throw StateError('Fake has no masa scripted for $day');
  }

  /// Tithi for [day]: day-index within its masa (1-based), except the Nija
  /// span whose Pratipada is Kshaya — its first sunrise already observes
  /// Dwitiya, so no date in range reports tithi 1.
  static double _tithiFor(DateTime day) {
    final range = _rangeFor(day);
    final index = day.difference(range.start).inDays;
    if (range.masa == 'Nija_Jyeshtha') return index + 2.0;
    return index + 1.0;
  }

  @override
  Future<void> init() async {}

  @override
  Future<double> calculateTithi(
    DateTime date, {
    double latitude = 28.6139,
    double longitude = 77.2090,
  }) async {
    final day = DateTime(date.year, date.month, date.day);
    return _tithiFor(day);
  }

  @override
  Future<String> calculateMasa(
    DateTime date,
    double rawTithi, {
    double latitude = 28.6139,
    double longitude = 77.2090,
  }) async {
    final day = DateTime(date.year, date.month, date.day);
    return _rangeFor(day).masa;
  }
}

void main() {
  late ProviderContainer container;
  late HinduCalendarService service;

  setUp(() {
    container = ProviderContainer(
      overrides: [
        panchangServiceProvider.overrideWithValue(
          _FakeAdhikaPanchangService(),
        ),
        resolvedCoordinatesProvider.overrideWithValue(
          (latitude: 28.6139, longitude: 77.2090),
        ),
        panchangInitProvider.overrideWith((ref) => Future.value()),
      ],
    );
    addTearDown(container.dispose);
    service = container.read(hinduCalendarServiceProvider);
  });

  group('Adhika month boundaries', () {
    test('monthStartContaining stays inside Adhika masa', () async {
      // Arrange
      final midAdhika = DateTime(2026, 6);

      // Act
      final start = await service.monthStartContaining(midAdhika);

      // Assert: Adhika start, not an estimate inside the neighboring masa
      expect(start, equals(DateTime(2026, 5, 17)));
    });

    test('monthStartContaining resolves Nija masa separately', () async {
      // Arrange
      final midNija = DateTime(2026, 6, 20);

      // Act
      final start = await service.monthStartContaining(midNija);

      // Assert
      expect(start, equals(DateTime(2026, 6, 15)));
    });

    test('nextMonthStartAfter Adhika lands on Nija, not Ashadha', () async {
      // Arrange
      final adhikaStart = DateTime(2026, 5, 17);

      // Act
      final next = await service.nextMonthStartAfter(adhikaStart);

      // Assert
      expect(next, equals(DateTime(2026, 6, 15)));
    });

    test('nextMasaStartFrom mid-Adhika and Nija Pratipada', () async {
      // Act + Assert: Adhika Pratipada -> Nija start
      expect(
        await service.nextMasaStartFrom(DateTime(2026, 5, 17)),
        equals(DateTime(2026, 6, 15)),
      );
      // Mid-Nija -> Ashadha start
      expect(
        await service.nextMasaStartFrom(DateTime(2026, 6, 20)),
        equals(DateTime(2026, 7, 14)),
      );
      // Exactly on Nija Pratipada -> still Ashadha (skips itself)
      expect(
        await service.nextMasaStartFrom(DateTime(2026, 6, 15)),
        equals(DateTime(2026, 7, 14)),
      );
    });

    test('prevMasaStartFrom Nija lands on Adhika, not Vaishakha', () async {
      // Arrange
      final midNija = DateTime(2026, 6, 20);

      // Act
      final prev = await service.prevMasaStartFrom(midNija);

      // Assert: old index arithmetic returned the Vaishakha start here
      expect(prev, equals(DateTime(2026, 5, 17)));
    });

    test('prevMasaStartFrom Ashadha lands on Nija', () async {
      // Arrange
      final midAshadha = DateTime(2026, 7, 20);

      // Act
      final prev = await service.prevMasaStartFrom(midAshadha);

      // Assert
      expect(prev, equals(DateTime(2026, 6, 15)));
    });

    test('getMonthStart finds the first (Adhika) occurrence', () async {
      // Arrange: Jyeshtha is hinduMonths[2]; VS 2083 covers May-Jul 2026
      // Act
      final start = await service.getMonthStart(2083, 2);

      // Assert: previously fell through to the estimate fallback because
      // both Adhika_ and Nija_ days were skipped by the search
      expect(start, equals(DateTime(2026, 5, 17)));
    });

    test('grid spans hold exactly one masa (matches per-date mode)', () async {
      // Arrange: every lunar month start in the scripted year. In
      // Gregorian-primary mode each date carries its own masa label, so
      // mixing is impossible there; this locks the Hindu-primary grid to
      // the same single-masa invariant (the reported bug showed Adhika +
      // Nija days in one grid).
      final starts = [
        DateTime(2026, 5, 17), // Adhika Jyeshtha
        DateTime(2026, 6, 15), // Nija Jyeshtha
        DateTime(2026, 7, 14), // Ashadha
      ];

      // Act + Assert
      for (final start in starts) {
        final startMasa = (await service.calculateDate(start)).masa;
        final next = await service.nextMonthStartAfter(start);
        var day = start;
        while (day.isBefore(next)) {
          final masa = (await service.calculateDate(day)).masa;
          expect(
            masa,
            equals(startMasa),
            reason: '$day must belong to $startMasa (grid of $start)',
          );
          day = day.add(const Duration(days: 1));
        }
        // Chain links with no gaps or overlaps.
        expect(
          await service.monthStartContaining(next),
          equals(next),
          reason: 'month after $start starts exactly at $next',
        );
      }
    });

    test('Kshaya Pratipada Nija month still slices exactly', () async {
      // The scripted Nija span has NO sunrise observing tithi 1 (Jun 15
      // already observes Dwitiya). Tithi-pinned scans fall back to garbage
      // here (old monthStartContaining returned May 19); masa-pinned scans
      // resolve through the masa transition instead.
      // Arrange
      final midNija = DateTime(2026, 6, 20);

      // Act + Assert
      expect(
        await service.monthStartContaining(midNija),
        equals(DateTime(2026, 6, 15)),
      );
      expect(
        await service.nextMonthStartAfter(DateTime(2026, 6, 15)),
        equals(DateTime(2026, 7, 14)),
      );
      expect(
        await service.prevMasaStartFrom(midNija),
        equals(DateTime(2026, 5, 17)),
      );
    });

    test('normal (non-Adhika) months are unaffected', () async {
      // Arrange
      final midVaishakha = DateTime(2026, 4, 25);
      final vaishakhaStart = DateTime(2026, 4, 18);

      // Act + Assert
      expect(
        await service.monthStartContaining(midVaishakha),
        equals(vaishakhaStart),
      );
      expect(
        await service.nextMonthStartAfter(vaishakhaStart),
        equals(DateTime(2026, 5, 17)),
      );
      expect(
        await service.prevMasaStartFrom(midVaishakha),
        equals(DateTime(2026, 3, 21)),
      );
    });
  });

  group('Adhika verdict (pure, no ephemeris)', () {
    test('newMoonDistance measures distance to the 30→1 wrap', () {
      expect(newMoonDistance(30.0), equals(0.0));
      expect(newMoonDistance(29.9), closeTo(0.1, 1e-9));
      expect(newMoonDistance(15.0), equals(15.0));
      expect(newMoonDistance(1.2), closeTo(28.8, 1e-9));
    });

    test('same-rashi pair is Adhika with the first-moon name', () {
      // Arrange: Taurus 45° .. Taurus 55° — no transit between new moons
      // Act
      final verdict = resolveAdhikaVerdict(
        sunLongN1: 45.0,
        sunLongN2: 55.0,
      );

      // Assert
      expect(verdict.adhika, isTrue);
      expect(verdict.masa, equals('Jyeshtha'));
    });

    test('pair straddling a transit is plain with the first-moon name', () {
      // Arrange: Taurus 59.9° .. Gemini 60.1°
      // Act
      final verdict = resolveAdhikaVerdict(
        sunLongN1: 59.9,
        sunLongN2: 60.1,
      );

      // Assert
      expect(verdict.adhika, isFalse);
      expect(verdict.masa, equals('Jyeshtha'));
    });

    test('exact 30° boundary counts as a transit (floor semantics)', () {
      // Arrange + Act
      final verdict = resolveAdhikaVerdict(
        sunLongN1: 59.99,
        sunLongN2: 60.0,
      );

      // Assert
      expect(verdict.adhika, isFalse);
    });

    test('wrapPairIndex finds the 30→1 straddle', () {
      // Arrange: mid-lunation sweep with the wrap between index 2 and 3
      const tithis = [27.5, 28.6, 29.7, 0.8, 1.9, 3.0];

      // Act
      final index = wrapPairIndex(tithis);

      // Assert
      expect(index, equals(2));
    });

    test('wrapPairIndex returns -1 with no wrap in window', () {
      expect(wrapPairIndex([5.0, 6.0, 7.0, 8.0]), equals(-1));
      expect(wrapPairIndex([25.0, 26.0, 27.0]), equals(-1));
    });

    test('interpolateNewMoonInstant weights by wrap distance', () {
      // Arrange: Aug 17 noon tithi 29.7, Aug 18 noon tithi 0.8
      final dayA = DateTime(2031, 8, 17, 12);
      final dayB = DateTime(2031, 8, 18, 12);

      // Act
      final instant = interpolateNewMoonInstant(dayA, 29.7, dayB, 0.8);

      // Assert: 0.3 / (0.3 + 0.8) of the way — late Aug 17, before a
      // hypothetical Aug 18 00:32 new moon within tolerance
      expect(instant.day, equals(17));
      expect(instant.hour, greaterThanOrEqualTo(18));
    });
  });
}
