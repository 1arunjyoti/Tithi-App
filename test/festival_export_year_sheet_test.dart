import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';

import 'package:tithi/features/settings/widgets/festival_export_year_sheet.dart';
import 'package:tithi/providers/accessibility_provider.dart';

/// AppButton reads the accessibility setting for haptics; stub the Hive-backed
/// provider so the sheet can render in a widget test.
class _StubAccessibility extends AccessibilityNotifier {
  @override
  AccessibilityState build() => const AccessibilityState();
}

void main() {
  final thisYear = DateTime.now().year;

  Future<void> openSheet(
    WidgetTester tester,
    ValueChanged<int> onExport,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [accessibilityProvider.overrideWith(_StubAccessibility.new)],
        child: MaterialApp(
          home: Scaffold(
            body: Center(
              child: Builder(
                builder: (context) => FilledButton(
                  onPressed: () => FestivalExportYearSheet.show(
                    context: context,
                    title: 'Add to Google Calendar (.ics)',
                    subtitle:
                        'Choose a year. You will choose where to save next.',
                    onExport: onExport,
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('a year tap selects; only the confirm button exports', (
    tester,
  ) async {
    // The modal sheet is taller than the default 800x600 test surface, which
    // would push the confirm button off-screen and make tap() miss it.
    await tester.binding.setSurfaceSize(const Size(800, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final exported = <int>[];
    await openSheet(tester, exported.add);

    expect(find.text('Add to Google Calendar (.ics)'), findsOneWidget);
    expect(find.text('Export $thisYear'), findsOneWidget);

    // One M3EList owns the surfaces and dispatches taps by index; its rows are
    // Expressive list items. The sheet chrome itself is pushed as a modal host
    // rather than a widget named M3EBottomSheet.
    expect(find.byType(M3EList), findsOneWidget);
    expect(find.byType(M3EListItem), findsNWidgets(4));

    // The parent list paints the selected surface (an embedded row's own
    // `selected` flag does not). Pin the light-mode fill so a regression
    // cannot leave the current year invisible again.
    final list = tester.widget<M3EList>(find.byType(M3EList));
    final theme = M3ETheme.of(tester.element(find.byType(M3EList)));
    // Light mode: primary fill with white selected text (onPrimary).
    expect(list.colorBuilder?.call(1), equals(theme.colorScheme.primary));
    expect(list.colorBuilder?.call(0), isNull);
    expect(
      theme.listTheme.item.selectedContentColor,
      equals(theme.colorScheme.onPrimary),
    );
    expect(theme.colorScheme.onPrimary, equals(Colors.white));

    // ...and what actually reaches the paint tree, not just the builders.
    final surfaces = find
        .byType(M3EListRowSurface)
        .evaluate()
        .map((element) => element.widget as M3EListRowSurface)
        .toList();
    expect(surfaces.length, equals(4));
    expect(surfaces[1].color, equals(theme.colorScheme.primary));
    final selectedText = tester.widget<Text>(find.text(thisYear.toString()));
    expect(selectedText.style?.color, equals(Colors.white));

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
