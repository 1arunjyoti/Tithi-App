import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tithi/theme/app_theme.dart';

/// Captures the ambient context under the Shukla theme, optionally with
/// High Contrast, so the `MutedInk` getters can be read.
Future<BuildContext> _captureContext(
  WidgetTester tester, {
  bool highContrast = false,
}) async {
  late BuildContext captured;
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.shuklaTheme,
      home: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context).copyWith(highContrast: highContrast),
          child: Builder(
            builder: (inner) {
              captured = inner;
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    ),
  );
  return captured;
}

void main() {
  group('MutedInk', () {
    testWidgets('levels get quieter in order', (tester) async {
      final context = await _captureContext(tester);

      expect(context.secondaryInk.a, closeTo(0.7, 0.001));
      expect(context.hintInk.a, closeTo(0.55, 0.001));
      expect(context.faintInk.a, closeTo(0.35, 0.001));
    });

    testWidgets('ink is the theme onSurface, not a hardcoded grey', (
      tester,
    ) async {
      final context = await _captureContext(tester);
      final onSurface = context.colors.onSurface;

      expect(context.secondaryInk.r, closeTo(onSurface.r, 0.001));
      expect(context.secondaryInk.g, closeTo(onSurface.g, 0.001));
      expect(context.secondaryInk.b, closeTo(onSurface.b, 0.001));
    });

    testWidgets('High Contrast folds text to full ink, faint stops at 0.6', (
      tester,
    ) async {
      final context = await _captureContext(tester, highContrast: true);

      expect(context.secondaryInk.a, closeTo(1.0, 0.001));
      expect(context.hintInk.a, closeTo(1.0, 0.001));
      // Decorative marks must still read as "not available", so they stop
      // short of full ink even in High Contrast.
      expect(context.faintInk.a, closeTo(0.6, 0.001));
    });
  });

  group('AppTheme.hairlineAlpha', () {
    testWidgets('keeps the requested alpha in normal contrast', (tester) async {
      final context = await _captureContext(tester);
      expect(AppTheme.hairlineAlpha(context, 0.1), 0.1);
      expect(AppTheme.hairlineAlpha(context, 0.08), 0.08);
    });

    testWidgets('stops at 0.22 in High Contrast', (tester) async {
      final context = await _captureContext(tester, highContrast: true);
      expect(AppTheme.hairlineAlpha(context, 0.1), 0.22);
      expect(AppTheme.hairlineAlpha(context, 0.08), 0.22);
    });
  });
}
