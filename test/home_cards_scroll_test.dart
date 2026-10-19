import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:tithi/models/festival.dart';
import 'package:tithi/models/panchang_data.dart';
import 'package:tithi/models/sankalpa.dart';
import 'package:tithi/providers/festival_provider.dart';
import 'package:tithi/providers/panchang_provider.dart';
import 'package:tithi/services/shloka_service.dart';
import 'package:tithi/services/storage_service.dart';
import 'package:tithi/widgets/daily_quote_widget.dart';
import 'package:tithi/widgets/event_list_widget.dart';

// Scroll-remount regression tests for the home-screen cards that stay inside
// the lazy SliverList.builder (see lib/screens/home_screen.dart): scrolling
// a card off-screen disposes its widget AND (without keep-alive) its
// autoDispose data provider. Scrolling back remounts into a loading frame
// (skeleton/shrink) and replays the card's AnimatedSize glide + fades —
// reading as its own slide-down independent of the scroll (the hero-card
// bug, fixed via SliverToBoxAdapter).
//
// Two complementary proofs:
// 1. Widget level (event list): real card in a SliverList.builder, scrolled
//    off and back; the first frame on re-entry must already show content.
// 2. Provider level (both cards): with zero listeners (the disposed state),
//    the provider must still hold data instead of dropping to loading.

void main() {
  setUp(() async {
    final tempDir = await Directory.systemTemp.createTemp('tithi_cards_test');
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
    // Warm the verse singleton here (real time): the quote provider reads
    // the asset via real async I/O. Memoized, so tests reuse it for free.
    TestWidgetsFlutterBinding.ensureInitialized();
    await ShlokaService().init();
  });

  tearDown(() async {
    try {
      await Hive.close().timeout(const Duration(seconds: 10));
    } catch (_) {}
  });

  PanchangData mockPanchang() {
    final now = DateTime.now();
    final day = DateTime(now.year, now.month, now.day);
    return PanchangData(
      date: day,
      rawTithi: 1.0,
      tithiNumber: 1,
      tithiName: 'Pratipada',
      paksha: 'Shukla',
      masa: 'Chaitra',
      sunrise: day,
      sunset: day,
    );
  }

  List<Override> baseOverrides() => [
    festivalInitProvider.overrideWith((ref) => Future.value()),
    festivalProvider.overrideWith((ref) => const <Festival>[]),
    panchangForDateProvider.overrideWith(
      (ref, date) => Future.value(mockPanchang()),
    ),
  ];

  group('provider retention across scroll disposal', () {
    test('dailyShloka survives last-listener removal', () async {
      final container = ProviderContainer(overrides: baseOverrides());
      addTearDown(container.dispose);
      final sub = container.listen(dailyShlokaProvider, (_, _) {});
      final first = await container.read(dailyShlokaProvider.future);
      expect(first, isNotNull);
      // Simulate the scrolled-off state: widget disposed = no listeners.
      sub.close();
      await Future.delayed(const Duration(milliseconds: 100));
      final retained = container.read(dailyShlokaProvider);
      expect(
        retained.hasValue,
        isTrue,
        reason: 'verse must stay cached for instant scroll-back',
      );
    });

    test('upcomingFestivals survives last-listener removal', () async {
      final container = ProviderContainer(overrides: baseOverrides());
      addTearDown(container.dispose);
      final sub = container.listen(upcomingFestivalsProvider, (_, _) {});
      await container.read(upcomingFestivalsProvider.future);
      // Simulate the scrolled-off state: widget disposed = no listeners.
      sub.close();
      await Future.delayed(const Duration(milliseconds: 100));
      final retained = container.read(upcomingFestivalsProvider);
      expect(
        retained.hasValue,
        isTrue,
        reason: 'rows must stay cached for instant scroll-back',
      );
    });
  });

  testWidgets('Event list replays skeleton glide on scroll back', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: baseOverrides(),
        child: MaterialApp(
          home: Scaffold(
            body: CustomScrollView(
              slivers: [
                SliverList.builder(
                  itemCount: 4,
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return const RepaintBoundary(child: EventListWidget());
                    }
                    return Container(height: 700, color: Colors.grey[300]);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Festivals & Events'), findsOneWidget);
    final settled = tester.getSize(find.byType(EventListWidget)).height;

    // Exact jumps (not drags): fling ballistics overshoot differently per
    // card height, so symmetric drags don't reliably restore offset 0.
    final scrollable = tester.state<ScrollableState>(
      find.byType(Scrollable).first,
    );
    scrollable.position.jumpTo(scrollable.position.maxScrollExtent);
    await tester.pumpAndSettle();
    expect(find.byType(EventListWidget), findsNothing);

    scrollable.position.jumpTo(0);
    // The rebuild of item 0 subscribes its provider this frame, so any
    // async gap is still pending: exactly the UI seen on re-entry.
    await tester.pump();
    final reentry = tester.getSize(find.byType(EventListWidget)).height;
    // ignore: avoid_print
    print('EVENTS settled=$settled reentry=$reentry');
    await tester.pumpAndSettle();
    final resettled = tester.getSize(find.byType(EventListWidget)).height;

    expect(resettled, moreOrLessEquals(settled, epsilon: 1.0));
    expect(reentry, moreOrLessEquals(settled, epsilon: 1.0));
  });
}
