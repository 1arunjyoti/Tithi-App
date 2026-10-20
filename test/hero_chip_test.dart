import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tithi/features/hero/widgets/hero_chip.dart';

void main() {
  /// Long transition-style label: far wider than [boxWidth] at this font size.
  const longLabel = 'Next tithi: Chaturdashi at 11:02 PM';

  Future<void> pumpChip(
    WidgetTester tester, {
    required String text,
    required bool wrap,
    double boxWidth = 150,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: ConstrainedBox(
              // Loose cap, mirroring the hero's Wrap (a tight SizedBox would
              // stretch the chip to the full width).
              constraints: BoxConstraints(maxWidth: boxWidth),
              child: HeroChip(
                icon: Icons.arrow_forward_rounded,
                text: text,
                wrap: wrap,
                fontWeight: FontWeight.w800,
                fontSize: 13,
                highContrast: false,
              ),
            ),
          ),
        ),
      ),
    );
  }

  group('HeroChip label wrapping', () {
    testWidgets('default keeps a single ellipsized line', (tester) async {
      // Arrange + Act
      await pumpChip(tester, text: longLabel, wrap: false);
      final height = tester.getSize(find.byType(HeroChip)).height;

      // Assert: one text line (padding 5 + 5 around a single line)
      expect(height, lessThan(40));
    });

    testWidgets('wrap breaks a long label onto multiple lines', (tester) async {
      // Arrange
      await pumpChip(tester, text: longLabel, wrap: false);
      final singleLine = tester.getSize(find.byType(HeroChip)).height;

      // Act
      await pumpChip(tester, text: longLabel, wrap: true);
      final multiLine = tester.getSize(find.byType(HeroChip)).height;

      // Assert: taller than the single-line chip, and no layout overflow
      expect(multiLine, greaterThan(singleLine));
      expect(tester.takeException(), isNull);
    });

    testWidgets('wrap keeps short labels shrink-wrapped', (tester) async {
      // Arrange + Act: same harness, long vs short label
      await pumpChip(tester, text: longLabel, wrap: true);
      final longWidth = tester.getSize(find.byType(HeroChip)).width;
      await pumpChip(tester, text: 'Now', wrap: true);
      final shortWidth = tester.getSize(find.byType(HeroChip)).width;

      // Assert: a short label stays narrower than the available box instead of
      // stretching to fill it (only long labels use the wrapped width)
      expect(shortWidth, lessThan(longWidth));
      expect(shortWidth, lessThan(150));
    });
  });
}
