import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tithi/core/location/place_clock.dart';
import 'package:tithi/providers/accessibility_provider.dart';
import 'package:tithi/providers/calendar_provider.dart';
import 'package:tithi/providers/location_provider.dart';
import 'package:tithi/widgets/jump_to_today_button.dart';

/// PressScale reads the accessibility box for its haptic gate; the real
/// notifier would open Hive, which these tests never initialize.
class _FixedAccessibility extends AccessibilityNotifier {
  @override
  AccessibilityState build() => const AccessibilityState();
}

/// A container with the device clock, so "today" needs no Hive/location.
ProviderContainer _container() {
  final container = ProviderContainer(
    overrides: [
      placeClockProvider.overrideWithValue(kDeviceClock),
      accessibilityProvider.overrideWith(_FixedAccessibility.new),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  group('jumpToTodayVisibleProvider', () {
    test('is off while the calendar already shows today', () {
      // Arrange
      final container = _container();
      final now = nowInPlaceClock(container.read(placeClockProvider));

      // Act: defaults are "today" in the current month.
      final visible = container.read(jumpToTodayVisibleProvider);

      // Assert
      expect(visible, isFalse);
      expect(container.read(selectedDateProvider), isNotNull);
      expect(now.year, container.read(focusedMonthProvider).year);
    });

    test('turns on when another day is selected', () {
      // Arrange
      final container = _container();
      final now = nowInPlaceClock(container.read(placeClockProvider));

      // Act
      container
          .read(selectedDateProvider.notifier)
          .setDate(DateTime(now.year, now.month, now.day - 1));

      // Assert
      expect(container.read(jumpToTodayVisibleProvider), isTrue);
    });

    test('turns on when another month is browsed', () {
      // Arrange
      final container = _container();
      final now = nowInPlaceClock(container.read(placeClockProvider));

      // Act: today is still selected, but it is no longer on screen.
      container
          .read(focusedMonthProvider.notifier)
          .setFocusedMonth(DateTime(now.year, now.month + 1));

      // Assert
      expect(container.read(jumpToTodayVisibleProvider), isTrue);
    });

    test('turns on when the app day rolls over at midnight', () {
      // Arrange: calendar and selection both still on the old day.
      final container = _container();
      final today = container.read(todayDateProvider);

      // Act: only the app's day moves, exactly what the midnight timer does.
      container
          .read(todayDateProvider.notifier)
          .setToday(today.add(const Duration(days: 1)));

      // Assert: the rule watches [todayDateProvider], so it re-evaluates
      // instead of caching an answer computed before the rollover.
      expect(container.read(jumpToTodayVisibleProvider), isTrue);
    });
  });

  group('JumpToTodayButton', () {
    testWidgets('tapping returns month, date and month-tap state to today', (
      tester,
    ) async {
      // Arrange: browsing two months ahead with a date selected there.
      final container = _container();
      final now = nowInPlaceClock(container.read(placeClockProvider));
      final away = DateTime(now.year, now.month + 2, 10);
      container.read(focusedMonthProvider.notifier).setFocusedMonth(away);
      container.read(selectedDateProvider.notifier).setDate(away);
      container.read(tappedCalendarDateProvider.notifier).state = away;

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(body: Center(child: JumpToTodayButton())),
          ),
        ),
      );

      // Act
      await tester.tap(find.byType(JumpToTodayButton));
      await tester.pump();

      // Assert: the grid and the selection move together, and the secondary
      // header drops the explicit tile tap.
      final selected = container.read(selectedDateProvider);
      expect(
        DateTime(selected.year, selected.month, selected.day),
        DateTime(now.year, now.month, now.day),
      );
      final focused = container.read(focusedMonthProvider);
      expect(
        DateTime(focused.year, focused.month),
        DateTime(now.year, now.month),
      );
      expect(container.read(tappedCalendarDateProvider), isNull);
    });

    testWidgets('tapping jumps to the app day, not the device clock', (
      tester,
    ) async {
      // Arrange: the app's "today" is pinned to a fixed date, while the
      // calendar is somewhere else entirely.
      final container = _container();
      final appToday = DateTime(2024, 3, 15);
      container.read(todayDateProvider.notifier).setToday(appToday);
      container
          .read(focusedMonthProvider.notifier)
          .setFocusedMonth(DateTime(2024, 6));
      container
          .read(selectedDateProvider.notifier)
          .setDate(DateTime(2024, 6, 10));

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(body: Center(child: JumpToTodayButton())),
          ),
        ),
      );

      // Act
      await tester.tap(find.byType(JumpToTodayButton));
      await tester.pump();

      // Assert: both the grid and the selection land on the app day.
      expect(container.read(selectedDateProvider), appToday);
      expect(container.read(focusedMonthProvider), appToday);
      expect(container.read(jumpToTodayVisibleProvider), isFalse);
    });
  });
}
