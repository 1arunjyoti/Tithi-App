import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:tithi/l10n/app_localizations.dart';
import 'package:tithi/models/panchang_data.dart';
import 'package:tithi/providers/accessibility_provider.dart';
import 'package:tithi/providers/moon_phase_provider.dart';
import 'package:tithi/providers/panchang_provider.dart';
import 'package:tithi/screens/moon_phases_screen.dart';
import 'package:tithi/services/moon_phase_service.dart';

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

({Widget widget, ProviderContainer container}) moonTestScreen() {
  final now = DateTime.now();
  final container = ProviderContainer(
    overrides: [
      accessibilityProvider.overrideWith(FakeAccessibilityNotifier.new),
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
    ],
  );
  final widget = UncontrolledProviderScope(
    container: container,
    child: const MaterialApp(
      localizationsDelegates: [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: MoonPhasesScreen(),
    ),
  );
  return (widget: widget, container: container);
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

    test('web wrap fringe (0,1] reads as late Amavasya', () {
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
}
