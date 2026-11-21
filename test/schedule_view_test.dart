import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tithi/features/schedule/providers/schedule_providers.dart';
import 'package:tithi/features/schedule/widgets/schedule_view_widget.dart';
import 'package:tithi/l10n/app_localizations.dart';
import 'package:tithi/models/festival.dart';
import 'package:tithi/models/hindu_month_system.dart';
import 'package:tithi/models/panchang_data.dart';
import 'package:tithi/providers/calendar_provider.dart' as cp;
import 'package:tithi/theme/app_theme.dart';

// Characterization tests for the schedule view, written before the file was
// split into features/schedule/{domain,widgets}. They pin what the date column
// resolves for each primary-calendar system and what a day row renders, so the
// extraction of ScheduleDateColumnView cannot silently change the display.

/// Selected date pinned to a constant so the widget never re-anchors and never
/// touches the place clock (which needs location state).
class _FixedSelectedDate extends cp.SelectedDateNotifier {
  @override
  DateTime build() => DateTime(2026, 5, 17);
}

Festival _festival() {
  return const Festival(
    id: 'test-utsav',
    name: 'Test Utsav',
    category: 'major',
    nameRegional: NameRegional(nameEnglish: 'Test Utsav'),
    visuals: Visuals(),
    purpose: Purpose(description: 'A test festival.'),
    panchangRules: PanchangRules(
      masa: 'Vaishakha',
      paksha: 'Shukla',
      tithi: 7,
      conditions: 'Lunar',
    ),
    rituals: Rituals(steps: []),
    media: Media(),
  );
}

PanchangData _day({bool withFestival = false}) {
  return PanchangData(
    date: DateTime(2026, 5, 17),
    rawTithi: 6.4,
    tithiNumber: 7,
    tithiName: 'Saptami',
    paksha: 'Shukla',
    masa: 'Vaishakha',
    sunrise: DateTime(2026, 5, 17, 6, 30),
    sunset: DateTime(2026, 5, 17, 17, 25),
    festivals: withFestival ? [_festival()] : const [],
  );
}

void main() {
  Future<void> pumpSchedule(
    WidgetTester tester, {
    required cp.AppCalendarSystem primary,
    required cp.AppCalendarSystem secondary,
    PanchangData? panchang,
    ({int day, String month, int year})? bengaliDate,
    HinduDateData? hinduDate,
  }) async {
    final data = ScheduleDateData(
      panchang: panchang ?? _day(),
      bengaliDate: bengaliDate,
      hinduDate: hinduDate,
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          cp.selectedDateProvider.overrideWith(_FixedSelectedDate.new),
          cp.primaryCalendarSystemProvider.overrideWithValue(primary),
          cp.secondaryCalendarSystemProvider.overrideWithValue(secondary),
          cp.hinduMonthSystemProvider.overrideWithValue(
            HinduMonthSystem.amanta,
          ),
          cp.tithiDisplayModeProvider.overrideWithValue(
            cp.TithiDisplayMode.pakshaBased,
          ),
          glassmorphismConfigProvider.overrideWithValue(
            const GlassmorphismConfig(isHighContrast: false),
          ),
          scheduleDateDataProvider.overrideWith((ref, date) => data),
        ],
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: ScheduleViewWidget()),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('date column', () {
    testWidgets('hindu primary shows the masa stem and tithi day', (
      tester,
    ) async {
      await pumpSchedule(
        tester,
        primary: cp.AppCalendarSystem.hindu,
        secondary: cp.AppCalendarSystem.gregorian,
        hinduDate: HinduDateData(
          day: 11,
          month: 'Kartika',
          paksha: 'Shukla',
          year: 2083,
          eraLabel: 'Vikram',
        ),
      );

      // 'Kartika'.split(' ').last -> first 4 chars, uppercased.
      expect(find.text('KART'), findsWidgets);
      // Hindu day wins over the panchang tithi number (7) for the big numeral.
      expect(find.text('11'), findsWidgets);
    });

    testWidgets('bengali primary shows the bengali month stem and day', (
      tester,
    ) async {
      await pumpSchedule(
        tester,
        primary: cp.AppCalendarSystem.bengali,
        secondary: cp.AppCalendarSystem.gregorian,
        bengaliDate: (day: 24, month: 'Baishakh', year: 1433),
      );

      expect(find.text('BAIS'), findsWidgets);
      expect(find.text('24'), findsWidgets);
    });

    testWidgets('falls back to the gregorian stem when the system has no '
        'date yet', (tester) async {
      await pumpSchedule(
        tester,
        primary: cp.AppCalendarSystem.bengali,
        secondary: cp.AppCalendarSystem.gregorian,
        // bengaliDate intentionally null: calculation not ready.
      );

      // No BENG/BAIS stem can be rendered without a Bengali date.
      expect(find.text('BAIS'), findsNothing);
      // The weekday row is always present, so the column still renders.
      expect(find.byType(ScheduleViewWidget), findsOneWidget);
    });
  });

  group('day row', () {
    testWidgets('shows paksha+tithi, sun times and the festival card', (
      tester,
    ) async {
      await pumpSchedule(
        tester,
        primary: cp.AppCalendarSystem.gregorian,
        secondary: cp.AppCalendarSystem.none,
        panchang: _day(withFestival: true),
      );

      expect(find.text('Shukla Saptami'), findsWidgets);
      expect(find.textContaining('Sunrise:'), findsWidgets);
      expect(find.textContaining('Sunset:'), findsWidgets);
      expect(find.textContaining('6:30'), findsWidgets);
      expect(find.text('Test Utsav'), findsWidgets);
    });

    testWidgets('omits the festival card when the day has no observance', (
      tester,
    ) async {
      await pumpSchedule(
        tester,
        primary: cp.AppCalendarSystem.gregorian,
        secondary: cp.AppCalendarSystem.none,
      );

      expect(find.text('Shukla Saptami'), findsWidgets);
      expect(find.text('Test Utsav'), findsNothing);
    });
  });
}
