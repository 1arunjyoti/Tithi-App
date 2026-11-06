import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:tithi/features/panchang/domain/panchang_crossings.dart';
import 'package:tithi/models/festival.dart';
import 'package:tithi/models/hindu_month_system.dart';
import 'package:tithi/models/panchang_data.dart';
import 'package:tithi/providers/panchang_provider.dart';
import 'package:tithi/services/bengali_calendar_service.dart';
import 'package:tithi/services/festival_matching_pipeline.dart';
import 'package:tithi/services/moon_events_service.dart';
import 'package:tithi/services/panchang_service.dart';
import 'package:tithi/services/storage_service.dart';

import 'fixtures/panchang_golden/golden_fixtures.dart';

void main() {
  final libPath = Platform.environment['SWISSEPH_LIB_PATH'];
  final libraryAvailable =
      libPath != null && libPath.isNotEmpty && File(libPath).existsSync();
  final istHost =
      DateTime.now().timeZoneOffset == const Duration(hours: 5, minutes: 30);
  final skipReason = !libraryAvailable
      ? 'Set SWISSEPH_LIB_PATH to a host Swiss Ephemeris library to run the '
            'golden engine comparison.'
      : !istHost
      ? 'The golden harness normalizes each civil day in the device zone (it '
            'does not pass the place timezone into the day pipeline); run on an '
            'IST host (UTC+05:30).'
      : null;

  group('Panchang golden engine', () {
    late GoldenFixtureSet fixture;
    late PanchangService service;
    late Box<dynamic> cacheBox;
    late List<Festival> festivals;
    late ProviderContainer container;
    late BengaliCalendarService bengali;
    late Directory tempDir;

    setUpAll(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      fixture = GoldenFixtureSet.load();

      tempDir = await Directory.systemTemp.createTemp('tithi_golden_engine');
      const channel = MethodChannel('plugins.flutter.io/path_provider');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async => tempDir.path);

      service = PanchangService();
      await service.init();

      Hive.init(tempDir.path);
      cacheBox = await Hive.openBox<dynamic>('golden_cache');
      // `bengaliCalendarServiceProvider` resolves the calculation school from
      // preferences, so the settings box must exist before the container reads
      // it - the default (no `panchang_school` key) is Bisuddhasiddhanta, which
      // is what the golden fixtures were recorded under.
      await Hive.openBox<dynamic>(StorageService.settingsBoxName);

      final json = await rootBundle.loadString(kFestivalCatalogPath);
      festivals = (jsonDecode(json) as List)
          .map((e) => Festival.fromJson(e as Map<String, dynamic>))
          .toList();

      container = ProviderContainer(
        overrides: [panchangInitProvider.overrideWith((ref) async {})],
      );
      bengali = container.read(bengaliCalendarServiceProvider);
    });

    tearDownAll(() async {
      container.dispose();
      await cacheBox.close();
      try {
        await tempDir.delete(recursive: true);
      } on FileSystemException {
        // The native ephemeris library keeps the copied .se1 files open on
        // Windows, so the OS temp directory is left for the OS to reclaim.
      }
    });

    test('engine reproduces every locked case within tolerance', () async {
      expect(fixture.panchang.cases, isNotEmpty);
      final failures = <String>[];
      final dayCache = <String, PanchangData>{};
      var compared = 0;

      Future<PanchangData> getDay(
        GoldenCase c,
        DateTime d, {
        required bool transition,
      }) async {
        final key = '${c.location.name}|${_dateKey(d)}|$transition';
        final cached = dayCache[key];
        if (cached != null) return cached;
        final value = await computePanchangData(
          normalizedDate: d,
          service: service,
          festivals: festivals,
          monthSystem: HinduMonthSystem.amanta,
          latitude: c.location.latitude,
          longitude: c.location.longitude,
          cacheBox: cacheBox,
          includeTransition: transition,
        );
        dayCache[key] = value;
        return value;
      }

      for (final c in fixture.panchang.cases) {
        final target = DateTime(c.date.year, c.date.month, c.date.day);
        final window = <DateTime, PanchangData>{};
        for (var offset = -1; offset <= 1; offset++) {
          final d = DateTime(target.year, target.month, target.day + offset);
          window[d] = await getDay(c, d, transition: offset == 0);
        }

        final day = applyVriddhiFilter(window)[target];
        if (day == null) {
          failures.add('${c.id}: no computed day for $target');
          continue;
        }
        final sunrise = day.sunrise;
        if (sunrise == null) {
          failures.add('${c.id}: no sunrise computed');
          continue;
        }

        final tolerance = c.tolerance;
        _expectInstant(
          failures,
          c.id,
          'sunrise',
          c.expected.sunrise,
          sunrise,
          tolerance.eventSeconds,
        );
        _expectInstant(
          failures,
          c.id,
          'sunset',
          c.expected.sunset,
          day.sunset,
          tolerance.eventSeconds,
        );
        _expectInstant(
          failures,
          c.id,
          'tithiEndsAt',
          c.expected.tithiEndsAt,
          day.tithiTransitionTime,
          tolerance.eventSeconds,
        );

        // Lunar anchors come from the same seam the observance path uses, so
        // the fixture locks the native rise/set convention (topocentric, real
        // ecliptic latitude, profile limb/refraction) rather than the retired
        // pure-Dart approximation.
        final moonrise = moonEventsService.moonrise(
          date: target,
          latitude: c.location.latitude,
          longitude: c.location.longitude,
          altitudeMeters: c.location.altitudeMeters,
          timezoneId: c.location.timezone,
        );
        _expectInstant(
          failures,
          c.id,
          'moonrise',
          c.expected.moonrise,
          moonrise,
          tolerance.eventSeconds,
        );

        // Moonset is the other user-visible lunar anchor (the tithi sheet's
        // chip pair). Locking the instant end-to-end is what pins the profile's
        // limb policy to a number: the bit mapping alone cannot catch a
        // convention drift.
        final moonset = moonEventsService.moonset(
          date: target,
          latitude: c.location.latitude,
          longitude: c.location.longitude,
          altitudeMeters: c.location.altitudeMeters,
          timezoneId: c.location.timezone,
        );
        _expectInstant(
          failures,
          c.id,
          'moonset',
          c.expected.moonset,
          moonset,
          tolerance.eventSeconds,
        );

        // A locked null must be a genuine no-set day, not a failed lookup.
        // The Moon sets roughly 50 minutes later each day, so a skipped civil
        // day still has a set on both neighbours and their gap exceeds 24 h.
        if (c.expected.moonset == null) {
          DateTime? setOn(int dayOffset) => moonEventsService.moonset(
            date: DateTime(target.year, target.month, target.day + dayOffset),
            latitude: c.location.latitude,
            longitude: c.location.longitude,
            altitudeMeters: c.location.altitudeMeters,
            timezoneId: c.location.timezone,
          );
          final previous = setOn(-1);
          final next = setOn(1);
          if (previous == null || next == null) {
            failures.add(
              '${c.id}: no-set day, but a neighbouring day has no set '
              '(prev=$previous, next=$next)',
            );
          } else if (next.difference(previous) <= const Duration(hours: 24)) {
            failures.add(
              '${c.id}: no-set day, but the neighbouring sets are only '
              '${next.difference(previous)} apart',
            );
          }
        }

        // A locked null must be a genuine no-rise day, not a failed lookup.
        // The Moon rises roughly 50 minutes later each day, so a skipped civil
        // day still has a rise on both neighbours and their gap exceeds 24 h.
        // Without this, a bug that returns null for every day would pass the
        // null == null comparison above.
        if (c.expected.moonrise == null) {
          DateTime? riseOn(int dayOffset) => moonEventsService.moonrise(
            date: DateTime(target.year, target.month, target.day + dayOffset),
            latitude: c.location.latitude,
            longitude: c.location.longitude,
            altitudeMeters: c.location.altitudeMeters,
            timezoneId: c.location.timezone,
          );
          final previous = riseOn(-1);
          final next = riseOn(1);
          if (previous == null || next == null) {
            failures.add(
              '${c.id}: no-rise day, but a neighbouring day has no rise '
              '(prev=$previous, next=$next)',
            );
          } else if (next.difference(previous) <= const Duration(hours: 24)) {
            failures.add(
              '${c.id}: no-rise day, but the neighbouring rises are only '
              '${next.difference(previous)} apart',
            );
          }
        }

        final expectedTithi = c.expected.tithiAtSunrise;
        if (day.paksha != expectedTithi.paksha ||
            day.tithiNumber != expectedTithi.number ||
            day.tithiName != expectedTithi.name) {
          failures.add(
            '${c.id}: tithi at sunrise expected '
            '${expectedTithi.paksha} ${expectedTithi.number} '
            '${expectedTithi.name}, got '
            '${day.paksha} ${day.tithiNumber} ${day.tithiName}',
          );
        }

        _expectTithi(
          failures,
          c.id,
          'nextTithi',
          c.expected.nextTithi,
          _tithiFromRawIndex(day.transitionTithiIndex),
        );

        final nakshatra = await service.calculateNakshatra(
          sunrise,
          latitude: c.location.latitude,
          longitude: c.location.longitude,
        );
        if (nakshatra != c.expected.nakshatraAtSunrise) {
          failures.add(
            '${c.id}: nakshatra expected ${c.expected.nakshatraAtSunrise}, '
            'got $nakshatra',
          );
        }

        // Nakshatra edges go through the same resolveNakshatraSpan the detail
        // sheet calls, so the fixture locks the shared crossing solver rather
        // than a test-local bisection that could drift from production.
        final nakshatraSpan = await resolveNakshatraSpan(
          sunrise: sunrise,
          indexAt: (time) async {
            final name = await service.calculateNakshatra(
              time,
              latitude: c.location.latitude,
              longitude: c.location.longitude,
            );
            if (name == null) return null;
            final index = hinduNakshatras.indexOf(name);
            return index < 0 ? null : index;
          },
        );
        if (nakshatraSpan == null) {
          failures.add('${c.id}: nakshatra span unresolved');
        } else {
          if (nakshatraSpan.nakshatra != c.expected.nakshatraAtSunrise) {
            failures.add(
              '${c.id}: nakshatra span expected '
              '${c.expected.nakshatraAtSunrise}, got '
              '${nakshatraSpan.nakshatra}',
            );
          }
          _expectInstant(
            failures,
            c.id,
            'nakshatraStartsAt',
            c.expected.nakshatraStartsAt,
            nakshatraSpan.start,
            tolerance.eventSeconds,
          );
          _expectInstant(
            failures,
            c.id,
            'nakshatraEndsAt',
            c.expected.nakshatraEndsAt,
            nakshatraSpan.end,
            tolerance.eventSeconds,
          );
          final nextNakshatra =
              hinduNakshatras[(nakshatraSpan.index + 1) % 27];
          if (nextNakshatra != c.expected.nextNakshatra) {
            failures.add(
              '${c.id}: nextNakshatra expected ${c.expected.nextNakshatra}, '
              'got $nextNakshatra',
            );
          }
        }

        final lons = await service.calculateSunMoonLongitudes(
          sunrise,
          latitude: c.location.latitude,
          longitude: c.location.longitude,
        );
        if (lons == null) {
          failures.add('${c.id}: no Sun/Moon longitudes');
        } else {
          final yoga = yogaNames[yogaIndexFor(lons.sun, lons.moon)];
          final karana = karanaNameForIndex(
            karanaIndexFor(lons.sun, lons.moon),
          );
          if (yoga != c.expected.yogaAtSunrise) {
            failures.add(
              '${c.id}: yoga expected ${c.expected.yogaAtSunrise}, '
              'got $yoga',
            );
          }
          if (karana != c.expected.karanaAtSunrise) {
            failures.add(
              '${c.id}: karana expected ${c.expected.karanaAtSunrise}, '
              'got $karana',
            );
          }
          _expectLongitude(
            failures,
            c.id,
            'sunLongitude',
            c.expected.sunLongitude,
            lons.sun,
            tolerance.longitudeArcseconds,
          );
          _expectLongitude(
            failures,
            c.id,
            'moonLongitude',
            c.expected.moonLongitude,
            lons.moon,
            tolerance.longitudeArcseconds,
          );

          // Sankranti: the first solar sign ingress strictly after sunrise.
          // The estimate is the mean solar rate (0.9856 deg/day) applied to
          // the degrees the Sun still needs in its current sign;
          // findSankrantiInstant brackets ±3 days around it and solves the
          // crossing with the shared root solver.
          final rashiIndex = sunRashiIndex(lons.sun);
          final degreesInSign = lons.sun - rashiIndex * 30;
          final estimate = sunrise.add(
            Duration(
              minutes: ((30 - degreesInSign) / 0.9856 * 1440).round(),
            ),
          );
          final ingress = await findSankrantiInstant(
            estimate: estimate,
            sunLongitudeAt: (instant) async =>
                (await service.calculateSunMoonLongitudes(
                  instant,
                  latitude: c.location.latitude,
                  longitude: c.location.longitude,
                ))?.sun,
            boundaryDegrees: (rashiIndex + 1) * 30.0,
          );
          _expectInstant(
            failures,
            c.id,
            'nextSankranti.at',
            c.expected.nextSankranti.at,
            ingress,
            tolerance.eventSeconds,
          );
          final expectedRashi = rashiNames[(rashiIndex + 1) % 12];
          if (expectedRashi != c.expected.nextSankranti.rashi) {
            failures.add(
              '${c.id}: nextSankranti.rashi expected '
              '${c.expected.nextSankranti.rashi}, got $expectedRashi',
            );
          }
        }

        if (day.masa != c.expected.masa) {
          failures.add(
            '${c.id}: masa expected ${c.expected.masa}, got ${day.masa}',
          );
        }
        final purnimanta = convertAmantaToPurnimant(day.masa, day.paksha);
        if (purnimanta != c.expected.masaPurnimanta) {
          failures.add(
            '${c.id}: masaPurnimanta expected '
            '${c.expected.masaPurnimanta}, got $purnimanta',
          );
        }
        if (day.masa.startsWith('Adhika_') != c.expected.adhika) {
          failures.add(
            '${c.id}: adhika expected ${c.expected.adhika}, '
            'got ${day.masa.startsWith('Adhika_')}',
          );
        }

        final festivalCase = fixture.festivalCaseById(c.id);
        if (festivalCase == null) {
          failures.add('${c.id}: missing festival fixture');
        } else {
          final actual = day.festivals.map((f) => f.id).toList()..sort();
          final expected = [...festivalCase.expectedFestivalIds]..sort();
          if (actual.join(',') != expected.join(',')) {
            failures.add(
              '${c.id}: festivals expected [${expected.join(', ')}], '
              'got [${actual.join(', ')}]',
            );
          }
        }

        final expectedBengali = c.expected.bengaliDate;
        if (expectedBengali != null) {
          final b = await bengali.calculateDate(
            target,
            latitude: c.location.latitude,
            longitude: c.location.longitude,
          );
          if (b.year != expectedBengali.year ||
              b.month != expectedBengali.month ||
              b.day != expectedBengali.day) {
            failures.add(
              '${c.id}: bengali expected '
              '${expectedBengali.year} ${expectedBengali.month} '
              '${expectedBengali.day}, got ${b.year} ${b.month} ${b.day}',
            );
          }
        }
        compared++;
      }

      expect(compared, fixture.panchang.cases.length);
      expect(failures, isEmpty, reason: failures.join('\n'));
    }, timeout: const Timeout(Duration(minutes: 20)));
  }, skip: skipReason);
}

String _dateKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

GoldenTithi? _tithiFromRawIndex(int? raw) {
  if (raw == null) return null;
  final paksha = raw <= 15 ? 'Shukla' : 'Krishna';
  final number = raw <= 15 ? raw : raw - 15;
  return GoldenTithi(
    paksha: paksha,
    number: number,
    name: PanchangData.tithiNameFor(number, paksha),
  );
}

void _expectInstant(
  List<String> failures,
  String id,
  String field,
  GoldenInstant? expected,
  DateTime? actual,
  int toleranceSeconds,
) {
  if (expected == null) {
    if (actual != null) {
      failures.add(
        '$id: $field expected null, got ${actual.toIso8601String()}',
      );
    }
    return;
  }
  if (actual == null) {
    failures.add('$id: $field expected ${expected.raw}, got null');
    return;
  }
  final deltaMs = actual
      .toUtc()
      .difference(expected.instant)
      .inMilliseconds
      .abs();
  if (deltaMs > toleranceSeconds * 1000) {
    failures.add(
      '$id: $field expected ${expected.raw}, got '
      '${actual.toIso8601String()} (delta ${deltaMs}ms)',
    );
  }
}

void _expectTithi(
  List<String> failures,
  String id,
  String field,
  GoldenTithi? expected,
  GoldenTithi? actual,
) {
  String label(GoldenTithi t) => '${t.paksha} ${t.number} ${t.name}';
  if (expected == null) {
    if (actual != null) {
      failures.add('$id: $field expected null, got ${label(actual)}');
    }
    return;
  }
  if (actual == null) {
    failures.add('$id: $field expected ${label(expected)}, got null');
    return;
  }
  if (expected.paksha != actual.paksha ||
      expected.number != actual.number ||
      expected.name != actual.name) {
    failures.add(
      '$id: $field expected ${label(expected)}, got ${label(actual)}',
    );
  }
}

void _expectLongitude(
  List<String> failures,
  String id,
  String field,
  double expected,
  double actual,
  double toleranceArcseconds,
) {
  var delta = (expected - actual).abs() % 360;
  if (delta > 180) delta = 360 - delta;
  final toleranceDegrees = toleranceArcseconds / 3600;
  if (delta > toleranceDegrees) {
    failures.add(
      '$id: $field expected $expected, got $actual '
      '(delta ${(delta * 3600).toStringAsFixed(2)} arcsec)',
    );
  }
}
