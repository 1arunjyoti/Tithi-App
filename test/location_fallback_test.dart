import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
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
    // The place lookup needs the full tzdb: `latest` omits 106 of the zone
    // identifiers the bundled boundaries can return.
    if (!tz.timeZoneDatabase.isInitialized) {
      tz_data.initializeTimeZones();
    }
    // Device zone used when a coordinate has no boundary polygon (or when the
    // lookup is unavailable). A real place coordinate must ignore it.
    const timezoneChannel = MethodChannel('flutter_timezone');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          timezoneChannel,
          (call) async =>
              call.method == 'getLocalTimezone' ? 'Asia/Kolkata' : null,
        );
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

  group('LocationData metadata persistence', () {
    test('GPS fix stores altitude and resolved timezone', () async {
      // Arrange
      final fake = _MountainFixFake();
      GeolocatorPlatform.instance = fake;
      final service = LocationService();
      await service.init();

      // Act
      final location = await service.getCurrentLocation();

      // Assert
      expect(location, isNotNull);
      expect(location!.altitudeMeters, equals(216.0));
      expect(location.timezoneId, equals('Asia/Kolkata'));
    });

    test('home location persists altitude and resolves a zone', () async {
      // Arrange
      final service = LocationService();
      await service.init();

      // Act
      await service.setHomeLocation(
        28.6139,
        77.2090,
        'Delhi',
        altitudeMeters: 216,
      );
      final home = service.getHomeLocation();

      // Assert
      expect(home, isNotNull);
      expect(home!.altitudeMeters, equals(216.0));
      expect(home.timezoneId, equals('Asia/Kolkata'));
    });

    test(
      'home location clears stale altitude when the new pick has none',
      () async {
        // Arrange
        final service = LocationService();
        await service.init();
        await service.setHomeLocation(
          28.6139,
          77.2090,
          'Delhi',
          altitudeMeters: 216,
        );

        // Act: a later pick without elevation must not inherit Delhi's height.
        await service.setHomeLocation(19.0760, 72.8777, 'Mumbai');
        final home = service.getHomeLocation();

        // Assert
        expect(home, isNotNull);
        expect(home!.altitudeMeters, isNull);
        expect(home.timezoneId, equals('Asia/Kolkata'));
      },
    );

    test('explicit timezone override wins over the place lookup', () async {
      // Arrange
      final service = LocationService();
      await service.init();

      // Act: New York coordinates, but the caller insists on IST.
      await service.setHomeLocation(
        40.7128,
        -74.0060,
        'New York',
        timezoneId: 'America/New_York',
      );
      final home = service.getHomeLocation();

      // Assert
      expect(home, isNotNull);
      expect(home!.timezoneId, equals('America/New_York'));
      expect(
        Hive.box(StorageService.locationSettingsBoxName)
            .get('home_timezone_source'),
        equals('user'),
        reason:
            'An explicit override must be marked so no migration retries it.',
      );
    });

    test('home location uses the place zone, not the device zone', () async {
      // Arrange: the platform reports Asia/Kolkata (setUp).
      final service = LocationService();
      await service.init();

      // Act
      await service.setHomeLocation(40.7128, -74.0060, 'New York');
      final home = service.getHomeLocation();

      // Assert
      expect(home, isNotNull);
      expect(home!.timezoneId, equals('America/New_York'));
      expect(
        Hive.box(StorageService.locationSettingsBoxName)
            .get('home_timezone_source'),
        equals('place'),
      );
    });

    test(
      'init backfills a zone for coordinates written before Phase 0',
      () async {
        // Arrange: write coordinates, then drop the zone to mimic an old box.
        final first = LocationService();
        await first.init();
        await first.setHomeLocation(28.6139, 77.2090, 'Delhi');
        final box = Hive.box(StorageService.locationSettingsBoxName);
        await box.delete('home_timezone');
        await box.delete('home_timezone_source');
        await first.dispose();

        // Act: a fresh service must resolve and persist the missing zone.
        final second = LocationService();
        await second.init();
        final home = second.getHomeLocation();

        // Assert
        expect(home, isNotNull);
        expect(home!.timezoneId, equals('Asia/Kolkata'));
      },
    );

    test('init re-resolves a legacy zone that has no source marker', () async {
      // Arrange: pre-lookup boxes stored the device zone (here IST) next to
      // the coordinates and have no provenance marker.
      final first = LocationService();
      await first.init();
      final box = Hive.box(StorageService.locationSettingsBoxName);
      await box.put('home_lat', 40.7128);
      await box.put('home_lng', -74.0060);
      await box.put('home_address', 'New York');
      await box.put('home_timezone', 'Asia/Kolkata');
      await first.dispose();

      // Act
      final second = LocationService();
      await second.init();

      // Assert
      expect(second.getHomeLocation()!.timezoneId, equals('America/New_York'));
      expect(
        Hive.box(StorageService.locationSettingsBoxName)
            .get('home_timezone_source'),
        equals('place'),
      );
    });

    test('init keeps a user-chosen zone for the same place', () async {
      // Arrange: a deliberate override that differs from the place's zone.
      final first = LocationService();
      await first.init();
      final box = Hive.box(StorageService.locationSettingsBoxName);
      await box.put('home_lat', 28.6139);
      await box.put('home_lng', 77.2090);
      await box.put('home_address', 'Delhi');
      await box.put('home_timezone', 'America/New_York');
      await box.put('home_timezone_source', 'user');
      await first.dispose();

      // Act
      final second = LocationService();
      await second.init();

      // Assert: the migration must not overwrite an explicit choice.
      expect(second.getHomeLocation()!.timezoneId, equals('America/New_York'));
    });
  });

  group('LocationService.tryResolvePosition', () {
    test('prefers the last known position over forcing a fix', () async {
      // Arrange: a cached fix exists, so no new one should be requested.
      final fake = _LastKnownFixFake();
      GeolocatorPlatform.instance = fake;
      final service = LocationService();
      await service.init();

      // Act
      final position = await service.tryResolvePosition();

      // Assert: instant answer, zero forced fixes (the failure mode behind
      // "GPS fix timed out, falling back to fused provider" + second timeout).
      expect(position, isNotNull);
      expect(position!.latitude, equals(28.61));
      expect(fake.currentPositionCalls, equals(0));
    });

    test('returns null instead of throwing when nothing resolves', () async {
      // Arrange: no cached fix and every fix attempt times out.
      final fake = _AlwaysTimingOutFake();
      GeolocatorPlatform.instance = fake;
      final service = LocationService();
      await service.init();

      // Act
      final position = await service.tryResolvePosition(
        fossTimeout: const Duration(milliseconds: 1),
        fusedTimeout: const Duration(milliseconds: 1),
      );

      // Assert
      expect(position, isNull);
    });
  });

  group('PlaceSearchResult.fromNominatim', () {
    test('parses a well-formed Nominatim row', () {
      // Arrange
      final json = <String, dynamic>{
        'lat': '28.6310',
        'lon': '77.2197',
        'display_name': 'Connaught Place, New Delhi, India',
      };

      // Act
      final place = PlaceSearchResult.fromNominatim(json);

      // Assert
      expect(place, isNotNull);
      expect(place!.latitude, closeTo(28.6310, 1e-6));
      expect(place.longitude, closeTo(77.2197, 1e-6));
      expect(place.displayName, 'Connaught Place, New Delhi, India');
    });

    test('rejects out-of-range coordinates', () {
      // Arrange
      final json = <String, dynamic>{
        'lat': '95.0',
        'lon': '77.2',
        'display_name': 'Nowhere',
      };

      // Act
      final place = PlaceSearchResult.fromNominatim(json);

      // Assert
      expect(place, isNull);
    });

    test('rejects rows without a usable label', () {
      // Arrange
      final json = <String, dynamic>{
        'lat': '28.6',
        'lon': '77.2',
        'display_name': '   ',
      };

      // Act / Assert
      expect(PlaceSearchResult.fromNominatim(json), isNull);
    });
  });

  group('LocationService.searchPlaces', () {
    test('skips the network for queries below the minimum length', () async {
      // Arrange: every request would fail loudly, so a pass proves no call.
      var requests = 0;
      final service = LocationService(
        httpClient: MockClient((_) async {
          requests++;
          throw const SocketException('should not be called');
        }),
      );

      // Act: a 2-character query must short-circuit (no HTTP, no init).
      final outcome = await service.searchPlaces('de');

      // Assert
      expect(outcome, isA<PlaceSearchSuccess>());
      expect((outcome as PlaceSearchSuccess).results, isEmpty);
      expect(requests, equals(0));
    });

    test('sends a policy-compliant request and parses results', () async {
      // Arrange
      late http.Request captured;
      final service = LocationService(
        httpClient: MockClient((request) async {
          captured = request;
          return http.Response(
            jsonEncode([
              {
                'lat': '28.6139',
                'lon': '77.2090',
                'display_name': 'New Delhi, India',
              },
            ]),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );

      // Act
      final outcome = await service.searchPlaces(
        'new delhi',
        languageCode: 'hi',
      );

      // Assert: results parsed, and the request carries the contactable
      // User-Agent plus the caller's language.
      expect(outcome, isA<PlaceSearchSuccess>());
      final results = (outcome as PlaceSearchSuccess).results;
      expect(results, hasLength(1));
      expect(results.first.displayName, 'New Delhi, India');

      expect(captured.url.host, 'nominatim.openstreetmap.org');
      expect(captured.url.queryParameters['q'], 'new delhi');
      expect(captured.url.queryParameters['format'], 'jsonv2');
      expect(captured.url.queryParameters['accept-language'], 'hi');
      expect(captured.headers['User-Agent'], contains('Tithi'));
    });

    test('decodes non-ASCII place names as UTF-8', () async {
      // Arrange: Nominatim omits a charset here, which makes `Response.body`
      // fall back to latin1 and mangle Devanagari — decode the bytes instead.
      final json = jsonEncode([
        {'lat': '28.6', 'lon': '77.2', 'display_name': 'नई दिल्ली, भारत'},
      ]);
      final service = LocationService(
        httpClient: MockClient(
          (_) async => http.Response.bytes(
            utf8.encode(json),
            200,
            headers: {'content-type': 'application/json'},
          ),
        ),
      );

      // Act
      final outcome = await service.searchPlaces('दिल्ली');

      // Assert
      expect(outcome, isA<PlaceSearchSuccess>());
      expect(
        (outcome as PlaceSearchSuccess).results.first.displayName,
        'नई दिल्ली, भारत',
      );
    });

    test('reports throttling as a distinct failure', () async {
      // Arrange
      final service = LocationService(
        httpClient: MockClient((_) async => http.Response('slow down', 429)),
      );

      // Act
      final outcome = await service.searchPlaces('delhi');

      // Assert
      expect(outcome, isA<PlaceSearchFailure>());
      expect(
        (outcome as PlaceSearchFailure).error,
        equals(PlaceSearchError.rateLimited),
      );
    });

    test('reports server errors without throwing', () async {
      // Arrange
      final service = LocationService(
        httpClient: MockClient((_) async => http.Response('boom', 503)),
      );

      // Act
      final outcome = await service.searchPlaces('delhi');

      // Assert
      expect(
        (outcome as PlaceSearchFailure).error,
        equals(PlaceSearchError.server),
      );
    });

    test('reports connectivity failures without throwing', () async {
      // Arrange
      final service = LocationService(
        httpClient: MockClient(
          (_) async => throw http.ClientException('connection refused'),
        ),
      );

      // Act
      final outcome = await service.searchPlaces('delhi');

      // Assert
      expect(
        (outcome as PlaceSearchFailure).error,
        equals(PlaceSearchError.offline),
      );
    });

    test('reports malformed payloads without throwing', () async {
      // Arrange: valid JSON, wrong shape.
      final service = LocationService(
        httpClient: MockClient(
          (_) async => http.Response('{"not":"a list"}', 200),
        ),
      );

      // Act
      final outcome = await service.searchPlaces('delhi');

      // Assert
      expect(
        (outcome as PlaceSearchFailure).error,
        equals(PlaceSearchError.unknown),
      );
    });

    test('skips malformed rows but keeps good ones', () async {
      // Arrange
      final service = LocationService(
        httpClient: MockClient(
          (_) async => http.Response(
            jsonEncode([
              {'lat': 'nonsense', 'lon': '77.2', 'display_name': 'Bad row'},
              {'lat': '999', 'lon': '77.2', 'display_name': 'Out of range'},
              {'lat': '28.6', 'lon': '77.2', 'display_name': 'Good row'},
            ]),
            200,
          ),
        ),
      );

      // Act
      final outcome = await service.searchPlaces('delhi');

      // Assert
      final results = (outcome as PlaceSearchSuccess).results;
      expect(results, hasLength(1));
      expect(results.single.displayName, 'Good row');
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

/// Fake with a platform-cached fix available: [getLastKnownPosition] answers
/// instantly and no new fix should ever be requested.
class _LastKnownFixFake extends TimeoutThenFixFake {
  @override
  Future<Position?> getLastKnownPosition({
    bool forceLocationManager = false,
  }) async => Position(
    longitude: 77.21,
    latitude: 28.61,
    timestamp: DateTime.now(),
    accuracy: 15,
    altitude: 0,
    altitudeAccuracy: 1,
    heading: 0,
    headingAccuracy: 1,
    speed: 0,
    speedAccuracy: 1,
  );
}

/// Fake with no cached fix whose every fix attempt times out.
class _AlwaysTimingOutFake extends TimeoutThenFixFake {
  @override
  Future<Position> getCurrentPosition({
    LocationSettings? locationSettings,
  }) async {
    currentPositionCalls++;
    requestedSettings.add(locationSettings);
    throw TimeoutException('GPS fix timed out');
  }
}

/// Immediate fix that reports a real altitude (216 m, Delhi).
class _MountainFixFake extends _ImmediateFixFake {
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
      altitude: 216,
      altitudeAccuracy: 1,
      heading: 0,
      headingAccuracy: 1,
      speed: 0,
      speedAccuracy: 1,
    );
  }
}
