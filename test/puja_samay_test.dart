import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tithi/features/event_detail/domain/puja_samay.dart';
import 'package:tithi/l10n/app_localizations.dart';
import 'package:tithi/models/festival.dart';
import 'package:tithi/models/panchang_data.dart';

void main() {
  late AppLocalizations l10n;

  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
  });

  PanchangRules rules({
    String? pujaKala,
    String? paranRule,
    bool? clipToTithi,
    String conditions = 'Lunar',
    int tithi = 4,
  }) {
    final json = <String, dynamic>{
      'masa': 'Shravana',
      'paksha': 'Shukla',
      'tithi': tithi,
      'conditions': conditions,
    };
    if (pujaKala != null) json['pujaKala'] = pujaKala;
    if (paranRule != null) json['paranRule'] = paranRule;
    if (clipToTithi != null) json['clipToTithi'] = clipToTithi;
    return PanchangRules.fromJson(json);
  }

  Festival festivalWith(PanchangRules r) {
    return Festival(
      id: 'f',
      name: 'F',
      nameRegional: const NameRegional(nameEnglish: 'F'),
      visuals: const Visuals(),
      purpose: const Purpose(description: 'd'),
      panchangRules: r,
      rituals: const Rituals(steps: []),
      media: const Media(),
    );
  }

  group('puja field parsing', () {
    test('absent fields default to null, null, false', () {
      // Arrange + Act
      final r = rules();

      // Assert
      expect(r.pujaKala, isNull);
      expect(r.paranRule, isNull);
      expect(r.clipToTithi, isFalse);
    });

    test('present fields parse through', () {
      // Arrange + Act
      final r = rules(
        pujaKala: 'nishita',
        paranRule: 'moonrise',
        clipToTithi: true,
      );

      // Assert
      expect(r.pujaKala, equals('nishita'));
      expect(r.paranRule, equals('moonrise'));
      expect(r.clipToTithi, isTrue);
    });

    test('explicit false clip stays false', () {
      // Arrange + Act
      final r = rules(clipToTithi: false);

      // Assert
      expect(r.clipToTithi, isFalse);
    });

    test('snake_case twins parse like the shipped Ganesh entry', () {
      // Arrange + Act
      final r = PanchangRules.fromJson({
        'masa': 'Bhadrapada',
        'paksha': 'Shukla',
        'tithi': 4,
        'conditions': 'Chaturthi',
        'puja_kala': 'madhyahna',
        'paran_rule': 'moonrise',
        'clip_to_tithi': true,
      });

      // Assert
      expect(r.pujaKala, equals('madhyahna'));
      expect(r.paranRule, equals('moonrise'));
      expect(r.clipToTithi, isTrue);
    });
  });

  group('normalization', () {
    test('known kala and paran values pass through', () {
      // Arrange + Act + Assert
      expect(
        normalizedPujaKala(festivalWith(rules(pujaKala: 'madhyahna'))),
        equals('madhyahna'),
      );
      expect(
        normalizedPujaKala(festivalWith(rules(pujaKala: 'sandhi_junction'))),
        equals('sandhi_junction'),
      );
      // Both Pradosh spellings are accepted, like `timingOverride`.
      expect(
        normalizedPujaKala(festivalWith(rules(pujaKala: 'pradosh'))),
        equals('pradosh'),
      );
      expect(
        normalizedPujaKala(festivalWith(rules(pujaKala: 'pradosha'))),
        equals('pradosha'),
      );
      // Godhuli (Tulsi Vivah) and Sankranti punya kala are window kalas too.
      expect(
        normalizedPujaKala(festivalWith(rules(pujaKala: 'godhuli'))),
        equals('godhuli'),
      );
      expect(
        normalizedPujaKala(festivalWith(rules(pujaKala: 'punya_kala'))),
        equals('punya_kala'),
      );
      expect(
        normalizedParanRule(festivalWith(rules(paranRule: 'dwadashi_window'))),
        equals('dwadashi_window'),
      );
    });

    test('unknown or absent values hide (null)', () {
      // Arrange + Act + Assert
      expect(normalizedPujaKala(festivalWith(rules())), isNull);
      expect(
        normalizedPujaKala(festivalWith(rules(pujaKala: 'bogus'))),
        isNull,
      );
      expect(normalizedParanRule(festivalWith(rules())), isNull);
      expect(
        normalizedParanRule(festivalWith(rules(paranRule: 'bogus'))),
        isNull,
      );
    });

    test('all kalas except sunrise and sunset are window kalas', () {
      // Arrange + Act + Assert
      expect(isPujaWindowKala('madhyahna'), isTrue);
      expect(isPujaWindowKala('nishita'), isTrue);
      expect(isPujaWindowKala('pradosha'), isTrue);
      expect(isPujaWindowKala('pradosh'), isTrue);
      expect(isPujaWindowKala('moonrise'), isTrue);
      expect(isPujaWindowKala('chandrodaya'), isTrue);
      expect(isPujaWindowKala('godhuli'), isTrue);
      expect(isPujaWindowKala('punya_kala'), isTrue);
      expect(isPujaWindowKala('sandhi_junction'), isTrue);
      expect(isPujaWindowKala('sunrise'), isFalse);
      expect(isPujaWindowKala('sunset'), isFalse);
    });
  });

  group('pujaKalaLabel', () {
    test('reuses sheet labels with English fallbacks', () {
      // Arrange + Act + Assert
      expect(pujaKalaLabel('madhyahna', l10n), equals('Madhyahna'));
      expect(pujaKalaLabel('sandhi_junction', l10n), equals('Sandhi'));
      expect(pujaKalaLabel('moonrise', null), equals('Moonrise'));
      expect(pujaKalaLabel('pradosh', null), equals('Pradosha'));
      expect(pujaKalaLabel('godhuli', null), equals('Godhuli'));
      expect(pujaKalaLabel('punya_kala', null), equals('Punya Kala'));
      expect(pujaKalaLabel('bogus', null), equals('bogus'));
    });
  });

  group('resolvePujaKala', () {
    // 6:00–18:00 day (D = 12h), 18:00–6:00 night (N = 12h).
    final sunrise = DateTime(2026, 8, 22, 6);
    final sunset = DateTime(2026, 8, 22, 18);
    final nextSunrise = DateTime(2026, 8, 23, 6);
    final moonrise = DateTime(2026, 8, 22, 20, 42);

    PujaKalaSpan? span(
      String kala, {
      bool clipToTithi = false,
      DateTime? tithiEnd,
      DateTime? moonriseAt,
    }) {
      return resolvePujaKala(
        kala: kala,
        date: DateTime(2026, 8, 22),
        sunrise: sunrise,
        sunset: sunset,
        nextSunrise: nextSunrise,
        moonrise: moonriseAt,
        tithiEnd: tithiEnd,
        clipToTithi: clipToTithi,
      );
    }

    test('madhyahna instant is midday, window the middle fifth', () {
      // Arrange + Act
      final s = span('madhyahna');

      // Assert: instant 12:00, window [10:48, 13:12].
      expect(s?.instant, equals(DateTime(2026, 8, 22, 12)));
      expect(s?.start, equals(DateTime(2026, 8, 22, 10, 48)));
      expect(s?.end, equals(DateTime(2026, 8, 22, 13, 12)));
    });

    test('nishita instant is the window midpoint past midnight', () {
      // Arrange + Act
      final s = span('nishita');

      // Assert: window [23:36, 00:24], instant 00:00.
      expect(s?.instant, equals(DateTime(2026, 8, 23)));
      expect(s?.start, equals(DateTime(2026, 8, 22, 23, 36)));
      expect(s?.end, equals(DateTime(2026, 8, 23, 0, 24)));
    });

    test('pradosha runs from sunset without an unflagged clip', () {
      // Arrange + Act
      final s = span('pradosha', tithiEnd: DateTime(2026, 8, 22, 19));

      // Assert: classical [18:00, 20:24] stays whole — clipping is
      // flag-driven, not Trayodashi-driven. Instant is the midpoint.
      expect(s?.instant, equals(DateTime(2026, 8, 22, 19, 12)));
      expect(s?.start, equals(DateTime(2026, 8, 22, 18)));
      expect(s?.end, equals(DateTime(2026, 8, 22, 20, 24)));
    });

    test('pradosh is an alias of pradosha', () {
      // Arrange + Act
      final alias = span('pradosh');
      final canonical = span('pradosha');

      // Assert: same window and instant, whichever spelling the data uses.
      expect(alias?.instant, equals(canonical?.instant));
      expect(alias?.start, equals(canonical?.start));
      expect(alias?.end, equals(canonical?.end));
    });

    test('clipToTithi cuts the end at the tithi-sandhi', () {
      // Arrange + Act
      final s = span(
        'pradosha',
        clipToTithi: true,
        tithiEnd: DateTime(2026, 8, 22, 19),
      );

      // Assert: end clips, instant stays the natural midpoint.
      expect(s?.instant, equals(DateTime(2026, 8, 22, 19, 12)));
      expect(s?.start, equals(DateTime(2026, 8, 22, 18)));
      expect(s?.end, equals(DateTime(2026, 8, 22, 19)));
    });

    test('clip leaves exterior or missing ends alone', () {
      // Arrange + Act + Assert
      expect(
        span(
          'madhyahna',
          clipToTithi: true,
          tithiEnd: DateTime(2026, 8, 22, 9),
        )?.end,
        equals(DateTime(2026, 8, 22, 13, 12)),
      );
      expect(
        span(
          'madhyahna',
          clipToTithi: true,
          tithiEnd: DateTime(2026, 8, 22, 15),
        )?.end,
        equals(DateTime(2026, 8, 22, 13, 12)),
      );
      expect(
        span('madhyahna', clipToTithi: true)?.end,
        equals(DateTime(2026, 8, 22, 13, 12)),
      );
      expect(
        span(
          'madhyahna',
          tithiEnd: DateTime(2026, 8, 22, 12),
        )?.end,
        equals(DateTime(2026, 8, 22, 13, 12)),
      );
    });

    test('moonrise is a 48-minute grace window from the rise', () {
      // Arrange + Act
      final s = span('moonrise', moonriseAt: moonrise);

      // Assert
      expect(s?.instant, equals(moonrise));
      expect(s?.start, equals(moonrise));
      expect(s?.end, equals(DateTime(2026, 8, 22, 21, 30)));
      expect(span('moonrise'), isNull);
    });

    test('moonrise resolves without nextSunrise (paran sync path)', () {
      // Arrange + Act: the paran line resolves moonrise kalas without the
      // day anchors — a required nextSunrise once crashed this path.
      final s = resolvePujaKala(
        kala: 'moonrise',
        date: DateTime(2026, 8, 22),
        sunrise: null,
        sunset: null,
        nextSunrise: null,
        moonrise: DateTime(2026, 8, 22, 20, 42),
        tithiEnd: null,
        clipToTithi: false,
      );

      // Assert
      expect(s?.end, equals(DateTime(2026, 8, 22, 21, 30)));
    });

    test('day windows need nextSunrise', () {
      // Arrange + Act + Assert
      expect(
        resolvePujaKala(
          kala: 'madhyahna',
          date: DateTime(2026, 8, 22),
          sunrise: sunrise,
          sunset: sunset,
          nextSunrise: null,
          moonrise: null,
          tithiEnd: null,
          clipToTithi: false,
        ),
        isNull,
      );
    });

    test('sandhi is a 48-minute span centered on the tithi end', () {
      // Arrange + Act
      final end = DateTime(2026, 8, 22, 15);
      final s = span('sandhi_junction', tithiEnd: end);

      // Assert
      expect(s?.instant, equals(end));
      expect(s?.start, equals(DateTime(2026, 8, 22, 14, 36)));
      expect(s?.end, equals(DateTime(2026, 8, 22, 15, 24)));
      expect(span('sandhi_junction'), isNull);
    });

    test('exact instants and missing anchors resolve to null', () {
      // Arrange + Act + Assert
      expect(span('sunrise'), isNull);
      expect(span('sunset'), isNull);
      expect(
        resolvePujaKala(
          kala: 'madhyahna',
          date: DateTime(2026, 8, 22),
          sunrise: null,
          sunset: sunset,
          nextSunrise: nextSunrise,
          moonrise: null,
          tithiEnd: null,
          clipToTithi: false,
        ),
        isNull,
      );
    });
  });

  group('resolvePujaInstant', () {
    final at = DateTime(2026, 8, 22, 20, 42);

    test('sunrise and sunset map to their anchors', () {
      // Arrange + Act + Assert
      expect(
        resolvePujaInstant(kala: 'sunrise', sunrise: at, sunset: null),
        equals(at),
      );
      expect(
        resolvePujaInstant(kala: 'sunset', sunrise: null, sunset: at),
        equals(at),
      );
    });

    test('missing anchors and window kalas resolve to null', () {
      // Arrange + Act + Assert
      expect(
        resolvePujaInstant(kala: 'sunrise', sunrise: null, sunset: null),
        isNull,
      );
      expect(
        resolvePujaInstant(kala: 'moonrise', sunrise: at, sunset: at),
        isNull,
      );
      expect(
        resolvePujaInstant(
          kala: 'sandhi_junction',
          sunrise: at,
          sunset: at,
        ),
        isNull,
      );
      expect(
        resolvePujaInstant(kala: 'madhyahna', sunrise: at, sunset: at),
        isNull,
      );
    });
  });

  group('Godhuli and punya kala windows', () {
    // 6:00–18:00 day (D = 12h), 18:00–6:00 night.
    final sunrise = DateTime(2026, 8, 22, 6);
    final sunset = DateTime(2026, 8, 22, 18);
    final nextSunrise = DateTime(2026, 8, 23, 6);
    final date = DateTime(2026, 8, 22);

    PujaKalaSpan? span(
      String kala, {
      DateTime? sankrantiInstant,
      List<BhadraWindow> bhadraWindows = const [],
      bool avoidBhadra = false,
      bool clipToTithi = false,
      DateTime? tithiEnd,
    }) {
      return resolvePujaKala(
        kala: kala,
        date: date,
        sunrise: sunrise,
        sunset: sunset,
        nextSunrise: nextSunrise,
        moonrise: null,
        tithiEnd: tithiEnd,
        clipToTithi: clipToTithi,
        sankrantiInstant: sankrantiInstant,
        bhadraWindows: bhadraWindows,
        avoidBhadra: avoidBhadra,
      );
    }

    test('godhuli runs from sunset for one day-ghati', () {
      // Arrange + Act
      final s = span('godhuli');

      // Assert: [18:00, 18:24], instant at the midpoint.
      expect(s?.start, equals(DateTime(2026, 8, 22, 18)));
      expect(s?.end, equals(DateTime(2026, 8, 22, 18, 24)));
      expect(s?.instant, equals(DateTime(2026, 8, 22, 18, 12)));
    });

    test('punya kala runs 40 ghatis from a daytime transit, clipped', () {
      // Arrange + Act: transit at 10:00, 16 hours would end at 02:00 next day.
      final s = span(
        'punya_kala',
        sankrantiInstant: DateTime(2026, 8, 22, 10),
      );

      // Assert: clipped to sunset, instant is the transit itself.
      expect(s?.instant, equals(DateTime(2026, 8, 22, 10)));
      expect(s?.start, equals(DateTime(2026, 8, 22, 10)));
      expect(s?.end, equals(DateTime(2026, 8, 22, 18)));
    });

    test('an after-sunset transit shifts punya kala to this sunrise', () {
      // Arrange: yesterday 20:00 transit, so today carries the observance.
      final s = span(
        'punya_kala',
        sankrantiInstant: DateTime(2026, 8, 21, 20),
      );

      // Assert: window starts at sunrise and keeps the transit + 16h end.
      expect(s?.start, equals(sunrise));
      expect(s?.end, equals(DateTime(2026, 8, 22, 12)));
      expect(s?.instant, equals(sunrise));
    });

    test('punya kala hides without a transit or with one after sunset', () {
      // Arrange + Act + Assert
      expect(span('punya_kala'), isNull);
      expect(
        span('punya_kala', sankrantiInstant: DateTime(2026, 8, 22, 20)),
        isNull,
      );
    });

    test('avoidBhadra trims aparahna to the Bhadra-free part', () {
      // Arrange: aparahna [13:12, 15:36], Bhadra [13:00, 14:00].
      final s = span(
        'aparahna',
        avoidBhadra: true,
        bhadraWindows: [
          (
            start: DateTime(2026, 8, 22, 13),
            end: DateTime(2026, 8, 22, 14),
          ),
        ],
      );

      // Assert: the free tail is used, instant at its midpoint.
      expect(s?.start, equals(DateTime(2026, 8, 22, 14)));
      expect(s?.end, equals(DateTime(2026, 8, 22, 15, 36)));
      expect(s?.instant, equals(DateTime(2026, 8, 22, 14, 48)));
    });

    test('avoidBhadra falls back to Pradosha when the kala is covered', () {
      // Arrange: Bhadra covers the whole aparahna window.
      final s = span(
        'aparahna',
        avoidBhadra: true,
        bhadraWindows: [
          (
            start: DateTime(2026, 8, 22, 12),
            end: DateTime(2026, 8, 22, 16),
          ),
        ],
      );

      // Assert: classical Pradosha [18:00, 20:24].
      expect(s?.start, equals(DateTime(2026, 8, 22, 18)));
      expect(s?.end, equals(DateTime(2026, 8, 22, 20, 24)));
    });

    test('avoidBhadra hides when neither kala is usable', () {
      // Arrange + Act: Bhadra spans aparahna and the Pradosha fallback.
      final s = span(
        'aparahna',
        avoidBhadra: true,
        bhadraWindows: [
          (
            start: DateTime(2026, 8, 22, 12),
            end: DateTime(2026, 8, 22, 22),
          ),
        ],
      );

      // Assert
      expect(s, isNull);
    });

    test('a sub-12-minute Bhadra-free sliver falls back', () {
      // Arrange: only 11 minutes of aparahna remain outside Bhadra.
      final s = span(
        'aparahna',
        avoidBhadra: true,
        bhadraWindows: [
          (
            start: DateTime(2026, 8, 22, 13, 12),
            end: DateTime(2026, 8, 22, 15, 25),
          ),
        ],
      );

      // Assert: not a usable muhurta, so Pradosha is shown instead.
      expect(s?.start, equals(DateTime(2026, 8, 22, 18)));
    });

    test('avoidBhadra without windows leaves the kala whole', () {
      // Arrange + Act: the scan is gated on a matched festival, so an empty
      // list means "not computed", not "no Bhadra".
      final s = span('aparahna', avoidBhadra: true);

      // Assert
      expect(s?.start, equals(DateTime(2026, 8, 22, 13, 12)));
      expect(s?.end, equals(DateTime(2026, 8, 22, 15, 36)));
    });
  });

  group('ghatikasBetween', () {
    test('counts 24-minute units with a minimum of one', () {
      // Arrange + Act + Assert
      expect(
        ghatikasBetween(
          DateTime(2026, 8, 22, 10, 48),
          DateTime(2026, 8, 22, 13, 12),
        ),
        equals(6),
      );
      expect(
        ghatikasBetween(
          DateTime(2026, 8, 22, 20, 42),
          DateTime(2026, 8, 22, 21, 30),
        ),
        equals(2),
      );
      expect(
        ghatikasBetween(
          DateTime(2026, 8, 22, 12),
          DateTime(2026, 8, 22, 12, 5),
        ),
        equals(1),
      );
    });
  });
}
