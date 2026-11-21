import 'dart:io';

import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter_localizations/flutter_localizations.dart'
    show GlobalWidgetsLocalizations;
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:tithi/l10n/app_localizations.dart';
import 'package:tithi/models/festival.dart';
import 'package:tithi/models/panchang_data.dart';
import 'package:tithi/models/panchang_school.dart';
import 'package:tithi/models/festival_region.dart';
import 'package:tithi/providers/accessibility_provider.dart';
import 'package:tithi/providers/calendar_provider.dart';
import 'package:tithi/providers/festival_provider.dart';
import 'package:tithi/providers/festival_occurrences_provider.dart';
import 'package:tithi/providers/home_cards_visibility_provider.dart';
import 'package:tithi/providers/home_widget_provider.dart';
import 'package:tithi/providers/panchang_provider.dart';
import 'package:tithi/screens/all_festivals_screen.dart';
import 'package:tithi/screens/home_screen.dart';
import 'package:tithi/screens/home_shell.dart';
import 'package:tithi/services/storage_service.dart';
import 'package:tithi/theme/app_theme.dart';
import 'package:tithi/features/calendar/data/calendar_models.dart';
import 'package:tithi/features/calendar/providers/cell_providers.dart';
import 'package:tithi/widgets/event_list_widget.dart';
import 'package:tithi/features/quote/providers/quote_providers.dart';
import 'package:tithi/features/hero/providers/hero_providers.dart';
import 'package:tithi/features/countdown/providers/countdown_providers.dart';
import 'package:tithi/features/moon/providers/moon_providers.dart';
import 'package:tithi/services/moon_phase_service.dart';

class _NoHapticsNotifier extends AccessibilityNotifier {
  @override
  AccessibilityState build() => const AccessibilityState(hapticFeedback: false);
}

/// The optional home cards are hidden so this test builds only the calendar
/// and the events card; their providers never fire.
class _HiddenWisdomNotifier extends DailyWisdomVisibleNotifier {
  @override
  bool build() => false;
}

class _HiddenCountdownCardNotifier extends FestivalCountdownsVisibleNotifier {
  @override
  bool build() => false;
}

/// One catalog entry, so the home card renders a real "View all" button.
Festival _festival() => const Festival(
  id: 'shell_row',
  name: 'Shell Row Festival',
  category: 'major',
  nameRegional: NameRegional(nameEnglish: 'Test'),
  visuals: Visuals(),
  purpose: Purpose(description: 'A test festival description'),
  panchangRules: PanchangRules(
    masa: '',
    paksha: 'Shukla',
    tithi: 4,
    conditions: '',
  ),
  rituals: Rituals(steps: []),
  media: Media(),
);

PanchangData _panchang(DateTime date) => PanchangData(
  date: date,
  rawTithi: 4.5,
  tithiNumber: 4,
  tithiName: 'Chaturthi',
  paksha: 'Shukla',
  masa: 'Chaitra',
  sunrise: DateTime(date.year, date.month, date.day, 6),
  sunset: DateTime(date.year, date.month, date.day, 18),
);

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('tithi_home_shell');
    Hive.init(tempDir.path);
    await StorageService().init();
  });

  tearDown(() async {
    try {
      await Hive.close().timeout(const Duration(seconds: 10));
    } catch (_) {}
  });

  /// Pumps the real [HomeShell] on a phone-sized surface with every
  /// native-backed provider stubbed, the way the app runs on first launch.
  Future<void> pumpShell(WidgetTester tester) async {
    tester.view.physicalSize = const Size(420, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final panchang = _panchang(today);
    final festival = _festival();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          festivalProvider.overrideWithValue([festival]),
          festivalRegionProvider.overrideWithValue(FestivalRegion.all),
          panchangSchoolProvider.overrideWithValue(PanchangSchool.bisuddha),
          accessibilityProvider.overrideWith(_NoHapticsNotifier.new),
          dailyWisdomVisibleProvider.overrideWith(_HiddenWisdomNotifier.new),
          festivalCountdownsVisibleProvider.overrideWith(
            _HiddenCountdownCardNotifier.new,
          ),
          // Native FFI / MethodChannel providers never resolve here, so they
          // are stubbed to keep each card out of its loading state.
          panchangInitProvider.overrideWith((ref) => Future.value()),
          todayPanchangProvider.overrideWith((ref) => Future.value(panchang)),
          livePanchangProvider.overrideWith(
            (ref, day) => Future.value(panchang),
          ),
          monthlyPanchangProvider.overrideWith(
            (ref, month) => Future.value({}),
          ),
          panchangForDateProvider.overrideWith(
            (ref, date) => Future.value(panchang),
          ),
          gregorianCalendarCellDataProvider.overrideWith(
            (ref, args) => Future.value(<DateTime, CalendarCellData>{}),
          ),
          dailyShlokaProvider.overrideWith((ref) => Future.value()),
          bengaliDateForHeroProvider.overrideWith(
            (ref, date) => Future.value(),
          ),
          upcomingFestivalsProvider.overrideWith((ref) => Future.value([])),
          homeFestivalCountdownTargetsProvider.overrideWith(
            (ref) => Future.value([]),
          ),
          allFestivalCountdownTargetsProvider.overrideWith(
            (ref) => Future.value([]),
          ),
          moonPhaseDataProvider.overrideWith(
            (ref) => Future.value(
              MoonPhaseData(
                nextAmavasya: today.add(const Duration(days: 10)),
                nextPurnima: today.add(const Duration(days: 3)),
                currentTithi: 4.5,
                isShukla: true,
              ),
            ),
          ),
          homeWidgetSupportedProvider.overrideWith(
            (ref) => Future.value(false),
          ),
          homeWidgetPinSupportProvider.overrideWith(
            (ref) => Future.value(false),
          ),
          homeWidgetSyncProvider.overrideWith((ref) {}),
          panchangWidgetSyncProvider.overrideWith((ref) {}),
          allFestivalOccurrencesProvider.overrideWith(
            (ref, year) => Future.value([(festival: festival, date: today)]),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.shuklaTheme,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: const HomeShell(),
        ),
      ),
    );
    // Bounded pumps: several cards own indefinite animations/spinners, so
    // pumpAndSettle would never return.
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    // Let the calendar's delayed neighbor precache fire: a timer still pending
    // when the tree is disposed fails the test.
    await tester.pump(const Duration(milliseconds: 900));
    await tester.pump(const Duration(milliseconds: 100));
  }

  group('HomeShell tabs', () {
    testWidgets('the Today tab is wired to switch tabs, not push routes', (
      tester,
    ) async {
      // Arrange
      await pumpShell(tester);

      // Assert: the shell hands HomeScreen the tab-switch callback. Without it
      // the card's "View all" silently falls back to pushing a second copy of
      // the Festivals screen over the shell (the pre-shell behavior).
      final home = tester.widget<HomeScreen>(find.byType(HomeScreen));
      expect(home.onSelectTab, isNotNull);
      expect(tester.takeException(), isNull);
    });

    testWidgets('"View all N festivals" switches to the Festivals tab', (
      tester,
    ) async {
      // Arrange
      await pumpShell(tester);
      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      expect(find.byType(AllFestivalsScreen), findsNothing);

      // Act
      expect(find.textContaining('View all'), findsOneWidget);
      await tester.tap(find.textContaining('View all'));
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      // Assert: the Festivals tab is mounted in the shell, no route was pushed,
      // and the shell is still on the first route.
      expect(find.byType(AllFestivalsScreen), findsOneWidget);
      expect(navigator.canPop(), isFalse);
      expect(tester.takeException(), isNull);
    });
  });
}
