import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tithi/models/festival.dart';
import 'package:tithi/providers/accessibility_provider.dart';
import 'package:tithi/providers/festival_provider.dart';
import 'package:tithi/widgets/festival_search_delegate.dart';

class _NoHapticsNotifier extends AccessibilityNotifier {
  @override
  AccessibilityState build() => const AccessibilityState(hapticFeedback: false);
}

void main() {
  Festival fixture({
    required String id,
    required String name,
    String image = '',
  }) => Festival(
    id: id,
    name: name,
    category: 'major',
    nameRegional: const NameRegional(nameEnglish: 'Test Festival'),
    visuals: Visuals(image: image),
    purpose: const Purpose(description: 'A test festival.'),
    panchangRules: const PanchangRules(
      masa: '',
      paksha: 'Shukla',
      tithi: 4,
      conditions: '',
    ),
    rituals: const Rituals(steps: []),
    media: const Media(),
  );

  /// Opens the app's search overlay from a plain button.

  testWidgets('results show artwork when the festival ships one', (
    tester,
  ) async {
    // Arrange: two matching festivals, only the first has artwork.
    final withArt = fixture(
      id: 'art',
      name: 'Ganesh Chaturthi',
      image: 'assets/images/festival/shri_ganesh.webp',
    );
    final plain = fixture(id: 'plain', name: 'Ganesh Visarjan');
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          festivalProvider.overrideWithValue([withArt, plain]),
          accessibilityProvider.overrideWith(_NoHapticsNotifier.new),
        ],
        child: const MaterialApp(home: _SearchHost()),
      ),
    );

    // Act
    await tester.tap(find.text('open search'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'ganesh');
    await tester.pumpAndSettle();

    // Assert: both rows render, one with the picture and one with the glyph.
    expect(find.text('Ganesh Chaturthi'), findsOneWidget);
    expect(find.text('Ganesh Visarjan'), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
    expect(find.byIcon(Icons.celebration), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

/// Kept as a widget (not a closure) so the test can host it under
/// `MaterialApp` while the delegate receives a live [WidgetRef].
class _SearchHost extends ConsumerWidget {
  const _SearchHost();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Builder(
        builder: (context) => TextButton(
          onPressed: () => showSearch<void>(
            context: context,
            delegate: FestivalSearchDelegate(ref: ref, parentContext: context),
          ),
          child: const Text('open search'),
        ),
      ),
    );
  }
}
