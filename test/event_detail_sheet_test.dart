import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:tithi/models/festival.dart';
import 'package:tithi/models/panchang_data.dart';
import 'package:tithi/providers/calendar_provider.dart';
import 'package:tithi/providers/panchang_provider.dart';
import 'package:tithi/services/storage_service.dart';
import 'package:tithi/widgets/event_detail_sheet.dart';

/// Widget-level proof that the Puja Samay card and the paran line render in
/// the event sheet once the festival's data carries pujaKala / paranRule —
/// and stay hidden otherwise (no data, or no panchang context).
void main() {
  const lat = 28.6139;
  const lon = 77.2090;

  setUp(() async {
    final tempDir = await Directory.systemTemp.createTemp('event_sheet_test');
    Hive.init(tempDir.path);
    await StorageService().init();
  });

  tearDown(() async {
    await Hive.close();
  });

  Festival festival({
    String? pujaKala,
    String? paranRule,
    String fasting = 'Fast until the puja.',
  }) {
    return Festival(
      id: 'f1',
      name: 'Test Festival',
      nameRegional: const NameRegional(nameEnglish: 'Test Festival'),
      visuals: const Visuals(),
      purpose: const Purpose(description: 'A test festival.'),
      panchangRules: PanchangRules(
        masa: 'Shravana',
        paksha: 'Shukla',
        tithi: 4,
        conditions: 'Lunar',
        pujaKala: pujaKala,
        paranRule: paranRule,
      ),
      rituals: Rituals(
        steps: const ['Light a lamp'],
        fasting: fasting.isEmpty ? null : fasting,
      ),
      media: const Media(),
    );
  }

  PanchangData day() {
    return PanchangData(
      date: DateTime(2026, 10, 6),
      rawTithi: 4.5,
      tithiNumber: 4,
      tithiName: '',
      paksha: 'Shukla',
      masa: 'Shravana',
      sunrise: DateTime(2026, 10, 6, 5, 29),
      sunset: DateTime(2026, 10, 6, 17, 28),
    );
  }

  Future<void> pumpSheet(
    WidgetTester tester,
    Festival f,
    PanchangData? panchang,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          resolvedCoordinatesProvider.overrideWithValue((
            latitude: lat,
            longitude: lon,
          )),
          tithiDisplayModeProvider.overrideWithValue(
            TithiDisplayMode.pakshaBased,
          ),
          tithiTimingsProvider.overrideWith(
            (ref, arg) => Future.value((
              start: DateTime(2026, 10, 5, 20, 10),
              end: DateTime(2026, 10, 6, 17),
            )),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: EventDetailSheet(festival: f, panchang: panchang),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> scrollTo(WidgetTester tester, String text) async {
    await tester.scrollUntilVisible(
      find.text(text),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
  }

  group('EventDetailSheet hero language chips', () {
    Festival multiRegional() {
      return const Festival(
        id: 'f2',
        name: 'Test Festival',
        nameRegional: NameRegional(
          nameEnglish: 'Test Festival',
          nameHindi: 'परीक्षा उत्सव हिंदी में',
          nameBengali: 'বাংলায় পরীক্ষা উৎসব',
          nameTelugu: 'తెలుగులో పరీక్ష పండుగ',
          nameKannada: 'ಕನ್ನಡದಲ್ಲಿ ಪರೀಕ್ಷಾ ಹಬ್ಬ',
          nameTamil: 'தமிழில் சோதனை திருவிழா',
          nameMalayalam: 'മലയാളത്തിൽ പരീക്ഷാ ഉത്സവം',
        ),
        visuals: Visuals(),
        purpose: Purpose(description: 'A test festival.'),
        panchangRules: PanchangRules(
          masa: 'Shravana',
          paksha: 'Shukla',
          tithi: 4,
          conditions: 'Lunar',
        ),
        rituals: Rituals(steps: ['Light a lamp']),
        media: Media(),
      );
    }

    Future<void> pumpPhoneSheet(
      WidgetTester tester,
      Festival f,
      PanchangData? panchang,
    ) async {
      // Phone-width surface so six regional names always wrap past the
      // first row (the default 800px test surface could fit them in one).
      tester.view.physicalSize = const Size(390 * 3, 844 * 3);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      await pumpSheet(tester, f, panchang);
    }

    testWidgets('collapses to the first row with a trailing arrow', (
      tester,
    ) async {
      // Arrange + Act
      await pumpPhoneSheet(tester, multiRegional(), day());

      // Assert: collapsed by default — expand arrow visible (clipped chips
      // stay in the tree, so assert on the arrow, not on hidden chip text).
      expect(find.byIcon(Icons.keyboard_arrow_down), findsOneWidget);
      expect(find.byIcon(Icons.keyboard_arrow_up), findsNothing);
    });

    testWidgets('arrow reveals all chips and collapses back', (
      tester,
    ) async {
      // Arrange
      await pumpPhoneSheet(tester, multiRegional(), day());

      // Act: expand.
      await tester.tap(find.byIcon(Icons.keyboard_arrow_down));
      await tester.pumpAndSettle();

      // Assert: collapse arrow replaces the expand one.
      expect(find.byIcon(Icons.keyboard_arrow_up), findsOneWidget);
      expect(find.byIcon(Icons.keyboard_arrow_down), findsNothing);

      // Act: collapse again.
      await tester.tap(find.byIcon(Icons.keyboard_arrow_up));
      await tester.pumpAndSettle();

      // Assert: back to the collapsed arrow.
      expect(find.byIcon(Icons.keyboard_arrow_down), findsOneWidget);
      expect(find.byIcon(Icons.keyboard_arrow_up), findsNothing);
    });

    testWidgets('single-row names render with no toggle', (tester) async {
      // Arrange + Act: one regional name always fits a single row.
      await pumpSheet(
        tester,
        const Festival(
          id: 'f3',
          name: 'Test Festival',
          nameRegional: NameRegional(
            nameEnglish: 'Test Festival',
            nameHindi: 'परीक्षा',
          ),
          visuals: Visuals(),
          purpose: Purpose(description: 'A test festival.'),
          panchangRules: PanchangRules(
            masa: 'Shravana',
            paksha: 'Shukla',
            tithi: 4,
            conditions: 'Lunar',
          ),
          rituals: Rituals(steps: ['Light a lamp']),
          media: Media(),
        ),
        day(),
      );

      // Assert
      expect(find.text('परीक्षा'), findsOneWidget);
      expect(find.byIcon(Icons.keyboard_arrow_down), findsNothing);
      expect(find.byIcon(Icons.keyboard_arrow_up), findsNothing);
    });
  });

  group('EventDetailSheet puja cards', () {
    testWidgets('shows the Puja Samay card once pujaKala is set', (
      tester,
    ) async {
      // Arrange + Act
      await pumpSheet(
        tester,
        festival(pujaKala: 'madhyahna', paranRule: 'moonrise'),
        day(),
      );

      // Assert: section header with the kala, two-cell card labels.
      await scrollTo(tester, 'Puja Samay · Madhyahna');
      expect(find.text('Puja Samay · Madhyahna'), findsOneWidget);
      expect(find.text('MADHYAHNA'), findsOneWidget);
      expect(find.text('PUJA WINDOW'), findsOneWidget);
      // The Panchang Details Begins/Ends card stands above the Puja card.
      expect(find.text('BEGINS'), findsWidgets);
    });

    testWidgets('shows the paran line once paranRule is set', (
      tester,
    ) async {
      // Arrange + Act
      await pumpSheet(
        tester,
        festival(pujaKala: 'moonrise', paranRule: 'moonrise'),
        day(),
      );

      // Assert: red label plus the moonrise reason (Oct 6 Delhi moonrise
      // resolves via the real calculator, with prevailing fallback).
      await scrollTo(tester, 'Paran (breaking the fast):');
      expect(find.text('Paran (breaking the fast):'), findsOneWidget);
      expect(find.textContaining('after moonrise'), findsOneWidget);
    });

    testWidgets('hides both without data or without panchang', (
      tester,
    ) async {
      // Arrange + Act: no kala/rule in data.
      await pumpSheet(tester, festival(), day());

      // Assert
      expect(find.textContaining('Puja Samay'), findsNothing);
      expect(find.textContaining('Paran (breaking'), findsNothing);

      // Arrange + Act: data present but opened without a date (e.g. the
      // all-festivals list) — windows need the day's anchors.
      await pumpSheet(
        tester,
        festival(pujaKala: 'madhyahna', paranRule: 'moonrise'),
        null,
      );

      // Assert
      expect(find.textContaining('Puja Samay'), findsNothing);
      expect(find.textContaining('Paran (breaking'), findsNothing);
      // The fasting text itself still shows.
      expect(find.text('Fast until the puja.'), findsOneWidget);
    });
  });
}
