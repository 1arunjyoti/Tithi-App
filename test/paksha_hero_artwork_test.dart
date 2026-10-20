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
import 'package:tithi/core/anim/press_scale.dart';
import 'package:tithi/features/hero/widgets/artwork_window.dart';
import 'package:tithi/features/hero/widgets/hero_festival_image.dart';
import 'package:tithi/widgets/paksha_hero_card.dart';
import 'package:tithi/widgets/tithi_detail_sheet.dart';

class _NoHapticsNotifier extends AccessibilityNotifier {
  @override
  AccessibilityState build() => const AccessibilityState(hapticFeedback: false);
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

/// Asset path of the picture painted last — the deck's front card.
///
/// Thumbnails are decoded at the drawn size, so the provider is a [ResizeImage]
/// wrapping the asset; unwrap it to read the path.
String _frontArtwork(WidgetTester tester) {
  final image = tester.widget<Image>(find.byType(Image).last);
  final provider = image.image;
  final asset = provider is ResizeImage ? provider.imageProvider : provider;
  return (asset as AssetImage).assetName;
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
  Festival fixture({
    String image = '',
    String id = 'test-festival',
    String name = 'Test Festival',
    int? priority,
  }) => Festival(
    id: id,
    name: name,
    category: 'major',
    nameRegional: NameRegional(nameEnglish: name),
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
    displayPriority: priority,
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

  /// Two illustrated festivals on one day: the deck case.
  PanchangData heroDataTwoArtworks() => PanchangData(
    date: DateTime(2026, 9, 14),
    rawTithi: 6.5,
    tithiNumber: 6,
    tithiName: 'Shashthi',
    paksha: 'Shukla',
    masa: 'Bhadrapada',
    festivals: [
      fixture(
        id: 'ganesh',
        name: 'Ganesh Chaturthi',
        image: 'assets/images/festival/shri_ganesh.webp',
        priority: 1,
      ),
      fixture(
        id: 'durga',
        name: 'Durga Puja',
        image: 'assets/images/festival/durga_puja.webp',
        priority: 2,
      ),
    ],
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
    bool tickerEnabled = true,

    /// Extra blank space under the card so the page really scrolls; without
    /// it the scroll view has no extent and takes no drags at all.
    double filler = 0,
    List<Override> extraOverrides = const [],
  }) async {
    final page = filler > 0
        ? Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const PakshaHeroCard(),
              SizedBox(height: filler),
            ],
          )
        : const PakshaHeroCard();
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
        child: MaterialApp(
          home: Scaffold(
            body: TickerMode(
              enabled: tickerEnabled,
              child: SingleChildScrollView(child: page),
            ),
          ),
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
      await pumpHero(tester, image: 'assets/images/festival/shri_ganesh.webp');

      // Assert: text content intact and the picture slot is present
      expect(find.text('Shukla Paksha · Shashthi'), findsOneWidget);
      expect(find.byType(Image), findsOneWidget);
    });

    testWidgets('tapping the hero opens the tithi detail sheet', (
      tester,
    ) async {
      // Arrange
      await pumpHero(tester);

      // Act: bounded pumps instead of pumpAndSettle — the sheet keeps an
      // indefinite animation running (its loading state), so settling never
      // happens even though the sheet is fully on screen.
      await tester.tap(find.text('Shukla Paksha · Shashthi'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // Assert
      expect(find.byType(TithiDetailSheet), findsOneWidget);
    });

    testWidgets('long-pressing the artwork opens the floating window', (
      tester,
    ) async {
      // Arrange (real bundled festival artwork path)
      await pumpHero(tester, image: 'assets/images/festival/shri_ganesh.webp');

      // Act
      await tester.longPress(find.byType(HeroFestivalImage));
      await tester.pumpAndSettle();

      // Assert: window on top, artwork name captioned, sheet untouched
      expect(find.byType(ArtworkWindow), findsOneWidget);
      expect(find.text('Test Festival'), findsOneWidget);
      expect(find.byType(TithiDetailSheet), findsNothing);
    });

    testWidgets('tapping the artwork still opens the tithi detail sheet', (
      tester,
    ) async {
      // Arrange
      await pumpHero(tester, image: 'assets/images/festival/shri_ganesh.webp');

      // Act: a plain tap on the picture is not the enlarge gesture. Bounded
      // pumps instead of pumpAndSettle: an unrelated never-settling
      // animation runs while the sheet is open over the artwork.
      await tester.tap(find.byType(HeroFestivalImage));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // Assert
      expect(find.byType(TithiDetailSheet), findsOneWidget);
      expect(find.byType(ArtworkWindow), findsNothing);
    });

    testWidgets('the artwork window dismisses on close', (tester) async {
      // Arrange
      await pumpHero(tester, image: 'assets/images/festival/shri_ganesh.webp');
      await tester.longPress(find.byType(HeroFestivalImage));
      await tester.pumpAndSettle();

      // Act
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      // Assert
      expect(find.byType(ArtworkWindow), findsNothing);
    });

    testWidgets('several festival artworks stack and open as a gallery', (
      tester,
    ) async {
      // Arrange: the single-image slot, for footprint comparison
      await pumpHero(tester, image: 'assets/images/festival/shri_ganesh.webp');
      final slotRect = tester.getRect(find.byType(HeroFestivalImage));

      // Arrange: two illustrated festivals, ranked so the deck is deterministic
      // (a fresh tree so the new panchang override is actually read)
      await tester.pumpWidget(const SizedBox.shrink());
      await pumpHero(tester, data: heroDataTwoArtworks());

      // Assert: two stacked pictures, one node naming both festivals, position
      // pill on the front card
      expect(find.byType(Image), findsNWidgets(2));
      final stackNode = find.byWidgetPredicate(
        (w) =>
            w is Semantics &&
            w.properties.label == 'Ganesh Chaturthi, Durga Puja',
      );
      expect(stackNode, findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(PakshaHeroCard),
          matching: find.byWidgetPredicate((w) => w is Text && w.data == '1/2'),
        ),
        findsOneWidget,
      );

      // Assert: the deck occupies exactly the single-image footprint, so the
      // moon text column never reflows when a second festival joins the day
      final deckRect = tester.getRect(stackNode);
      expect(deckRect.size.width, moreOrLessEquals(slotRect.size.width));
      expect(deckRect.size.height, moreOrLessEquals(slotRect.size.height));
      expect(deckRect.center, offsetMoreOrLessEquals(slotRect.center));

      // Act: long press opens the gallery on the headline picture (front card)
      await tester.longPress(find.byType(Image).last);
      await tester.pumpAndSettle();

      // Assert: counter and first caption
      expect(find.byType(ArtworkWindow), findsOneWidget);
      expect(find.text('1 / 2'), findsOneWidget);
      expect(find.text('Ganesh Chaturthi'), findsOneWidget);

      // Act: swipe to the next picture
      await tester.drag(find.byType(PageView), const Offset(-320, 0));
      await tester.pumpAndSettle();

      // Assert: counter and caption follow the page
      expect(find.text('2 / 2'), findsOneWidget);
      expect(find.text('Durga Puja'), findsOneWidget);
      expect(find.text('Ganesh Chaturthi'), findsNothing);
    });

    testWidgets('swiping the deck rotates it and the gallery follows', (
      tester,
    ) async {
      // Arrange: two illustrated festivals, headline first (priority 1)
      await pumpHero(tester, data: heroDataTwoArtworks());
      final deck = find.byWidgetPredicate(
        (w) => w is Semantics && w.properties.onScrollLeft != null,
      );
      expect(deck, findsOneWidget);
      expect(_frontArtwork(tester), endsWith('shri_ganesh.webp'));

      // Act: swipe left (next picture)
      await tester.drag(deck, const Offset(-120, 0));
      await tester.pumpAndSettle();

      // Assert: the deck rotated, the front picture and the pill follow
      expect(_frontArtwork(tester), endsWith('durga_puja.webp'));
      expect(find.text('2/2'), findsOneWidget);
      expect(find.text('1/2'), findsNothing);

      // Act: swipe right (previous picture)
      await tester.drag(deck, const Offset(120, 0));
      await tester.pumpAndSettle();

      // Assert: back at the headline picture
      expect(_frontArtwork(tester), endsWith('shri_ganesh.webp'));
      expect(find.text('1/2'), findsOneWidget);

      // Arrange: to the second picture again, then open the gallery
      await tester.drag(deck, const Offset(-120, 0));
      await tester.pumpAndSettle();
      await tester.longPress(find.byType(Image).last);
      await tester.pumpAndSettle();

      // Assert: the gallery opens on the picture in front, not always the
      // day's headline one
      expect(find.byType(ArtworkWindow), findsOneWidget);
      expect(find.text('2 / 2'), findsOneWidget);
      expect(find.text('Durga Puja'), findsOneWidget);
    });

    testWidgets('the deck rotates itself on an interval, slowly', (
      tester,
    ) async {
      // Arrange: two illustrated festivals, headline first
      await pumpHero(tester, data: heroDataTwoArtworks());
      expect(find.text('1/2'), findsOneWidget);

      // Act: idle past the interval
      await tester.pump(const Duration(seconds: 10));
      await tester.pump(const Duration(milliseconds: 300));

      // Assert: the turn is a slow cross-dissolve, not a snap — both decks
      // are still painted a third of a second in
      expect(find.byType(Image), findsNWidgets(4));

      await tester.pumpAndSettle();
      expect(find.text('2/2'), findsOneWidget);
      expect(_frontArtwork(tester), endsWith('durga_puja.webp'));

      // Act: idle again
      await tester.pump(const Duration(seconds: 10));
      await tester.pumpAndSettle();

      // Assert: it keeps cycling
      expect(find.text('1/2'), findsOneWidget);
      expect(_frontArtwork(tester), endsWith('shri_ganesh.webp'));
    });

    testWidgets('a manual swipe stops the auto rotation', (tester) async {
      // Arrange
      await pumpHero(tester, data: heroDataTwoArtworks());
      final deck = find.byWidgetPredicate(
        (w) => w is Semantics && w.properties.onScrollLeft != null,
      );

      // Act: the user picks the second picture, then leaves the card alone
      await tester.drag(deck, const Offset(-120, 0));
      await tester.pumpAndSettle();
      expect(find.text('2/2'), findsOneWidget);
      await tester.pump(const Duration(seconds: 25));
      await tester.pumpAndSettle();

      // Assert: their choice stays in front instead of sliding away
      expect(find.text('2/2'), findsOneWidget);
      expect(_frontArtwork(tester), endsWith('durga_puja.webp'));
    });

    testWidgets('auto rotation stays off under Reduce Motion', (tester) async {
      // Arrange: system Reduce Motion on
      tester.binding.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.binding.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      await pumpHero(tester, data: heroDataTwoArtworks());

      // Act: well past the interval
      await tester.pump(const Duration(seconds: 25));
      await tester.pumpAndSettle();

      // Assert: motion the user opted out of never starts
      expect(find.text('1/2'), findsOneWidget);
      expect(_frontArtwork(tester), endsWith('shri_ganesh.webp'));
    });

    testWidgets('auto rotation stays off while the hero is offstage', (
      tester,
    ) async {
      // Arrange: another (opaque) screen on top mutes this route's tickers
      await pumpHero(tester, data: heroDataTwoArtworks(), tickerEnabled: false);

      // Act: well past the interval
      await tester.pump(const Duration(seconds: 25));
      await tester.pumpAndSettle();

      // Assert: nothing rotated behind the other screen
      expect(find.text('1/2'), findsOneWidget);
      expect(_frontArtwork(tester), endsWith('shri_ganesh.webp'));
    });

    testWidgets('scrolling from the card does not shrink it', (tester) async {
      // Arrange: a page tall enough to actually scroll
      await pumpHero(tester, data: heroDataTwoArtworks(), filler: 1200);
      final cardPress = find.byWidgetPredicate(
        (w) => w is PressScale && w.pressedScale == 0.985,
      );
      double cardScale() => tester
          .widget<AnimatedScale>(
            find
                .descendant(of: cardPress, matching: find.byType(AnimatedScale))
                .first,
          )
          .scale;

      // Act: start a scroll with the finger on the hero
      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(PakshaHeroCard)),
      );
      await tester.pump(const Duration(milliseconds: 150));
      await gesture.moveBy(const Offset(0, -60));
      await tester.pumpAndSettle();

      // Assert: the card is being scrolled, so it must not stay pressed (it
      // used to sit at 0.985 for the whole drag and spring back on lift)
      expect(cardScale(), 1.0);

      await gesture.up();
      await tester.pumpAndSettle();
      expect(cardScale(), 1.0);
    });

    testWidgets('scrolling the page past the deck does not stop it', (
      tester,
    ) async {
      // Arrange
      await pumpHero(tester, data: heroDataTwoArtworks(), filler: 1200);
      final deck = find.byWidgetPredicate(
        (w) => w is Semantics && w.properties.onScrollLeft != null,
      );

      // Act: a vertical drag that starts on the picture is the page scrolling,
      // not the deck being taken over.
      await tester.drag(deck, const Offset(0, -60));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 10));
      await tester.pumpAndSettle();

      // Assert: the idle rotation survived the scroll
      expect(find.text('2/2'), findsOneWidget);
      expect(_frontArtwork(tester), endsWith('durga_puja.webp'));
    });

    testWidgets('the idle turn waits while the page is scrolling', (
      tester,
    ) async {
      // Arrange: finger down and dragging, so the page reports "scrolling"
      await pumpHero(tester, data: heroDataTwoArtworks(), filler: 1200);
      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(PakshaHeroCard)),
      );
      await gesture.moveBy(const Offset(0, -40));
      await tester.pump();

      // Act: hold the drag well past the interval
      await tester.pump(const Duration(seconds: 15));
      await tester.pumpAndSettle();

      // Assert: the deck held still under the finger
      expect(find.text('1/2'), findsOneWidget);

      // Act: let the page settle, then wait a full interval
      await gesture.up();
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 10));
      await tester.pumpAndSettle();

      // Assert: it picks up again once nothing is moving
      expect(find.text('2/2'), findsOneWidget);
    });

    testWidgets('the deck holds still while it is scrolled out of view', (
      tester,
    ) async {
      // Arrange: scroll the hero completely off the top
      await pumpHero(tester, data: heroDataTwoArtworks(), filler: 1400);
      final page = find.byType(SingleChildScrollView);
      await tester.drag(page, const Offset(0, -700));
      await tester.pumpAndSettle();
      expect(
        tester.getRect(find.byType(PakshaHeroCard)).bottom,
        lessThanOrEqualTo(0),
      );

      // Act: several intervals pass with the card out of sight
      await tester.pump(const Duration(seconds: 15));
      await tester.pumpAndSettle();

      // Assert: nothing turned where nobody could see it
      expect(find.text('1/2'), findsOneWidget);

      // Act: scroll back, then wait one interval
      await tester.drag(page, const Offset(0, 700));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 10));
      await tester.pumpAndSettle();

      // Assert: it is alive again once it is back on screen
      expect(find.text('2/2'), findsOneWidget);
    });

    testWidgets('auto rotation pauses while the app is in the background', (
      tester,
    ) async {
      // Arrange
      await pumpHero(tester, data: heroDataTwoArtworks());

      // Act: the app goes to the background
      // ignore: invalid_use_of_protected_member
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump(const Duration(seconds: 25));
      await tester.pumpAndSettle();

      // Assert: nothing turned while nobody could see it
      expect(find.text('1/2'), findsOneWidget);

      // Act: and comes back
      // ignore: invalid_use_of_protected_member
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump(const Duration(seconds: 10));
      await tester.pumpAndSettle();

      // Assert: the idle rotation is re-armed
      expect(find.text('2/2'), findsOneWidget);
    });

    testWidgets('thumbnails decode at the size they are drawn', (tester) async {
      // Arrange: a ~100 pt slot showing a 600x800 asset
      await pumpHero(tester, data: heroDataTwoArtworks());

      // Act
      final thumbnails = tester.widgetList<Image>(find.byType(Image));

      // Assert: the full-size bitmap is never decoded for the thumbnail slot
      expect(thumbnails, isNotEmpty);
      for (final image in thumbnails) {
        final provider = image.image;
        expect(provider, isA<ResizeImage>());
        expect((provider as ResizeImage).width, lessThan(600));
      }
    });

    testWidgets('tapping the deck still opens the tithi detail sheet', (
      tester,
    ) async {
      // Arrange
      await pumpHero(tester, data: heroDataTwoArtworks());
      final deck = find.byWidgetPredicate(
        (w) => w is Semantics && w.properties.onScrollLeft != null,
      );

      // Act: a tap is not a swipe. Bounded pumps instead of pumpAndSettle:
      // the sheet runs a never-settling animation over the artwork.
      await tester.tap(deck);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // Assert
      expect(find.byType(TithiDetailSheet), findsOneWidget);
      expect(find.byType(ArtworkWindow), findsNothing);

      // Act: the sheet stays open for longer than the idle interval
      await tester.pump(const Duration(seconds: 25));
      await tester.pump(const Duration(milliseconds: 300));

      // Assert: with the sheet covering the card, the deck held still
      expect(find.text('1/2'), findsOneWidget);
    });

    testWidgets('a single artwork keeps the plain slot, no counter', (
      tester,
    ) async {
      // Arrange + Act
      await pumpHero(tester, image: 'assets/images/festival/shri_ganesh.webp');
      await tester.longPress(find.byType(HeroFestivalImage));
      await tester.pumpAndSettle();

      // Assert: no deck badge and no position pill for one picture
      expect(find.byType(ArtworkWindow), findsOneWidget);
      expect(find.textContaining(' / '), findsNothing);
      expect(
        find.descendant(
          of: find.byType(PakshaHeroCard),
          matching: find.byWidgetPredicate((w) => w is Text && w.data == '1'),
        ),
        findsNothing,
      );
    });

    testWidgets('a zoomed artwork is panned, not paged', (tester) async {
      // Arrange: gallery open on the first of two pictures
      await pumpHero(tester, data: heroDataTwoArtworks());
      await tester.longPress(find.byType(Image).last);
      await tester.pumpAndSettle();
      final viewer = find.byType(InteractiveViewer);

      // Act: double tap zooms in, then a horizontal drag
      await tester.tap(viewer);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(viewer);
      await tester.pumpAndSettle();
      await tester.drag(viewer, const Offset(-320, 0));
      await tester.pumpAndSettle();

      // Assert: the drag moved the picture, not the pager
      expect(find.text('1 / 2'), findsOneWidget);

      // Act: double tap zooms back out, then the same drag pages
      await tester.tap(viewer);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(viewer);
      await tester.pumpAndSettle();
      await tester.drag(viewer, const Offset(-320, 0));
      await tester.pumpAndSettle();

      // Assert
      expect(find.text('2 / 2'), findsOneWidget);
    });

    testWidgets('dragging from the artwork scrolls instead of enlarging', (
      tester,
    ) async {
      // Arrange: artwork at the top of a long scroll view — the same shape as
      // the home screen (hero in a sliver, scrollable page beneath).
      var longPressed = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: [
                  SizedBox(
                    width: 120,
                    child: HeroFestivalImage(
                      source: 'assets/images/festival/shri_ganesh.webp',
                      semanticsLabel: 'Ganesh',
                      highContrast: false,
                      width: 120,
                      onLongPress: () => longPressed = true,
                    ),
                  ),
                  const SizedBox(height: 2000),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final position = tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position;

      // Act: press on the artwork and move before the long-press deadline.
      // Two moves, like `tester.drag`: the first crosses the touch slop (the
      // scroll recognizer accepts), the second is the scrolling movement.
      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(HeroFestivalImage)),
      );
      await gesture.moveBy(const Offset(0, -20));
      await tester.pump();
      await gesture.moveBy(const Offset(0, -80));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();

      // Assert: the page scrolled and the long press never fired.
      expect(position.pixels, greaterThan(0));
      expect(longPressed, isFalse);
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
      expect(find.text('Monday, ৩১ ভাদ্র', findRichText: true), findsOneWidget);
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

    testWidgets('same system in both slots drops the tag date', (tester) async {
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
              (ref, date) => Future.value(date.day == 14 ? tall : short),
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
          livePanchangProvider.overrideWith((ref, day) => Future.value(base)),
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
          resolvedCoordinatesProvider.overrideWithValue((
            latitude: 28.6139,
            longitude: 77.2090,
          )),
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
