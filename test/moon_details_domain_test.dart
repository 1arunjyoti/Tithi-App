import 'package:flutter_test/flutter_test.dart';
import 'package:tithi/core/notifications/moon_notification_content.dart';
import 'package:tithi/features/moon/domain/full_moon_names.dart';
import 'package:tithi/features/moon/domain/moon_distance.dart';
import 'package:tithi/features/moon/domain/moon_viewing.dart';
import 'package:tithi/l10n/app_localizations_en.dart';
import 'package:tithi/models/eclipse.dart';

void main() {
  final l10n = AppLocalizationsEn();

  group('full moon names', () {
    test('traditional monthly names cover all twelve months', () {
      expect(traditionalFullMoonName(1, l10n), 'Wolf Moon');
      expect(traditionalFullMoonName(9, l10n), 'Corn Moon');
      expect(traditionalFullMoonName(12, l10n), 'Cold Moon');
      expect(traditionalFullMoonName(13, l10n), isNull);
    });

    test('named Purnima overrides the month spelling', () {
      expect(namedPurnimaForMasa('Ashadha', l10n), 'Guru Purnima');
      expect(namedPurnimaForMasa('Adhika_Ashadha', l10n), 'Guru Purnima');
      expect(indianFullMoonName('Chaitra', l10n), 'Chaitra Purnima');
    });

    test('Blue Moon is the second full moon in a month, not the first', () {
      final purnimas = [
        DateTime.utc(2026, 6, 1, 10),
        DateTime.utc(2026, 6, 30, 12),
        DateTime.utc(2026, 7, 30, 8),
      ];
      final blue = blueMoonPurnimas(purnimas);
      expect(blue, hasLength(1));
      expect(blue.single, equals(purnimas[1]));
      expect(isBlueMoon(purnimas[0], purnimas), isFalse);
      expect(isBlueMoon(purnimas[1], purnimas), isTrue);
    });

    test('lunar age runs 0 -> synodic month across tithi 1..31', () {
      expect(lunarAgeDays(1.0), closeTo(0.0, 1e-9));
      expect(lunarAgeDays(16.0), closeTo(kSynodicMonthDays / 2, 1e-9));
      expect(lunarAgeDays(31.0), closeTo(kSynodicMonthDays, 1e-9));
      expect(lunarAgeDays(0.5), closeTo(lunarAgeDays(30.5), 1e-9));
    });

    test('phase stage uses lit fraction plus side', () {
      expect(moonPhaseStage(0.01, true), MoonPhaseStage.newMoon);
      expect(moonPhaseStage(0.25, true), MoonPhaseStage.waxingCrescent);
      expect(moonPhaseStage(0.5, false), MoonPhaseStage.lastQuarter);
      expect(moonPhaseStage(0.75, false), MoonPhaseStage.waningGibbous);
      expect(moonPhaseStage(0.99, false), MoonPhaseStage.fullMoon);
    });
  });

  group('moon distance', () {
    test('converts AU with the IAU constant and classifies thresholds', () {
      expect(moonDistanceKm(1.0), closeTo(149597870.7, 1e-6));
      expect(classifyMoonDistance(359000), MoonDistanceKind.supermoon);
      expect(classifyMoonDistance(384400), MoonDistanceKind.normal);
      expect(classifyMoonDistance(406000), MoonDistanceKind.micromoon);
    });
  });

  group('viewing window', () {
    test('pairs an evening rise with the next morning set', () {
      final rise = DateTime(2026, 6, 15, 19);
      final morningSet = DateTime(2026, 6, 15, 6);
      final nextSet = DateTime(2026, 6, 16, 5);
      expect(
        setFollowingRise(
          rise: rise,
          sameDaySet: morningSet,
          nextSet: nextSet,
        ),
        nextSet,
      );
      expect(
        setFollowingRise(rise: rise, sameDaySet: nextSet),
        nextSet,
      );
    });

    final sunrise = DateTime(2026, 6, 15, 6);
    final sunset = DateTime(2026, 6, 15, 18, 30);
    final nextSunrise = DateTime(2026, 6, 16, 6, 5);

    MoonViewingWindow? window({DateTime? rise, DateTime? set}) =>
        bestMoonViewingWindow(
          moonrise: rise,
          moonset: set,
          morningSunrise: sunrise,
          eveningSunset: sunset,
          nextSunrise: nextSunrise,
        );

    test('prefers the evening window when the Moon rises after sunset', () {
      final result = window(
        rise: DateTime(2026, 6, 15, 19),
        set: DateTime(2026, 6, 16, 5),
      );
      expect(result, isNotNull);
      expect(result!.isMorning, isFalse);
      expect(result.start, equals(DateTime(2026, 6, 15, 19)));
      expect(result.end, equals(DateTime(2026, 6, 16, 5)));
    });

    test('uses the pre-sunrise window for a Moon that sets by day', () {
      final result = window(
        rise: DateTime(2026, 6, 15, 3),
        set: DateTime(2026, 6, 15, 15),
      );
      expect(result, isNotNull);
      expect(result!.isMorning, isTrue);
      expect(result.start, equals(DateTime(2026, 6, 15, 3)));
      expect(result.end, equals(sunrise));
    });

    test('returns null when the Moon is down all night', () {
      expect(
        window(
          rise: DateTime(2026, 6, 15, 6, 30),
          set: DateTime(2026, 6, 15, 18),
        ),
        isNull,
      );
      expect(window(set: DateTime(2026, 6, 15, 5)), isNull);
    });
  });

  group('moon notification content', () {
    test('Blue Moon, New Moon and eclipse are limited to the window', () {
      final purnimas = [
        DateTime.utc(2026, 6, 1, 10),
        DateTime.utc(2026, 6, 30, 12),
      ];
      final events = buildMoonNotifications(
        purnimas: purnimas,
        amavasyas: [DateTime.utc(2026, 6, 15, 9)],
        eclipses: [
          Eclipse(
            type: EclipseType.lunarTotal,
            maxEclipseTime: DateTime.utc(2026, 6, 30, 23, 30),
          ),
        ],
        from: DateTime.utc(2026, 6, 30),
        days: 1,
        l10n: l10n,
        toLocal: (instant) => instant.toUtc(),
      );

      expect(
        events.map((e) => e.title),
        equals([l10n.blueMoonNotificationTitle, l10n.eclipseNotificationTitle]),
      );
      expect(events.first.body, contains(l10n.blueMoonNotificationBody));
    });

    test('ordinary full moon carries its traditional name', () {
      final events = buildMoonNotifications(
        purnimas: [DateTime.utc(2026, 12, 24, 10)],
        amavasyas: const [],
        eclipses: const [],
        from: DateTime.utc(2026, 12, 24),
        days: 1,
        l10n: l10n,
        toLocal: (instant) => instant.toUtc(),
      );
      expect(events.single.title, l10n.fullMoonNotificationTitle);
      expect(events.single.body, contains(l10n.coldMoon));
    });
  });
}
