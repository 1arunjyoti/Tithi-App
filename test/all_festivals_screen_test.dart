import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
import 'package:tithi/features/countdown/domain/target_resolution.dart'
    show collectRecurringOccurrences;
import 'package:tithi/models/festival.dart';
import 'package:tithi/models/festival_region.dart';
import 'package:tithi/providers/accessibility_provider.dart';
import 'package:tithi/providers/festival_provider.dart';
import 'package:tithi/screens/all_festivals_screen.dart';
import 'package:tithi/services/storage_service.dart';
import 'package:tithi/widgets/festival_row_tile.dart';

class _NoHapticsNotifier extends AccessibilityNotifier {
  @override
  AccessibilityState build() => const AccessibilityState(hapticFeedback: false);
}

class _HapticsNotifier extends AccessibilityNotifier {
  @override
  // ignore: avoid_redundant_argument_values
  AccessibilityState build() => const AccessibilityState(hapticFeedback: true);
}

void main() {
  setUp(() async {
    final tempDir = await Directory.systemTemp.createTemp(
      'tithi_all_fest_test',
    );
    Hive.init(tempDir.path);
    await StorageService().init();
  });

  tearDown(() async {
    await Hive.close();
  });

  DateTime todayOnly() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  Festival fixture({
    required String id,
    required String name,
    String category = 'major',
    bool recurring = false,
    List<String> regions = const ['all'],
  }) => Festival(
    id: id,
    name: name,
    category: category,
    nameRegional: const NameRegional(nameEnglish: 'Test'),
    visuals: const Visuals(),
    purpose: const Purpose(description: 'A test festival description'),
    panchangRules: PanchangRules(
      masa: '',
      paksha: 'Shukla',
      tithi: 4,
      conditions: '',
      recurring: recurring,
    ),
    rituals: const Rituals(steps: []),
    media: const Media(),
    regions: regions,
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

  /// Opens the app-bar filter sheet, optionally stages a category/region (or
  /// taps Reset), then applies with Done.
  Future<void> applyFilters(
    WidgetTester tester, {
    String? category,
    String? region,
    bool reset = false,
  }) async {
    await tester.tap(find.byIcon(Icons.tune_rounded));
    await tester.pumpAndSettle();
    if (reset) {
      await tester.tap(find.text('Reset'));
      await tester.pumpAndSettle();
    }
    if (category != null) {
      await tester.tap(find.text(category));
      await tester.pumpAndSettle();
    }
    if (region != null) {
      await tester.tap(find.text(region));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.text('Done'));
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

  group('collectRecurringOccurrences', () {
    test('expands a recurring vrat to every occurrence in the year', () async {
      // Arrange: a tithi that recurs every 29 days, first on Jan 5.
      final occurrences = List.generate(
        18,
        (i) => DateTime(2026, 1, 5).add(Duration(days: 29 * i)),
      );
      Future<DateTime?> nextAfter(DateTime start) async {
        for (final date in occurrences) {
          if (!date.isBefore(start)) return date;
        }
        return null;
      }

      // Act
      final dates = await collectRecurringOccurrences(
        first: occurrences.first,
        through: DateTime(2026, 12, 31),
        nextAfter: nextAfter,
      );

      // Assert: 13 lunations fall inside 2026 (Jan 5 … Dec 19), none after.
      expect(dates, hasLength(13));
      expect(dates.last, equals(DateTime(2026, 12, 19)));
      expect(dates.every((d) => d.year == 2026), isTrue);
    });

    test('stops when the resolver does not advance', () async {
      // A malformed rule that keeps returning the same date must not hang.
      final dates = await collectRecurringOccurrences(
        first: DateTime(2026, 1, 5),
        through: DateTime(2026, 12, 31),
        nextAfter: (_) async => DateTime(2026, 1, 5),
      );

      expect(dates, equals([DateTime(2026, 1, 5)]));
    });
  });

  group('festivalMatchesCategoryFilter', () {
    test('major appears only under All and Major', () {
      final festival = fixture(id: 'm', name: 'Major');

      expect(
        festivalMatchesCategoryFilter(festival, FestivalCategoryFilter.all),
        isTrue,
      );
      expect(
        festivalMatchesCategoryFilter(festival, FestivalCategoryFilter.major),
        isTrue,
      );
      expect(
        festivalMatchesCategoryFilter(festival, FestivalCategoryFilter.vrat),
        isFalse,
      );
      expect(
        festivalMatchesCategoryFilter(
          festival,
          FestivalCategoryFilter.recurring,
        ),
        isFalse,
      );
    });

    test('vrat appears under All and Vrat, not Recurring', () {
      final festival = fixture(id: 'v', name: 'Vrat', category: 'vrat');

      expect(
        festivalMatchesCategoryFilter(festival, FestivalCategoryFilter.all),
        isTrue,
      );
      expect(
        festivalMatchesCategoryFilter(festival, FestivalCategoryFilter.major),
        isFalse,
      );
      expect(
        festivalMatchesCategoryFilter(festival, FestivalCategoryFilter.vrat),
        isTrue,
      );
      expect(
        festivalMatchesCategoryFilter(
          festival,
          FestivalCategoryFilter.recurring,
        ),
        isFalse,
      );
    });

    test('recurring appears under All, Vrat and Recurring', () {
      // Purnima/Amavasya use category 'recurring'; the app-wide vrat
      // definition includes the recurring flag, so both chips show them.
      final festival = fixture(
        id: 'r',
        name: 'Recurring',
        category: 'recurring',
        recurring: true,
      );

      expect(
        festivalMatchesCategoryFilter(festival, FestivalCategoryFilter.all),
        isTrue,
      );
      expect(
        festivalMatchesCategoryFilter(festival, FestivalCategoryFilter.major),
        isFalse,
      );
      expect(
        festivalMatchesCategoryFilter(festival, FestivalCategoryFilter.vrat),
        isTrue,
      );
      expect(
        festivalMatchesCategoryFilter(
          festival,
          FestivalCategoryFilter.recurring,
        ),
        isTrue,
      );
    });
  });

  group('festivalMatchesRegionFilter', () {
    test('pan-India festivals match every region', () {
      final panIndia = fixture(id: 'all', name: 'Pan India');

      for (final region in FestivalRegion.values) {
        expect(festivalMatchesRegionFilter(panIndia, region), isTrue);
      }
    });

    test('a zone keeps pan-India and its own, hides other zones', () {
      final south = fixture(id: 's', name: 'South', regions: const ['south']);
      final north = fixture(id: 'n', name: 'North', regions: const ['north']);

      expect(festivalMatchesRegionFilter(south, FestivalRegion.all), isTrue);
      expect(festivalMatchesRegionFilter(south, FestivalRegion.south), isTrue);
      expect(festivalMatchesRegionFilter(south, FestivalRegion.north), isFalse);

      expect(festivalMatchesRegionFilter(north, FestivalRegion.south), isFalse);
      expect(festivalMatchesRegionFilter(north, FestivalRegion.north), isTrue);
    });

    test('category and region compose', () {
      final southVrat = fixture(
        id: 'sv',
        name: 'South Vrat',
        category: 'vrat',
        regions: const ['south'],
      );

      expect(
        festivalMatchesFilters(
          southVrat,
          const FestivalFilterSelection(
            category: FestivalCategoryFilter.vrat,
            region: FestivalRegion.south,
          ),
        ),
        isTrue,
      );
      expect(
        festivalMatchesFilters(
          southVrat,
          const FestivalFilterSelection(
            category: FestivalCategoryFilter.vrat,
            region: FestivalRegion.north,
          ),
        ),
        isFalse,
      );
      expect(
        festivalMatchesFilters(
          southVrat,
          const FestivalFilterSelection(
            category: FestivalCategoryFilter.major,
            region: FestivalRegion.south,
          ),
        ),
        isFalse,
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
      // Chip labels also say "Major"/"Vrat", so scope these to the rows.
      Finder inRows(String text) => find.descendant(
        of: find.byType(FestivalRowTile),
        matching: find.text(text),
      );
      expect(inRows('Major'), findsNothing);
      // The undatable row keeps the category label as its fallback line.
      expect(inRows('Vrat'), findsOneWidget);
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

    testWidgets('lists every occurrence of a recurring festival', (
      tester,
    ) async {
      // Arrange: the same catalog entry on two dates (Ekadashi Shukla).
      final today = todayOnly();
      final ekadashi = fixture(
        id: 'ekadashi_shukla',
        name: 'Ekadashi (Shukla)',
        category: 'vrat',
      );
      await pumpScreen(
        tester,
        occurrences: sortDatedFestivals([
          (festival: ekadashi, date: today),
          (festival: ekadashi, date: today.add(const Duration(days: 15))),
        ]),
      );

      // Assert: one row per occurrence — no duplicate-key crash.
      expect(find.text('Ekadashi (Shukla)'), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    });

    testWidgets('filter sheet narrows by category and composes with search', (
      tester,
    ) async {
      // Arrange: one festival per category, dated in order.
      final today = todayOnly();
      final major = fixture(id: 'alpha', name: 'Alpha Major');
      final vrat = fixture(id: 'beta', name: 'Beta Vrat', category: 'vrat');
      final recurring = fixture(
        id: 'gamma',
        name: 'Gamma Recurring',
        category: 'recurring',
        recurring: true,
      );
      await pumpScreen(
        tester,
        occurrences: sortDatedFestivals([
          (festival: major, date: today),
          (festival: vrat, date: today.add(const Duration(days: 1))),
          (festival: recurring, date: today.add(const Duration(days: 2))),
        ]),
      );

      // Default: no filter selected, so no dot on the filter icon.
      expect(tester.widget<Badge>(find.byType(Badge)).isLabelVisible, isFalse);
      expect(find.text('Alpha Major'), findsOneWidget);
      expect(find.text('Beta Vrat'), findsOneWidget);
      expect(find.text('Gamma Recurring'), findsOneWidget);

      // Vrat: category vrat + recurring (Ekadashi/Purnima convention).
      await applyFilters(tester, category: 'Vrat');
      expect(tester.widget<Badge>(find.byType(Badge)).isLabelVisible, isTrue);
      expect(find.text('Alpha Major'), findsNothing);
      expect(find.text('Beta Vrat'), findsOneWidget);
      expect(find.text('Gamma Recurring'), findsOneWidget);

      // Recurring: only the recurring flag.
      await applyFilters(tester, category: 'Recurring');
      expect(find.text('Alpha Major'), findsNothing);
      expect(find.text('Beta Vrat'), findsNothing);
      expect(find.text('Gamma Recurring'), findsOneWidget);

      // Major: only category major.
      await applyFilters(tester, category: 'Major');
      expect(find.text('Alpha Major'), findsOneWidget);
      expect(find.text('Beta Vrat'), findsNothing);

      // Search composes with the active filter: no vrat named "beta" among
      // the major-only rows would show if the filter were ignored.
      await applyFilters(tester, category: 'Vrat');
      await tester.enterText(find.byType(TextField), 'beta');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      expect(find.text('Alpha Major'), findsNothing);
      expect(find.text('Beta Vrat'), findsOneWidget);
      expect(find.text('Gamma Recurring'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('filter sheet narrows by region and resets', (tester) async {
      // Arrange: pan-India plus one vrat rooted in each of two zones.
      final today = todayOnly();
      final panIndia = fixture(id: 'pan', name: 'Pan India Festival');
      final southVrat = fixture(
        id: 'south',
        name: 'South Vrat',
        category: 'vrat',
        regions: const ['south'],
      );
      final northVrat = fixture(
        id: 'north',
        name: 'North Vrat',
        category: 'vrat',
        regions: const ['north'],
      );
      await pumpScreen(
        tester,
        occurrences: sortDatedFestivals([
          (festival: panIndia, date: today),
          (festival: southVrat, date: today.add(const Duration(days: 1))),
          (festival: northVrat, date: today.add(const Duration(days: 2))),
        ]),
      );

      // South keeps pan-India festivals plus South-rooted ones.
      await applyFilters(tester, region: 'South India');
      expect(find.text('Pan India Festival'), findsOneWidget);
      expect(find.text('South Vrat'), findsOneWidget);
      expect(find.text('North Vrat'), findsNothing);

      // Category composes with the retained region.
      await applyFilters(tester, category: 'Vrat');
      expect(find.text('Pan India Festival'), findsNothing);
      expect(find.text('South Vrat'), findsOneWidget);
      expect(find.text('North Vrat'), findsNothing);

      // Reset returns both dimensions to no filtering.
      await applyFilters(tester, reset: true);
      expect(tester.widget<Badge>(find.byType(Badge)).isLabelVisible, isFalse);
      expect(find.text('Pan India Festival'), findsOneWidget);
      expect(find.text('South Vrat'), findsOneWidget);
      expect(find.text('North Vrat'), findsOneWidget);
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

    testWidgets('a row tap fires exactly one haptic', (tester) async {
      // Arrange: intercept the platform channel so haptics are countable.
      final haptics = <MethodCall>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'HapticFeedback.vibrate') haptics.add(call);
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );

      final festival = fixture(id: 'haptic', name: 'Haptic Festival');
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            allFestivalOccurrencesProvider.overrideWith(
              (ref) => Future.value([(festival: festival, date: null)]),
            ),
            festivalProvider.overrideWithValue([festival]),
            accessibilityProvider.overrideWith(_HapticsNotifier.new),
          ],
          child: const MaterialApp(home: AllFestivalsScreen()),
        ),
      );
      await tester.pumpAndSettle();

      // Act: the row owns the haptic; _showDetails must not add a second.
      await tester.tap(find.text('Haptic Festival'));
      await tester.pump();

      // Assert
      expect(haptics, hasLength(1));
      expect(haptics.single.arguments, 'HapticFeedbackType.lightImpact');
    });
  });
}
