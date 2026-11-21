import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:tithi/features/countdown/providers/countdown_providers.dart';
import 'package:tithi/models/festival.dart';
import 'package:tithi/models/hindu_month_system.dart';
import 'package:tithi/models/panchang_school.dart';
import 'package:tithi/providers/calendar_provider.dart';
import 'package:tithi/providers/locale_provider.dart';
import 'package:tithi/providers/primary_date_label_provider.dart';
import 'package:tithi/services/bengali_calendar/bengali_calendar_data.dart';
import 'package:tithi/services/bengali_calendar_service.dart';
import 'package:tithi/services/hindu_calendar_service.dart';
import 'package:tithi/services/panchang/ephemeris/panchang_ephemeris.dart';
import 'package:tithi/services/storage_service.dart';
import 'package:tithi/widgets/festival_countdown_card.dart';
import 'package:tithi/widgets/festival_row_tile.dart';

typedef _HinduDate = ({
  int tithi,
  int fullTithi,
  String paksha,
  String masa,
  int vsYear,
  int shakaYear,
});

class _FakeHinduCalendarService extends HinduCalendarService {
  _FakeHinduCalendarService(super.ref, this.result);

  final _HinduDate? result;

  @override
  Future<_HinduDate> calculateDate(DateTime date) async => result!;
}

class _FakeBengaliCalendarService extends BengaliCalendarService {
  _FakeBengaliCalendarService(super.ref, super.ephemeris, this.result);

  final BengaliCalendarDate? result;

  @override
  Future<BengaliCalendarDate> calculateDate(
    DateTime date, {
    double latitude = 22.5726,
    double longitude = 88.3639,
  }) async => result!;
}

class _LocaleNotifier extends LocaleNotifier {
  _LocaleNotifier(this.value);

  final Locale value;

  @override
  Locale? build() => value;
}

class _TodayNotifier extends TodayDateNotifier {
  _TodayNotifier(this.value);

  final DateTime value;

  @override
  DateTime build() => value;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final date = DateTime(2026, 10, 5);

  ProviderContainer containerFor({
    required AppCalendarSystem system,
    Locale locale = const Locale('en'),
    _HinduDate? hindu,
    BengaliCalendarDate? bengali,
  }) {
    return ProviderContainer(
      overrides: [
        primaryCalendarSystemProvider.overrideWithValue(system),
        localeProvider.overrideWith(() => _LocaleNotifier(locale)),
        panchangSchoolProvider.overrideWithValue(PanchangSchool.bisuddha),
        hinduMonthSystemProvider.overrideWithValue(HinduMonthSystem.amanta),
        hinduCalendarServiceProvider.overrideWith(
          (ref) => _FakeHinduCalendarService(ref, hindu),
        ),
        bengaliCalendarServiceProvider.overrideWith(
          (ref) => _FakeBengaliCalendarService(
            ref,
            ephemerisFor(PanchangSchool.bisuddha),
            bengali,
          ),
        ),
      ],
    );
  }

  group('primaryCalendarDatePartProvider', () {
    test('Gregorian primary keeps the caller pattern', () async {
      final container = containerFor(system: AppCalendarSystem.gregorian);
      addTearDown(container.dispose);

      final label = await container.read(
        primaryCalendarDatePartProvider(
          (date: date, gregorianPattern: 'd MMM', locale: 'en'),
        ).future,
      );

      expect(label, '5 Oct');
    });

    test('none falls back to the Gregorian pattern', () async {
      final container = containerFor(system: AppCalendarSystem.none);
      addTearDown(container.dispose);

      final label = await container.read(
        primaryCalendarDatePartProvider(
          (date: date, gregorianPattern: 'd MMM', locale: 'en'),
        ).future,
      );

      expect(label, '5 Oct');
    });

    test('Hindu primary shows localized masa + paksha tithi', () async {
      final container = containerFor(
        system: AppCalendarSystem.hindu,
        hindu: (
          tithi: 11,
          fullTithi: 11,
          paksha: 'Shukla',
          masa: 'Kartika',
          vsYear: 2083,
          shakaYear: 1948,
        ),
      );
      addTearDown(container.dispose);

      final label = await container.read(
        primaryCalendarDatePartProvider(
          (date: date, gregorianPattern: 'd MMM', locale: 'en'),
        ).future,
      );

      expect(label, 'Kartika Shukla Ekadashi');
    });

    test('Bengali primary shows the Bengali date', () async {
      final container = containerFor(
        system: AppCalendarSystem.bengali,
        bengali: (day: 18, month: 'Ashshin', year: 1433),
      );
      addTearDown(container.dispose);

      final label = await container.read(
        primaryCalendarDatePartProvider(
          (date: date, gregorianPattern: 'd MMM', locale: 'en'),
        ).future,
      );

      expect(label, '18 Ashshin 1433');
    });

    test('Bengali primary uses Bengali script under the bn app language',
        () async {
      final container = containerFor(
        system: AppCalendarSystem.bengali,
        locale: const Locale('bn'),
        bengali: (day: 18, month: 'Ashshin', year: 1433),
      );
      addTearDown(container.dispose);

      final label = await container.read(
        primaryCalendarDatePartProvider(
          (date: date, gregorianPattern: 'd MMM', locale: 'bn'),
        ).future,
      );

      expect(label, contains('১৮'));
      expect(label, isNot(contains('18')));
    });

    test('a failed calendar lookup falls back to Gregorian', () async {
      final container = containerFor(system: AppCalendarSystem.hindu);
      addTearDown(container.dispose);

      final label = await container.read(
        primaryCalendarDatePartProvider(
          (date: date, gregorianPattern: 'd MMM', locale: 'en'),
        ).future,
      );

      expect(label, '5 Oct');
    });
  });

  group('festival list rows', () {
    setUp(() async {
      final tempDir = await Directory.systemTemp.createTemp(
        'tithi_primary_date_test',
      );
      Hive.init(tempDir.path);
      await StorageService().init();
    });

    tearDown(() async {
      await Hive.close();
    });

    Festival fixture() => const Festival(
      id: 'test',
      name: 'Test Festival',
      category: 'major',
      nameRegional: NameRegional(nameEnglish: 'Test'),
      visuals: Visuals(),
      purpose: Purpose(description: 'A test festival'),
      panchangRules: PanchangRules(
        masa: '',
        paksha: 'Shukla',
        tithi: 11,
        conditions: '',
      ),
      rituals: Rituals(steps: []),
      media: Media(),
    );

    testWidgets('FestivalRowTile shows the primary-calendar date', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            todayDateProvider.overrideWith(
              () => _TodayNotifier(DateTime(2026, 9)),
            ),
            primaryCalendarDatePartProvider.overrideWith(
              (ref, arg) => Future.value('18 Ashshin 1433'),
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: FestivalRowTile(festival: fixture(), date: date),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Mon, 18 Ashshin 1433'), findsOneWidget);
      expect(find.text('Mon, 5 Oct'), findsNothing);
    });

    testWidgets('Gregorian rows keep their existing date line', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            todayDateProvider.overrideWith(
              () => _TodayNotifier(DateTime(2026, 9)),
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: FestivalRowTile(festival: fixture(), date: date),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Mon, 5 Oct'), findsOneWidget);
    });

    testWidgets('countdown tile shows the primary-calendar date', (tester) async {
      final target = FestivalCountdownTarget(
        id: 'test',
        title: 'Test Festival',
        festival: fixture(),
        date: date,
        daysRemaining: 12,
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            primaryCalendarDatePartProvider.overrideWith(
              (ref, arg) => Future.value('18 Ashshin 1433'),
            ),
          ],
          child: MaterialApp(
            home: Scaffold(body: FestivalCountdownTile(target: target)),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Mon, 18 Ashshin 1433'), findsOneWidget);
      expect(find.text('Mon, Oct 5'), findsNothing);
    });
  });
}
