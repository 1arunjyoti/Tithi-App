import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:tithi/models/festival.dart';
import 'package:tithi/models/panchang_data.dart';
import 'package:tithi/providers/accessibility_provider.dart';
import 'package:tithi/providers/calendar_provider.dart';
import 'package:tithi/providers/festival_provider.dart';
import 'package:tithi/providers/panchang_provider.dart';
import 'package:tithi/screens/all_festivals_screen.dart';
import 'package:tithi/services/storage_service.dart';
import 'package:tithi/widgets/event_detail_sheet.dart';
import 'package:tithi/widgets/event_list_widget.dart';

class _NoHapticsNotifier extends AccessibilityNotifier {
  @override
  AccessibilityState build() =>
      const AccessibilityState(hapticFeedback: false);
}

class _FixedDateNotifier extends SelectedDateNotifier {
  @override
  DateTime build() => DateTime(2026, 9, 14);
}

void main() {
  setUp(() async {
    final tempDir = await Directory.systemTemp.createTemp('tithi_fest_test');
    Hive.init(tempDir.path);
    await StorageService().init();
  });

  tearDown(() async {
    await Hive.close();
  });

  Festival fixture({
    required String id,
    required String name,
    String category = 'major',
    String description = 'A test festival description',
  }) => Festival(
    id: id,
    name: name,
    category: category,
    nameRegional: const NameRegional(nameEnglish: 'Test'),
    visuals: const Visuals(),
    purpose: Purpose(description: description),
    panchangRules: const PanchangRules(
      masa: '',
      paksha: 'Shukla',
      tithi: 4,
      conditions: '',
    ),
    rituals: const Rituals(steps: []),
    media: const Media(),
  );

  PanchangData dayData({
    required DateTime date,
    required List<Festival> festivals,
    String tithiName = 'Chaturthi',
    int tithiNumber = 4,
  }) => PanchangData(
    date: date,
    rawTithi: tithiNumber + 0.5,
    tithiNumber: tithiNumber,
    tithiName: tithiName,
    paksha: 'Shukla',
    masa: 'Bhadrapada',
    festivals: festivals,
    sunrise: DateTime(date.year, date.month, date.day, 5, 39),
    sunset: DateTime(date.year, date.month, date.day, 18, 12),
  );

  final festA = fixture(id: 'a', name: 'Balarama Jayanti');
  final festB = fixture(
    id: 'b',
    name: 'Vishwakarma Puja',
    category: 'vrat',
    description: 'Dedicated to Lord Vishwakarma',
  );
  final festC = fixture(id: 'c', name: 'Distant Festival');

  Future<void> pumpCard(
    WidgetTester tester, {
    required Map<DateTime, PanchangData> days,
    required List<Festival> all,
    List<Override> extraOverrides = const [],
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          selectedDateProvider.overrideWith(_FixedDateNotifier.new),
          ...extraOverrides,
          panchangForDateProvider.overrideWith(
            (ref, date) => Future.value(
              days[DateTime(date.year, date.month, date.day)] ??
                  dayData(date: date, festivals: const []),
            ),
          ),
          festivalProvider.overrideWithValue(all),
          accessibilityProvider.overrideWith(_NoHapticsNotifier.new),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(child: EventListWidget()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('Festivals home card', () {
    testWidgets('selected day first, then upcoming with countdown suffix', (
      tester,
    ) async {
      // Arrange: festival on the selected day + one two days later.
      await pumpCard(
        tester,
        days: {
          DateTime(2026, 9, 14): dayData(
            date: DateTime(2026, 9, 14),
            festivals: [festA],
          ),
          DateTime(2026, 9, 16): dayData(
            date: DateTime(2026, 9, 16),
            festivals: [festB],
            tithiName: 'Shashthi',
            tithiNumber: 6,
          ),
        },
        all: [festA, festB, festC],
      );

      // Assert: order + gold date lines. Rows dated today show the "Today"
      // label (no date, no countdown suffix); other rows keep the formatted
      // date. The tithi half uses the waxing/waning word + localized tithi
      // name (matching FestivalRowTile), not the paksha name. Fixture dates
      // are fixed, so resolve against the real today to stay hermetic
      // whatever day the suite runs.
      final now = DateTime.now();
      bool isRealToday(DateTime d) =>
          d.year == now.year && d.month == now.month && d.day == now.day;
      final dyA = tester.getCenter(find.text('Balarama Jayanti')).dy;
      final dyB = tester.getCenter(find.text('Vishwakarma Puja')).dy;
      expect(dyA, lessThan(dyB));
      expect(
        find.text(
          isRealToday(DateTime(2026, 9, 14))
              ? 'Today · Waxing Chaturthi'
              : 'Mon, 14 Sep · Waxing Chaturthi',
        ),
        findsOneWidget,
      );
      expect(
        find.text(
          isRealToday(DateTime(2026, 9, 16))
              ? 'Today · Waxing Shashthi'
              : 'Wed, 16 Sep · Waxing Shashthi · in 2 days',
        ),
        findsOneWidget,
      );
      expect(find.text('View all 3 festivals'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('empty window keeps the view-all button', (tester) async {
      // Arrange: no festivals anywhere in the window.
      await pumpCard(tester, days: const {}, all: const []);

      // Assert
      expect(find.text('No festivals in the next 3 days'), findsOneWidget);
      expect(find.text('View all festivals'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('view-all opens the searchable all-festivals screen', (
      tester,
    ) async {
      // Arrange (occurrences overridden: hermetic, no FFI scans)
      await pumpCard(
        tester,
        days: {
          DateTime(2026, 9, 14): dayData(
            date: DateTime(2026, 9, 14),
            festivals: [festA],
          ),
        },
        all: [festA, festB, festC],
        extraOverrides: [
          allFestivalOccurrencesProvider.overrideWith(
            (ref) => Future.value([
              (festival: festB, date: DateTime(2026, 9, 17)),
              (festival: festA, date: DateTime(2026, 9, 14)),
              (festival: festC, date: null),
            ]),
          ),
        ],
      );

      // Act
      await tester.tap(find.text('View all 3 festivals'));
      await tester.pumpAndSettle();

      // Assert: chronological screen with dates (incl. window-absent C).
      expect(find.byType(AllFestivalsScreen), findsOneWidget);
      expect(find.text('Distant Festival'), findsOneWidget);
      expect(find.textContaining('Mon, 14 Sep'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('tapping a row opens its detail sheet', (tester) async {
      // Arrange
      await pumpCard(
        tester,
        days: {
          DateTime(2026, 9, 14): dayData(
            date: DateTime(2026, 9, 14),
            festivals: [festA],
          ),
        },
        all: [festA],
      );

      // Act (bounded pumps: the sheet hosts an infinite animation,
      // so pumpAndSettle never completes)
      await tester.tap(find.text('Balarama Jayanti'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));

      // Assert
      expect(find.byType(EventDetailSheet), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
