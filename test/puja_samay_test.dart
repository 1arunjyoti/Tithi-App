import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tithi/features/event_detail/domain/puja_samay.dart';
import 'package:tithi/l10n/app_localizations.dart';
import 'package:tithi/models/festival.dart';

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
      expect(isPujaWindowKala('moonrise'), isTrue);
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
