import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:tithi/features/hero/widgets/hero_chip.dart';
import 'package:tithi/features/hero/widgets/hero_festival_image.dart';
import 'package:tithi/models/festival.dart';
import 'package:tithi/models/panchang_data.dart';
import 'package:tithi/providers/accessibility_provider.dart';
import 'package:tithi/providers/calendar_provider.dart';
import 'package:tithi/providers/location_provider.dart';
import 'package:tithi/providers/panchang_provider.dart';
import 'package:tithi/services/storage_service.dart';
import 'package:tithi/widgets/moon_animation_widget.dart';
import 'package:tithi/widgets/paksha_hero_card.dart';

class _NoHapticsNotifier extends AccessibilityNotifier {
  @override
  AccessibilityState build() => const AccessibilityState(hapticFeedback: false);
}

class _FixedDateNotifier extends SelectedDateNotifier {
  @override
  DateTime build() => DateTime(2026, 9, 14);
}

/// Hero placement contract: every element hangs off the card's content box
/// (left edges aligned), the artwork is flush to the content right and centered
/// on the text + chip column, and the vertical gaps follow the hero rhythm
/// (6 / 10 / 10).
void main() {
  setUp(() async {
    final tempDir = await Directory.systemTemp.createTemp('tithi_layout_test');
    Hive.init(tempDir.path);
    await StorageService().init();
  });

  tearDown(() async {
    await Hive.close();
  });

  Festival fixture() => const Festival(
    id: 'f',
    name: 'Test Festival',
    category: 'major',
    nameRegional: NameRegional(nameEnglish: 'Test Festival'),
    visuals: Visuals(image: 'assets/images/festival/shri_ganesh.webp'),
    purpose: Purpose(description: 'd'),
    panchangRules: PanchangRules(
      masa: '',
      paksha: 'Shukla',
      tithi: 8,
      conditions: '',
    ),
    rituals: Rituals(steps: []),
    media: Media(),
  );

  /// Ashtami with artwork and a daytime transition into Ashtami — the tallest
  /// hero variant: header, title, moon row, artwork and a transition chip.
  PanchangData tallDay() => PanchangData(
    date: DateTime(2026, 9, 14),
    rawTithi: 7.2,
    tithiNumber: 8,
    tithiName: 'Ashtami',
    paksha: 'Shukla',
    masa: 'Bhadrapada',
    festivals: [fixture()],
    sunrise: DateTime(2026, 9, 14, 6, 5),
    sunset: DateTime(2026, 9, 14, 18, 20),
    tithiTransitionTime: DateTime(2026, 9, 14, 13, 2),
    transitionTithiIndex: 8,
  );

  Future<void> pumpHero(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          selectedDateProvider.overrideWith(_FixedDateNotifier.new),
          livePanchangProvider.overrideWith(
            (ref, day) => Future.value(tallDay()),
          ),
          monthlyPanchangProvider.overrideWith((ref, m) => Future.value({})),
          cityNameProvider.overrideWithValue(const AsyncValue.data('Kolkata')),
          accessibilityProvider.overrideWith(_NoHapticsNotifier.new),
        ],
        child: const MaterialApp(
          home: Scaffold(body: SingleChildScrollView(child: PakshaHeroCard())),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('PakshaHeroCard placement', () {
    testWidgets('left edges align to the card content box', (tester) async {
      // Arrange + Act
      await pumpHero(tester);
      final title = tester.getRect(
        find.text('Monday, Bhadrapada Ashtami', findRichText: true),
      );
      final chip = tester.getRect(find.byType(HeroChip).last);
      final moon = tester.getRect(find.byType(MoonAnimationWidget));

      // Assert: title and transition chip start at the content left, and the
      // 44pt icon tile is centered on that same edge (28pt moon inside it).
      expect(title.left, closeTo(chip.left, 0.5));
      expect(moon.left - 8, closeTo(title.left, 0.5));
    });

    testWidgets('artwork sits flush right and centers on text + chip', (
      tester,
    ) async {
      // Arrange + Act
      await pumpHero(tester);
      final card = tester.getRect(find.byType(PakshaHeroCard));
      final artwork = tester.getRect(find.byType(HeroFestivalImage));
      final moonTitle = tester.getRect(find.text('Shukla Paksha · Ashtami'));
      final chip = tester.getRect(find.byType(HeroChip).last);

      // Assert: flush to the content right (card margin 12 + padding 16)
      expect(artwork.right, closeTo(card.right - 28, 1));

      // Assert: centered against the whole left column (text + chip), which is
      // what keeps the picture in the middle of the card.
      final columnCenter = (moonTitle.top + chip.bottom) / 2;
      expect(artwork.center.dy, closeTo(columnCenter, 1));
    });

    testWidgets('vertical gaps follow the 6 / 10 / 10 rhythm', (tester) async {
      // Arrange + Act
      await pumpHero(tester);
      final tag = tester.getRect(find.textContaining('SELECTED'));
      final locationPill = tester.getRect(find.byType(HeroChip).first);
      final title = tester.getRect(
        find.text('Monday, Bhadrapada Ashtami', findRichText: true),
      );
      final moonTitle = tester.getRect(find.text('Shukla Paksha · Ashtami'));
      final sublabel = tester.getRect(find.textContaining('illuminated'));
      final chip = tester.getRect(find.byType(HeroChip).last);

      // Assert: header → title 6, title → moon block 10, moon block → chip 10.
      // Header/moon-block bottoms come from the tallest child so the check
      // holds whatever the font metrics are.
      final headerBottom = tag.bottom > locationPill.bottom
          ? tag.bottom
          : locationPill.bottom;
      expect(title.top - headerBottom, closeTo(6, 0.5));
      expect(moonTitle.top - title.bottom, closeTo(10, 0.5));
      expect(chip.top - sublabel.bottom, closeTo(10, 0.5));

      // Assert: no overflow anywhere in the taller-than-usual hero
      expect(tester.takeException(), isNull);
    });
  });
}
