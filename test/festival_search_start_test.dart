import 'package:flutter_test/flutter_test.dart';
import 'package:tithi/features/panchang/domain/festival_search_start.dart';

void main() {
  group('festival occurrence scan start', () {
    test('a January scan for a December/January month starts before January', () {
      // Shattila Ekadashi is Pausha Krishna 11 and falls on Jan 14 2026. The
      // old estimate jumped to Oct 17 2026, so the All Festivals yearly scan
      // (baseDate = Jan 1) skipped the occurrence entirely while the live
      // month grid and home card still showed it.
      final start = festivalScanStart(DateTime(2026), 'Pausha');

      expect(
        start.isBefore(DateTime(2026)),
        isTrue,
        reason: 'the Jan 14 2026 occurrence must be inside the scan window',
      );
      expect(
        start.isBefore(DateTime(2025, 10)),
        isFalse,
        reason: 'starting a whole year early would defeat the fast-forward',
      );
    });

    test('never starts after the requested base date', () {
      for (final masa in [
        'Chaitra',
        'Vaishakha',
        'Jyeshtha',
        'Ashadha',
        'Shravana',
        'Bhadrapada',
        'Ashwin',
        'Kartika',
        'Margashirsha',
        'Pausha',
        'Magha',
        'Phalguna',
      ]) {
        for (final from in [
          DateTime(2026),
          DateTime(2026, 6),
          DateTime(2026, 11, 22),
        ]) {
          expect(
            festivalScanStart(from, masa).isAfter(from),
            isFalse,
            reason: '$masa from ${from.toIso8601String()}',
          );
        }
      }
    });

    test('wildcard and unknown months start at the base date', () {
      expect(festivalScanStart(DateTime(2026), '*'), equals(DateTime(2026)));
      expect(
        festivalScanStart(DateTime(2026), 'Adhika_Jyeshtha'),
        equals(DateTime(2026)),
      );
    });
  });
}
