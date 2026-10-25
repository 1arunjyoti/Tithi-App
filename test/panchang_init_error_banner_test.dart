import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tithi/providers/panchang_provider.dart';
import 'package:tithi/services/panchang_init/panchang_init.dart';
import 'package:tithi/widgets/panchang_init_error_banner.dart';

// Phase 6: the calendar maps panchang provider failures to an empty month, so
// a broken ephemeris install used to look like "no festivals this month".
// The banner is the only surface that explains it, which makes these
// assertions the user-visible half of the init fix.

void main() {
  Future<void> pumpBanner(WidgetTester tester, Override override) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [override],
        child: const MaterialApp(
          home: Scaffold(body: PanchangInitErrorBanner()),
        ),
      ),
    );
    // Let the overridden future settle.
    await tester.pump();
    await tester.pump();
  }

  testWidgets('renders nothing while init is pending', (tester) async {
    // Arrange
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          panchangInitProvider.overrideWith((ref) => Completer<void>().future),
        ],
        child: const MaterialApp(
          home: Scaffold(body: PanchangInitErrorBanner()),
        ),
      ),
    );

    // Assert
    expect(find.byType(Text), findsNothing);
  });

  testWidgets('renders nothing when init succeeds', (tester) async {
    // Act
    await pumpBanner(
      tester,
      panchangInitProvider.overrideWith((ref) async {}),
    );

    // Assert
    expect(find.byType(Text), findsNothing);
  });

  testWidgets('shows the ephemeris message and a retry', (tester) async {
    // Arrange
    const message =
        'The Swiss Ephemeris file "sepl_18.se1" is missing from the app '
        'bundle. Reinstall the app to restore it.';

    // Act
    await pumpBanner(
      tester,
      panchangInitProvider.overrideWith(
        (ref) async => throw const EphemerisAssetException(message),
      ),
    );

    // Assert
    expect(find.text('Error loading data'), findsOneWidget);
    expect(find.text(message), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('hides internals behind generic copy for unknown errors',
      (tester) async {
    // Act
    await pumpBanner(
      tester,
      panchangInitProvider.overrideWith(
        (ref) async => throw StateError('FFI handle 0xDEADBEEF'),
      ),
    );

    // Assert
    expect(
      find.text('An unexpected error occurred. Please try again.'),
      findsOneWidget,
    );
    expect(find.textContaining('0xDEADBEEF'), findsNothing);
  });

  testWidgets('retry re-runs init and clears the banner on success',
      (tester) async {
    // Arrange: first attempt fails, second succeeds.
    var attempts = 0;
    await pumpBanner(
      tester,
      panchangInitProvider.overrideWith((ref) async {
        attempts++;
        if (attempts == 1) {
          throw const EphemerisAssetException('Disk is full.');
        }
      }),
    );
    expect(find.text('Disk is full.'), findsOneWidget);

    // Act
    await tester.tap(find.text('Retry'));
    await tester.pump();
    await tester.pump();

    // Assert
    expect(attempts, 2);
    expect(find.text('Disk is full.'), findsNothing);
    expect(find.text('Retry'), findsNothing);
  });
}
