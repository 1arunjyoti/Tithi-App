import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tithi/core/anim/press_scale.dart';

/// The target scale PressScale is animating towards (1.0 = not pressed).
double _targetScale(WidgetTester tester) =>
    tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale;

Widget _page({double extra = 0}) {
  return ProviderScope(
    child: MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: Column(
            children: [
              const PressScale(
                haptic: false,
                child: SizedBox(
                  key: ValueKey('tile'),
                  width: 300,
                  height: 200,
                  child: ColoredBox(color: Colors.red),
                ),
              ),
              SizedBox(height: extra),
            ],
          ),
        ),
      ),
    ),
  );
}

void main() {
  group('PressScale', () {
    testWidgets('a press shrinks the child and release restores it', (
      tester,
    ) async {
      // Arrange
      await tester.pumpWidget(_page());

      // Act: finger down without moving
      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(const ValueKey('tile'))),
      );
      await tester.pump(const Duration(milliseconds: 150));

      // Assert: pressed
      expect(_targetScale(tester), 0.94);

      // Act: lift
      await gesture.up();
      await tester.pumpAndSettle();

      // Assert: back to rest
      expect(_targetScale(tester), 1.0);
    });

    testWidgets('a drag past the touch slop is not a press', (tester) async {
      // Arrange: the page scrolls, exactly like the home screen list
      await tester.pumpWidget(_page(extra: 1200));

      // Act: scroll starting on the pressable card
      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(const ValueKey('tile'))),
      );
      await tester.pump(const Duration(milliseconds: 150));
      expect(_targetScale(tester), 0.94);

      await gesture.moveBy(const Offset(0, -60));
      await tester.pumpAndSettle();

      // Assert: the card let go instead of staying shrunk for the whole drag
      expect(_targetScale(tester), 1.0);

      // Act: lift
      await gesture.up();
      await tester.pumpAndSettle();

      // Assert: and it does not bounce back on release either
      expect(_targetScale(tester), 1.0);
    });

    testWidgets('a second finger does not restart a released press', (
      tester,
    ) async {
      // Arrange
      await tester.pumpWidget(_page(extra: 1200));
      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(const ValueKey('tile'))),
      );
      await tester.pump(const Duration(milliseconds: 150));
      await gesture.moveBy(const Offset(0, -60));
      await tester.pumpAndSettle();
      expect(_targetScale(tester), 1.0);

      // Act: another finger lands while the first is still down
      final second = await tester.startGesture(const Offset(150, 400));
      await tester.pump(const Duration(milliseconds: 150));

      // Assert: the card stays at rest
      expect(_targetScale(tester), 1.0);

      await second.up();
      await gesture.up();
      await tester.pumpAndSettle();
    });
  });
}
