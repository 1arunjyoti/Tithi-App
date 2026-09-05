import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tithi/models/panchang_data.dart';
import 'package:tithi/providers/calendar_provider.dart';
import 'package:tithi/providers/panchang_provider.dart';
import 'package:tithi/widgets/tithi_detail_sheet.dart';

void main() {
  const lat = 28.6139;
  const lon = 77.2090;

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

      // Assert
      expect(find.textContaining('Ashtami'), findsWidgets);
      expect(find.text('Begins:'), findsOneWidget);
      expect(find.text('8:10 AM, Oct 3'), findsOneWidget);
      expect(find.text('Ends:'), findsOneWidget);
      expect(find.text('5:53 AM, Oct 4'), findsOneWidget);
      expect(
        find.text('Transition → Navami at 5:53 AM'),
        findsOneWidget,
      );
      expect(find.text('Navami ends:'), findsOneWidget);
      expect(find.text('4:20 AM, Oct 5'), findsOneWidget);
      expect(find.text('Sunrise:'), findsOneWidget);
      expect(find.text('Sunset:'), findsOneWidget);
    });

    testWidgets('normal day hides the transition section', (tester) async {
      // Arrange + Act
      await pumpSheet(tester, normalDay());

      // Assert
      expect(find.text('Begins:'), findsOneWidget);
      expect(find.text('Ends:'), findsOneWidget);
      expect(find.textContaining('Transition'), findsNothing);
      expect(find.textContaining('ends:'), findsNothing);
    });

    testWidgets('missing timings hide the timing rows', (tester) async {
      // Arrange + Act
      await pumpSheet(tester, normalDay(), timings: (arg) async => null);

      // Assert
      expect(find.text('Begins:'), findsNothing);
      expect(find.text('Ends:'), findsNothing);
      // Anchors and header still render.
      expect(find.textContaining('Ekadashi'), findsWidgets);
      expect(find.text('Sunrise:'), findsOneWidget);
    });
  });
}
