import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tithi/models/festival.dart';
import 'package:tithi/widgets/festival_thumbnail.dart';

void main() {
  Festival festival({String image = '', String category = 'major'}) => Festival(
    id: 'fixture',
    name: 'Test Festival',
    category: category,
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

  Future<void> pumpThumb(WidgetTester tester, Festival value) {
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: FestivalThumbnail(
              festival: value,
              size: 48,
              backgroundColor: Colors.grey,
              glyphColor: Colors.amber,
            ),
          ),
        ),
      ),
    );
  }

  group('FestivalThumbnail', () {
    testWidgets('draws the bundled artwork when the festival ships one', (
      tester,
    ) async {
      // Arrange + Act
      await pumpThumb(
        tester,
        festival(image: 'assets/images/festival/shri_ganesh.webp'),
      );

      // Assert: the picture replaces the category glyph.
      expect(find.byType(Image), findsOneWidget);
      expect(find.byIcon(Icons.wb_sunny_rounded), findsNothing);
    });

    testWidgets('falls back to the category glyph without artwork', (
      tester,
    ) async {
      // Arrange + Act
      await pumpThumb(tester, festival(category: 'vrat'));

      // Assert
      expect(find.byType(Image), findsNothing);
      expect(find.byIcon(Icons.temple_buddhist), findsOneWidget);
    });
  });
}
