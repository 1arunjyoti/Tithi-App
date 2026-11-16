import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tithi/theme/app_motion.dart';

/// Captures the ambient context under a MediaQuery with the Reduce Motion /
/// OS `disableAnimations` flag set as requested.
Future<BuildContext> _captureContext(
  WidgetTester tester, {
  bool reduceMotion = false,
}) async {
  late BuildContext captured;
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(disableAnimations: reduceMotion),
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
  group('AppMotion tokens', () {
    test('are the existing tiers, by job', () {
      expect(AppMotion.press, const Duration(milliseconds: 100));
      expect(AppMotion.chrome, const Duration(milliseconds: 150));
      expect(AppMotion.subtle, const Duration(milliseconds: 180));
      expect(AppMotion.standard, const Duration(milliseconds: 200));
      expect(AppMotion.resize, const Duration(milliseconds: 220));
      expect(AppMotion.emphasized, const Duration(milliseconds: 250));
      expect(AppMotion.scroll, const Duration(milliseconds: 260));
      expect(AppMotion.entrance, const Duration(milliseconds: 280));
      expect(AppMotion.page, const Duration(milliseconds: 300));
      expect(AppMotion.staggerStep, const Duration(milliseconds: 60));
    });

    test('curves name the dominant easings', () {
      expect(AppMotion.standardCurve, Curves.easeOutCubic);
      expect(AppMotion.emphasizedCurve, Curves.easeInOutCubic);
      expect(AppMotion.exitCurve, Curves.easeInCubic);
    });
  });

  group('AppMotion.of', () {
    testWidgets('keeps the token duration normally', (tester) async {
      final context = await _captureContext(tester);

      expect(AppMotion.of(context, AppMotion.standard), AppMotion.standard);
      expect(AppMotion.of(context, AppMotion.press), AppMotion.press);
    });

    testWidgets('collapses to 1ms under Reduce Motion', (tester) async {
      final context = await _captureContext(tester, reduceMotion: true);

      // 1ms, not zero: AnimatedSize crashes if it completes inside its own
      // layout pass (see AppTheme.animationDuration).
      expect(
        AppMotion.of(context, AppMotion.emphasized),
        const Duration(milliseconds: 1),
      );
      expect(
        AppMotion.of(context, AppMotion.standard),
        const Duration(milliseconds: 1),
      );
    });
  });
}
