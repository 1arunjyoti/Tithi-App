import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:tithi/features/hero/widgets/hero_chip.dart';
import 'package:tithi/models/festival.dart';
import 'package:tithi/models/panchang_data.dart';
import 'package:tithi/providers/accessibility_provider.dart';
import 'package:tithi/providers/calendar_provider.dart';
import 'package:tithi/providers/location_provider.dart';
import 'package:tithi/providers/panchang_provider.dart';
import 'package:tithi/services/storage_service.dart';
import 'package:tithi/widgets/paksha_hero_card.dart';
import 'package:tithi/widgets/tithi_detail_sheet.dart';

/// Records the names of pushed routes so a tap can be asserted to drill into
/// the picker rather than open the card's detail sheet.
class _RouteLog extends NavigatorObserver {
  final List<String> pushed = <String>[];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushed.add(route.settings.name ?? '');
    super.didPush(route, previousRoute);
  }
}

class _NoHapticsNotifier extends AccessibilityNotifier {
  @override
  AccessibilityState build() => const AccessibilityState(hapticFeedback: false);
}

class _FixedDateNotifier extends SelectedDateNotifier {
  @override
  DateTime build() => DateTime(2026, 9, 14);
}

void main() {
  setUp(() async {
    final tempDir = await Directory.systemTemp.createTemp(
      'tithi_location_test',
    );
    Hive.init(tempDir.path);
    await StorageService().init();
  });

  tearDown(() async {
    await Hive.close();
  });

  PanchangData heroData() => PanchangData(
    date: DateTime(2026, 9, 14),
    rawTithi: 6.5,
    tithiNumber: 6,
    tithiName: 'Shashthi',
    paksha: 'Shukla',
    masa: 'Bhadrapada',
    festivals: [
      const Festival(
        id: 'test-festival',
        name: 'Test Festival',
        category: 'major',
        nameRegional: NameRegional(nameEnglish: 'Test Festival'),
        visuals: Visuals(),
        purpose: Purpose(description: 'Test description'),
        panchangRules: PanchangRules(
          masa: '',
          paksha: 'Shukla',
          tithi: 6,
          conditions: '',
        ),
        rituals: Rituals(steps: []),
        media: Media(),
      ),
    ],
    sunrise: DateTime(2026, 9, 14, 5, 39),
    sunset: DateTime(2026, 9, 14, 18, 12),
  );

  Future<void> pumpHero(WidgetTester tester, NavigatorObserver observer) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          selectedDateProvider.overrideWith(_FixedDateNotifier.new),
          panchangForDateProvider.overrideWith(
            (ref, date) => Future.value(heroData()),
          ),
          monthlyPanchangProvider.overrideWith(
            (ref, month) => Future.value({}),
          ),
          cityNameProvider.overrideWithValue(const AsyncValue.data('Kolkata')),
          accessibilityProvider.overrideWith(_NoHapticsNotifier.new),
          tithiTimingsProvider.overrideWith(
            (ref, arg) async => (
              start: DateTime(2026, 9, 14, 5, 39),
              end: DateTime(2026, 9, 15, 4, 20),
            ),
          ),
        ],
        child: MaterialApp(
          navigatorObservers: [observer],
          home: const Scaffold(
            body: SingleChildScrollView(child: PakshaHeroCard()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('tapping the location pill opens the picker, not the sheet', (
    tester,
  ) async {
    // Arrange
    final nav = _RouteLog();
    await pumpHero(tester, nav);
    final pill = find.byType(HeroChip).first;
    expect(
      find.descendant(of: pill, matching: find.text('Kolkata')),
      findsOneWidget,
    );

    // Act: the pill is inside the card's own InkWell, so this also proves the
    // nested tap wins the arena instead of opening TithiDetailSheet.
    await tester.tap(pill);
    await tester.pump();

    // Assert
    expect(nav.pushed, contains('LocationPickerScreen'));
    expect(find.byType(TithiDetailSheet), findsNothing);

    // The picker is a live map (tile loads, GPS follow stream); tear the tree
    // down so its pending work is disposed instead of tripping the test
    // binding's dangling-timer check.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('the location pill is a button for screen readers', (
    tester,
  ) async {
    // Arrange
    final handle = tester.ensureSemantics();
    await pumpHero(tester, _RouteLog());

    // Assert: button flag + tap action + the picker hint survive.
    final data = tester
        .getSemantics(find.byType(HeroChip).first)
        .getSemanticsData();
    expect(data.flagsCollection.isButton, isTrue);
    expect(data.hasAction(SemanticsAction.tap), isTrue);
    expect(data.hint, 'Set Home Location');

    handle.dispose();
  });
}
