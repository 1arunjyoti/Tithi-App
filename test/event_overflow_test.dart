import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:tithi/models/festival.dart';
import 'package:tithi/models/panchang_data.dart';
import 'package:tithi/models/sankalpa.dart';
import 'package:tithi/providers/festival_countdown_provider.dart';
import 'package:tithi/providers/festival_provider.dart';
import 'package:tithi/services/storage_service.dart';
import 'package:tithi/theme/app_theme.dart';
import 'package:tithi/widgets/event_list_widget.dart';
import 'package:tithi/widgets/festival_countdown_card.dart';

// The home card caps rows at upcomingFestivalMaxRows; beyond the cap the
// glance must name what was cut instead of failing silently.
void main() {
  setUp(() async {
    final tempDir = await Directory.systemTemp.createTemp('tithi_overflow');
    Hive.init(tempDir.path);
    try {
      Hive.registerAdapter(FestivalAdapter());
      Hive.registerAdapter(NameRegionalAdapter());
      Hive.registerAdapter(VisualsAdapter());
      Hive.registerAdapter(PurposeAdapter());
      Hive.registerAdapter(PanchangRulesAdapter());
      Hive.registerAdapter(RitualsAdapter());
      Hive.registerAdapter(MediaAdapter());
      Hive.registerAdapter(SankalpaAdapter());
    } catch (_) {
      // Ignore if already registered
    }
    await StorageService().init();
  });

  tearDown(() async {
    try {
      await Hive.close().timeout(const Duration(seconds: 10));
    } catch (_) {}
  });

  Festival fixture(String id, String name) => Festival(
    id: id,
    name: name,
    category: 'major',
    nameRegional: NameRegional(nameEnglish: name),
    visuals: const Visuals(),
    purpose: const Purpose(description: 'Test description'),
    panchangRules: const PanchangRules(
      masa: '',
      paksha: 'Shukla',
      tithi: 1,
      conditions: '',
    ),
    rituals: const Rituals(steps: []),
    media: const Media(),
  );

  PanchangData mockPanchang(DateTime day) => PanchangData(
    date: day,
    rawTithi: 1.0,
    tithiNumber: 1,
    tithiName: 'Pratipada',
    paksha: 'Shukla',
    masa: 'Chaitra',
    sunrise: day,
    sunset: day,
  );

  List<UpcomingFestival> window(int count) {
    final now = DateTime.now();
    final base = DateTime(now.year, now.month, now.day);
    return List.generate(count, (i) {
      final day = base.add(Duration(days: i ~/ 2));
      return (
        date: day,
        festival: fixture('f$i', 'Festival $i'),
        panchang: mockPanchang(day),
        daysAway: i ~/ 2,
      );
    });
  }

  Future<void> pumpCard(
    WidgetTester tester,
    List<UpcomingFestival> items,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          festivalProvider.overrideWith((ref) => const <Festival>[]),
          upcomingFestivalsProvider.overrideWith((ref) => Future.value(items)),
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

  testWidgets('names hidden festivals beyond the row cap', (tester) async {
    await pumpCard(tester, window(6));

    // First 4 render as rows; the cut 2 are named inline.
    expect(find.text('Festival 0'), findsOneWidget);
    expect(find.text('Festival 3'), findsOneWidget);
    expect(find.textContaining('+2 more'), findsOneWidget);
    expect(find.textContaining('Festival 4'), findsOneWidget);
    expect(find.textContaining('Festival 5'), findsOneWidget);
  });

  testWidgets('no overflow line when everything fits', (tester) async {
    await pumpCard(tester, window(3));

    expect(find.text('Festival 0'), findsOneWidget);
    expect(find.textContaining('more:'), findsNothing);
  });

  Future<void> pumpTile(
    WidgetTester tester,
    FestivalCountdownTarget target, {
    ThemeData? theme,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: theme,
          home: Scaffold(
            body: SingleChildScrollView(
              child: FestivalCountdownTile(target: target),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  FestivalCountdownTarget countdownTarget(int daysAway) {
    final now = DateTime.now();
    final base = DateTime(now.year, now.month, now.day);
    final day = base.add(Duration(days: daysAway));
    return FestivalCountdownTarget(
      id: 'holi',
      title: 'Holi',
      festival: fixture('holi', 'Holi'),
      date: day,
      daysRemaining: daysAway,
    );
  }

  testWidgets('today block carries Today, no pill row', (tester) async {
    await pumpTile(tester, countdownTarget(0));

    expect(find.text('Today'), findsOneWidget);
    expect(find.textContaining('days to go'), findsNothing);
    expect(find.text('Holi'), findsOneWidget);
  });

  testWidgets('tomorrow block reads singular day', (tester) async {
    await pumpTile(tester, countdownTarget(1));

    expect(find.text('1'), findsOneWidget);
    expect(find.text('day'), findsOneWidget);
    expect(find.textContaining('days to go'), findsNothing);
  });

  testWidgets('later block reads plural days', (tester) async {
    await pumpTile(tester, countdownTarget(5));

    expect(find.text('5'), findsOneWidget);
    expect(find.text('days'), findsOneWidget);
    expect(find.textContaining('days to go'), findsNothing);
  });

  double channelLuminance(double component) {
    return component <= 0.03928
        ? component / 12.92
        : math.pow((component + 0.055) / 1.055, 2.4) as double;
  }

  double relativeLuminance(Color color) {
    return 0.2126 * channelLuminance(color.r) +
        0.7152 * channelLuminance(color.g) +
        0.0722 * channelLuminance(color.b);
  }

  double contrastRatio(Color a, Color b) {
    final l1 = relativeLuminance(a);
    final l2 = relativeLuminance(b);
    final lighter = l1 > l2 ? l1 : l2;
    final darker = l1 > l2 ? l2 : l1;
    return (lighter + 0.05) / (darker + 0.05);
  }

  Future<void> expectTodayBlockLegible(
    WidgetTester tester, {
    ThemeData? theme,
  }) async {
    await pumpTile(tester, countdownTarget(0), theme: theme);
    final context = tester.element(find.text('Today'));

    // Block is filled with the accent (not the soft tile tint).
    final accent = AppTheme.festivalAccent(context);
    final soft = AppTheme.festivalTileBackground(context);
    final block = tester
        .elementList(find.byType(Container))
        .map((e) => e.widget as Container)
        .map((w) => w.decoration)
        .whereType<BoxDecoration>()
        .firstWhere((d) => d.color == accent || d.color == soft);
    expect(block.color, equals(accent));

    // Ink is the on-accent color (not the accent itself).
    final onAccent = AppTheme.onFestivalAccent(context);
    for (final label in ['0', 'Today']) {
      final text = tester.widget<Text>(find.text(label));
      expect(text.style?.color, equals(onAccent));
    }

    // Large-text contrast floor (WCAG AA 3:1): the big count is large bold
    // type; the pairing is the same fill + ink the old pill used.
    expect(contrastRatio(accent, onAccent), greaterThanOrEqualTo(3.0));
  }

  testWidgets('today block stays legible on gold fill (light)', (
    tester,
  ) async {
    await expectTodayBlockLegible(tester);
  });

  testWidgets('today block stays legible on gold fill (dark)', (
    tester,
  ) async {
    await expectTodayBlockLegible(tester, theme: ThemeData.dark());
  });
}
