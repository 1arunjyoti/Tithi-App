import 'dart:math' as math;

import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter_localizations/flutter_localizations.dart'
    show GlobalWidgetsLocalizations;
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:tithi/l10n/app_localizations.dart';
import 'package:tithi/models/eclipse.dart';
import 'package:tithi/models/panchang_data.dart';
import 'package:tithi/models/panchang_school.dart';
import 'package:tithi/providers/accessibility_provider.dart';
import 'package:tithi/providers/calendar_provider.dart';
import 'package:tithi/features/eclipse/providers/eclipse_providers.dart';
import 'package:tithi/features/moon/providers/moon_details_providers.dart';
import 'package:tithi/features/moon/providers/moon_providers.dart';
import 'package:tithi/providers/panchang_provider.dart';
import 'package:tithi/screens/moon_phases_screen.dart';
import 'package:tithi/services/moon_phase_service.dart';
import 'package:tithi/theme/app_theme.dart';

PanchangData mockDayPanchang(DateTime date) {
  return PanchangData(
    date: date,
    rawTithi: 8.0,
    tithiNumber: 8,
    tithiName: 'Ashtami',
    paksha: 'Shukla',
    masa: 'Chaitra',
    sunrise: date,
    sunset: date,
  );
}

/// Accessibility state without Hive (settings box is closed under
/// flutter_test, so the real notifier's build would throw on read).
class FakeAccessibilityNotifier extends AccessibilityNotifier {
  @override
  AccessibilityState build() => const AccessibilityState();
}

({Widget widget, ProviderContainer container, DateTime now}) moonTestScreen({
  ThemeData? theme,
}) {
  final now = DateTime.now();
  final container = ProviderContainer(
    overrides: [
      accessibilityProvider.overrideWith(FakeAccessibilityNotifier.new),
      // PanchangService reads the persisted calculation school, so without
      // this override the provider chain would touch the closed settings box.
      panchangSchoolProvider.overrideWithValue(PanchangSchool.bisuddha),
      moonPhaseDataProvider.overrideWith(
        (ref) async => MoonPhaseData(
          nextAmavasya: now.add(const Duration(days: 22)),
          nextPurnima: now.add(const Duration(days: 7)),
          currentTithi: 8.0,
          isShukla: true,
        ),
      ),
      upcomingPurnimasProvider.overrideWith(
        (ref) async => [now.add(const Duration(days: 7))],
      ),
      upcomingAmavasyasProvider.overrideWith(
        (ref) async => [now.add(const Duration(days: 22))],
      ),
      panchangForDateProvider.overrideWith(
        (ref, date) async => mockDayPanchang(date),
      ),
      // The new detail cards read the native/location seams. Host tests have
      // neither, so pin them to inert values and keep the hero/list behaviour
      // under test.
      moonSkyTimesProvider.overrideWith(
        (ref, date) async => const MoonSkyTimes(),
      ),
      moonViewingWindowProvider.overrideWith((ref, date) async => null),
      moonDistanceInfoProvider.overrideWith((ref, date) async => null),
      upcomingEclipsesProvider.overrideWith((ref) async => <Eclipse>[]),
    ],
  );
  final widget = UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      theme: theme,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: const MoonPhasesScreen(),
    ),
  );
  return (widget: widget, container: container, now: now);
}

void main() {
  group('Moon phase mapping', () {
    test('mid-tithi fallback is symmetric across the new-moon minimum', () {
      // Arrange + Act (no rawTithi: mid-tithi estimate)
      final amavasya = MoonPhaseService.illuminationFractionForDay(
        tithiNumber: 15,
        isShukla: false,
      );
      final pratipada = MoonPhaseService.illuminationFractionForDay(
        tithiNumber: 1,
        isShukla: true,
      );

      // Assert: both read 3.3%, never inverted
      expect(amavasya, closeTo(0.5 / 15, 1e-9));
      expect(pratipada, closeTo(0.5 / 15, 1e-9));
    });

    test(
      'fractional sunrise tithi is preferred and monotonic into new moon',
      () {
        // Arrange + Act
        final amavasyaDay = MoonPhaseService.illuminationFractionForDay(
          tithiNumber: 15,
          isShukla: false,
          rawTithi: 30.3,
        );
        final pratipadaDay = MoonPhaseService.illuminationFractionForDay(
          tithiNumber: 1,
          isShukla: true,
          rawTithi: 1.3,
        );

        // Assert
        expect(amavasyaDay, closeTo((31 - 30.3) / 15, 1e-9));
        expect(pratipadaDay, closeTo((1.3 - 1) / 15, 1e-9));
        expect(pratipadaDay, lessThan(amavasyaDay));
      },
    );

    test('wrap fringe (0,1] reads as late Amavasya', () {
      // Act
      final phase = MoonPhaseService.illuminationFractionForDay(
        tithiNumber: 15,
        isShukla: false,
        rawTithi: 0.5,
      );

      // Assert: 0.5 -> 30.5 -> 3.3%
      expect(phase, closeTo(0.5 / 15, 1e-9));
    });

    test('garbage rawTithi falls back to the mid-tithi estimate', () {
      // Act + Assert
      for (final garbage in [double.nan, 0.0, -3.0, 99.0]) {
        expect(
          MoonPhaseService.illuminationFractionForDay(
            tithiNumber: 8,
            isShukla: true,
            rawTithi: garbage,
          ),
          closeTo(7.5 / 15, 1e-9),
        );
      }
    });

    test('Amavasya renders as a sliver, not nearly full', () {
      // Regression: Krishna 15 (Amavasya) used to map to 29/30, which the
      // painter reads as 97% lit.
      // Act
      final phase = MoonPhaseService.illuminationFractionForDay(
        tithiNumber: 15,
        isShukla: false,
      );

      // Assert
      expect(phase, lessThan(0.1));
    });

    test('clampMoonScrubOffset keeps the offset in range', () {
      // Act + Assert
      expect(clampMoonScrubOffset(99), equals(moonScrubRangeDays));
      expect(clampMoonScrubOffset(-99), equals(-moonScrubRangeDays));
      expect(clampMoonScrubOffset(3), equals(3));
    });
  });

  group('Moon scrub hero', () {
    testWidgets('dragging back shows that date; double-tap resets to Today', (
      tester,
    ) async {
      // Arrange
      final harness = moonTestScreen();
      addTearDown(harness.container.dispose);
      await tester.pumpWidget(harness.widget);
      await tester.pump(const Duration(milliseconds: 200));
      final scrubArea = find.byKey(const ValueKey('moon-scrub-area'));
      expect(scrubArea, findsOneWidget);
      expect(find.text('Today'), findsOneWidget);

      // Act: drag left past one 28px day-step. Raw pointer moves bypass
      // the gesture arena, so a plain drag works here.
      await tester.drag(scrubArea, const Offset(-40, 0));
      await tester.pump(const Duration(milliseconds: 500));

      // Assert: exactly one day back (truncate(-40 / 28) == -1).
      expect(harness.container.read(moonScrubOffsetProvider), equals(-1));
      final now = DateTime.now();
      final yesterday = DateTime(now.year, now.month, now.day - 1);
      expect(find.text('Today'), findsNothing);
      expect(find.text(DateFormat.yMMMd().format(yesterday)), findsOneWidget);

      // Act: double-tap resets to today
      await tester.tap(scrubArea);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(scrubArea);
      await tester.pump(const Duration(milliseconds: 500));

      // Assert
      expect(find.text('Today'), findsOneWidget);
    });
  });

  group('Moon halo', () {
    testWidgets('glow fades inside its own box instead of clipping at the app bar', (
      tester,
    ) async {
      final harness = moonTestScreen();
      addTearDown(harness.container.dispose);
      await tester.pumpWidget(harness.widget);
      await tester.pump(const Duration(milliseconds: 200));

      final halo = tester.widget<Container>(
        find.byKey(const ValueKey('moon-halo')),
      );
      final decoration = halo.decoration! as BoxDecoration;
      expect(decoration.boxShadow, isNull);
      expect(decoration.gradient, isA<RadialGradient>());
      // Layered bloom: warm core, bright amber rim, faint cool scatter, fade.
      final gradient = decoration.gradient! as RadialGradient;
      Color opaque(Color color) => color.withValues(alpha: 1);
      expect(gradient.stops, hasLength(5));
      expect(opaque(gradient.colors[0]), AppTheme.moonGlowCore);
      expect(opaque(gradient.colors[2]), AppTheme.moonGlowRim);
      expect(opaque(gradient.colors[3]), AppTheme.moonGlowScatter);
      expect(gradient.colors[4], Colors.transparent);
    });
  });

  group('Card placement and tabs', () {
    testWidgets('countdown cards stay directly under the hero', (tester) async {
      tester.view.physicalSize = const Size(500, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final harness = moonTestScreen();
      addTearDown(harness.container.dispose);
      await tester.pumpWidget(harness.widget);
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 50));

      final countdownTop = tester
          .getTopLeft(find.byKey(const ValueKey('moon-countdown-purnima')))
          .dy;
      final viewingTop = tester.getTopLeft(find.text('Best viewing time')).dy;
      expect(countdownTop, lessThan(viewingTop));
    });

    testWidgets('tabs sit with the list and switch between Purnima/Amavasya', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(500, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final harness = moonTestScreen();
      addTearDown(harness.container.dispose);
      await tester.pumpWidget(harness.widget);
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('Upcoming dates'), findsOneWidget);
      final purnimaDate = DateFormat.yMMMMEEEEd().format(
        harness.now.add(const Duration(days: 7)),
      );
      final amavasyaDate = DateFormat.yMMMMEEEEd().format(
        harness.now.add(const Duration(days: 22)),
      );
      expect(find.text(purnimaDate), findsOneWidget);

      await tester.tap(
        find.descendant(
          of: find.byType(TabBar),
          matching: find.text('Amavasya'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(amavasyaDate), findsOneWidget);
    });
  });

  group('Upcoming dates list legibility', () {
    double channel(double c) =>
        c <= 0.03928 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4) as double;

    double luminance(Color color) =>
        0.2126 * channel(color.r) +
        0.7152 * channel(color.g) +
        0.0722 * channel(color.b);

    double contrastRatio(Color a, Color b) {
      final la = luminance(a) + 0.05;
      final lb = luminance(b) + 0.05;
      return la > lb ? la / lb : lb / la;
    }

    final themes = <String, ThemeData>{
      'Shukla': AppTheme.shuklaTheme,
      'Krishna': AppTheme.krishnaTheme,
      'Pure Dark': AppTheme.pureDarkTheme,
    };

    for (final entry in themes.entries) {
      testWidgets('${entry.key}: row date line and time clear contrast', (
        tester,
      ) async {
        // Arrange: real palette, so the tertiary ink that `bodyMedium` resolves
        // to is what the row actually paints with. The default 800x600 test
        // surface is shorter than the hero + countdown cards, which would
        // leave the list zero-height and unbuilt.
        tester.view.physicalSize = const Size(500, 1400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);
        final harness = moonTestScreen(theme: entry.value);
        addTearDown(harness.container.dispose);
        await tester.pumpWidget(harness.widget);
        await tester.pump(const Duration(milliseconds: 200));
        // Second frame: the tab lists resolve after the two async providers.
        await tester.pump(const Duration(milliseconds: 50));

        final along = harness.now.add(const Duration(days: 7));
        final dateText = tester.widget<Text>(
          find.text(DateFormat.yMMMMEEEEd().format(along)),
        );
        final timeText = tester.widget<Text>(
          find.text(DateFormat.jm().format(along)),
        );
        final page = entry.value.scaffoldBackgroundColor;

        // Assert: the date is full ink and semibold; the time is a composited
        // secondary (translucent ink must be blended before measuring).
        final dateInk = dateText.style!.color!;
        final timeInk = Color.alphaBlend(timeText.style!.color!, page);
        expect(dateInk.a, 1.0, reason: '${entry.key} date is not translucent');
        expect(
          contrastRatio(dateInk, page),
          greaterThanOrEqualTo(7.0),
          reason: '${entry.key} date line must read as primary text',
        );
        expect(
          contrastRatio(timeInk, page),
          greaterThanOrEqualTo(4.5),
          reason: '${entry.key} time line must clear body-text contrast',
        );
        expect(dateText.style!.fontWeight, FontWeight.w600);
      });
    }
  });
}
