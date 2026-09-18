import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tithi/models/panchang_data.dart';
import 'package:tithi/providers/calendar_provider.dart';
import 'package:tithi/providers/panchang_provider.dart';

// Tests for the live hero: the displayed label advances intraday when a
// tithi boundary passes, while festivals, masa and the sunrise record stay
// pinned. Model sequencing is pure (no timers); the tick provider is cove
// with short real timers below.

/// Sep-18-like day: Saptami (7) at sunrise, Ashtami (8) from [transition].
PanchangData flipDay(DateTime transition) => PanchangData.fromRawTithi(
  date: DateTime(transition.year, transition.month, transition.day),
  rawTithi: 7.2,
  masa: 'Bhadrapada',
  allFestivals: [],
  sunrise: DateTime(
    transition.year,
    transition.month,
    transition.day,
    6,
    5,
  ),
  sunset: DateTime(
    transition.year,
    transition.month,
    transition.day,
    18,
    20,
  ),
  tithiTransitionTime: transition,
  transitionTithiIndex: 8,
);

void main() {
  group('liveLabelAt sequencing', () {
    test('before the boundary the sunrise label prevails', () {
      // Arrange
      final transition = DateTime(2026, 9, 18, 13, 2);
      final day = flipDay(transition);

      // Act
      final live = day.liveLabelAt(DateTime(2026, 9, 18, 12, 59));

      // Assert
      expect(live.number, equals(7));
      expect(live.paksha, equals('Shukla'));
      expect(live.name, equals('Saptami'));
      expect(live.index, equals(7));
    });

    test('at the exact boundary instant the incoming tithi takes over', () {
      // Arrange
      final transition = DateTime(2026, 9, 18, 13, 2);
      final day = flipDay(transition);

      // Act
      final live = day.liveLabelAt(transition);

      // Assert
      expect(live.number, equals(8));
      expect(live.name, equals('Ashtami'));
      expect(live.index, equals(8));
    });

    test('after the boundary the incoming tithi prevails', () {
      // Arrange
      final transition = DateTime(2026, 9, 18, 13, 2);
      final day = flipDay(transition);

      // Act
      final live = day.liveLabelAt(DateTime(2026, 9, 18, 15));

      // Assert
      expect(live.number, equals(8));
      expect(live.paksha, equals('Shukla'));
      expect(live.name, equals('Ashtami'));
      expect(live.index, equals(8));
    });

    test('no transition means the label never moves', () {
      // Arrange
      final day = PanchangData.fromRawTithi(
        date: DateTime(2026, 10, 16),
        rawTithi: 6.4,
        masa: 'Ashwin',
        allFestivals: [],
      );

      // Act + Assert
      for (final hour in [0, 6, 12, 18, 23]) {
        final live = day.liveLabelAt(DateTime(2026, 10, 16, hour));
        expect(live.number, equals(6));
        expect(live.name, equals('Shashthi'));
      }
    });

    test('kshaya follow-on advances the label a second time', () {
      // Arrange: X → Y at 07:00, Y → Z at 22:00 (squeezed Y owns no sunrise
      // but does own the evening).
      final day = PanchangData.fromRawTithi(
        date: DateTime(2026, 10, 4),
        rawTithi: 23.2,
        masa: 'Ashwin',
        allFestivals: [],
        tithiTransitionTime: DateTime(2026, 10, 4, 7),
        transitionTithiIndex: 24,
      );
      final followOn = DateTime(2026, 10, 4, 22);

      // Act + Assert
      expect(
        day.liveLabelAt(DateTime(2026, 10, 4, 6)).index,
        equals(23),
      );
      expect(
        day
            .liveLabelAt(
              DateTime(2026, 10, 4, 12),
              followOnTime: followOn,
              followOnIndex: 25,
            )
            .index,
        equals(24),
      );
      expect(
        day
            .liveLabelAt(
              DateTime(2026, 10, 4, 23),
              followOnTime: followOn,
              followOnIndex: 25,
            )
            .index,
        equals(25),
      );
    });
  });

  group('withLiveLabel', () {
    test('pre-flip returns the identical record (no rebuild churn)', () {
      // Arrange
      final transition = DateTime(2026, 9, 18, 13, 2);
      final day = flipDay(transition);

      // Act
      final live = day.withLiveLabel(DateTime(2026, 9, 18, 9));

      // Assert
      expect(identical(live, day), isTrue);
    });

    test('post-flip swaps the label but pins everything else', () {
      // Arrange
      final transition = DateTime(2026, 9, 18, 13, 2);
      final day = flipDay(transition);

      // Act
      final live = day.withLiveLabel(DateTime(2026, 9, 18, 15));

      // Assert: label advanced …
      expect(live.tithiNumber, equals(8));
      expect(live.tithiName, equals('Ashtami'));
      expect(live.paksha, equals('Shukla'));
      expect(live.tithiIndex, equals(8));
      // … context pinned.
      expect(live.rawTithi, equals(day.rawTithi));
      expect(live.masa, equals('Bhadrapada'));
      expect(live.festivals, same(day.festivals));
      expect(
        live.tithiTransitionTime,
        equals(DateTime(2026, 9, 18, 13, 2)),
      );
      expect(live.transitionTithiIndex, equals(8));
      // The flipped-to tithi is now displayed, so the transition no longer
      // exits the label — while the boundary itself stays recorded.
      expect(live.hasTithiTransition, isTrue);
      expect(live.transitionExitsLabel, isFalse);
      // Sunrise history survives for the handover line.
      expect(live.sunriseTithiNumber, equals(7));
      expect(live.sunriseTithiName, equals('Saptami'));
      expect(live.sunrisePaksha, equals('Shukla'));
    });

    test('sunrise getters name the day the record started with', () {
      // Arrange
      final day = flipDay(DateTime(2026, 9, 18, 13, 2));

      // Act + Assert
      expect(day.sunriseTithiIndex, equals(7));
      expect(day.sunriseTithiNumber, equals(7));
      expect(day.sunrisePaksha, equals('Shukla'));
      expect(day.sunriseTithiName, equals('Saptami'));
    });
  });

  group('liveTithiTickProvider', () {
    ProviderContainer containerWith(PanchangData record) {
      final container = ProviderContainer(
        overrides: [
          panchangForDateProvider.overrideWith(
            (ref, date) => Future.value(record),
          ),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    test('no timer without a transition (vriddhi day stays at 0)', () async {
      // Arrange
      final now = DateTime.now();
      final record = PanchangData.fromRawTithi(
        date: DateTime(now.year, now.month, now.day),
        rawTithi: 6.4,
        masa: 'Ashwin',
        allFestivals: [],
      );
      final container = containerWith(record);
      container.listen<int>(liveTithiTickProvider, (prev, next) {});

      // Act
      await Future<void>.delayed(const Duration(milliseconds: 400));

      // Assert
      expect(container.read(liveTithiTickProvider), equals(0));
    });

    test('fires once shortly after the boundary passes', () async {
      // Arrange: transition 300 ms out (+1 s flip grace → ~1.3 s).
      final transition = DateTime.now().add(
        const Duration(milliseconds: 300),
      );
      final record = PanchangData.fromRawTithi(
        date: DateTime(
          transition.year,
          transition.month,
          transition.day,
        ),
        rawTithi: 7.2,
        masa: 'Bhadrapada',
        allFestivals: [],
        tithiTransitionTime: transition,
        transitionTithiIndex: 8,
      );
      final container = containerWith(record);
      var fires = 0;
      container.listen<int>(liveTithiTickProvider, (prev, next) {
        fires++;
      });

      // Act
      await Future<void>.delayed(const Duration(seconds: 2));

      // Assert: exactly one flip tick (no repeat polling).
      expect(container.read(liveTithiTickProvider), equals(1));
      expect(fires, equals(1));
    });

    test('chains onto a second intraday boundary (kshaya)', () async {
      // Arrange: first transition already past (flipped), follow-on end
      // 500 ms out and still before tomorrow's sunrise.
      final first = DateTime.now().subtract(
        const Duration(milliseconds: 200),
      );
      final second = DateTime.now().add(const Duration(milliseconds: 500));
      final record = PanchangData.fromRawTithi(
        date: DateTime(first.year, first.month, first.day),
        rawTithi: 23.2,
        masa: 'Ashwin',
        allFestivals: [],
        tithiTransitionTime: first,
        transitionTithiIndex: 24,
      );
      final container = ProviderContainer(
        overrides: [
          panchangForDateProvider.overrideWith(
            (ref, date) => Future.value(record),
          ),
          tithiTimingsProvider.overrideWith(
            (ref, arg) => Future.value((
              start: first,
              end: second,
            )),
          ),
          // Short-circuit the location chain (no Hive in unit tests).
          resolvedCoordinatesProvider.overrideWithValue(
            (latitude: 28.6139, longitude: 77.2090),
          ),
        ],
      );
      addTearDown(container.dispose);
      container.listen<int>(liveTithiTickProvider, (prev, next) {});

      // Act
      await Future<void>.delayed(const Duration(seconds: 2));

      // Assert: the follow-on timer fired exactly once.
      expect(container.read(liveTithiTickProvider), equals(1));
    });

    test('dormant while browsing a non-today date', () async {
      // Arrange: record dated yesterday with a transition minutes out —
      // must never arm because the live hero only tracks today.
      final transition = DateTime.now().add(
        const Duration(milliseconds: 300),
      );
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      final record = PanchangData.fromRawTithi(
        date: DateTime(yesterday.year, yesterday.month, yesterday.day),
        rawTithi: 7.2,
        masa: 'Bhadrapada',
        allFestivals: [],
        tithiTransitionTime: transition,
        transitionTithiIndex: 8,
      );
      final container = ProviderContainer(
        overrides: [
          panchangForDateProvider.overrideWith(
            (ref, date) => Future.value(record),
          ),
          selectedDateProvider.overrideWith(
            _FixedPastDateNotifier.new,
          ),
        ],
      );
      addTearDown(container.dispose);
      container.listen<int>(liveTithiTickProvider, (prev, next) {});

      // Act
      await Future<void>.delayed(const Duration(milliseconds: 600));

      // Assert
      expect(container.read(liveTithiTickProvider), equals(0));
    });
  });

  group('livePanchangProvider date gating', () {
  test('non-today dates return the frozen sunrise record', () async {
    // Arrange: yesterday with a long-past transition — even though the
    // boundary is hours behind, a browsed date never relabels.
    final now = DateTime.now();
    final yesterday = DateTime(now.year, now.month, now.day - 1);
    final record = PanchangData.fromRawTithi(
      date: yesterday,
      rawTithi: 7.2,
      masa: 'Bhadrapada',
      allFestivals: [],
      tithiTransitionTime: DateTime(
        yesterday.year,
        yesterday.month,
        yesterday.day,
        13,
        2,
      ),
      transitionTithiIndex: 8,
    );
    final container = ProviderContainer(
      overrides: [
        panchangForDateProvider.overrideWith(
          (ref, date) => Future.value(record),
        ),
        tithiTimingsProvider.overrideWith((ref, arg) async => null),
      ],
    );
    addTearDown(container.dispose);

    // Act
    final live = await container.read(
      livePanchangProvider(yesterday).future,
    );

    // Assert: identical record, sunrise label, history intact.
    expect(identical(live, record), isTrue);
    expect(live.tithiNumber, equals(7));
    expect(live.tithiName, equals('Saptami'));
    expect(live.hasTithiTransition, isTrue);
    expect(live.transitionTithiNumber, equals(8));
    });
  });

  group('livePanchangProvider failure isolation', () {
    test('throwing follow-on lookup still flips (no hero outage)', () async {
      // Arrange: today, already past the boundary, but the ephemeris
      // follow-on search throws.
      final now = DateTime.now();
      final day = DateTime(now.year, now.month, now.day);
      final record = PanchangData.fromRawTithi(
        date: day,
        rawTithi: 7.2,
        masa: 'Bhadrapada',
        allFestivals: [],
        tithiTransitionTime: day.add(const Duration(hours: 1)),
        transitionTithiIndex: 8,
      );
      final container = ProviderContainer(
        overrides: [
          panchangForDateProvider.overrideWith(
            (ref, date) => Future.value(record),
          ),
          tithiTimingsProvider.overrideWith(
            (ref, arg) => Future.error(StateError('ephemeris offline')),
          ),
          liveNowProvider.overrideWithValue(
            day.add(const Duration(hours: 3)),
          ),
          // Short-circuit the location chain (no Hive in unit tests).
          resolvedCoordinatesProvider.overrideWithValue(
            (latitude: 28.6139, longitude: 77.2090),
          ),
        ],
      );
      addTearDown(container.dispose);

      // Act
      final live = await container.read(livePanchangProvider(day).future);

      // Assert: first flip applied, follow-on skipped, no error surfaced.
      expect(live.tithiNumber, equals(8));
      expect(live.tithiName, equals('Ashtami'));
      expect(live.hasTithiTransition, isTrue);
    });
  });
}

class _FixedPastDateNotifier extends SelectedDateNotifier {
  @override
  DateTime build() => DateTime.now().subtract(const Duration(days: 3));
}
