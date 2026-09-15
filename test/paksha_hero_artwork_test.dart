import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:tithi/models/festival.dart';
import 'package:tithi/models/hindu_month_system.dart';
import 'package:tithi/models/panchang_data.dart';
import 'package:tithi/providers/accessibility_provider.dart';
import 'package:tithi/providers/calendar_provider.dart';
import 'package:tithi/providers/locale_provider.dart';
import 'package:tithi/providers/location_provider.dart';
import 'package:tithi/providers/panchang_provider.dart';
import 'package:tithi/services/storage_service.dart';
import 'package:tithi/widgets/paksha_hero_card.dart';
import 'package:tithi/widgets/tithi_detail_sheet.dart';

class _NoHapticsNotifier extends AccessibilityNotifier {
  @override
  AccessibilityState build() =>
      const AccessibilityState(hapticFeedback: false);
}

class _FixedDateNotifier extends SelectedDateNotifier {
  @override
  DateTime build() => DateTime(2026, 9, 14);
}

class _BengaliLocaleNotifier extends LocaleNotifier {
  @override
  Locale? build() => const Locale('bn');
}

void main() {
  setUp(() async {
    final tempDir = await Directory.systemTemp.createTemp('tithi_hero_test');
    Hive.init(tempDir.path);
    await StorageService().init();
  });

  tearDown(() async {
    await Hive.close();
  });

  /// Festival fixture: [image] maps to Festival.visuals.image ('' = none).
  Festival fixture({String image = ''}) => Festival(
    id: 'test-festival',
    name: 'Test Festival',
    category: 'major',
    nameRegional: const NameRegional(nameEnglish: 'Test Festival'),
    visuals: Visuals(image: image),
    purpose: const Purpose(description: 'Test description'),
    panchangRules: const PanchangRules(
      masa: '',
      paksha: 'Shukla',
      tithi: 6,
      conditions: '',
    ),
    rituals: const Rituals(steps: []),
    media: const Media(),
  );

  PanchangData heroData({String image = ''}) => PanchangData(
    date: DateTime(2026, 9, 14),
    rawTithi: 6.5,
    tithiNumber: 6,
    tithiName: 'Shashthi',
    paksha: 'Shukla',
    masa: 'Bhadrapada',
    festivals: [fixture(image: image)],
    sunrise: DateTime(2026, 9, 14, 5, 39),
    sunset: DateTime(2026, 9, 14, 18, 12),
  );

  /// Krishna-paksha fixture for month-system tests (Shravana Krishna =
  /// Bhadrapada in Purnimant).
  PanchangData heroDataKrishna() => PanchangData(
    date: DateTime(2026, 9, 6),
    rawTithi: 23.0,
    tithiNumber: 8,
    tithiName: 'Ashtami',
    paksha: 'Krishna',
    masa: 'Shravana',
  );

  Future<void> pumpHero(
    WidgetTester tester, {
    String image = '',
    String city = 'Kolkata',
    PanchangData? data,
    List<Override> extraOverrides = const [],
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          selectedDateProvider.overrideWith(_FixedDateNotifier.new),
          panchangForDateProvider.overrideWith(
            (ref, date) => Future.value(data ?? heroData(image: image)),
          ),
          monthlyPanchangProvider.overrideWith(
            (ref, month) => Future.value({}),
          ),
          cityNameProvider.overrideWithValue(AsyncValue.data(city)),
          ...extraOverrides,
          accessibilityProvider.overrideWith(_NoHapticsNotifier.new),
          tithiTimingsProvider.overrideWith(
            (ref, arg) async => (
              start: DateTime(2026, 9, 14, 5, 39),
              end: DateTime(2026, 9, 15, 4, 20),
            ),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(body: SingleChildScrollView(child: PakshaHeroCard())),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('PakshaHeroCard festival artwork', () {
    testWidgets('text-only layout when the festival has no image', (
      tester,
    ) async {
      // Arrange + Act
      await pumpHero(tester);

      // Assert: hero content renders, artwork slot stays absent
      expect(find.text('Shukla Paksha · Shashthi'), findsOneWidget);
      expect(find.byType(Image), findsNothing);
    });

    testWidgets('artwork slot renders when the festival has an image', (
      tester,
    ) async {
      // Arrange + Act (real bundled festival artwork path)
      await pumpHero(
        tester,
        image: 'assets/images/festival/shri_ganesh.jpeg',
      );

      // Assert: text content intact and the picture slot is present
      expect(find.text('Shukla Paksha · Shashthi'), findsOneWidget);
      expect(find.byType(Image), findsOneWidget);
    });

    testWidgets('tapping the hero opens the tithi detail sheet', (
      tester,
    ) async {
      // Arrange
      await pumpHero(tester);

      // Act
      await tester.tap(find.text('Shukla Paksha · Shashthi'));
      await tester.pumpAndSettle();

      // Assert
      expect(find.byType(TithiDetailSheet), findsOneWidget);
    });

    testWidgets('Purnimant Krishna days show the converted masa', (
      tester,
    ) async {
      // Arrange + Act (Shravana Krishna = Bhadrapada in Purnimant)
      await pumpHero(
        tester,
        data: heroDataKrishna(),
        extraOverrides: [
          hinduMonthSystemProvider.overrideWithValue(
            HinduMonthSystem.purnimant,
          ),
        ],
      );

      // Assert: day line uses the converted month (full RichText string)
      expect(
        find.text('Sunday, Bhadrapada Ashtami', findRichText: true),
        findsOneWidget,
      );
      expect(
        find.text('Sunday, Shravana Ashtami', findRichText: true),
        findsNothing,
      );
    });

    testWidgets('Bengali secondary renders transliterated in English', (
      tester,
    ) async {
      // Arrange + Act (test locale is English → no Bengali script)
      await pumpHero(
        tester,
        extraOverrides: [
          secondaryCalendarSystemProvider.overrideWithValue(
            AppCalendarSystem.bengali,
          ),
          bengaliDateForHeroProvider.overrideWith(
            (ref, date) => Future.value((day: 31, month: 'Bhadro', year: 1432)),
          ),
        ],
      );

      // Assert: moon row intact, title carries the Bengali secondary
      expect(find.text('Shukla Paksha · Shashthi'), findsOneWidget);
      expect(
        find.text('Monday, 31 Bhadro', findRichText: true),
        findsOneWidget,
      );
    });

    testWidgets('Bengali app language shows Bengali script', (tester) async {
      // Arrange + Act
      await pumpHero(
        tester,
        extraOverrides: [
          localeProvider.overrideWith(_BengaliLocaleNotifier.new),
          secondaryCalendarSystemProvider.overrideWithValue(
            AppCalendarSystem.bengali,
          ),
          bengaliDateForHeroProvider.overrideWith(
            (ref, date) => Future.value((day: 31, month: 'Bhadro', year: 1432)),
          ),
        ],
      );

      // Assert: script + digits only under the Bengali app language
      expect(
        find.text('Monday, ৩১ ভাদ্র', findRichText: true),
        findsOneWidget,
      );
    });

    testWidgets('Hindu primary shows Hindu tag, Gregorian title', (
      tester,
    ) async {
      // Arrange + Act
      await pumpHero(
        tester,
        extraOverrides: [
          primaryCalendarSystemProvider.overrideWithValue(
            AppCalendarSystem.hindu,
          ),
          secondaryCalendarSystemProvider.overrideWithValue(
            AppCalendarSystem.gregorian,
          ),
        ],
      );

      // Assert: tag = primary compact, title = weekday + secondary full
      // (fixed date is not "today" on the real clock → SELECTED prefix)
      expect(find.text('SELECTED · BHADRAPADA SHASHTHI'), findsOneWidget);
      expect(
        find.text('Monday, 14 September 2026', findRichText: true),
        findsOneWidget,
      );
    });

    testWidgets('Bengali primary shows Bengali tag', (tester) async {
      // Arrange + Act
      await pumpHero(
        tester,
        extraOverrides: [
          primaryCalendarSystemProvider.overrideWithValue(
            AppCalendarSystem.bengali,
          ),
          bengaliDateForHeroProvider.overrideWith(
            (ref, date) => Future.value((day: 31, month: 'Bhadro', year: 1432)),
          ),
        ],
      );

      // Assert (English app language → transliterated tag)
      expect(find.text('SELECTED · 31 BHADRO 1432'), findsOneWidget);
      expect(
        find.text('Monday, Bhadrapada Shashthi', findRichText: true),
        findsOneWidget,
      );
    });

    testWidgets('same system in both slots drops the tag date', (
      tester,
    ) async {
      // Arrange + Act
      await pumpHero(
        tester,
        extraOverrides: [
          primaryCalendarSystemProvider.overrideWithValue(
            AppCalendarSystem.hindu,
          ),
        ],
      );

      // Assert: secondary defaults to Hindu, so tag is bare SELECTED
      expect(find.text('SELECTED'), findsOneWidget);
      expect(
        find.text('Monday, Bhadrapada Shashthi', findRichText: true),
        findsOneWidget,
      );
    });

    testWidgets('secondary none shows weekday only', (tester) async {
      // Arrange + Act
      await pumpHero(
        tester,
        extraOverrides: [
          secondaryCalendarSystemProvider.overrideWithValue(
            AppCalendarSystem.none,
          ),
        ],
      );

      // Assert: no "no secondary calendar" label, just the weekday
      expect(find.text('SELECTED · 14 SEP 2026'), findsOneWidget);
      expect(find.text('Monday', findRichText: true), findsOneWidget);
      expect(find.textContaining('no secondary'), findsNothing);
    });

    testWidgets('header never overflows on narrow screens', (tester) async {
      // Arrange: 320pt-wide surface with artwork and a very long city name
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      await pumpHero(
        tester,
        image: 'assets/images/festival/shri_ganesh.jpeg',
        city: 'A very long city name that keeps going',
      );

      // Assert: no RenderFlex overflow (thrown as FlutterError), hero intact
      expect(tester.takeException(), isNull);
      expect(find.text('Shukla Paksha · Shashthi'), findsOneWidget);
    });
  });
}
