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
import 'package:tithi/widgets/daily_quote_widget.dart';

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
    final locationService = LocationService();
    await locationService.init();

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

    // Build the app overriding FFI/computation heavy providers
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
        ],
        child: const TithiApp(),
      ),
    );

    // Let the FutureProviders settle and trigger state updates
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();

    // Verify the app title is present
    expect(find.text('Tithi'), findsOneWidget);
  });
}
