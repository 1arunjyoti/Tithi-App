import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:tithi/core/navigation/home_tab.dart';
import 'package:tithi/providers/version_provider.dart';
import 'package:tithi/services/storage_service.dart';
import 'package:tithi/widgets/app_drawer.dart';

// The drawer's Countdowns entry is also one of the shell's destinations.
// Before the shell owned tabs, the entry pushed a full-screen copy of the
// countdowns screen *over* the shell: the bar kept pointing at Today while a
// different screen covered it, back popped to a stale tab, and both copies
// held separate scroll/search state. Hosted by the shell, the entry must
// select the tab instead.
void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('tithi_app_drawer');
    Hive.init(tempDir.path);
    await StorageService().init();
  });

  tearDown(() async {
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  Future<void> pumpDrawer(
    WidgetTester tester, {
    ValueChanged<HomeTab>? onSelectTab,
  }) async {
    // Narrow window: the entry only switches tabs where the shell exists, and
    // `isTabletOrLarger` decides whether the drawer pops itself.
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          versionStringProvider.overrideWith((ref) async => '1.0.0'),
        ],
        child: MaterialApp(
          // The test font (Ahem) draws every glyph as a full square, so the
          // drawer header's icon + two lines of text is wider than it is with
          // the app's real font and overflows its 280dp drawer. Scaling the
          // text down keeps the layout under test identical without the
          // overflow noise the production font does not produce.
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(0.8)),
            child: child!,
          ),
          home: Scaffold(
            drawer: AppDrawer(onSelectTab: onSelectTab),
            body: const SizedBox.expand(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    tester.state<ScaffoldState>(find.byType(Scaffold)).openDrawer();
    await tester.pumpAndSettle();
  }

  Future<void> tapCountdowns(WidgetTester tester) async {
    await tester.tap(find.text('Festival Countdowns'));
    await tester.pump();
  }

  testWidgets('selects the shell tab instead of pushing a second copy', (
    tester,
  ) async {
    // Arrange
    HomeTab? selected;
    await pumpDrawer(tester, onSelectTab: (tab) => selected = tab);

    // Act
    await tapCountdowns(tester);
    await tester.pumpAndSettle();

    // Assert: the shell was asked for its Countdowns tab, the drawer closed,
    // and no route was stacked on top of the shell.
    expect(selected, HomeTab.countdowns);
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    expect(navigator.canPop(), isFalse);
  });

  testWidgets('still pushes when there is no shell to switch', (tester) async {
    // Arrange: the wide sidebar (and every screen that pushes this drawer on
    // its own) passes no callback.
    await pumpDrawer(tester);

    // Act: the route transition is enough to prove a push started; the pushed
    // screen is never built, so nothing heavy is mounted by this test.
    await tapCountdowns(tester);
    await tester.pump(const Duration(milliseconds: 30));

    // Assert
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    expect(navigator.canPop(), isTrue);

    // Tear the pushed route down before the test ends.
    navigator.pop();
    await tester.pumpAndSettle();
  });
}
