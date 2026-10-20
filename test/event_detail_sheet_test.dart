import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:tithi/models/festival.dart';
import 'package:tithi/models/panchang_data.dart';
import 'package:tithi/features/sheets/sheet_launcher.dart';
import 'package:tithi/features/sheets/widgets/sheet_link_tile.dart';
import 'package:tithi/providers/calendar_provider.dart';
import 'package:tithi/providers/panchang_provider.dart';
import 'package:tithi/services/storage_service.dart';
import 'package:tithi/widgets/event_detail_sheet.dart';
import 'package:tithi/widgets/tithi_detail_sheet.dart';

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
    String conditions = 'Lunar',
    int tithi = 4,
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
        tithi: tithi,
        conditions: conditions,
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

  List<Override> sheetOverrides() => [
    resolvedCoordinatesProvider.overrideWithValue((
      latitude: lat,
      longitude: lon,
    )),
    tithiDisplayModeProvider.overrideWithValue(TithiDisplayMode.pakshaBased),
    tithiTimingsProvider.overrideWith(
      (ref, arg) => Future.value((
        start: DateTime(2026, 10, 5, 20, 10),
        end: DateTime(2026, 10, 6, 17),
      )),
    ),
    // Hermetic for the tithi sheet the cross-link opens: the real
    // nakshatra/yoga providers need the native ephemeris.
    nakshatraTimingsProvider.overrideWith(
      (ref, arg) => Future<
        ({DateTime end, int index, String nakshatra, DateTime start})?
      >.value(),
    ),
    yogaKaranaTimingsProvider.overrideWith(
      (ref, arg) => Future<
        ({
          int yogaIndex,
          String yoga,
          DateTime yogaEnd,
          int karanaIndex,
          String karana,
          DateTime karanaEnd,
        })?
      >.value(),
    ),
  ];

  Future<void> pumpSheet(
    WidgetTester tester,
    Festival f,
    PanchangData? panchang, {
    DateTime? date,
    List<Override> extraOverrides = const [],
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [...sheetOverrides(), ...extraOverrides],
        child: MaterialApp(
          home: Scaffold(
            body: EventDetailSheet(
              festival: f,
              panchang: panchang,
              date: date,
            ),
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

  group('EventDetailSheet tithi cross-link', () {
    testWidgets('shows the panchang link once the day is known', (
      tester,
    ) async {
      // Arrange + Act
      await pumpSheet(tester, festival(), day());

      // Assert: label + the day the link opens.
      expect(find.text('View full panchang'), findsOneWidget);
      expect(find.text('6 October 2026'), findsOneWidget);
    });

    testWidgets('hides the link without panchang', (tester) async {
      // Arrange + Act: rules-only layout.
      await pumpSheet(tester, festival(), null);

      // Assert
      expect(find.text('View full panchang'), findsNothing);
    });

    testWidgets('tapping the link opens the tithi sheet', (tester) async {
      // Arrange
      await pumpSheet(tester, festival(), day());

      // Act
      await tester.ensureVisible(find.text('View full panchang'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('View full panchang'));
      await tester.pumpAndSettle();

      // Assert
      expect(find.byType(TithiDetailSheet), findsOneWidget);
      expect(find.byType(EventDetailSheet), findsOneWidget);
    });

    testWidgets('opened from the tithi sheet, the link pops back', (
      tester,
    ) async {
      // Arrange: a host route, so the sheet has something to pop back to.
      await tester.pumpWidget(
        ProviderScope(
          overrides: sheetOverrides(),
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => showEventDetailSheet(
                    context,
                    festival: festival(),
                    panchang: day(),
                    fromTithiSheet: true,
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.byType(EventDetailSheet), findsOneWidget);

      // Act
      await tester.ensureVisible(find.text('View full panchang'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('View full panchang'));
      await tester.pumpAndSettle();

      // Assert: back to the host, no duplicate tithi sheet stacked.
      expect(find.byType(EventDetailSheet), findsNothing);
      expect(find.byType(TithiDetailSheet), findsNothing);
      expect(find.text('open'), findsOneWidget);
    });

    testWidgets('resolves the day from the occurrence date', (tester) async {
      // Arrange + Act: only the date, as the all-festivals list provides.
      await pumpSheet(
        tester,
        festival(),
        null,
        date: DateTime(2026, 10, 6),
        extraOverrides: [
          panchangForDateProvider.overrideWith((ref, date) => day()),
        ],
      );

      // Assert
      expect(find.text('View full panchang'), findsOneWidget);
      expect(find.text('6 October 2026'), findsOneWidget);
    });

    testWidgets('upgrades in place once the day resolves', (tester) async {
      // Arrange: hold the resolution so the rules-only layout is visible.
      final completer = Completer<PanchangData>();
      await pumpSheet(
        tester,
        festival(),
        null,
        date: DateTime(2026, 10, 6),
        extraOverrides: [
          panchangForDateProvider.overrideWith((ref, date) => completer.future),
        ],
      );
      expect(find.text('View full panchang'), findsNothing);

      // Act: the occurrence date is already known, so the hero shows it
      // while the panchang is still loading.
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Text &&
              (w.textSpan?.toPlainText() ?? '').contains('6 October 2026'),
        ),
        findsOneWidget,
      );

      completer.complete(day());
      await tester.pumpAndSettle();

      // Assert
      expect(find.text('View full panchang'), findsOneWidget);
    });

    testWidgets('a supplied panchang wins over the date', (tester) async {
      // Arrange + Act
      await pumpSheet(
        tester,
        festival(),
        day(),
        date: DateTime(2026, 12, 25),
      );

      // Assert: the link points at the panchang's own day.
      expect(find.text('6 October 2026'), findsOneWidget);
      expect(find.text('25 December 2026'), findsNothing);
    });

    testWidgets('hides the link when the day cannot be resolved', (
      tester,
    ) async {
      // Arrange + Act
      await pumpSheet(
        tester,
        festival(),
        null,
        date: DateTime(2026, 10, 6),
        extraOverrides: [
          panchangForDateProvider.overrideWith(
            (ref, date) => Future.error(StateError('boom')),
          ),
        ],
      );

      // Assert: rules-only layout survives the failure.
      expect(find.text('View full panchang'), findsNothing);
      expect(find.text('Fast until the puja.'), findsOneWidget);
    });

    testWidgets('exposes the link as one labelled button', (tester) async {
      // Arrange + Act
      await pumpSheet(tester, festival(), day());

      // Assert: one composed label (visible Texts excluded) + tap action.
      final data = tester
          .getSemantics(find.byType(SheetLinkTile))
          .getSemanticsData();
      expect(data.label, 'View full panchang. 6 October 2026');
      expect(data.hasAction(SemanticsAction.tap), isTrue);
    });
  });

  group('EventDetailSheet observance note', () {
    testWidgets('renders the rule as a caption under Panchang Details', (
      tester,
    ) async {
      // Arrange + Act
      await pumpSheet(tester, festival(), day());

      // Assert: present, below the section header, in secondary text style.
      final caption = find.text(
        'Observed on the day the tithi prevailing at sunrise',
      );
      expect(caption, findsOneWidget);
      final header = tester.getTopLeft(find.text('Panchang Details')).dy;
      expect(tester.getTopLeft(caption).dy, greaterThan(header));
      final style = tester.widget<Text>(caption).style;
      expect(style?.fontSize, 12.5);
      expect(style?.fontWeight, FontWeight.w500);
    });

    testWidgets('hides the note where no tithi checkpoint applies', (
      tester,
    ) async {
      // Arrange + Act: solar fixed-date festival.
      await pumpSheet(tester, festival(conditions: 'Solar', tithi: 0), null);

      // Assert
      expect(find.textContaining('Observed on the day'), findsNothing);
    });
  });
}
