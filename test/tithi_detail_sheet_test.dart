import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:tithi/models/panchang_data.dart';
import 'package:tithi/providers/accessibility_provider.dart';
import 'package:tithi/providers/calendar_provider.dart';
import 'package:tithi/providers/panchang_provider.dart';
import 'package:tithi/services/storage_service.dart';
import 'package:tithi/widgets/tithi_detail_sheet.dart';

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

  Future<void> pumpSheet(
    WidgetTester tester,
    PanchangData panchang, {
    Future<({DateTime end, DateTime start})?> Function(
      ({DateTime date, double latitude, double longitude, int tithiIndex}) arg,
    )?
    timings,
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
      expect(find.text('8:10 AM, Oct 3'), findsOneWidget);
      expect(find.text('ENDS'), findsOneWidget);
      expect(find.text('5:53 AM, Oct 4'), findsOneWidget);
      expect(find.text('TRANSITION'), findsOneWidget);
      expect(find.text('Navami begins at 5:53 AM'), findsOneWidget);
      expect(find.text('Navami ends 4:20 AM, Oct 5'), findsOneWidget);
      expect(find.text('Sunrise 5:28 AM'), findsOneWidget);
      expect(find.text('Sunset 5:30 PM'), findsOneWidget);
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
      expect(find.text('8:10 AM, Ashwin Ashtami'), findsOneWidget);
      expect(find.text('5:53 AM, Ashwin Ashtami'), findsWidgets);
      expect(find.text('8:10 AM, Oct 3'), findsNothing);
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
      expect(find.text('8:10 AM, 18 Ashshin 1433'), findsOneWidget);
      expect(find.text('8:10 AM, Oct 3'), findsNothing);
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

    testWidgets('missing timings hide the timings card', (tester) async {
      // Arrange + Act
      await pumpSheet(tester, normalDay(), timings: (arg) async => null);

      // Assert
      expect(find.text('BEGINS'), findsNothing);
      expect(find.text('ENDS'), findsNothing);
      // Sun chips, header and explainer still render.
      expect(find.textContaining('Ekadashi'), findsWidgets);
      expect(find.text('Sunrise 5:29 AM'), findsOneWidget);
    });
  });
}
