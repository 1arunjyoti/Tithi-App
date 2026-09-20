import 'package:flutter_test/flutter_test.dart';
import 'package:tithi/models/panchang_data.dart';
import 'package:tithi/providers/panchang_provider.dart';

PanchangData _panchang(DateTime date) {
  return PanchangData.fromRawTithi(
    date: date,
    rawTithi: 8.5,
    masa: 'Chaitra',
    allFestivals: const [],
    sunrise: DateTime(date.year, date.month, date.day, 6, 30),
    sunset: DateTime(date.year, date.month, date.day, 18),
  );
}

void main() {
  group('selected-date panchang cache', () {
    test('reuses an adaptive day record across time-normalized lookups', () {
      // Arrange
      final date = DateTime(2097, 4, 12);
      final adaptiveRecord = _panchang(date);

      // Act
      storePanchangUiSync(date, adaptiveRecord);

      // Assert
      expect(
        cachedPanchangUiSync(DateTime(2097, 4, 12, 22, 15)),
        same(adaptiveRecord),
      );
    });

    test('keeps a refined transition when the adaptive grid refreshes', () {
      // Arrange
      final date = DateTime(2097, 4, 13);
      final transition = DateTime(2097, 4, 13, 14, 20);
      final refined = _panchang(date).copyWith(
        tithiTransitionTime: transition,
        transitionTithiIndex: 9,
      );
      storePanchangUiSync(date, refined);

      // Act
      storePanchangUiSync(date, _panchang(date));

      // Assert
      final cached = cachedPanchangUiSync(date)!;
      expect(cached.tithiTransitionTime, transition);
      expect(cached.transitionTithiIndex, 9);
    });
  });
}
