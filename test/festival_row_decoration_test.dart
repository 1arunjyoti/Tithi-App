import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tithi/theme/app_theme.dart';

/// Rows are flush on their parent card in every palette; only the selected
/// calendar day gets a wash. High Contrast is the one place the wash keeps an
/// edge, because colour alone does not carry the selection there.
void main() {
  final themes = <String, ThemeData>{
    'Shukla': AppTheme.shuklaTheme,
    'Krishna': AppTheme.krishnaTheme,
    'Pure Dark': AppTheme.pureDarkTheme,
  };

  Future<BuildContext> pumpTheme(
    WidgetTester tester,
    ThemeData theme, {
    bool highContrast = false,
  }) async {
    late BuildContext captured;
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: MediaQuery(
          data: MediaQueryData(highContrast: highContrast),
          child: Builder(
            builder: (context) {
              captured = context;
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );
    return captured;
  }

  testWidgets('standard rows are transparent in every theme', (tester) async {
    for (final entry in themes.entries) {
      final context = await pumpTheme(tester, entry.value);
      final decoration = AppTheme.festivalRowDecoration(context);
      expect(
        decoration,
        const BoxDecoration(),
        reason: '${entry.key} rows must sit flush on the card',
      );
    }
  });

  testWidgets('selected-day wash is borderless and subtle by default', (
    tester,
  ) async {
    for (final entry in themes.entries) {
      final context = await pumpTheme(tester, entry.value);
      final decoration = AppTheme.festivalRowDecoration(
        context,
        isSelectedDay: true,
      );
      expect(
        decoration.color!.withValues(alpha: 1),
        AppTheme.festivalAccent(context),
        reason: '${entry.key} wash uses the festival accent',
      );
      expect(decoration.color!.a, closeTo(0.08, 0.001));
      expect(decoration.border, isNull);
      expect(decoration.borderRadius, BorderRadius.circular(14));
    }
  });

  testWidgets('high contrast keeps a hairline accent edge', (tester) async {
    for (final entry in themes.entries) {
      final context = await pumpTheme(tester, entry.value, highContrast: true);
      final decoration = AppTheme.festivalRowDecoration(
        context,
        isSelectedDay: true,
      );
      expect(decoration.color!.a, closeTo(0.18, 0.001));
      final border = decoration.border! as Border;
      expect(border.top.width, 1.0);
      expect(border.top.color.a, closeTo(0.6, 0.001));
      expect(
        border.top.color.withValues(alpha: 1),
        AppTheme.festivalAccent(context),
      );
    }
  });
}
