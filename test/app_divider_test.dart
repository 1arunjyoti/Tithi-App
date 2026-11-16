import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tithi/theme/app_theme.dart';
import 'package:tithi/widgets/app_divider.dart';
import 'package:tithi/widgets/inset_row_divider.dart';

/// Pumps [child] under the Shukla theme, optionally with High Contrast.
Widget _host(Widget child, {bool highContrast = false}) {
  return MaterialApp(
    theme: AppTheme.shuklaTheme,
    home: Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(context).copyWith(highContrast: highContrast),
        child: Scaffold(body: Center(child: child)),
      ),
    ),
  );
}

double _alphaOf(WidgetTester tester) {
  final divider = tester.widget<Divider>(find.byType(Divider));
  return divider.color!.a;
}

void main() {
  group('AppDivider', () {
    testWidgets('section rule is a 1px hairline at 0.1', (tester) async {
      await tester.pumpWidget(_host(const AppDivider()));

      final divider = tester.widget<Divider>(find.byType(Divider));
      expect(divider.height, 1);
      expect(divider.thickness, 1);
      expect(divider.indent, 0);
      expect(divider.endIndent, 0);
      expect(_alphaOf(tester), closeTo(0.1, 0.001));
    });

    testWidgets('row rule is quieter than a section rule', (tester) async {
      await tester.pumpWidget(_host(const AppDivider.row()));

      expect(_alphaOf(tester), closeTo(0.08, 0.001));
      expect(tester.widget<AppDivider>(find.byType(AppDivider)).tight, isTrue);
    });

    testWidgets('forwards indent and endIndent', (tester) async {
      await tester.pumpWidget(
        _host(const AppDivider(indent: 16, endIndent: 8)),
      );

      final divider = tester.widget<Divider>(find.byType(Divider));
      expect(divider.indent, 16);
      expect(divider.endIndent, 8);
    });

    testWidgets('High Contrast lifts a rule to 0.22, not full ink', (
      tester,
    ) async {
      await tester.pumpWidget(_host(const AppDivider(), highContrast: true));
      expect(_alphaOf(tester), closeTo(0.22, 0.001));

      await tester.pumpWidget(
        _host(const AppDivider.row(), highContrast: true),
      );
      expect(_alphaOf(tester), closeTo(0.22, 0.001));
    });
  });

  group('InsetRowDivider', () {
    testWidgets('delegates to the row rule at the leading inset', (
      tester,
    ) async {
      await tester.pumpWidget(_host(const InsetRowDivider(leadingInset: 44)));

      final delegate = tester.widget<AppDivider>(find.byType(AppDivider));
      expect(delegate.tight, isTrue);
      expect(delegate.indent, 44);
      expect(_alphaOf(tester), closeTo(0.08, 0.001));
    });

    testWidgets('High Contrast applies to the delegated rule', (tester) async {
      await tester.pumpWidget(
        _host(const InsetRowDivider(leadingInset: 44), highContrast: true),
      );

      expect(_alphaOf(tester), closeTo(0.22, 0.001));
    });
  });
}
