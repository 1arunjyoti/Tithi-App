import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tithi/providers/calendar_provider.dart';

void main() {
  group('tappedCalendarDateProvider', () {
    testWidgets('defaults to null, holds a tile tap, clears on month jump', (
      tester,
    ) async {
      // Arrange
      late WidgetRef ref;
      await tester.pumpWidget(
        ProviderScope(
          child: Consumer(
            builder: (context, r, child) {
              ref = r;
              return const SizedBox();
            },
          ),
        ),
      );

      // Assert: default (no tap yet) — header shows the two-month range.
      expect(ref.read(tappedCalendarDateProvider), isNull);

      // Act: user actively taps a date tile.
      ref.read(tappedCalendarDateProvider.notifier).state = DateTime(
        2026,
        9,
        5,
      );

      // Assert: tap held — header narrows to that date's single month.
      expect(
        ref.read(tappedCalendarDateProvider),
        equals(DateTime(2026, 9, 5)),
      );

      // Act: month navigation (chevron/swipe jumps via setCalendarMonth).
      setCalendarMonth(ref, DateTime(2026, 10));

      // Assert: tap state cleared — header returns to the range default.
      expect(ref.read(tappedCalendarDateProvider), isNull);
    });
  });
}
