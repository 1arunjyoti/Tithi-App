import 'package:flutter_test/flutter_test.dart';
import 'package:tithi/services/bengali_calendar/bengali_calendar_data.dart';

void main() {
  group('BengaliCalendarDateCache', () {
    test('keys dates by normalized day and calculation location', () {
      final cache = BengaliCalendarDateCache(maxEntries: 2);
      final date = DateTime(2099, 4, 15);
      final key = bengaliCalendarDateCacheKey(date, 22.5726, 88.3639);
      const value = (day: 2, month: 'Boishakh', year: 1506);
      cache.store(key, value);

      expect(
        cache.read(
          bengaliCalendarDateCacheKey(DateTime(2099, 4, 15), 22.5726, 88.3639),
        ),
        value,
      );
      expect(
        cache.read(bengaliCalendarDateCacheKey(date, 23.0, 88.3639)),
        isNull,
      );
    });

    test('evicts the oldest entry when full', () {
      final cache = BengaliCalendarDateCache(maxEntries: 2);
      const value = (day: 1, month: 'Boishakh', year: 1506);
      cache.store('first', value);
      cache.store('second', value);
      cache.store('third', value);

      expect(cache.read('first'), isNull);
      expect(cache.read('second'), value);
      expect(cache.read('third'), value);
    });
  });
}
