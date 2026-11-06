import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:jyotish/jyotish.dart';

import 'package:tithi/models/panchang_school.dart';
import 'package:tithi/services/panchang/ephemeris/panchang_ephemeris.dart';

/// Guards the seam *between* the two calculation schools.
///
/// Every other test exercises one school at a time, so a regression that made
/// `ephemerisFor` ignore its argument - or made one implementation quietly
/// delegate to the other - would still pass them all. These assertions fail if
/// the two schools stop being two different theories, and they pin the
/// direction of the difference: `suryasiddhanta` is the one that reproduces the
/// New Delhi reference boundaries, `bisuddha` is the one that does not.
void main() {
  late DrikPanchangEphemeris drik;
  late SuryaSiddhantaEphemeris ss;

  setUpAll(() async {
    await Jyotish().initialize(
      ephemerisPath: Directory('assets/ephe').absolute.path,
    );
    drik = ephemerisFor(PanchangSchool.bisuddha) as DrikPanchangEphemeris;
    ss = ephemerisFor(PanchangSchool.suryasiddhanta)
        as SuryaSiddhantaEphemeris;
  });

  const latitude = 28.6139;
  const longitude = 77.2090;

  test('ephemerisFor returns the implementation the school names', () {
    expect(drik.school, PanchangSchool.bisuddha);
    expect(ss.school, PanchangSchool.suryasiddhanta);
    expect(drik.tag, 'drik-lahiri');
    expect(ss.tag, isNot(drik.tag), reason: 'cache keys would collide');
    expect(ephemerisFor(PanchangSchool.bisuddha), isA<DrikPanchangEphemeris>());
    expect(
      ephemerisFor(PanchangSchool.suryasiddhanta),
      isA<SuryaSiddhantaEphemeris>(),
    );
  });

  test('the schools disagree on both bodies, not just by rounding', () async {
    // 2005-10-20 14:51 IST is a tithi-end row in the reference file. Any
    // instant would do for this test; this one is convenient because the
    // elongation is pinned by an external source.
    final instant = _ist('2005-10-20', '14:51');

    final a = await drik.longitudesAt(
      instant,
      latitude: latitude,
      longitude: longitude,
    );
    final b = await ss.longitudesAt(
      instant,
      latitude: latitude,
      longitude: longitude,
    );

    expect(
      (a.sun - b.sun).abs(),
      greaterThan(0.2),
      reason: 'sun: drik ${a.sun} vs SS ${b.sun}',
    );
    expect(
      (a.moon - b.moon).abs(),
      greaterThan(0.5),
      reason: 'moon: drik ${a.moon} vs SS ${b.moon}',
    );
  });

  test('suryasiddhanta reproduces the reference boundary, bisuddha does not',
      () async {
    // Tithi 18 ends when the elongation reaches 12 * 18 = 216 degrees.
    final tithiEnd = _ist('2005-10-20', '14:51');
    // Nakshatra 18 ends when the Moon reaches 18 * (360 / 27) = 240 degrees.
    final nakshatraEnd = _ist('2017-11-20', '23:49');

    final ssTithi = await ss.longitudesAt(
      tithiEnd,
      latitude: latitude,
      longitude: longitude,
    );
    final ssNakshatra = await ss.longitudesAt(
      nakshatraEnd,
      latitude: latitude,
      longitude: longitude,
    );
    final drikTithi = await drik.longitudesAt(
      tithiEnd,
      latitude: latitude,
      longitude: longitude,
    );

    expect(
      _signedDelta(_norm(ssTithi.moon - ssTithi.sun) - 216),
      closeTo(0, 0.01),
    );
    expect(_signedDelta(_norm(ssNakshatra.moon) - 240), closeTo(0, 0.01));

    // The same instant under the drik school is off by half a degree of
    // elongation - ~1 hour of clock - which is why the two options show
    // different tithi boundaries.
    expect(
      _signedDelta(_norm(drikTithi.moon - drikTithi.sun) - 216).abs(),
      greaterThan(0.2),
    );
  });

  test('the Surya Siddhanta path is geocentric: position is ignored', () async {
    final instant = _ist('2026-10-28', '12:00');
    final atDelhi = await ss.longitudesAt(
      instant,
      latitude: latitude,
      longitude: longitude,
    );
    final atKolkata = await ss.longitudesAt(
      instant,
      latitude: 22.5726,
      longitude: 88.3639,
    );

    expect(atKolkata.sun, atDelhi.sun);
    expect(atKolkata.moon, atDelhi.moon);
  });
}

/// Panjika times are IST; the engine works in real instants.
DateTime _ist(String date, String hhmm) {
  final time = hhmm.split(':');
  return DateTime.utc(
    int.parse(date.substring(0, 4)),
    int.parse(date.substring(5, 7)),
    int.parse(date.substring(8, 10)),
    int.parse(time[0]),
    int.parse(time[1]),
  ).subtract(const Duration(hours: 5, minutes: 30));
}

double _norm(double degrees) {
  final value = degrees % 360;
  return value < 0 ? value + 360 : value;
}

double _signedDelta(double degrees) {
  var value = _norm(degrees);
  if (value > 180) value -= 360;
  return value;
}
