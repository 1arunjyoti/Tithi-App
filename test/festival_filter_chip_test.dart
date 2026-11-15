import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tithi/theme/app_theme.dart';
import 'package:tithi/widgets/festival_filter_chip.dart';

/// Selection fill of `FestivalFilterChip` as painted on each frame.
///
/// `RawChip` draws the fill on the `Ink` decoration inside the chip and
/// rebuilds it from the selection animation, so sampling it mid-fade shows
/// what the user actually sees between tap and settle.
Set<Color> _paintedFills(WidgetTester tester) {
  final seen = <Color>{};
  for (final ink in tester.widgetList<Ink>(
    find.descendant(
      of: find.byType(FestivalFilterChip),
      matching: find.byType(Ink),
    ),
  )) {
    final decoration = ink.decoration;
    if (decoration is ShapeDecoration && decoration.color != null) {
      seen.add(decoration.color!);
    }
  }
  return seen;
}

void main() {
  for (final entry in {
    'Shukla': AppTheme.shuklaTheme,
    'Krishna': AppTheme.krishnaTheme,
    'Pure Dark': AppTheme.pureDarkTheme,
  }.entries) {
    testWidgets(
      'selection fade never paints above the accent wash (${entry.key})',
      (tester) async {
        final theme = entry.value;
        final wash = theme.colorScheme.primary.withValues(alpha: 0.16);
        // Material 3's chip default for the fill a selection fade starts
        // from; the regression this locks was that opaque block showing for
        // the length of the fade in both the strip and the filter sheet.
        final opaqueDefault = theme.colorScheme.secondaryContainer;
        expect(opaqueDefault.a, 1.0);

        var selected = false;
        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            home: Scaffold(
              body: Center(
                child: StatefulBuilder(
                  builder: (context, setState) => FestivalFilterChip(
                    label: 'Major',
                    selected: selected,
                    onTap: () => setState(() => selected = true),
                  ),
                ),
              ),
            ),
          ),
        );

        final seen = <Color>{..._paintedFills(tester)};
        await tester.tap(find.text('Major'));
        // Sample through the whole fade, not just its endpoints.
        for (var frame = 0; frame < 10; frame++) {
          await tester.pump(const Duration(milliseconds: 25));
          seen.addAll(_paintedFills(tester));
        }

        expect(selected, isTrue);
        // Every frame stays within the wash: the pre-fix chip faded down from
        // an opaque fill, so its alpha started at 1.0.
        for (final color in seen) {
          expect(
            color.a,
            lessThanOrEqualTo(wash.a + 0.001),
            reason: 'painted $color mid-selection (wash is $wash)',
          );
        }
        expect(seen, contains(wash));
      },
    );
  }
}
