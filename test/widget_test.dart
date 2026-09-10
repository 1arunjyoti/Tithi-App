import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:tithi/main.dart';
import 'package:tithi/services/storage_service.dart';
import 'package:tithi/models/festival.dart';
import 'package:tithi/models/sankalpa.dart';
import 'package:tithi/providers/location_provider.dart';
import 'package:tithi/providers/festival_provider.dart';
import 'package:tithi/services/location_service.dart';
import 'package:tithi/models/panchang_data.dart';
import 'package:tithi/providers/panchang_provider.dart';
import 'package:tithi/providers/festival_countdown_provider.dart';
import 'package:tithi/providers/moon_phase_provider.dart';
import 'package:tithi/providers/home_widget_provider.dart';
import 'package:tithi/services/moon_phase_service.dart';
import 'package:tithi/widgets/daily_quote_widget.dart';

/// LocationService without native dependencies (GetStorage/Geolocator).
/// The real init() never completes under flutter_test's FakeAsync clock and
/// throws MissingPluginException on real async — both fatal to this test.
class _FakeLocationService extends LocationService {
  @override
  Future<bool> isFirstLaunch() async => false;

  @override
  Future<bool> isLocationEnabled() async => false;

  @override
  Future<void> markFirstLaunchComplete() async {}

  @override
  Future<void> setLocationEnabled(bool enabled) async {}

  @override
  Future<void> markAppBackgrounded() async {}

  @override
  Future<LocationData?> getCurrentLocation() async =>
      LocationData.defaultLocation;
}

void main() {
  setUp(() async {
    final tempDir = await Directory.systemTemp.createTemp('tithi_test');
    Hive.init(tempDir.path);
    
    // Register Hive adapters before opening boxes
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

    // Put mock location preferences in Hive to avoid permission dialogs and Geolocator calls
    final locationBox = Hive.box(StorageService.locationSettingsBoxName);
    await locationBox.put('first_launch', false);
    await locationBox.put('location_enabled', false);
  });

  tearDown(() async {
    await Hive.close();
  });

  testWidgets('App renders correctly', (WidgetTester tester) async {
    final locationService = _FakeLocationService();

    final mockDate = DateTime.now();
    final normalizedMockDate = DateTime(mockDate.year, mockDate.month, mockDate.day);
    final mockPanchang = PanchangData(
      date: normalizedMockDate,
      rawTithi: 1.0,
      tithiNumber: 1,
      tithiName: 'Pratipada',
      paksha: 'Shukla',
      masa: 'Chaitra',
      sunrise: normalizedMockDate,
      sunset: normalizedMockDate,
    );
    final mockMonthlyPanchang = {
      normalizedMockDate: mockPanchang,
    };
    // Moon countdown widget shows an indeterminate spinner while loading;
    // the real service needs native ephemeris (FFI) unavailable in tests.
    final mockMoonPhase = MoonPhaseData(
      nextAmavasya: normalizedMockDate.add(const Duration(days: 10)),
      nextPurnima: normalizedMockDate.add(const Duration(days: 3)),
      currentTithi: 8.0,
      isShukla: true,
    );

    // Build the app overriding FFI/computation heavy providers.
    // Bounded pumps instead of pumpAndSettle below: any provider backed by
    // native code can leave a loading spinner mounted forever under
    // flutter_test, and pumpAndSettle would never return on its frames.
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          locationServiceProvider.overrideWithValue(locationService),
          locationInitProvider.overrideWith((ref) => Future.value()),
          locationEnabledProvider.overrideWith((ref) => Future.value(false)),
          isFirstLaunchProvider.overrideWith((ref) => Future.value(false)),
          currentLocationProvider.overrideWith((ref) => Future.value(LocationData.defaultLocation)),
          festivalInitProvider.overrideWith((ref) => Future.value()),
          todayPanchangProvider.overrideWith((ref) => Future.value(mockPanchang)),
          panchangForDateProvider.overrideWith((ref, date) => Future.value(mockPanchang)),
          monthlyPanchangProvider.overrideWith((ref, focusedMonth) => Future.value(mockMonthlyPanchang)),
          homeFestivalCountdownTargetsProvider.overrideWith((ref) => Future.value([])),
          dailyShlokaProvider.overrideWith((ref) => Future.value()),
          // Native-backed providers that never resolve under flutter_test:
          // Jyotish FFI init (blocks adaptive calendar + countdown targets),
          // moon phase ephemeris (blocks moon countdown spinner),
          // home-screen widget platform channels.
          panchangInitProvider.overrideWith((ref) => Future.value()),
          moonPhaseDataProvider.overrideWith((ref) => Future.value(mockMoonPhase)),
          homeWidgetSupportedProvider.overrideWith((ref) => Future.value(false)),
          homeWidgetPinSupportProvider.overrideWith((ref) => Future.value(false)),
        ],
        child: const TithiApp(),
      ),
    );
    await tester.pump();
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    // Verify the app title is present
    expect(find.text('Tithi'), findsOneWidget);
  });
}
