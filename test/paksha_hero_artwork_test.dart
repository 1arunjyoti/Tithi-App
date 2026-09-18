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

class _FixedDayNotifier extends SelectedDateNotifier {
  _FixedDayNotifier(this.day);

  final DateTime day;

  @override
  DateTime build() => day;
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
    DateTime? selectedDay,
    List<Override> extraOverrides = const [],
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          if (selectedDay == null)
            selectedDateProvider.overrideWith(_FixedDateNotifier.new)
          else
            selectedDateProvider.overrideWith(
              () => _FixedDayNotifier(selectedDay),
            ),
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
        image: 'assets/images/festival/shri_ganesh.webp',
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

    testWidgets('switching dates glides instead of flashing', (tester) async {
      // Arrange: tall day (artwork + transition chip) settled on screen.
      // Month cache serves both days, mirroring an on-device same-month tap
      // (no skeleton in the middle).
      final tall = heroData(image: 'assets/images/festival/shri_ganesh.webp');
      final short = PanchangData(
        date: DateTime(2026, 9, 16),
        rawTithi: 8.5,
        tithiNumber: 8,
        tithiName: 'Ashtami',
        paksha: 'Shukla',
        masa: 'Bhadrapada',
        sunrise: DateTime(2026, 9, 16, 5, 39),
        sunset: DateTime(2026, 9, 16, 18, 12),
      );
      final dateNotifier = _FixedDateNotifier();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            selectedDateProvider.overrideWith(() => dateNotifier),
            panchangForDateProvider.overrideWith(
              (ref, date) =>
                  Future.value(date.day == 14 ? tall : short),
            ),
            monthlyPanchangProvider.overrideWith(
              (ref, month) => Future.value({
                DateTime(2026, 9, 14): tall,
                DateTime(2026, 9, 16): short,
              }),
            ),
            cityNameProvider.overrideWithValue(
              const AsyncValue.data('Kolkata'),
            ),
            accessibilityProvider.overrideWith(_NoHapticsNotifier.new),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(child: PakshaHeroCard()),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final tallHeight = tester.getSize(find.byType(PakshaHeroCard)).height;

      // Act: tap over to the short day, stepping frame by frame.
      dateNotifier.setDate(DateTime(2026, 9, 16));
      final heights = <double>[];
      for (var i = 0; i < 25; i++) {
        await tester.pump(const Duration(milliseconds: 16));
        heights.add(tester.getSize(find.byType(PakshaHeroCard)).height);
      }
      await tester.pumpAndSettle();
      final shortHeight = tester.getSize(find.byType(PakshaHeroCard)).height;

      // Assert: monotonic glide, no skeleton dip or overshoot spike, and a
      // gentle start (no rapid-expand kick on the first frames).
      expect(shortHeight, lessThan(tallHeight));
      for (var i = 0; i < heights.length; i++) {
        expect(heights[i], lessThanOrEqualTo(tallHeight));
        expect(heights[i], greaterThanOrEqualTo(shortHeight - 0.5));
        if (i > 0) expect(heights[i], lessThanOrEqualTo(heights[i - 1]));
      }
      expect(
        tallHeight - heights[1],
        lessThan((tallHeight - shortHeight) * 0.25),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('live flip shows the incoming tithi without Next wording', (
      tester,
    ) async {
      // Arrange: Sep-18-like record already flipped (label Ashtami,
      // transition into Ashtami at 1:02 PM), served as the live record.
      final flipped = PanchangData.fromRawTithi(
        date: DateTime(2026, 9, 14),
        rawTithi: 7.2,
        masa: 'Bhadrapada',
        allFestivals: [],
        sunrise: DateTime(2026, 9, 14, 6, 5),
        sunset: DateTime(2026, 9, 14, 18, 20),
        tithiTransitionTime: DateTime(2026, 9, 14, 13, 2),
        transitionTithiIndex: 8,
      ).withLiveLabel(DateTime(2026, 9, 14, 15));

      // Act
      await pumpHero(
        tester,
        data: heroData(),
        extraOverrides: [
          livePanchangProvider.overrideWith(
            (ref, day) => Future.value(flipped),
          ),
        ],
      );

      // Assert: title names the flipped-to tithi; the chip states when it
      // began instead of calling the current tithi "next".
      expect(find.text('Shukla Paksha · Ashtami'), findsOneWidget);
      expect(find.textContaining('Next tithi'), findsNothing);
      expect(find.textContaining('Ashtami begins at'), findsOneWidget);
    });

    testWidgets('pre-flip live record keeps Next tithi wording', (
      tester,
    ) async {
      // Arrange: same day before the boundary — live record is unflipped.
      final base = PanchangData.fromRawTithi(
        date: DateTime(2026, 9, 14),
        rawTithi: 7.2,
        masa: 'Bhadrapada',
        allFestivals: [],
        sunrise: DateTime(2026, 9, 14, 6, 5),
        sunset: DateTime(2026, 9, 14, 18, 20),
        tithiTransitionTime: DateTime(2026, 9, 14, 13, 2),
        transitionTithiIndex: 8,
      );

      // Act
      await pumpHero(
        tester,
        data: heroData(),
        extraOverrides: [
          livePanchangProvider.overrideWith(
            (ref, day) => Future.value(base),
          ),
        ],
      );

      // Assert
      expect(find.text('Shukla Paksha · Saptami'), findsOneWidget);
      expect(find.textContaining('Next tithi'), findsOneWidget);
    });

    testWidgets('hero label follows the live clock past the boundary', (
      tester,
    ) async {
      // Arrange: today, Saptami → Ashtami at 1:02 PM, live clock pinned at
      // 3 PM (past the boundary). Widget-test pumps advance fake timers
      // but not the wall clock that labels are evaluated against, so the
      // flip is driven through the overridable liveNowProvider clock seam
      // instead of time travel; timer firing itself is covered by the
      // liveTithiTickProvider unit tests with real timers.
      final now = DateTime.now();
      final day = DateTime(now.year, now.month, now.day);
      final transition = DateTime(day.year, day.month, day.day, 13, 2);
      final record = PanchangData.fromRawTithi(
        date: day,
        rawTithi: 7.2,
        masa: 'Bhadrapada',
        allFestivals: [],
        sunrise: DateTime(day.year, day.month, day.day, 6, 5),
        sunset: DateTime(day.year, day.month, day.day, 18, 20),
        tithiTransitionTime: transition,
        transitionTithiIndex: 8,
      );
      await pumpHero(
        tester,
        data: record,
        selectedDay: day,
        extraOverrides: [
          liveNowProvider.overrideWithValue(
            DateTime(day.year, day.month, day.day, 15),
          ),
          resolvedCoordinatesProvider.overrideWithValue(
            (latitude: 28.6139, longitude: 77.2090),
          ),
        ],
      );

      // Assert: hero relabeled from the tithi timings, chip follows.
      expect(find.text('Shukla Paksha · Ashtami'), findsOneWidget);
      expect(find.text('Shukla Paksha · Saptami'), findsNothing);
      expect(find.textContaining('Next tithi'), findsNothing);
      expect(find.textContaining('Ashtami begins at'), findsOneWidget);
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
        image: 'assets/images/festival/shri_ganesh.webp',
        city: 'A very long city name that keeps going',
      );

      // Assert: no RenderFlex overflow (thrown as FlutterError), hero intact
      expect(tester.takeException(), isNull);
      expect(find.text('Shukla Paksha · Shashthi'), findsOneWidget);
    });
  });
}
