import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:tithi/models/panchang_data.dart';
import 'package:tithi/providers/accessibility_provider.dart';
import 'package:tithi/providers/calendar_provider.dart';
import 'package:tithi/providers/panchang_provider.dart';
import 'package:tithi/services/storage_service.dart';
import 'package:tithi/widgets/event_list_widget.dart';

class _NoHapticsNotifier extends AccessibilityNotifier {
  @override
  AccessibilityState build() =>
      const AccessibilityState(hapticFeedback: false);
}

void main() {
  setUp(() async {
    final tempDir = await Directory.systemTemp.createTemp('tithi_card_test');
    Hive.init(tempDir.path);
    await StorageService().init();
  });

  tearDown(() async {
    await Hive.close();
  });

  /// Oct 4 2026 squeeze day: Ashtami at sunrise, Navami from 05:53.
  PanchangData cardData() => PanchangData.fromRawTithi(
    date: DateTime(2026, 10, 4),
    rawTithi: 23.98,
    sunrise: DateTime(2026, 10, 4, 5, 28),
    sunset: DateTime(2026, 10, 4, 17, 30),
    tithiTransitionTime: DateTime(2026, 10, 4, 5, 53),
    transitionTithiIndex: 24,
  );

  Future<void> pumpCard(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          panchangForDateProvider.overrideWith(
            (ref, date) => Future.value(cardData()),
          ),
          monthlyPanchangProvider.overrideWith((ref, month) => Future.value({})),
          tithiDisplayModeProvider.overrideWithValue(
            TithiDisplayMode.pakshaBased,
          ),
          accessibilityProvider.overrideWith(_NoHapticsNotifier.new),
          tithiTimingsProvider.overrideWith(
            (ref, arg) async => arg.tithiIndex == 24
                ? (
                    start: DateTime(2026, 10, 4, 5, 53),
                    end: DateTime(2026, 10, 5, 4, 20),
                  )
                : (
                    start: DateTime(2026, 10, 3, 8, 10),
                    end: DateTime(2026, 10, 4, 5, 53),
                  ),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(child: EventListWidget()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('PanchangCard transition', () {
    testWidgets('sizes smoothly and shows the transition line', (
      tester,
    ) async {
      // Arrange + Act
      await pumpCard(tester);

      // Assert: transition line rendered inside an AnimatedSize container
      // (no hard jump when month-preview data swaps for resolved data).
      expect(find.byType(AnimatedSize), findsOneWidget);
      expect(find.text('→ Navami · 5:53 AM'), findsOneWidget);
    });

    testWidgets('tapping the card opens the tithi detail sheet', (
      tester,
    ) async {
      // Arrange
      await pumpCard(tester);

      // Act
      await tester.tap(find.text('→ Navami · 5:53 AM'));
      await tester.pumpAndSettle();

      // Assert
      expect(
        find.text('Transition → Navami at 5:53 AM'),
        findsOneWidget,
      );
    });
  });
}
