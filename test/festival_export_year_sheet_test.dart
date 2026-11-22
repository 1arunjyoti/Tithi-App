import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:tithi/features/settings/widgets/festival_export_year_sheet.dart';

void main() {
  final thisYear = DateTime.now().year;

  Future<void> openSheet(
    WidgetTester tester,
    ValueChanged<int> onExport,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: Builder(
              builder: (context) => FilledButton(
                onPressed: () => FestivalExportYearSheet.show(
                  context: context,
                  title: 'Add to Google Calendar (.ics)',
                  subtitle: 'Choose a year. You will choose where to save next.',
                  onExport: onExport,
                ),
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

  testWidgets('a year tap selects; only the confirm button exports',
      (tester) async {
    // The modal sheet is taller than the default 800x600 test surface, which
    // would push the confirm button off-screen and make tap() miss it.
    await tester.binding.setSurfaceSize(const Size(800, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final exported = <int>[];
    await openSheet(tester, exported.add);

    expect(find.text('Add to Google Calendar (.ics)'), findsOneWidget);
    expect(find.text('Export $thisYear'), findsOneWidget);

    // Selecting another year keeps the sheet open and retitles the button;
    // it must not start the export on its own.
    await tester.tap(find.text((thisYear + 1).toString()));
    await tester.pumpAndSettle();

    expect(find.text('Add to Google Calendar (.ics)'), findsOneWidget);
    expect(find.text('Export ${thisYear + 1}'), findsOneWidget);
    expect(exported, isEmpty);

    // The explicit confirm closes the sheet and reports the selected year.
    await tester.tap(find.text('Export ${thisYear + 1}'));
    await tester.pumpAndSettle();

    expect(exported, equals([thisYear + 1]));
    expect(find.text('Add to Google Calendar (.ics)'), findsNothing);
  });
}
