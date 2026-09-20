import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:hive/hive.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:tithi/services/location_service.dart';
import 'package:tithi/services/storage_service.dart';

/// Scripted fake: first [getCurrentPosition] call throws [TimeoutException]
/// (GPS fix never arrives, e.g. indoors), later calls succeed.
class TimeoutThenFixFake extends GeolocatorPlatform
    with MockPlatformInterfaceMixin {
  int currentPositionCalls = 0;
  final List<LocationSettings?> requestedSettings = [];

  @override
  Future<bool> isLocationServiceEnabled() async => true;

  @override
  Future<LocationPermission> checkPermission() async =>
      LocationPermission.whileInUse;

  @override
  Future<Position?> getLastKnownPosition({
    bool forceLocationManager = false,
  }) async => null;

  @override
  Future<Position> getCurrentPosition({
    LocationSettings? locationSettings,
  }) async {
    currentPositionCalls++;
    requestedSettings.add(locationSettings);
    if (currentPositionCalls == 1) {
      throw TimeoutException('GPS fix timed out');
    }
    return Position(
      longitude: 77.2,
      latitude: 28.6,
      timestamp: DateTime.now(),
      accuracy: 20,
      altitude: 0,
      altitudeAccuracy: 1,
      heading: 0,
      headingAccuracy: 1,
      speed: 0,
      speedAccuracy: 1,
    );
  }
}

void main() {
  late GeolocatorPlatform originalPlatform;

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    originalPlatform = GeolocatorPlatform.instance;
    final tempDir = await Directory.systemTemp.createTemp('tithi_loc_test');
    // NominatimGeocoding.init resolves its cache dir via path_provider,
    // which has no platform implementation in unit tests.
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async => tempDir.path);
    Hive.init(tempDir.path);
    await StorageService().init();
  });

  tearDown(() async {
    GeolocatorPlatform.instance = originalPlatform;
    await Hive.close();
  });

  group('LocationService GPS fallback', () {
    test('retries via fused provider after GPS timeout', () async {
      // Arrange
      final fake = TimeoutThenFixFake();
      GeolocatorPlatform.instance = fake;
      final service = LocationService();
      await service.init();

      // Act
      final location = await service.getCurrentLocation();

      // Assert: fused retry succeeded; first attempt used the FOSS
      // LocationManager, the retry did not.
      expect(location, isNotNull);
      expect(location!.latitude, equals(28.6));
      expect(location.longitude, equals(77.2));
      expect(fake.currentPositionCalls, equals(2));
      final first = fake.requestedSettings[0] as AndroidSettings;
      final second = fake.requestedSettings[1] as AndroidSettings;
      expect(first.forceLocationManager, isTrue);
      expect(second.forceLocationManager, isFalse);
    });

    test('no retry when GPS fixes immediately', () async {
      // Arrange: succeed on the first call.
      final fake = _ImmediateFixFake();
      GeolocatorPlatform.instance = fake;
      final service = LocationService();
      await service.init();

      // Act
      final location = await service.getCurrentLocation();

      // Assert
      expect(location, isNotNull);
      expect(fake.currentPositionCalls, equals(1));
    });
  });
}

class _ImmediateFixFake extends TimeoutThenFixFake {
  @override
  Future<Position> getCurrentPosition({
    LocationSettings? locationSettings,
  }) async {
    currentPositionCalls++;
    requestedSettings.add(locationSettings);
    return Position(
      longitude: 77.2,
      latitude: 28.6,
      timestamp: DateTime.now(),
      accuracy: 20,
      altitude: 0,
      altitudeAccuracy: 1,
      heading: 0,
      headingAccuracy: 1,
      speed: 0,
      speedAccuracy: 1,
    );
  }
}
