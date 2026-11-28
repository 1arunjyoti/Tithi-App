import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:tithi/features/eclipse/widgets/eclipse_details_sheet.dart';
import 'package:tithi/l10n/app_localizations.dart';
import 'package:tithi/models/eclipse.dart';
import 'package:tithi/theme/app_metrics.dart';
import 'package:tithi/theme/app_theme.dart';
import 'package:tithi/widgets/app_divider.dart';

/// Regression: the dense date/time rows used to overflow on a narrow phone
/// because the value was an unconstrained Text after a Spacer.
void main() {
  final eclipse = Eclipse(
    type: EclipseType.solarTotal,
    maxEclipseTime: DateTime(2026, 11, 26, 12, 30),
    partialStart: DateTime(2026, 11, 26, 10, 45),
    partialEnd: DateTime(2026, 11, 26, 14, 15),
    totalStart: DateTime(2026, 11, 26, 12, 15),
    totalEnd: DateTime(2026, 11, 26, 12, 45),
    visibleAtLocation: true,
  );

  Future<void> openSheet(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.shuklaTheme,
        localizationsDelegates: const [AppLocalizations.delegate],
        supportedLocales: const [Locale('en')],
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(1.6)),
          child: child ?? const SizedBox.shrink(),
        ),
        home: Scaffold(
          body: Center(
            child: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showEclipseDetailsSheet(context, eclipse),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('eclipse details sheet fits a narrow phone', (tester) async {
    await openSheet(tester);

    expect(find.text('Total Solar Eclipse'), findsOneWidget);
    expect(find.byType(SingleChildScrollView), findsWidgets);
  });

  testWidgets('the heading glyph has a gap and never wraps', (tester) async {
    await openSheet(tester);

    final glyph = find.text('☀️');
    final gap =
        tester.getTopLeft(find.text('Total Solar Eclipse')).dx -
        tester.getTopRight(glyph).dx;
    final glyphSize = tester.getSize(glyph);

    expect(gap, AppSpacing.s12);
    expect(glyphSize.height, lessThan(glyphSize.width * 2));
  });

  testWidgets('dense labels keep a tight, even gap to their values', (
    tester,
  ) async {
    await openSheet(tester);

    final label = find.text('Maximum Eclipse:');
    final value = find.textContaining('12:30');
    expect(label, findsOneWidget);
    expect(value, findsOneWidget);

    final gap = tester.getTopLeft(value).dx - tester.getTopRight(label).dx;
    expect(gap, lessThanOrEqualTo(AppSpacing.s16));
  });

  testWidgets('dividers sit evenly between sections', (tester) async {
    await openSheet(tester);

    final lastRow = find.text('Partial phase ends:');
    final firstAfterDivider = find.text('Duration:');
    expect(lastRow, findsOneWidget);
    expect(firstAfterDivider, findsOneWidget);

    // Measure the rows, not the label Texts: at large text scales a value
    // wraps to two lines and centres the label vertically inside its row.
    final lastRowBox = find.ancestor(of: lastRow, matching: find.byType(Row));
    final nextRowBox = find.ancestor(
      of: firstAfterDivider,
      matching: find.byType(Row),
    );
    final firstDivider = find.byType(AppDivider).at(0);

    final above =
        tester.getTopLeft(firstDivider).dy -
        tester.getBottomLeft(lastRowBox).dy;
    final below =
        tester.getTopLeft(nextRowBox).dy -
        tester.getBottomLeft(firstDivider).dy;

    expect(above, AppSpacing.s16);
    expect(below, AppSpacing.s16);
  });

  testWidgets('clock times share one format without seconds', (tester) async {
    await openSheet(tester);

    expect(find.textContaining(':00'), findsNothing);
  });
}
