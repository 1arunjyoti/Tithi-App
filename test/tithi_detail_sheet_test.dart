import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:tithi/models/panchang_data.dart';
import 'package:tithi/providers/accessibility_provider.dart';
import 'package:tithi/providers/calendar_provider.dart';
import 'package:tithi/providers/panchang_provider.dart';
import 'package:tithi/services/auspicious_timings.dart';
import 'package:tithi/services/storage_service.dart';
import 'package:tithi/services/sunrise_calculator.dart';
import 'package:tithi/utils/tithi_localization.dart';
import 'package:tithi/widgets/tithi_detail_sheet.dart';

/// Clock-time / short-date expectations built with the same formatter the
/// sheet uses. intl renders the day-period gap as U+202F (narrow no-break
/// space) under current CLDR data, so hardcoding 'h:mm AM' literals with a
/// regular space never matches — these helpers pin the *instants* under
/// test instead of intl's whitespace.
String jm(DateTime t) => formatLocalizedDate(t, 'jm', 'en');
String mmmd(DateTime t) => formatLocalizedDate(t, 'MMM d', 'en');
String hmm(DateTime t) => formatLocalizedDate(t, 'h:mm', 'en');

/// Exact-line finder that also matches RichText (whose [Text.data] is
/// null): the Yoga/Karana sublines emphasize the time portion with spans.
Finder exactLine(String s) => find.byWidgetPredicate(
  (w) =>
      (w is Text && w.data == s) ||
      (w is RichText && w.text.toPlainText() == s),
);

class _NoHapticsNotifier extends AccessibilityNotifier {
  @override
  AccessibilityState build() =>
      const AccessibilityState(hapticFeedback: false);
}

void main() {
  const lat = 28.6139;
  const lon = 77.2090;

  setUp(() async {
    final tempDir = await Directory.systemTemp.createTemp('tithi_sheet_test');
    Hive.init(tempDir.path);
    await StorageService().init();
  });

  tearDown(() async {
    await Hive.close();
  });

  /// Oct 4 2026 squeeze day: Ashtami at sunrise, Navami 05:53 → ~04:20.
  PanchangData squeezeDay() => PanchangData.fromRawTithi(
    date: DateTime(2026, 10, 4),
    rawTithi: 23.98,
    sunrise: DateTime(2026, 10, 4, 5, 28),
    sunset: DateTime(2026, 10, 4, 17, 30),
    tithiTransitionTime: DateTime(2026, 10, 4, 5, 53),
    transitionTithiIndex: 24,
  );

  PanchangData normalDay() => PanchangData.fromRawTithi(
    date: DateTime(2026, 10, 6),
    rawTithi: 26.5,
    sunrise: DateTime(2026, 10, 6, 5, 29),
    sunset: DateTime(2026, 10, 6, 17, 28),
  );

  /// Oct 3 2026 (Saturday) with the mockup's anchors: sunrise 5:24,
  /// sunset 17:36 (Gulika 5:24-6:56, Rahu 8:27-9:59, Yama 1:02-2:33).
  PanchangData saturdayWindows() => PanchangData.fromRawTithi(
    date: DateTime(2026, 10, 3),
    rawTithi: 22.5,
    sunrise: DateTime(2026, 10, 3, 5, 24),
    sunset: DateTime(2026, 10, 3, 17, 36),
  );

  Future<void> pumpSheet(
    WidgetTester tester,
    PanchangData panchang, {
    Future<({DateTime end, DateTime start})?> Function(
      ({DateTime date, double latitude, double longitude, int tithiIndex}) arg,
    )?
    timings,
    Future<
      ({DateTime end, int index, String nakshatra, DateTime start})?
    >
    Function(({DateTime date, double latitude, double longitude}) arg)?
    nakshatraTimings,
    Future<
      ({
        int yogaIndex,
        String yoga,
        DateTime yogaEnd,
        int karanaIndex,
        String karana,
        DateTime karanaEnd,
      })?
    >
    Function(({DateTime date, double latitude, double longitude}) arg)?
    yogaKarana,
    List<Override> extraOverrides = const [],
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          resolvedCoordinatesProvider.overrideWithValue((
            latitude: lat,
            longitude: lon,
          )),
          // Avoids Hive-backed calendar preferences in widget tests.
          tithiDisplayModeProvider.overrideWithValue(
            TithiDisplayMode.pakshaBased,
          ),
          accessibilityProvider.overrideWith(_NoHapticsNotifier.new),
          ...extraOverrides,
          tithiTimingsProvider.overrideWith(
            (ref, arg) =>
                timings?.call(arg) ??
                Future.value((
                  start: DateTime(2026, 10, 3, 8, 10),
                  end: DateTime(2026, 10, 4, 5, 53),
                )),
          ),
          // Hermetic by default (hidden card): the real provider needs the
          // native ephemeris, which widget tests don't have.
          nakshatraTimingsProvider.overrideWith((ref, arg) {
            final fn = nakshatraTimings;
            if (fn != null) return fn(arg);
            return Future<
              ({
                DateTime end,
                int index,
                String nakshatra,
                DateTime start,
              })?
            >.value();
          }),
          // Same hermetic default for the yoga/karana spans.
          yogaKaranaTimingsProvider.overrideWith((ref, arg) {
            final fn = yogaKarana;
            if (fn != null) return fn(arg);
            return Future<
              ({
                int yogaIndex,
                String yoga,
                DateTime yogaEnd,
                int karanaIndex,
                String karana,
                DateTime karanaEnd,
              })?
            >.value();
          }),
        ],
        child: MaterialApp(
          home: Scaffold(body: TithiDetailSheet(panchang: panchang)),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('TithiDetailSheet', () {
    testWidgets('squeeze day shows transition and next tithi end', (
      tester,
    ) async {
      // Arrange + Act
      await pumpSheet(
        tester,
        squeezeDay(),
        timings: (arg) async => arg.tithiIndex == 24
            ? (
                start: DateTime(2026, 10, 4, 5, 53),
                end: DateTime(2026, 10, 5, 4, 20),
              )
            : (
                start: DateTime(2026, 10, 3, 8, 10),
                end: DateTime(2026, 10, 4, 5, 53),
              ),
      );

      // Assert: hero header (moon row, badge, primary date) + dotted
      // label + side-by-side card with single-line "time, date" values +
      // tinted transition card. The old tag/day rows are gone.
      expect(find.text('SUN, OCT 4, 2026'), findsNothing);
      expect(find.text('Krishna Paksha · Ashtami'), findsOneWidget);
      expect(find.text('8'), findsOneWidget);
      // Header date follows the Gregorian primary by default.
      expect(
        find.text('Sunday, 4 October 2026', findRichText: true),
        findsOneWidget,
      );
      expect(find.text('TITHI TIMINGS'), findsOneWidget);
      expect(find.text('BEGINS'), findsOneWidget);
      expect(
        find.text(
          '${jm(DateTime(2026, 10, 3, 8, 10))}, '
          '${mmmd(DateTime(2026, 10, 3, 8, 10))}',
        ),
        findsOneWidget,
      );
      expect(find.text('ENDS'), findsOneWidget);
      expect(
        find.text(
          '${jm(DateTime(2026, 10, 4, 5, 53))}, '
          '${mmmd(DateTime(2026, 10, 4, 5, 53))}',
        ),
        findsOneWidget,
      );
      expect(find.text('TRANSITION'), findsOneWidget);
      expect(
        find.text('Navami begins at ${jm(DateTime(2026, 10, 4, 5, 53))}'),
        findsOneWidget,
      );
      expect(
        find.text(
          'Navami ends ${jm(DateTime(2026, 10, 5, 4, 20))}, '
          '${mmmd(DateTime(2026, 10, 5, 4, 20))}',
        ),
        findsOneWidget,
      );
      expect(
        find.text('Sunrise ${jm(DateTime(2026, 10, 4, 5, 28))}'),
        findsOneWidget,
      );
      expect(
        find.text('Sunset ${jm(DateTime(2026, 10, 4, 17, 30))}'),
        findsOneWidget,
      );
      expect(find.textContaining('Udaya tithi'), findsOneWidget);
    });

    testWidgets('Hindu primary shows masa date in header', (tester) async {
      // Arrange + Act
      await pumpSheet(
        tester,
        squeezeDay(),
        timings: (arg) async => (
          start: DateTime(2026, 10, 3, 8, 10),
          end: DateTime(2026, 10, 4, 5, 53),
        ),
        extraOverrides: [
          primaryCalendarSystemProvider.overrideWithValue(
            AppCalendarSystem.hindu,
          ),
        ],
      );

      // Assert: weekday + Hindu date (Hindu year joins separately if it
      // resolves, so match the stable prefix).
      expect(
        find.textContaining('Sunday, Ashtami', findRichText: true),
        findsWidgets,
      );
    });

    testWidgets('Bengali primary shows Bengali date in header', (tester) async {
      // Arrange + Act
      await pumpSheet(
        tester,
        squeezeDay(),
        timings: (arg) async => (
          start: DateTime(2026, 10, 3, 8, 10),
          end: DateTime(2026, 10, 4, 5, 53),
        ),
        extraOverrides: [
          primaryCalendarSystemProvider.overrideWithValue(
            AppCalendarSystem.bengali,
          ),
          bengaliDateForSheetProvider.overrideWith(
            (ref, date) => Future.value((day: 18, month: 'Ashshin', year: 1433)),
          ),
        ],
      );

      // Assert
      expect(
        find.text('Sunday, 18 Ashshin 1433', findRichText: true),
        findsOneWidget,
      );
    });

    testWidgets('Hindu primary shows Hindu dates in timings', (tester) async {
      // Arrange + Act
      await pumpSheet(
        tester,
        squeezeDay(),
        timings: (arg) async => (
          start: DateTime(2026, 10, 3, 8, 10),
          end: DateTime(2026, 10, 4, 5, 53),
        ),
        extraOverrides: [
          primaryCalendarSystemProvider.overrideWithValue(
            AppCalendarSystem.hindu,
          ),
          hinduInstantLabelProvider.overrideWith(
            (ref, arg) => Future.value('Ashwin Ashtami'),
          ),
        ],
      );

      // Assert: clock times stand, date fragments follow Hindu
      expect(
        find.text('${jm(DateTime(2026, 10, 3, 8, 10))}, Ashwin Ashtami'),
        findsOneWidget,
      );
      expect(
        find.text('${jm(DateTime(2026, 10, 4, 5, 53))}, Ashwin Ashtami'),
        findsWidgets,
      );
      expect(
        find.text(
          '${jm(DateTime(2026, 10, 3, 8, 10))}, '
          '${mmmd(DateTime(2026, 10, 3, 8, 10))}',
        ),
        findsNothing,
      );
    });

    testWidgets('Bengali primary shows Bengali dates in timings', (
      tester,
    ) async {
      // Arrange + Act
      await pumpSheet(
        tester,
        squeezeDay(),
        timings: (arg) async => (
          start: DateTime(2026, 10, 3, 8, 10),
          end: DateTime(2026, 10, 4, 5, 53),
        ),
        extraOverrides: [
          primaryCalendarSystemProvider.overrideWithValue(
            AppCalendarSystem.bengali,
          ),
          bengaliInstantLabelProvider.overrideWith(
            (ref, instant) => Future.value('18 Ashshin 1433'),
          ),
        ],
      );

      // Assert
      expect(
        find.text('${jm(DateTime(2026, 10, 3, 8, 10))}, 18 Ashshin 1433'),
        findsOneWidget,
      );
      expect(
        find.text(
          '${jm(DateTime(2026, 10, 3, 8, 10))}, '
          '${mmmd(DateTime(2026, 10, 3, 8, 10))}',
        ),
        findsNothing,
      );
    });

    testWidgets('normal day hides the transition card', (tester) async {
      // Arrange + Act
      await pumpSheet(tester, normalDay());

      // Assert
      expect(find.text('BEGINS'), findsOneWidget);
      expect(find.text('ENDS'), findsOneWidget);
      expect(find.text('TRANSITION'), findsNothing);
      expect(find.textContaining('begins at'), findsNothing);
    });

    testWidgets('shows moonrise and moonset chips alongside sun chips', (
      tester,
    ) async {
      // Arrange + Act: Oct 6 2026 Delhi has both a moonrise (01:42) and a
      // moonset (15:27). Chips are located by icon so the assertion is
      // immune to date-format whitespace (narrow no-break space).
      await pumpSheet(tester, normalDay());

      // Assert
      expect(find.byIcon(Icons.wb_sunny_rounded), findsOneWidget);
      expect(find.byIcon(Icons.nightlight_round), findsOneWidget);
      expect(find.byIcon(Icons.dark_mode_outlined), findsOneWidget);
      expect(find.byIcon(Icons.dark_mode), findsOneWidget);
    });

    testWidgets('shows the prevailing rise on no-moonrise days', (
      tester,
    ) async {
      // Arrange + Act: Oct 4 2026 Delhi has a moonset (14:02) but no
      // moonrise — the chip falls back to the previous evening's rise
      // (Oct 3, 23:26) with its date, instead of hiding.
      await pumpSheet(
        tester,
        squeezeDay(),
        timings: (arg) async => (
          start: DateTime(2026, 10, 3, 8, 10),
          end: DateTime(2026, 10, 4, 5, 53),
        ),
      );

      // Assert: both moon chips present; the rise chip carries the
      // previous day's date. Located by content so the assertion is
      // immune to date-format whitespace (narrow no-break space).
      expect(find.byIcon(Icons.dark_mode), findsOneWidget);
      expect(find.byIcon(Icons.dark_mode_outlined), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Text &&
              (w.data ?? '').contains('Moonrise') &&
              (w.data ?? '').contains('Oct 3'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('shows nakshatra card with span, lord and progress', (
      tester,
    ) async {
      // Arrange + Act: Rohini (index 3, lord Moon) spans into Oct 4 and
      // ends the same day, so the headline carries no date suffix.
      await pumpSheet(
        tester,
        squeezeDay(),
        timings: (arg) async => (
          start: DateTime(2026, 10, 3, 8, 10),
          end: DateTime(2026, 10, 4, 5, 53),
        ),
        nakshatraTimings: (arg) async => (
          index: 3,
          nakshatra: 'Rohini',
          start: DateTime(2026, 10, 3, 15, 30),
          end: DateTime(2026, 10, 4, 15, 42),
        ),
      );

      // Assert: label + headline pin the span; the lord substring is
      // asserted loosely because the elapsed share depends on the wall
      // clock. Clock text goes through the shared formatter (U+202F).
      // Rohini (index 3) is followed by Mrigashira (index 4).
      expect(find.text('NAKSHATRA'), findsOneWidget);
      expect(
        find.text('Rohini until ${jm(DateTime(2026, 10, 4, 15, 42))}'),
        findsOneWidget,
      );
      expect(find.textContaining('Lord: Moon'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(
        find.text(
          'Next: Mrigashira at ${jm(DateTime(2026, 10, 4, 15, 42))}',
        ),
        findsOneWidget,
      );
    });

    testWidgets('nakshatra headline carries the date when it ends next day', (
      tester,
    ) async {
      // Arrange + Act
      await pumpSheet(
        tester,
        squeezeDay(),
        timings: (arg) async => (
          start: DateTime(2026, 10, 3, 8, 10),
          end: DateTime(2026, 10, 4, 5, 53),
        ),
        nakshatraTimings: (arg) async => (
          index: 3,
          nakshatra: 'Rohini',
          start: DateTime(2026, 10, 4, 2, 10),
          end: DateTime(2026, 10, 5, 2, 10),
        ),
      );

      // Assert
      expect(
        find.text(
          'Rohini until ${jm(DateTime(2026, 10, 5, 2, 10))}, '
          '${mmmd(DateTime(2026, 10, 5, 2, 10))}',
        ),
        findsOneWidget,
      );
    });

    testWidgets('missing nakshatra span hides the card', (tester) async {
      // Arrange + Act: default pumpSheet resolves the span to null (web
      // fallback has no ephemeris).
      await pumpSheet(
        tester,
        squeezeDay(),
        timings: (arg) async => (
          start: DateTime(2026, 10, 3, 8, 10),
          end: DateTime(2026, 10, 4, 5, 53),
        ),
      );

      // Assert: timings still render, nakshatra label is gone.
      expect(find.text('BEGINS'), findsOneWidget);
      expect(find.text('NAKSHATRA'), findsNothing);
      expect(find.byType(LinearProgressIndicator), findsNothing);
    });

    testWidgets('shows yoga and karana card with followers', (
      tester,
    ) async {
      // Arrange + Act: Sukarma (index 6 -> Dhriti) ends same-day;
      // Bava (index 15 -> Balava) ends same-day. Follower names need no
      // search: yoga advances +1 mod 27, karana +1 mod 60.
      await pumpSheet(
        tester,
        squeezeDay(),
        timings: (arg) async => (
          start: DateTime(2026, 10, 3, 8, 10),
          end: DateTime(2026, 10, 4, 5, 53),
        ),
        yogaKarana: (arg) async => (
          yogaIndex: 6,
          yoga: 'Sukarma',
          yogaEnd: DateTime(2026, 10, 4, 15, 42),
          karanaIndex: 15,
          karana: 'Bava',
          karanaEnd: DateTime(2026, 10, 4, 15, 28),
        ),
      );

      // Assert: header + cell labels pin the layout; names and follower
      // lines pin the content. Clock text uses the shared formatter.
      expect(find.text('YOGA & KARANA'), findsOneWidget);
      expect(find.text('YOGA'), findsOneWidget);
      expect(find.text('KARANA'), findsOneWidget);
      expect(find.text('Sukarma'), findsOneWidget);
      expect(find.text('Bava'), findsOneWidget);
      expect(
        exactLine(
          'until ${jm(DateTime(2026, 10, 4, 15, 42))}, then Dhriti',
        ),
        findsOneWidget,
      );
      expect(
        exactLine(
          'until ${jm(DateTime(2026, 10, 4, 15, 28))}, then Balava',
        ),
        findsOneWidget,
      );
    });

    testWidgets('yoga/karana times render undimmed', (tester) async {
      // Arrange + Act
      await pumpSheet(
        tester,
        squeezeDay(),
        timings: (arg) async => (
          start: DateTime(2026, 10, 3, 8, 10),
          end: DateTime(2026, 10, 4, 5, 53),
        ),
        yogaKarana: (arg) async => (
          yogaIndex: 6,
          yoga: 'Sukarma',
          yogaEnd: DateTime(2026, 10, 4, 15, 42),
          karanaIndex: 15,
          karana: 'Bava',
          karanaEnd: DateTime(2026, 10, 4, 15, 28),
        ),
      );

      // Assert: the subline mixes a dim run with a fully-opaque time run.
      final rich = tester
          .widgetList<RichText>(find.byType(RichText))
          .firstWhere(
            (r) => r.text.toPlainText().contains('then Dhriti'),
          );
      final opacities = <double>{};
      void visit(InlineSpan span) {
        if (span is TextSpan) {
          final color = span.style?.color;
          if (color != null) opacities.add(color.a);
          span.children?.forEach(visit);
        }
      }

      visit(rich.text);
      expect(opacities.any((o) => o < 1.0), isTrue);
      expect(opacities.any((o) => o >= 1.0), isTrue);
    });

    testWidgets('missing yoga/karana spans hide the card', (tester) async {
      // Arrange + Act: default pumpSheet resolves the spans to null (web
      // fallback has no ephemeris).
      await pumpSheet(
        tester,
        squeezeDay(),
        timings: (arg) async => (
          start: DateTime(2026, 10, 3, 8, 10),
          end: DateTime(2026, 10, 4, 5, 53),
        ),
      );

      // Assert: timings still render, yoga/karana header is gone.
      expect(find.text('BEGINS'), findsOneWidget);
      expect(find.text('YOGA & KARANA'), findsNothing);
      expect(find.text('YOGA'), findsNothing);
    });

    testWidgets('sheet height is capped at 85 percent and scrolls', (
      tester,
    ) async {
      // Arrange + Act
      await pumpSheet(
        tester,
        squeezeDay(),
        timings: (arg) async => (
          start: DateTime(2026, 10, 3, 8, 10),
          end: DateTime(2026, 10, 4, 5, 53),
        ),
      );

      // Assert: the root caps height at 85% of the view; the rendered
      // sheet never exceeds it while the contents stay scrollable.
      final view = tester.view;
      final expectedCap =
          view.physicalSize.height / view.devicePixelRatio * 0.85;
      final caps = tester
          .widgetList<ConstrainedBox>(find.byType(ConstrainedBox))
          .where(
            (b) => (b.constraints.maxHeight - expectedCap).abs() < 0.001,
          );
      expect(caps, hasLength(1));
      expect(
        tester.getSize(find.byType(TithiDetailSheet).first).height,
        lessThanOrEqualTo(expectedCap + 0.001),
      );
      expect(find.byType(SingleChildScrollView), findsOneWidget);
    });

    testWidgets('downward drag from the top dismisses the sheet', (
      tester,
    ) async {
      // Arrange: present modally like paksha_hero_card (isScrollControlled
      // + transparent background) so the overscroll listener has a route
      // to pop. Overrides mirror pumpSheet.
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
            accessibilityProvider.overrideWith(_NoHapticsNotifier.new),
            tithiTimingsProvider.overrideWith(
              (ref, arg) => Future.value((
                start: DateTime(2026, 10, 3, 8, 10),
                end: DateTime(2026, 10, 4, 5, 53),
              )),
            ),
            // Hermetic like pumpSheet: the real span providers need the
            // native ephemeris, which never resolves in widget tests and
            // would leave loading spinners spinning (pumpAndSettle hang).
            nakshatraTimingsProvider.overrideWith((ref, arg) {
              return Future<
                ({
                  DateTime end,
                  int index,
                  String nakshatra,
                  DateTime start,
                })?
              >.value();
            }),
            yogaKaranaTimingsProvider.overrideWith((ref, arg) {
              return Future<
                ({
                  int yogaIndex,
                  String yoga,
                  DateTime yogaEnd,
                  int karanaIndex,
                  String karana,
                  DateTime karanaEnd,
                })?
              >.value();
            }),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (context) =>
                        TithiDetailSheet(panchang: squeezeDay()),
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
      expect(find.byType(TithiDetailSheet), findsOneWidget);

      // Act: sustained downward drag past the ~120px dismiss threshold.
      await tester.drag(find.byType(TithiDetailSheet), const Offset(0, 250));
      await tester.pumpAndSettle();

      // Assert
      expect(find.byType(TithiDetailSheet), findsNothing);
    });

    testWidgets('shows day windows card with timeline and ranges', (
      tester,
    ) async {
      // Arrange + Act: Saturday anchors from the mockup.
      await pumpSheet(
        tester,
        saturdayWindows(),
        timings: (arg) async => (
          start: DateTime(2026, 10, 2, 8, 10),
          end: DateTime(2026, 10, 3, 5, 53),
        ),
      );

      // Assert: header + rows pin the content; ranges use the shared
      // period ("8:27 – 9:59 AM") built with the shared formatter.
      // The striped Rahu slot is the only diagonal-stripes paint.
      expect(find.text('INAUSPICIOUS TIMINGS'), findsOneWidget);
      expect(find.text('Rahu Kalam'), findsOneWidget);
      expect(find.text('Yamaganda'), findsOneWidget);
      expect(find.text('Gulika Kalam'), findsOneWidget);
      expect(
        find.text(
          '${hmm(DateTime(2026, 10, 3, 8, 27))} – '
          '${jm(DateTime(2026, 10, 3, 9, 59))}',
        ),
        findsOneWidget,
      );
      expect(
        find.text(
          '${hmm(DateTime(2026, 10, 3, 5, 24))} – '
          '${jm(DateTime(2026, 10, 3, 6, 56))}',
        ),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is CustomPaint &&
              // Public since the sheet-cards extraction
              // (features/tithi_sheet/widgets).
              w.painter.runtimeType.toString() == 'DiagonalStripesPainter',
        ),
        findsOneWidget,
      );
    });

    testWidgets('hides day windows card without sun anchors', (
      tester,
    ) async {
      // Arrange + Act: no sunrise/sunset, so no day division is possible.
      await pumpSheet(
        tester,
        PanchangData.fromRawTithi(
          date: DateTime(2026, 10, 3),
          rawTithi: 22.5,
        ),
        timings: (arg) async => (
          start: DateTime(2026, 10, 2, 8, 10),
          end: DateTime(2026, 10, 3, 5, 53),
        ),
      );

      // Assert: timings still render, day windows header is gone.
      expect(find.text('BEGINS'), findsOneWidget);
      expect(find.text('INAUSPICIOUS TIMINGS'), findsNothing);
    });

    testWidgets('shows auspicious timings rows', (tester) async {
      // Arrange + Act: Saturday anchors (Abhijit 11:06-11:54, Brahma
      // 3:49-4:37, midpoint 11:30, Nishita 23:07-23:54).
      await pumpSheet(
        tester,
        saturdayWindows(),
        timings: (arg) async => (
          start: DateTime(2026, 10, 2, 8, 10),
          end: DateTime(2026, 10, 3, 5, 53),
        ),
      );

      // Assert: header + rows; Saturday boosts Abhijit.
      expect(find.text('AUSPICIOUS TIMINGS'), findsOneWidget);
      expect(find.text('Abhijit'), findsOneWidget);
      expect(find.text('Brahma Muhurta'), findsOneWidget);
      expect(find.text('Madhyahna'), findsOneWidget);
      expect(find.text('Nishita'), findsOneWidget);
      expect(find.text('Godhuli'), findsOneWidget);
      expect(find.text('Pradosha'), findsOneWidget);
      expect(
        find.text(
          '${hmm(DateTime(2026, 10, 3, 11, 6))} – '
          '${jm(DateTime(2026, 10, 3, 11, 54))}',
        ),
        findsOneWidget,
      );
      expect(
        find.text('midpoint ${jm(DateTime(2026, 10, 3, 11, 30))}'),
        findsOneWidget,
      );
      expect(find.text('Especially auspicious today'), findsOneWidget);
      expect(find.text('Avoided on Wednesday'), findsNothing);
    });

    testWidgets('Abhijit shows avoided note on Wednesday', (tester) async {
      // Arrange + Act: Oct 7 2026 is a Wednesday.
      await pumpSheet(
        tester,
        PanchangData.fromRawTithi(
          date: DateTime(2026, 10, 7),
          rawTithi: 26.5,
          sunrise: DateTime(2026, 10, 7, 5, 29),
          sunset: DateTime(2026, 10, 7, 17, 28),
        ),
        timings: (arg) async => (
          start: DateTime(2026, 10, 6, 8, 10),
          end: DateTime(2026, 10, 7, 5, 53),
        ),
      );

      // Assert
      expect(find.text('Avoided on Wednesday'), findsOneWidget);
      expect(find.text('Especially auspicious today'), findsNothing);
    });

    testWidgets('Nishita spanning midnight shows both periods', (
      tester,
    ) async {
      // Arrange: late sunset + real next sunrise puts Nishita across
      // midnight; expected range derived from the same pure arithmetic
      // (this pins the wiring and the two-period format, not the math).
      final sunrise = DateTime(2026, 10, 3, 5, 24);
      final sunset = DateTime(2026, 10, 3, 17, 54);
      final nextSunrise = SunriseCalculator.calculateSunriseIST(
        date: DateTime(2026, 10, 4),
        latitude: lat,
        longitude: lon,
      );
      final nishita = AuspiciousTimings.calculate(
        date: DateTime(2026, 10, 3),
        sunrise: sunrise,
        sunset: sunset,
        nextSunrise: nextSunrise,
      ).nishita;
      expect(nishita.end.day, equals(4)); // guard: truly spans midnight

      // Act
      await pumpSheet(
        tester,
        PanchangData.fromRawTithi(
          date: DateTime(2026, 10, 3),
          rawTithi: 22.5,
          sunrise: sunrise,
          sunset: sunset,
        ),
        timings: (arg) async => (
          start: DateTime(2026, 10, 2, 8, 10),
          end: DateTime(2026, 10, 3, 5, 53),
        ),
      );

      // Assert: the next-day end carries its date; the same-day start
      // does not.
      expect(nishita.end.day, equals(4));
      expect(
        find.text(
          '${jm(nishita.start)} – '
          '${jm(nishita.end)}, ${mmmd(nishita.end)}',
        ),
        findsOneWidget,
      );
    });

    testWidgets('Nishita fully past midnight dates both ends', (
      tester,
    ) async {
      // Arrange: January night puts the whole span on the next civil day;
      // expected range derived from the same pure arithmetic.
      final sunrise = DateTime(2026, 1, 15, 7, 15);
      final sunset = DateTime(2026, 1, 15, 17, 45);
      final nextSunrise = SunriseCalculator.calculateSunriseIST(
        date: DateTime(2026, 1, 16),
        latitude: lat,
        longitude: lon,
      );
      final nishita = AuspiciousTimings.calculate(
        date: DateTime(2026, 1, 15),
        sunrise: sunrise,
        sunset: sunset,
        nextSunrise: nextSunrise,
      ).nishita;
      expect(nishita.start.day, equals(16)); // guard: both ends off-day

      // Act
      await pumpSheet(
        tester,
        PanchangData.fromRawTithi(
          date: DateTime(2026, 1, 15),
          rawTithi: 22.5,
          sunrise: sunrise,
          sunset: sunset,
        ),
        timings: (arg) async => (
          start: DateTime(2026, 1, 14, 8, 10),
          end: DateTime(2026, 1, 15, 5, 53),
        ),
      );

      // Assert
      expect(
        find.text(
          '${jm(nishita.start)}, ${mmmd(nishita.start)} – '
          '${jm(nishita.end)}, ${mmmd(nishita.end)}',
        ),
        findsOneWidget,
      );
    });

    testWidgets('hides auspicious card without sun anchors', (tester) async {
      // Arrange + Act
      await pumpSheet(
        tester,
        PanchangData.fromRawTithi(
          date: DateTime(2026, 10, 3),
          rawTithi: 22.5,
        ),
        timings: (arg) async => (
          start: DateTime(2026, 10, 2, 8, 10),
          end: DateTime(2026, 10, 3, 5, 53),
        ),
      );

      // Assert
      expect(find.text('BEGINS'), findsOneWidget);
      expect(find.text('AUSPICIOUS TIMINGS'), findsNothing);
    });

    testWidgets('missing timings hide the timings card', (tester) async {
      // Arrange + Act
      await pumpSheet(tester, normalDay(), timings: (arg) async => null);

      // Assert
      expect(find.text('BEGINS'), findsNothing);
      expect(find.text('ENDS'), findsNothing);
      // Sun chips, header and explainer still render.
      expect(find.textContaining('Ekadashi'), findsWidgets);
      expect(
        find.text('Sunrise ${jm(DateTime(2026, 10, 6, 5, 29))}'),
        findsOneWidget,
      );
    });
  });
}
