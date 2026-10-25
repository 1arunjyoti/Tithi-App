import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tithi/providers/panchang_provider.dart';
import 'package:tithi/services/panchang_init/panchang_init.dart';
import 'package:tithi/widgets/panchang_init_error_banner.dart';
import 'package:tithi/widgets/panchang_init_failure_overlay.dart';

// Phase 6 (#23): the banner used to be mounted only on the home screen, while
// about two dozen other call sites await panchangInitProvider and degrade to
// empty data. The overlay is mounted from MaterialApp.builder so the failure
// follows the user onto every pushed route.

void main() {
  /// A body that reports the status-bar inset it sees, which is how the
  /// "banner consumes the inset" rule is pinned.
  Widget probe() => Builder(
    builder: (context) =>
        Text('top:${MediaQuery.of(context).padding.top.round()}'),
  );

  Future<void> pumpApp(
    WidgetTester tester, {
    required Override override,
    Widget? home,
  }) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.padding = const FakeViewPadding(top: 24);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPadding);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [override],
        child: MaterialApp(
          builder: (context, child) =>
              PanchangInitFailureOverlay(child: child!),
          home: home ?? Scaffold(body: probe()),
        ),
      ),
    );
    // Let the overridden future settle.
    await tester.pump();
    await tester.pump();
  }

  testWidgets('leaves the app untouched while init succeeds', (tester) async {
    // Act
    await pumpApp(
      tester,
      override: panchangInitProvider.overrideWith((ref) async {}),
    );

    // Assert: no banner, and the status-bar inset is still the app's own.
    expect(find.byType(PanchangInitErrorBanner), findsNothing);
    expect(find.text('top:24'), findsOneWidget);
  });

  testWidgets('pins the banner above the app when init fails', (tester) async {
    // Arrange
    const message =
        'The Swiss Ephemeris file "sepl_18.se1" is missing from the app '
        'bundle. Reinstall the app to restore it.';

    // Act
    await pumpApp(
      tester,
      override: panchangInitProvider.overrideWith(
        (ref) async => throw const EphemerisAssetException(message),
      ),
    );

    // Assert: the app is still on screen, starting below the banner.
    expect(find.text(message), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    expect(find.text('top:0'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('top:0')).dy,
      greaterThanOrEqualTo(
        tester.getBottomLeft(find.byType(PanchangInitErrorBanner)).dy,
      ),
    );
  });

  testWidgets('keeps the banner visible on a pushed route', (tester) async {
    // Arrange: a second screen the user can navigate to.
    final home = Scaffold(
      body: Builder(
        builder: (context) => Center(
          child: TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const Scaffold(body: Text('second screen')),
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await pumpApp(
      tester,
      override: panchangInitProvider.overrideWith(
        (ref) async => throw const EphemerisEngineException('Engine missing.'),
      ),
      home: home,
    );

    // Act
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // Assert: the failure follows the user instead of living on the home
    // screen only.
    expect(find.text('second screen'), findsOneWidget);
    expect(find.text('Engine missing.'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('retry from a pushed route re-runs init and clears the banner',
      (tester) async {
    // Arrange: first attempt fails, second succeeds.
    var attempts = 0;
    final home = Scaffold(
      body: Builder(
        builder: (context) => Center(
          child: TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const Scaffold(body: Text('second screen')),
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await pumpApp(
      tester,
      override: panchangInitProvider.overrideWith((ref) async {
        attempts++;
        if (attempts == 1) {
          throw const EphemerisAssetException('Disk is full.');
        }
      }),
      home: home,
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Disk is full.'), findsOneWidget);

    // Act
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    // Assert: the route stays where it was and the app reclaims the space.
    expect(attempts, 2);
    expect(find.text('second screen'), findsOneWidget);
    expect(find.byType(PanchangInitErrorBanner), findsNothing);
    expect(find.text('Retry'), findsNothing);
  });
}
