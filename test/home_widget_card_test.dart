import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tithi/providers/accessibility_provider.dart';
import 'package:tithi/providers/home_widget_provider.dart';
import 'package:tithi/widgets/home_widget_card.dart';

class _FixedAccessibility extends AccessibilityNotifier {
  @override
  AccessibilityState build() => const AccessibilityState();
}

void main() {
  Future<void> pumpCard(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          accessibilityProvider.overrideWith(_FixedAccessibility.new),
          homeWidgetSyncProvider.overrideWith((ref) {}),
          homeWidgetSupportedProvider.overrideWith((ref) async => true),
          homeWidgetPinSupportProvider.overrideWith((ref) async => true),
        ],
        child: const MaterialApp(home: Scaffold(body: HomeWidgetCard())),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('starts collapsed and toggles from the header', (tester) async {
    // Arrange / Act: first mount.
    await pumpCard(tester);

    // Assert: only the header is visible.
    expect(find.text('Home Screen Widgets'), findsOneWidget);
    expect(find.text('Festival Countdowns'), findsNothing);
    expect(find.text('Hero Card'), findsNothing);

    // Act: tap the header.
    await tester.tap(find.text('Home Screen Widgets'));
    await tester.pumpAndSettle();

    // Assert: the five-row gallery is revealed.
    expect(find.text('Festival Countdowns'), findsOneWidget);
    expect(find.text('Hero Card'), findsOneWidget);
    expect(find.text('Auspicious Timings'), findsOneWidget);
    expect(find.text('Inauspicious Timings'), findsOneWidget);
    expect(find.text('Auspicious & Inauspicious'), findsOneWidget);

    // Act: tap the header again.
    await tester.tap(find.text('Home Screen Widgets'));
    await tester.pumpAndSettle();

    // Assert: the gallery is hidden again.
    expect(find.text('Festival Countdowns'), findsNothing);
    expect(find.text('Hero Card'), findsNothing);
  });
}
