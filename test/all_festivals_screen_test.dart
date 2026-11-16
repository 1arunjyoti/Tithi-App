import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
import 'package:tithi/core/navigation/home_tab.dart';
import 'package:tithi/features/countdown/domain/target_resolution.dart'
    show collectRecurringOccurrences;
import 'package:tithi/models/festival.dart';
import 'package:tithi/models/festival_region.dart';
import 'package:tithi/providers/accessibility_provider.dart';
import 'package:tithi/providers/festival_provider.dart';
import 'package:tithi/screens/all_festivals_screen.dart';
import 'package:tithi/services/storage_service.dart';
import 'package:tithi/widgets/major_festival_card.dart';
import 'package:tithi/widgets/festival_row_tile.dart';
import 'package:tithi/widgets/festival_filter_chip.dart';

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
    bool featured = false,
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
    featuredFlag: featured,
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

  /// Finder for a category chip inside the open filter sheet.
  ///
  /// The labels also exist on the screen's inline strip behind the sheet, so
  /// every sheet interaction has to be scoped to the modal.
  Finder sheetCategoryChip(String label) => find.descendant(
    of: find.byType(BottomSheet),
    matching: find.widgetWithText(FestivalFilterChip, label),
  );

  /// Finder for one chip on the inline strip under the search field.
  Finder stripCategoryChip(String label) => find.descendant(
    of: find.byKey(AllFestivalsScreen.categoryChipsKey),
    matching: find.widgetWithText(FestivalFilterChip, label),
  );

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
      await tester.tap(
        find.descendant(
          of: find.byType(BottomSheet),
          matching: find.text('Reset'),
        ),
      );
      await tester.pumpAndSettle();
    }
    if (category != null) {
      await tester.tap(sheetCategoryChip(category));
      await tester.pumpAndSettle();
    }
    if (region != null) {
      await tester.tap(
        find.descendant(
          of: find.byType(BottomSheet),
          matching: find.text(region),
        ),
      );
      await tester.pumpAndSettle();
    }
    await tester.tap(
      find.descendant(
        of: find.byType(BottomSheet),
        matching: find.text('Done'),
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

    test('featured reads the curated flag, independent of category', () {
      // Arrange: a featured vrat and an ordinary major. `featured` is an
      // editorial flag, so it must not be confused with `category: 'major'`
      // (96 of the catalog's 110 records) or with recurrence.
      final featuredVrat = fixture(
        id: 'fv',
        name: 'Featured Vrat',
        category: 'vrat',
        featured: true,
      );
      final ordinaryMajor = fixture(id: 'om', name: 'Ordinary Major');

      // Assert
      expect(
        festivalMatchesCategoryFilter(
          featuredVrat,
          FestivalCategoryFilter.featured,
        ),
        isTrue,
      );
      expect(
        festivalMatchesCategoryFilter(
          ordinaryMajor,
          FestivalCategoryFilter.featured,
        ),
        isFalse,
      );
      // Featured is orthogonal: the vrat still matches its own categories.
      expect(
        festivalMatchesCategoryFilter(
          featuredVrat,
          FestivalCategoryFilter.vrat,
        ),
        isTrue,
      );
      expect(
        festivalMatchesCategoryFilter(
          featuredVrat,
          FestivalCategoryFilter.major,
        ),
        isFalse,
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
      final soon = fixture(id: 'soon', name: 'Soon Festival', category: 'vrat');
      final later = fixture(
        id: 'later',
        name: 'Later Festival',
        category: 'vrat',
      );
      final now = fixture(id: 'now', name: 'Now Festival', category: 'vrat');
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

    testWidgets('features the curated flag, not every major', (tester) async {
      // Arrange: a flagship major, an ordinary major and a vrat, deliberately
      // out of order (the flagship is the furthest away).
      final today = todayOnly();
      final flagship = fixture(
        id: 'flagship',
        name: 'Flagship Major',
        featured: true,
      );
      final ordinary = fixture(id: 'ordinary', name: 'Ordinary Major');
      final vrat = fixture(id: 'vrat', name: 'Some Vrat', category: 'vrat');
      await pumpScreen(
        tester,
        occurrences: sortDatedFestivals([
          (festival: ordinary, date: today.add(const Duration(days: 2))),
          (festival: vrat, date: today.add(const Duration(days: 3))),
          (festival: flagship, date: today.add(const Duration(days: 5))),
        ]),
      );

      // Assert: one card, and it is the featured entry. `category: 'major'`
      // covers 96 of the catalog's 110 festivals, so it cannot decide this,
      // and "next from today" would have featured Ordinary Major instead.
      expect(find.byType(MajorFestivalCard), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(MajorFestivalCard),
          matching: find.text('Flagship Major'),
        ),
        findsOneWidget,
      );
      expect(find.byType(FestivalRowTile), findsNWidgets(2));
      expect(
        find.descendant(
          of: find.byType(FestivalRowTile),
          matching: find.text('Ordinary Major'),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('features a flagship regardless of its date', (tester) async {
      // Arrange: both entries are in the past, so the list does not scroll
      // and the old "next major from today" rule had nothing left to feature.
      final today = todayOnly();
      final pastFlagship = fixture(
        id: 'past_flagship',
        name: 'Past Flagship',
        featured: true,
      );
      final pastMajor = fixture(id: 'past_major', name: 'Past Major');
      await pumpScreen(
        tester,
        occurrences: sortDatedFestivals([
          (
            festival: pastFlagship,
            date: today.subtract(const Duration(days: 3)),
          ),
          (festival: pastMajor, date: today.subtract(const Duration(days: 2))),
        ]),
      );

      // Assert: importance is a property of the festival, not of the calendar.
      // Durga Puja's first days would otherwise lose the card as soon as the
      // list moved past them.
      expect(find.byType(MajorFestivalCard), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(MajorFestivalCard),
          matching: find.text('Past Flagship'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(FestivalRowTile),
          matching: find.text('Past Major'),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('filter sheet narrows by category and composes with search', (
      tester,
    ) async {
      // Arrange: one festival per category, dated in order.
      final today = todayOnly();
      // Featured so the composed list still renders the card; this test is
      // about the filters, not about which entry earns the card.
      final major = fixture(id: 'alpha', name: 'Alpha Major', featured: true);
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
      expect(find.byType(MajorFestivalCard), findsOneWidget);
      // The other categories keep the compact row.
      expect(find.byType(FestivalRowTile), findsNWidgets(2));
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

    testWidgets('category chips sit under the search field and start on All', (
      tester,
    ) async {
      // Arrange
      final today = todayOnly();
      await pumpScreen(
        tester,
        occurrences: [
          (festival: fixture(id: 'a', name: 'Alpha Puja'), date: today),
        ],
      );

      // Assert: the strip is the search field's sibling, directly below it.
      final strip = find.byKey(AllFestivalsScreen.categoryChipsKey);
      expect(strip, findsOneWidget);
      expect(
        tester.getTopLeft(strip).dy,
        greaterThanOrEqualTo(tester.getBottomLeft(find.byType(TextField)).dy),
      );

      // Every category filter, in enum order, including the curated Featured.
      const labels = ['All', 'Major', 'Vrat', 'Recurring', 'Featured'];
      for (final label in labels) {
        expect(
          find.descendant(of: strip, matching: find.text(label)),
          findsOneWidget,
        );
      }

      // Default state: All is selected, nothing is narrowed.
      expect(
        tester.widget<FestivalFilterChip>(stripCategoryChip('All')).selected,
        isTrue,
      );
      for (final label in labels.skip(1)) {
        expect(
          tester.widget<FestivalFilterChip>(stripCategoryChip(label)).selected,
          isFalse,
        );
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('Featured chip narrows to the curated flagships', (
      tester,
    ) async {
      // Arrange: two curated flagships (one a vrat, to prove the flag is not
      // `category: 'major'`) and one ordinary major.
      final today = todayOnly();
      final flagship = fixture(
        id: 'flagship',
        name: 'Flagship Major',
        featured: true,
      );
      final flagshipVrat = fixture(
        id: 'flagship_vrat',
        name: 'Featured Vrat',
        category: 'vrat',
        featured: true,
      );
      final ordinary = fixture(id: 'ordinary', name: 'Ordinary Major');
      await pumpScreen(
        tester,
        occurrences: sortDatedFestivals([
          (festival: ordinary, date: today),
          (festival: flagship, date: today.add(const Duration(days: 1))),
          (festival: flagshipVrat, date: today.add(const Duration(days: 2))),
        ]),
      );

      // Act
      await tester.tap(stripCategoryChip('Featured'));
      await tester.pumpAndSettle();

      // Assert: only the flagged entries remain, both as the large card.
      expect(
        tester
            .widget<FestivalFilterChip>(stripCategoryChip('Featured'))
            .selected,
        isTrue,
      );
      expect(find.text('Ordinary Major'), findsNothing);
      expect(find.text('Flagship Major'), findsOneWidget);
      expect(find.text('Featured Vrat'), findsOneWidget);
      expect(find.byType(MajorFestivalCard), findsNWidgets(2));
      expect(find.byType(FestivalRowTile), findsNothing);
      expect(tester.widget<Badge>(find.byType(Badge)).isLabelVisible, isTrue);
      expect(tester.takeException(), isNull);
    });

    testWidgets('inline chip and filter sheet share one selection', (
      tester,
    ) async {
      // Arrange
      final today = todayOnly();
      await pumpScreen(
        tester,
        occurrences: sortDatedFestivals([
          (festival: fixture(id: 'a', name: 'Alpha Major'), date: today),
          (
            festival: fixture(
              id: 'b',
              name: 'Beta Recurring',
              category: 'recurring',
              recurring: true,
            ),
            date: today.add(const Duration(days: 1)),
          ),
        ]),
      );

      // Chip -> sheet: opening the sheet shows the strip's choice staged.
      await tester.tap(stripCategoryChip('Recurring'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.tune_rounded));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<FestivalFilterChip>(sheetCategoryChip('Recurring'))
            .selected,
        isTrue,
      );
      expect(
        tester.widget<FestivalFilterChip>(sheetCategoryChip('All')).selected,
        isFalse,
      );

      // Sheet -> chip: applying Major in the sheet moves the strip's tint.
      await tester.tap(sheetCategoryChip('Major'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(BottomSheet),
          matching: find.text('Done'),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester.widget<FestivalFilterChip>(stripCategoryChip('Major')).selected,
        isTrue,
      );
      expect(
        tester
            .widget<FestivalFilterChip>(stripCategoryChip('Recurring'))
            .selected,
        isFalse,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('a region picked in the sheet survives a chip tap', (
      tester,
    ) async {
      // Arrange: one pan-India major plus a vrat rooted in each of two zones.
      final today = todayOnly();
      final panMajor = fixture(id: 'pan', name: 'Pan Major');
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
          (festival: panMajor, date: today),
          (festival: southVrat, date: today.add(const Duration(days: 1))),
          (festival: northVrat, date: today.add(const Duration(days: 2))),
        ]),
      );

      // Act: narrow by region in the sheet, then by category on the strip.
      await applyFilters(tester, region: 'South India');
      expect(find.text('North Vrat'), findsNothing);
      await tester.tap(stripCategoryChip('Vrat'));
      await tester.pumpAndSettle();

      // Assert: the chip only changed the category, so the region still bites.
      expect(find.text('South Vrat'), findsOneWidget);
      expect(find.text('North Vrat'), findsNothing);
      expect(find.text('Pan Major'), findsNothing);
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

      final festival = fixture(
        id: 'haptic',
        name: 'Haptic Festival',
        category: 'vrat',
      );
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

  group('drawer', () {
    /// Hosts the tab the way `HomeShell` does: with the tab-switch callback
    /// that also tells the screen it may own a drawer.
    Future<void> pumpHosted(
      WidgetTester tester, {
      ValueChanged<HomeTab>? onSelectTab,
      List<String>? drawerStates,
    }) async {
      final today = todayOnly();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            allFestivalOccurrencesProvider.overrideWith(
              (ref) => Future.value([
                (festival: fixture(id: 'row', name: 'A Festival'), date: today),
              ]),
            ),
            accessibilityProvider.overrideWith(_NoHapticsNotifier.new),
          ],
          child: MaterialApp(
            // The drawer header's icon + two text lines is wider than 280dp in
            // the square test font (Ahem) and would overflow there only.
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(0.8)),
              child: child!,
            ),
            home: AllFestivalsScreen(
              onSelectTab: onSelectTab,
              onDrawerStateChanged: (open) => drawerStates?.add('$open'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('hosted as a tab it opens the drawer from its own app bar', (
      tester,
    ) async {
      // Arrange
      final reported = <String>[];
      await pumpHosted(tester, onSelectTab: (_) {}, drawerStates: reported);

      // Assert: the tab has its own hamburger instead of Today's...
      expect(find.byIcon(Icons.menu_rounded), findsOneWidget);

      // Act
      await tester.tap(find.byIcon(Icons.menu_rounded));
      await tester.pumpAndSettle();

      // Assert: ...and it opens this tab's drawer (a hamburger with no drawer
      // would assert on tap), reporting it so the shell can hide the capsule.
      final scaffold = tester.state<ScaffoldState>(find.byType(Scaffold));
      expect(scaffold.isDrawerOpen, isTrue);
      expect(reported, contains('true'));
      expect(tester.takeException(), isNull);
    });

    testWidgets('pushed as a full page it keeps the back slot, no hamburger', (
      tester,
    ) async {
      // Arrange / Act: no shell, so no drawer to open.
      await pumpHosted(tester);

      // Assert
      expect(find.byIcon(Icons.menu_rounded), findsNothing);
      expect(
        tester.state<ScaffoldState>(find.byType(Scaffold)).hasDrawer,
        isFalse,
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('re-tap to top', () {
    testWidgets('the reveal counter returns the list to its first row', (
      tester,
    ) async {
      // Arrange: more rows than fit on screen, scrolled down.
      final today = todayOnly();
      final occurrences = List.generate(
        12,
        (i) => (
          festival: fixture(id: 'f$i', name: 'Festival $i', category: 'vrat'),
          date: today.add(Duration(days: i)),
        ),
      );
      await pumpScreen(tester, occurrences: occurrences);
      expect(find.text('Festival 0'), findsOneWidget);

      await tester.drag(
        find.byType(FestivalRowTile).first,
        const Offset(0, -600),
      );
      await tester.pumpAndSettle();
      expect(find.text('Festival 0'), findsNothing);

      // Act: the shell reports a tap on the already-selected Festivals
      // destination. The tab cannot be scrolled from outside - the list owns
      // its offset - so it watches the counter instead.
      final container = ProviderScope.containerOf(
        tester.element(find.byType(AllFestivalsScreen)),
        listen: false,
      );
      container.read(tabRevealProvider(HomeTab.festivals).notifier).state++;
      await tester.pumpAndSettle();

      // Assert: back at the top (asserted by content: the package re-anchors
      // its layout instead of moving the scroll offset).
      expect(find.text('Festival 0'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
