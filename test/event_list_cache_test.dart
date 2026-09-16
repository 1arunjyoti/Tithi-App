import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tithi/models/panchang_data.dart';
import 'package:tithi/providers/calendar_provider.dart';
import 'package:tithi/providers/panchang_provider.dart';
import 'package:tithi/widgets/event_list_widget.dart';

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
  test(
    'upcoming events use cached adaptive records without panchang FFI',
    () async {
      // Arrange
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final selected = DateTime(2098, 1, 10);
      container.read(selectedDateProvider.notifier).setDate(selected);
      for (var offset = 0; offset < upcomingFestivalWindowDays; offset++) {
        final day = selected.add(Duration(days: offset));
        storePanchangUiSync(day, _panchang(day));
      }

      // Act
      final events = await container.read(upcomingFestivalsProvider.future);

      // Assert
      expect(events, isEmpty);
    },
  );
}
