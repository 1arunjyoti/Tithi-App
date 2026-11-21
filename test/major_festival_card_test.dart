import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:tithi/l10n/app_localizations.dart';
import 'package:tithi/l10n/app_localizations_en.dart';
import 'package:tithi/models/festival.dart';
import 'package:tithi/models/panchang_data.dart';
import 'package:tithi/providers/calendar_provider.dart';
import 'package:tithi/providers/panchang_provider.dart';
import 'package:tithi/services/storage_service.dart';
import 'package:tithi/utils/tithi_localization.dart';
import 'package:tithi/widgets/app_card.dart';
import 'package:tithi/widgets/festival_thumbnail.dart';
import 'package:tithi/widgets/major_festival_card.dart';

class _FixedToday extends TodayDateNotifier {
  _FixedToday(this.day);

  final DateTime day;

  @override
  DateTime build() => day;
}

/// Widget-level proof for the featured major-festival card: the observance
/// rows it shows, the wording of the paran rule, the artwork/glyph decision,
/// and the composed semantics label that replaces the raw Texts.
void main() {
  const lat = 28.6139;
  const lon = 77.2090;
  final observanceDay = DateTime(2026, 11, 12);

  setUp(() async {
    final tempDir = await Directory.systemTemp.createTemp(
      'major_festival_card_test',
    );
    Hive.init(tempDir.path);
    await StorageService().init();
  });

  tearDown(() async {
    await Hive.close();
  });

  Festival festival({
    String? pujaKala,
    String? paranRule,
    String category = 'major',
    int tithi = 11,
    String image = '',
    String description = 'A test festival.',
    String? nameHindi,
  }) {
    return Festival(
      id: 'featured',
      name: 'Test Festival',
      category: category,
      nameRegional: NameRegional(
        nameEnglish: 'Test Festival',
        nameHindi: nameHindi,
      ),
      visuals: Visuals(image: image),
      purpose: Purpose(description: description),
      panchangRules: PanchangRules(
        masa: 'Kartika',
        paksha: 'Shukla',
        tithi: tithi,
        conditions: 'Lunar',
        pujaKala: pujaKala,
        paranRule: paranRule,
      ),
      rituals: const Rituals(steps: []),
      media: const Media(),
    );
  }

  PanchangData day() {
    return PanchangData(
      date: observanceDay,
      rawTithi: 11.5,
      tithiNumber: 11,
      tithiName: '',
      paksha: 'Shukla',
      masa: 'Kartika',
      sunrise: DateTime(2026, 11, 12, 6, 30),
      sunset: DateTime(2026, 11, 12, 17, 25),
    );
  }

  Future<void> pumpCard(
    WidgetTester tester,
    Festival f, {
    DateTime? today,
    double textScale = 1.0,
    Size? surface,
    Locale locale = const Locale('en'),
  }) async {
    if (surface != null) {
      tester.view.physicalSize = surface * 3;
      tester.view.devicePixelRatio = 3;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
    }
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          resolvedCoordinatesProvider.overrideWithValue((
            latitude: lat,
            longitude: lon,
          )),
          panchangForDateProvider.overrideWith((ref, date) => day()),
          // Same-day observed span, so the shared range formatter renders the
          // compact "7:45 – 9:30 AM" form (no repeated date, one period).
          tithiTimingsProvider.overrideWith(
            (ref, arg) => Future.value((
              start: DateTime(2026, 11, 12, 7, 45),
              end: DateTime(2026, 11, 12, 9, 30),
            )),
          ),
          todayDateProvider.overrideWith(
            () => _FixedToday(today ?? observanceDay),
          ),
        ],
        child: MaterialApp(
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          home: Scaffold(
            body: SingleChildScrollView(
              child: MajorFestivalCard(
                item: (festival: f, date: observanceDay),
                onTap: () {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('localizedPakshaTithiName', () {
    final l10n = AppLocalizationsEn();

    test('maps a full 1-30 index to its paksha and phase name', () {
      // 16 is Krishna Pratipada, not "Krishna Pratipada #16" or Shukla.
      expect(localizedPakshaTithiName(16, l10n), 'Krishna Pratipada');
      expect(localizedPakshaTithiName(1, l10n), 'Shukla Pratipada');
    });

    test('keeps the paksha edges on Purnima and Amavasya', () {
      // The %15 conversion must not turn 15/30 into Pratipada.
      expect(localizedPakshaTithiName(15, l10n), 'Shukla Purnima');
      expect(localizedPakshaTithiName(30, l10n), 'Krishna Amavasya');
    });
  });

  group('MajorFestivalCard observance rows', () {
    testWidgets('names the festival kala and captions paran once', (
      tester,
    ) async {
      // Arrange + Act: a fast broken after the Nishita puja.
      await pumpCard(
        tester,
        festival(pujaKala: 'nishita', paranRule: 'after_puja_kala'),
      );

      // Assert: tithi window, kala-named puja window, one-colon paran caption.
      expect(find.text('TITHI'), findsOneWidget);
      expect(find.textContaining('Shukla Ekadashi'), findsOneWidget);
      // intl separates the clock from AM/PM with a narrow no-break space, so
      // match the times rather than the exact rendered string.
      expect(find.textContaining('7:45'), findsOneWidget);
      expect(find.textContaining('9:30'), findsOneWidget);
      expect(find.text('NISHITA'), findsOneWidget);
      expect(find.text('PARAN'), findsOneWidget);
      expect(find.text('after the Nishita puja'), findsOneWidget);
      expect(find.textContaining('::'), findsNothing);
      expect(find.textContaining('puja puja'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('festival title uses full-strength ink like a list row', (
      tester,
    ) async {
      // Arrange + Act
      await pumpCard(tester, festival());

      // Assert: the title carries an explicit onSurface colour. A colourless
      // AppTypography.ui would inherit bodyMedium's secondaryInk and read
      // muted next to the compact FestivalRowTile titles.
      final cardElement = tester.element(find.byType(MajorFestivalCard));
      final expected = Theme.of(cardElement).colorScheme.onSurface;
      final title = tester.widget<Text>(
        find.descendant(
          of: find.byType(MajorFestivalCard),
          matching: find.text('Test Festival'),
        ),
      );
      expect(title.style?.color, expected);
      expect(tester.takeException(), isNull);
    });

    testWidgets('hides the paran row when the kala is missing', (tester) async {
      // Arrange + Act: after_puja_kala needs the festival's own puja kala.
      await pumpCard(tester, festival(paranRule: 'after_puja_kala'));

      // Assert: no rule is claimed instead of a generic "puja puja".
      expect(find.text('PARAN'), findsNothing);
      expect(find.textContaining('puja'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('keeps the countdown the compact rows show', (tester) async {
      // Arrange + Act: today is two days before the observance.
      await pumpCard(
        tester,
        festival(pujaKala: 'nishita'),
        today: DateTime(2026, 11, 10),
      );

      // Assert: the date line stays date + tithi, and the countdown is its own
      // chip instead of a suffix that pushed the tithi name off the line.
      expect(find.text('Thu, 12 November · Shukla Ekadashi'), findsOneWidget);
      expect(find.text('in 2 days'), findsOneWidget);
    });

    testWidgets('says Today for an observance happening today', (tester) async {
      // Arrange + Act
      await pumpCard(tester, festival(pujaKala: 'nishita'));

      // Assert: the date line never contradicts the app's "today".
      expect(find.textContaining('Today'), findsOneWidget);
      expect(find.textContaining('in 0 days'), findsNothing);
      // ...and today's card carries the accent hairline the rows lack.
      final card = tester.widget<AppCard>(find.byType(AppCard));
      expect(card.accent, isNotNull);
      final surface = tester.widget<Container>(
        find
            .descendant(
              of: find.byType(AppCard),
              matching: find.byWidgetPredicate(
                (widget) =>
                    widget is Container && widget.decoration is BoxDecoration,
              ),
            )
            .first,
      );
      expect((surface.decoration! as BoxDecoration).border, isNotNull);
    });

    testWidgets('exposes one composed label and hides the raw rows', (
      tester,
    ) async {
      // Arrange
      final handle = tester.ensureSemantics();

      // Act
      await pumpCard(
        tester,
        festival(pujaKala: 'nishita', paranRule: 'after_puja_kala'),
        today: DateTime(2026, 11, 10),
      );

      // Assert: name, date and every row in one node, as FestivalRowTile does.
      final node = find.bySemanticsLabel(RegExp('Test Festival'));
      expect(node, findsOneWidget);
      final label = tester.getSemantics(node).label;
      expect(label, contains('Thu, 12 November'));
      expect(label, contains('TITHI: 7:45'));
      expect(label, contains('after the Nishita puja'));

      // The binding verifies handles before tearDowns, so dispose here.
      handle.dispose();
    });

    testWidgets('shows the description without stretching the card', (
      tester,
    ) async {
      // Arrange + Act
      await pumpCard(
        tester,
        festival(description: 'A long description ' * 12, pujaKala: 'nishita'),
      );

      // Assert: the "what is this" line exists and stays a single line, so a
      // long catalog description cannot stretch the card.
      final text = tester.widget<Text>(
        find.textContaining('A long description'),
      );
      expect(text.maxLines, 1);
      expect(text.overflow, TextOverflow.ellipsis);
      expect(tester.takeException(), isNull);
    });

    testWidgets('uses a glyph chip instead of a placeholder square', (
      tester,
    ) async {
      // Arrange + Act: no artwork, which is the case for 89 of 96 majors.
      await pumpCard(tester, festival(pujaKala: 'nishita'));

      // Assert: no 100dp empty square, but the category glyph is still there.
      expect(find.byType(FestivalThumbnail), findsNothing);
      expect(find.byIcon(festivalRowIcon(festival())), findsOneWidget);
    });

    testWidgets('draws the artwork square when the festival ships one', (
      tester,
    ) async {
      // Arrange + Act
      await pumpCard(
        tester,
        festival(image: 'assets/images/festival/shri_ganesh.webp'),
      );

      // Assert: the real picture gets the large slot. (The glyph chip that
      // stands in for a missing picture is the previous test's concern; here
      // the thumbnail owns the glyph fallback too.)
      expect(find.byType(FestivalThumbnail), findsOneWidget);
    });

    testWidgets('adds the localized name when the catalog has one', (
      tester,
    ) async {
      // Arrange + Act: Hindi UI, festival with a Hindi name.
      await pumpCard(
        tester,
        festival(nameHindi: 'परीक्षण महोत्सव'),
        locale: const Locale('hi'),
      );

      // Assert: the English name leads, the regional one sits under it.
      expect(find.text('Test Festival'), findsOneWidget);
      expect(find.text('परीक्षण महोत्सव'), findsOneWidget);
    });

    testWidgets('fits a narrow screen with large text', (tester) async {
      // Arrange + Act: 320dp phone, 1.6x text.
      await pumpCard(
        tester,
        festival(pujaKala: 'nishita', paranRule: 'after_puja_kala'),
        surface: const Size(320, 640),
        textScale: 1.6,
      );

      // Assert: the header row and the stacked timings wrap instead of
      // overflowing (the old inline caption/value form overflowed here).
      expect(find.text('Test Festival'), findsOneWidget);
      expect(find.text('TITHI'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
