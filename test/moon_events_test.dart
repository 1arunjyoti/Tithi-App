import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jyotish/jyotish.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;

import 'package:tithi/features/panchang/domain/panchang_day.dart';
import 'package:tithi/features/panchang/domain/panchang_day_resolver.dart';
import 'package:tithi/models/panchang_profile.dart';
import 'package:tithi/services/moon_events_service.dart';
import 'package:tithi/services/panchang/panchang_service.dart';

// Phase 5: moonrise/moonset decide real observances (Karva Chauth's puja and
// paran both wait for the Moon), so the instant comes from native
// `swe_rise_trans`, not the truncated pure-Dart lunar series. These tests pin
// the convention, the "no rise today" contract the observances depend on, and
// the wiring from the day resolver down to the native call.

const double _delhiLat = 28.6139;
const double _delhiLng = 77.2090;
const String _delhiZone = 'Asia/Kolkata';

void main() {
  final libPath = Platform.environment['SWISSEPH_LIB_PATH'];
  final libraryAvailable =
      libPath != null && libPath.isNotEmpty && File(libPath).existsSync();
  final skipReason = libraryAvailable
      ? null
      : 'Set SWISSEPH_LIB_PATH to a host Swiss Ephemeris library to run the '
            'native lunar rise/set tests.';

  TestWidgetsFlutterBinding.ensureInitialized();

  late PanchangService service;
  late Directory tempDir;
  late MoonEventsService native;

  setUpAll(() async {
    tzdata.initializeTimeZones();
    tempDir = await Directory.systemTemp.createTemp('tithi_moon_events');
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async => tempDir.path);
    // Without the host library the native groups are skipped, so there is
    // nothing to configure.
    if (!libraryAvailable) return;
    service = PanchangService();
    await service.init();
    // `init` copies the bundled ephemeris files and configures the shared
    // services; build an independent instance so these tests never depend on
    // another suite's global state.
    native = MoonEventsService();
    native.configureSwiss(ephemerisPath: '${tempDir.path}/ephe');
  });

  tearDownAll(() async {
    try {
      await tempDir.delete(recursive: true);
    } on FileSystemException {
      // The native library keeps the copied .se1 files mapped on Windows.
    }
  });

  /// Declares a group that needs the host Swiss Ephemeris library.
  void nativeGroup(String name, void Function() body) =>
      group(name, body, skip: skipReason);

  group('labelled fallback', () {
    test('defaults to the pure-Dart approximation', () {
      // Arrange / Act
      final service = MoonEventsService();

      // Assert: no native library is touched until configureSwiss runs, so a
      // platform without it keeps a working (if approximate) answer.
      expect(service.usesNativeCalculator, isFalse);
    });

    test('reports a rise and a set for an ordinary Delhi day', () {
      // Arrange
      const approx = ApproximateMoonEventCalculator();

      // Act
      final rise = approx.rise(
        date: DateTime(2026, 1, 6),
        latitude: _delhiLat,
        longitude: _delhiLng,
      );
      final set = approx.set(
        date: DateTime(2026, 1, 6),
        latitude: _delhiLat,
        longitude: _delhiLng,
      );

      // Assert
      expect(rise, isNotNull);
      expect(set, isNotNull);
      expect(rise!.day, 6);
      expect(set!.day, 6);
    });
  });

  nativeGroup('native convention', () {
    test('is native once configured', () {      expect(native.usesNativeCalculator, isTrue);
    });

    test('agrees with the fallback to within a few minutes', () {
      // Arrange: the approximation is documented as ~1-3 minutes out, which is
      // why it may only ever be a labelled fallback.
      const approx = ApproximateMoonEventCalculator();
      final dates = [
        DateTime(2026, 1, 6),
        DateTime(2026, 3, 15),
        DateTime(2026, 6, 20),
        DateTime(2026, 9, 10),
        DateTime(2026, 10, 6),
        DateTime(2026, 11, 20),
        DateTime(2026, 12, 31),
      ];

      for (final date in dates) {
        // Act
        final expected = approx.rise(
          date: date,
          latitude: _delhiLat,
          longitude: _delhiLng,
        );
        final actual = native.moonrise(
          date: date,
          latitude: _delhiLat,
          longitude: _delhiLng,
          timezoneId: _delhiZone,
        );

        // Assert
        expect(actual, isNotNull, reason: '$date has a moonrise');
        expect(expected, isNotNull, reason: '$date has a moonrise');
        expect(
          actual!.difference(expected!).inSeconds.abs(),
          lessThanOrEqualTo(240),
          reason: '$date: fallback should stay within 4 minutes',
        );
      }
    });

    test('keeps the Moon topocentric and its ecliptic latitude', () {
      // Arrange
      final bindings = SwissEphBindings();
      final calculator = SwissMoonEventCalculator(bindings: bindings);

      // Act
      final bits = calculator.riseSetBits;

      // Assert: the Hindu solar bit must never appear here - it drops the
      // Moon's ecliptic latitude and parallax, which move a rise by up to an
      // hour.
      expect(bits & SwissEphBindings.SE_BIT_GEOCTR_NO_ECL_LAT, isZero);
      expect(bits & SwissEphBindings.SE_BIT_DISC_CENTER, isZero);
      expect(bits & SwissEphBindings.SE_BIT_DISC_BOTTOM, isZero);
      expect(bits & SwissEphBindings.SE_BIT_NO_REFRACTION, isZero);
    });

    test('maps the profile limb and refraction policy onto rise/set bits', () {
      // Arrange
      final bindings = SwissEphBindings();

      // Act
      final center = SwissMoonEventCalculator(
        bindings: bindings,
        profile: const PanchangProfile(
          lunarLimb: LunarLimb.center,
          lunarRefraction: LunarRefraction.none,
        ),
      ).riseSetBits;
      final lower = SwissMoonEventCalculator(
        bindings: bindings,
        profile: const PanchangProfile(lunarLimb: LunarLimb.lowerLimb),
      ).riseSetBits;

      // Assert
      expect(center & SwissEphBindings.SE_BIT_DISC_CENTER, isNot(0));
      expect(center & SwissEphBindings.SE_BIT_NO_REFRACTION, isNot(0));
      expect(lower & SwissEphBindings.SE_BIT_DISC_BOTTOM, isNot(0));
      expect(lower & SwissEphBindings.SE_BIT_DISC_CENTER, isZero);
      expect(lower & SwissEphBindings.SE_BIT_NO_REFRACTION, isZero);
    });

    test('returns null when the Moon does not rise that day', () {
      // Arrange: Mumbai 2026-09-04 is the shipped no-moonrise day (the golden
      // fixture omits moonrise for it).
      // Act
      final rise = native.moonrise(
        date: DateTime(2026, 9, 4),
        latitude: 19.0760,
        longitude: 72.8777,
        timezoneId: _delhiZone,
      );

      // Assert: `swe_rise_trans` only searches forward, so without the
      // same-civil-day check this would silently return tomorrow's rise and
      // move a moonrise observance onto the wrong day.
      expect(rise, isNull);
    });

    test('finds a no-rise day inside one lunation', () {
      // Arrange: the Moon skips a rise on roughly one civil day a month, so a
      // month that reports none would mean the day filter stopped working.
      final days = <int>[];

      // Act
      for (var day = 1; day <= 30; day++) {
        final rise = native.moonrise(
          date: DateTime(2026, 9, day),
          latitude: 19.0760,
          longitude: 72.8777,
          timezoneId: _delhiZone,
        );
        if (rise == null) days.add(day);
      }

      // Assert
      expect(days, isNotEmpty);
    });

    test('resolves the civil day in the place zone, not the device zone', () {
      // Arrange: a place where the local day and the UTC day differ. Asking for
      // the same wall date must give the same event regardless of the device
      // zone, because the search starts at local midnight.
      // Act
      final tokyo = native.moonrise(
        date: DateTime(2026, 1, 6),
        latitude: 35.6762,
        longitude: 139.6503,
        timezoneId: 'Asia/Tokyo',
      );

      // Assert
      expect(tokyo, isNotNull);
      expect(tokyo!.day, 6, reason: 'the event belongs to the Tokyo civil day');
    });
  });

  nativeGroup('prevailing-event fallbacks', () {
    test('findPreviousRise returns the evening before a no-rise day', () {
      // Act
      final previous = native.findPreviousRise(
        date: DateTime(2026, 9, 4),
        latitude: 19.0760,
        longitude: 72.8777,
        timezoneId: _delhiZone,
      );

      // Assert: the Moon up on the 4th rose on the 3rd, so the chip and the
      // puja card still have an instant.
      expect(previous, isNotNull);
      expect(previous!.isBefore(DateTime(2026, 9, 4)), isTrue);
      expect(
        previous.isAfter(DateTime(2026, 9, 2)),
        isTrue,
        reason: 'a lunar rise/set cycle is ~24.8h',
      );
    });

    test('findNextSet returns a set after the day ends', () {
      // Act
      final next = native.findNextSet(
        date: DateTime(2026, 9, 4),
        latitude: 19.0760,
        longitude: 72.8777,
        timezoneId: _delhiZone,
      );

      // Assert
      expect(next, isNotNull);
      expect(next!.isAfter(DateTime(2026, 9, 4)), isTrue);
    });
  });

  nativeGroup('MoonEventsService', () {
    test('forDate reads both anchors from the same calculator', () {
      // Act
      final events = native.forDate(
        date: DateTime(2026, 1, 6),
        latitude: _delhiLat,
        longitude: _delhiLng,
        timezoneId: _delhiZone,
      );

      // Assert
      expect(events.moonrise, isNotNull);
      expect(events.moonset, isNotNull);
      expect(events.moonrise!.day, 6);
      expect(events.moonset!.day, 6);
    });

    test('caches per day and clears when the place zone changes', () {
      // Arrange
      final service = MoonEventsService();
      service.configureSwiss(ephemerisPath: '${tempDir.path}/ephe');

      // Act
      final first = service.moonrise(
        date: DateTime(2026, 1, 6),
        latitude: _delhiLat,
        longitude: _delhiLng,
        timezoneId: _delhiZone,
      );
      final cached = service.moonrise(
        date: DateTime(2026, 1, 6),
        latitude: _delhiLat,
        longitude: _delhiLng,
        timezoneId: _delhiZone,
      );
      final sizeAfterRead = service.debugCacheSize;
      service.setPlaceTimezone('America/New_York');

      // Assert
      expect(cached, first);
      expect(sizeAfterRead, greaterThan(0));
      expect(
        service.debugCacheSize,
        isZero,
        reason: 'cached instants were resolved in the previous zone',
      );
    });

    test('a no-rise day stays null through the service', () {
      // Act
      final events = native.forDate(
        date: DateTime(2026, 9, 4),
        latitude: 19.0760,
        longitude: 72.8777,
        timezoneId: _delhiZone,
      );

      // Assert: the resolver turns this into `PanchangSolarDay.moonrise ==
      // null`, which a `moonrise` observance handles through MoonrisePolicy.
      expect(events.moonrise, isNull);
    });
  });

  nativeGroup('day resolver wiring', () {
    test('the canonical day takes its lunar anchors from the seam', () async {
      // Arrange
      const place = PanchangPlace(
        latitude: _delhiLat,
        longitude: _delhiLng,
        timezoneId: _delhiZone,
        label: 'Delhi',
      );
      final resolver = PanchangDayResolver(
        service: service,
        moonEvents: native,
      );
      final date = DateTime(2026, 1, 6);

      // Act
      final day = await resolver.resolve(date: date, place: place);

      // Assert: the observance input is the native instant, not the
      // approximation the retired path produced.
      final expected = native.moonrise(
        date: date,
        latitude: _delhiLat,
        longitude: _delhiLng,
        timezoneId: _delhiZone,
      );
      expect(day.solar.moonrise, isNotNull);
      expect(day.solar.moonrise, expected);
      expect(day.solar.moonset, isNotNull);
    });
  });
}
