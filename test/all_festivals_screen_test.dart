import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:tithi/models/festival.dart';
import 'package:tithi/providers/accessibility_provider.dart';
import 'package:tithi/screens/all_festivals_screen.dart';

class _NoHapticsNotifier extends AccessibilityNotifier {
  @override
  AccessibilityState build() => const AccessibilityState(hapticFeedback: false);
}

void main() {
  DateTime todayOnly() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  Festival fixture({
    required String id,
    required String name,
    String category = 'major',
  }) => Festival(
    id: id,
    name: name,
    category: category,
    nameRegional: const NameRegional(nameEnglish: 'Test'),
    visuals: const Visuals(),
    purpose: const Purpose(description: 'A test festival description'),
    panchangRules: const PanchangRules(
      masa: '',
      paksha: 'Shukla',
      tithi: 4,
      conditions: '',
    ),
    rituals: const Rituals(steps: []),
    media: const Media(),
  );

  Future<void> pumpScreen(
    WidgetTester tester, {
    required List<DatedFestival> occurrences,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          allFestivalOccurrencesProvider.overrideWith(
            (ref) => Future.value(occurrences),
          ),
          accessibilityProvider.overrideWith(_NoHapticsNotifier.new),
        ],
        child: const MaterialApp(home: AllFestivalsScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('sortDatedFestivals', () {
    test('ascending dates, undated last', () {
      // Arrange: deliberately unsorted input with one undatable festival.
      final today = todayOnly();
      final soon = fixture(id: 'soon', name: 'Soon Festival');
      final later = fixture(id: 'later', name: 'Later Festival');
      final now = fixture(id: 'now', name: 'Now Festival');
      final undated = fixture(id: 'undated', name: 'Undated Festival');

      // Act
      final sorted = sortDatedFestivals([
        (festival: later, date: today.add(const Duration(days: 3))),
        (festival: undated, date: null),
        (festival: soon, date: today.add(const Duration(days: 1))),
        (festival: now, date: today),
      ]);

      // Assert
      expect(
        sorted.map((e) => e.festival.id),
        equals(['now', 'soon', 'later', 'undated']),
      );
    });
  });

  group('AllFestivalsScreen', () {
    testWidgets('rows show dates instead of the category label', (
      tester,
    ) async {
      // Arrange
      final today = todayOnly();
      final soon = fixture(id: 'soon', name: 'Soon Festival');
      final later = fixture(id: 'later', name: 'Later Festival');
      final now = fixture(id: 'now', name: 'Now Festival');
      final undated = fixture(
        id: 'undated',
        name: 'Undated Festival',
        category: 'vrat',
      );
      await pumpScreen(
        tester,
        occurrences: sortDatedFestivals([
          (festival: later, date: today.add(const Duration(days: 3))),
          (festival: undated, date: null),
          (festival: soon, date: today.add(const Duration(days: 1))),
          (festival: now, date: today),
        ]),
      );

      // Assert: chronological order with the undated entry last.
      final dyNow = tester.getCenter(find.text('Now Festival')).dy;
      final dySoon = tester.getCenter(find.text('Soon Festival')).dy;
      final dyLater = tester.getCenter(find.text('Later Festival')).dy;
      final dyUndated = tester.getCenter(find.text('Undated Festival')).dy;
      expect(dyNow, lessThan(dySoon));
      expect(dySoon, lessThan(dyLater));
      expect(dyLater, lessThan(dyUndated));

      // Assert: rows carry dates (not the category label) with countdowns.
      // The row dated today shows the "Today" label instead of its date.
      final fmt = DateFormat('EEE, d MMM');
      expect(find.text('Today'), findsOneWidget);
      expect(
        find.text(
          '${fmt.format(today.add(const Duration(days: 3)))} · in 3 days',
        ),
        findsOneWidget,
      );
      expect(find.text('Major'), findsNothing);
      // The undatable row keeps the category label as its fallback line.
      expect(find.text('Vrat'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('list starts at the current point', (tester) async {
      // Arrange: more rows than fit on screen.
      final today = todayOnly();
      final occurrences = List.generate(
        12,
        (i) => (
          festival: fixture(id: 'f$i', name: 'Festival $i'),
          date: today.add(Duration(days: i)),
        ),
      );
      await pumpScreen(tester, occurrences: occurrences);

      // Assert: first rows built, far rows not (list pinned at top).
      expect(find.text('Festival 0'), findsOneWidget);
      expect(find.text('Festival 11'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('auto-scrolls past January entries to the current point', (
      tester,
    ) async {
      // Arrange: year runs past -> today -> future (pre-sorted like the
      // provider emits), with enough rows that scrolling displaces the top.
      final today = todayOnly();
      final fillers = List.generate(
        10,
        (i) => (
          festival: fixture(id: 'fill$i', name: 'Filler Festival $i'),
          date: today.add(Duration(days: 3 + i)),
        ),
      );
      await pumpScreen(
        tester,
        occurrences: sortDatedFestivals([
          (
            festival: fixture(id: 'future', name: 'Future Festival'),
            date: today.add(const Duration(days: 2)),
          ),
          (
            festival: fixture(id: 'past', name: 'Past Festival'),
            date: today.subtract(const Duration(days: 10)),
          ),
          (festival: fixture(id: 'today', name: 'Today Festival'), date: today),
          ...fillers,
        ]),
      );

      // Assert: the list landed on today's row (January entries above the
      // current point are out of the tree). Note: jumpTo re-anchors the
      // package's layout at the target index instead of moving the scroll
      // offset, so assert content — not pixels (stays 0 by design).
      expect(find.text('Today Festival'), findsOneWidget);
      // The January entry scrolled out of the cache extent entirely.
      expect(find.text('Past Festival'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('auto-scrolls to a far target that starts unbuilt', (
      tester,
    ) async {
      // Arrange: the device case — ~20 January entries above today, so the
      // target row is nowhere near the built viewport on open.
      final today = todayOnly();
      final past = List.generate(
        20,
        (i) => (
          festival: fixture(id: 'past$i', name: 'Past Festival $i'),
          date: today.subtract(Duration(days: 20 - i)),
        ),
      );
      final future = List.generate(
        9,
        (i) => (
          festival: fixture(id: 'fut$i', name: 'Future Festival $i'),
          date: today.add(Duration(days: 1 + i)),
        ),
      );
      await pumpScreen(
        tester,
        occurrences: sortDatedFestivals([
          ...past,
          (festival: fixture(id: 'today', name: 'Today Festival'), date: today),
          ...future,
        ]),
      );

      // Assert: landed on today's row, January entries gone from the tree
      // (same jumpTo note as above: content, not pixels, proves position).
      expect(find.text('Today Festival'), findsOneWidget);
      expect(find.text('Past Festival 0'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('search filters by name', (tester) async {
      // Arrange
      final today = todayOnly();
      await pumpScreen(
        tester,
        occurrences: [
          (festival: fixture(id: 'a', name: 'Alpha Puja'), date: today),
          (
            festival: fixture(id: 'b', name: 'Beta Vrat', category: 'vrat'),
            date: today.add(const Duration(days: 2)),
          ),
        ],
      );

      // Act
      await tester.enterText(find.byType(TextField), 'beta');
      await tester.pumpAndSettle();

      // Assert
      expect(find.text('Beta Vrat'), findsOneWidget);
      expect(find.text('Alpha Puja'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });
}
