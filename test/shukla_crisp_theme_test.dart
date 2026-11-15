import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tithi/theme/app_theme.dart';

void main() {
  group('Crisp Daylight (Shukla) theme', () {
    testWidgets('page, ink and accent use the crisp palette', (tester) async {
      // Arrange / Act
      await tester.pumpWidget(
        MaterialApp(theme: AppTheme.shuklaTheme, home: const SizedBox.shrink()),
      );
      final theme = AppTheme.shuklaTheme;

      // Assert
      expect(theme.scaffoldBackgroundColor, AppTheme.shuklaBackground);
      expect(AppTheme.shuklaBackground, const Color(0xFFF5F5F7));
      expect(theme.colorScheme.primary, AppTheme.shuklaAccent);
      expect(AppTheme.shuklaAccent, const Color(0xFFE84A1B));
      expect(theme.colorScheme.onSurface, AppTheme.shuklaInk);
      expect(AppTheme.shuklaInk, const Color(0xFF111113));
    });

    testWidgets('cards are opaque white, hairline-bordered and flat', (
      tester,
    ) async {
      // Arrange
      await tester.pumpWidget(
        MaterialApp(theme: AppTheme.shuklaTheme, home: const SizedBox.shrink()),
      );
      final cardTheme = AppTheme.shuklaTheme.cardTheme;
      final shape = cardTheme.shape! as RoundedRectangleBorder;

      // Act / Assert
      expect(cardTheme.color, Colors.white);
      expect(cardTheme.elevation, 0);
      expect(cardTheme.shadowColor, Colors.transparent);
      expect(shape.side.color, AppTheme.shuklaHairline);
      expect(shape.side.width, 1);
      expect(AppTheme.shuklaHairline, const Color(0xFFE5E5EA));
    });

    testWidgets('glass cards and the hero are flat white in light', (
      tester,
    ) async {
      // Arrange
      late BuildContext context;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.shuklaTheme,
          home: Builder(
            builder: (innerContext) {
              context = innerContext;
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      // Act
      final card = AppTheme.glassmorphism(context: context);
      final border = card.border! as Border;

      // Assert
      expect(card.color, Colors.white);
      expect(card.color!.a, 1.0);
      expect(card.boxShadow, isNull);
      expect(border.top.color, AppTheme.shuklaHairline);
      expect(border.top.width, 1);
      // Sheet/detail hero surfaces stay crisp white with no ambient wash.
      expect(AppTheme.heroGradient(context), [Colors.white, Colors.white]);
      expect(AppTheme.heroGlow(context), Colors.transparent);
      // The home hero keeps the previous warm peach treatment.
      expect(AppTheme.homeHeroGradient(context), const [
        Color(0xFFFFF3E0),
        Color(0xFFFFE0B2),
      ]);
      expect(AppTheme.homeHeroForeground(context), const Color(0xFF4E342E));
      expect(AppTheme.homeHeroAccent(context), const Color(0xFFBF360C));
      expect(AppTheme.homeHeroGlow(context).a, greaterThan(0));
      expect(
        AppTheme.homeHeroChipBackground(context),
        Colors.white.withValues(alpha: 0.6),
      );
    });

    testWidgets('festival glyphs carry the accent on neutral tiles', (
      tester,
    ) async {
      // Arrange
      late BuildContext context;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.shuklaTheme,
          home: Builder(
            builder: (innerContext) {
              context = innerContext;
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      // Act / Assert
      expect(AppTheme.festivalAccent(context), AppTheme.shuklaAccent);
      expect(AppTheme.festivalTileBackground(context), AppTheme.shuklaTile);
      expect(
        AppTheme.calendarTodayBackground(context),
        AppTheme.shuklaTodayFill,
      );
      expect(AppTheme.calendarTodayForeground(context), AppTheme.shuklaAccent);
    });
  });
}
