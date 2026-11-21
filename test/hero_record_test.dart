import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tithi/models/panchang_data.dart';
import 'package:tithi/features/hero/widgets/paksha_hero_card.dart';

/// What the hero paints while its live record reloads.
///
/// Resume (and every place/date re-sync) puts [livePanchangProvider] into an
/// `AsyncLoading` reload that still carries the previous record. Falling back
/// to the cached body there re-keys the hero's content switcher and blank-fades
/// the card, which reads as the hero freezing before it updates.
void main() {
  PanchangData day(String tithi) => PanchangData(
    date: DateTime(2026, 11, 19),
    rawTithi: 9.5,
    tithiNumber: 10,
    tithiName: tithi,
    paksha: 'Shukla',
    masa: 'Kartika',
    sunrise: DateTime(2026, 11, 19, 6, 40),
    sunset: DateTime(2026, 11, 19, 17, 30),
  );

  group('heroRecordFor', () {
    test('keeps painting the previous record while a reload is in flight', () {
      // Arrange: a resolved record followed by the reload state Riverpod
      // produces on resume (loading, previous value retained).
      final previous = day('Dashami');
      final reloading = const AsyncValue<PanchangData>.loading().copyWithPrevious(
        AsyncValue.data(previous),
        isRefresh: false,
      );

      // Act
      final shown = heroRecordFor(live: reloading, cached: day('Navami'));

      // Assert: the stale-while-revalidate record stays on screen and stays
      // marked resolved, so the content key (date, resolved) never changes.
      expect(shown, isNotNull);
      expect(shown!.record.tithiName, equals('Dashami'));
      expect(shown.resolved, isTrue);
      expect(reloading.isReloading, isTrue);
    });

    test('uses the cached record on a true cold start', () {
      // Arrange: nothing resolved yet, but the month batch already has the day.
      final cached = day('Navami');

      // Act
      final shown = heroRecordFor(
        live: const AsyncValue<PanchangData>.loading(),
        cached: cached,
      );

      // Assert
      expect(shown, isNotNull);
      expect(shown!.record, same(cached));
      expect(shown.resolved, isFalse);
    });

    test('yields to the cache when the live record failed', () {
      // Arrange: a reload error that still carries the old record.
      final cached = day('Navami');
      final failed = AsyncValue<PanchangData>.error(
        StateError('ephemeris unavailable'),
        StackTrace.empty,
      ).copyWithPrevious(AsyncValue.data(day('Dashami')));

      // Act
      final shown = heroRecordFor(live: failed, cached: cached);

      // Assert: an error is the one state that must not keep the stale live
      // record (it may be the reason the record is wrong).
      expect(shown, isNotNull);
      expect(shown!.record, same(cached));
      expect(shown.resolved, isFalse);
    });

    test('returns nothing when both the live record and cache are empty', () {
      // Act
      final shown = heroRecordFor(
        live: const AsyncValue<PanchangData>.loading(),
        cached: null,
      );

      // Assert: the caller paints the true-cold placeholder.
      expect(shown, isNull);
    });
  });
}
