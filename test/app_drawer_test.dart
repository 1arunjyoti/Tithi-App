import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:tithi/providers/version_provider.dart';
import 'package:tithi/services/storage_service.dart';
import 'package:tithi/widgets/app_drawer.dart';

// Countdowns is not a shell destination: the drawer entry pushes the screen as
// a peer route over whatever tab is showing (same as Moon Phases or Settings),
// so the entry behaves the same in the narrow drawer and the wide sidebar.
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

  Future<void> pumpDrawer(WidgetTester tester) async {
    // Narrow window: the drawer pops itself before pushing (`isTabletOrLarger`
    // decides), which is the path the shell uses.
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [versionStringProvider.overrideWith((ref) async => '1.0.0')],
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
          home: const Scaffold(drawer: AppDrawer(), body: SizedBox.expand()),
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

  testWidgets('Countdowns entry pushes the screen as a peer route', (
    tester,
  ) async {
    // Arrange
    await pumpDrawer(tester);

    // Act: the route transition is enough to prove a push started; the pushed
    // screen is never built far enough to resolve its countdown targets.
    await tapCountdowns(tester);
    await tester.pump(const Duration(milliseconds: 30));

    // Assert: a route sits on top of the hosting screen (back returns to the
    // tab rather than leaving a destination switched under the bar).
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    expect(navigator.canPop(), isTrue);

    // Tear the pushed route down before the test ends.
    navigator.pop();
    await tester.pumpAndSettle();
    expect(navigator.canPop(), isFalse);
  });
}
