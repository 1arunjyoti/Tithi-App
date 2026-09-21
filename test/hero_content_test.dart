import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tithi/features/hero/domain/hero_content.dart';
import 'package:tithi/l10n/app_localizations.dart';
import 'package:tithi/models/hindu_month_system.dart';
import 'package:tithi/models/panchang_data.dart';
import 'package:tithi/providers/calendar_provider.dart';

void main() {
  late AppLocalizations l10n;

  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
  });

  PanchangData day({
    int tithiNumber = 7,
    String paksha = 'Shukla',
    double rawTithi = 7.5,
    String masa = 'Shravana',
    DateTime? transitionTime,
    int? transitionTithiIndex,
  }) {
    return PanchangData(
      date: DateTime(2026, 9, 14),
      rawTithi: rawTithi,
      tithiNumber: tithiNumber,
      tithiName: '',
      paksha: paksha,
      masa: masa,
      tithiTransitionTime: transitionTime,
      transitionTithiIndex: transitionTithiIndex,
    );
  }

  HeroContent content(
    PanchangData panchang, {
    AppCalendarSystem primary = AppCalendarSystem.gregorian,
    AppCalendarSystem secondary = AppCalendarSystem.hindu,
    bool isToday = true,
  }) {
    return heroContentData(
      panchang: panchang,
      l10n: l10n,
      primarySystem: primary,
      secondarySystem: secondary,
      monthSystem: HinduMonthSystem.amanta,
      bengali: null,
      useBengaliScript: false,
      isToday: isToday,
    );
  }

  group('HeroContent tag line', () {
    test('collapses to Today when both systems match', () {
      // Arrange
      final panchang = day();

      // Act
      final c = content(
        panchang,
        secondary: AppCalendarSystem.gregorian,
      );

      // Assert
      expect(c.tagLabel, equals(l10n.today));
    });

    test('shows Selected for browsed dates', () {
      // Arrange
      final panchang = day();

      // Act
      final c = content(
        panchang,
        secondary: AppCalendarSystem.gregorian,
        isToday: false,
      );

      // Assert
      expect(c.tagLabel, equals(l10n.selected));
    });

    test('gregorian primary tag carries the compact date', () {
      // Arrange
      final panchang = day();

      // Act
      final c = content(panchang);

      // Assert
      expect(c.tagLabel, startsWith('${l10n.today} · '));
      expect(c.tagLabel, contains('2026'));
    });
  });

  group('HeroContent transition chips', () {
    test('no transition means no chips', () {
      // Arrange
      final panchang = day();

      // Act
      final c = content(panchang);

      // Assert
      expect(panchang.hasTithiTransition, isFalse);
      expect(c.chips, isEmpty);
      expect(c.artwork, isNull);
    });

    test('exiting transition yields a next-tithi chip with highlight', () {
      // Arrange: Saptami prevailing, Ashtami (index 8) takes over intraday.
      final panchang = day(
        transitionTime: DateTime(2026, 9, 14, 13, 2),
        transitionTithiIndex: 8,
      );

      // Act
      final c = content(panchang);

      // Assert
      expect(panchang.transitionExitsLabel, isTrue);
      expect(c.chips, hasLength(1));
      expect(c.chips.single.highlight, equals(l10n.tithiAshtami));
      expect(c.chips.single.inlineIcon, isTrue);
    });

    test('entered transition states when the tithi began', () {
      // Arrange: label already flipped to Ashtami (index 8 == 8).
      final panchang = day(
        tithiNumber: 8,
        transitionTime: DateTime(2026, 9, 14, 13, 2),
        transitionTithiIndex: 8,
      );

      // Act
      final c = content(panchang);

      // Assert
      expect(panchang.hasTithiTransition, isTrue);
      expect(panchang.transitionExitsLabel, isFalse);
      expect(c.chips, hasLength(1));
      expect(c.chips.single.highlight, isNull);
      expect(c.chips.single.text, contains(l10n.tithiAshtami));
    });
  });

  group('HeroContent secondary line', () {
    test('none secondary leaves weekday alone', () {
      // Arrange
      final panchang = day();

      // Act
      final c = content(panchang, secondary: AppCalendarSystem.none);

      // Assert
      expect(c.secondaryKind, equals(HeroSecondaryKind.none));
      expect(c.secondaryText, isNull);
      expect(c.weekday, isNotEmpty);
    });

    test('bengali secondary formats the resolved date', () {
      // Arrange
      final panchang = day();

      // Act
      final c = heroContentData(
        panchang: panchang,
        l10n: l10n,
        primarySystem: AppCalendarSystem.gregorian,
        secondarySystem: AppCalendarSystem.bengali,
        monthSystem: HinduMonthSystem.amanta,
        bengali: (day: 30, month: 'Bhadro', year: 1433),
        useBengaliScript: false,
        isToday: true,
      );

      // Assert
      expect(c.secondaryKind, equals(HeroSecondaryKind.bengali));
      expect(c.secondaryText, equals('30 Bhadro'));
    });

    test('illumination percent carries one decimal', () {
      // Arrange
      final panchang = day();

      // Act
      final c = content(panchang);

      // Assert
      expect(c.illuminationPct, matches(RegExp(r'^\d+\.\d$')));
      expect(c.title, contains(l10n.tithiSaptami));
      expect(c.subLabel, contains(l10n.waxing));
    });
  });
}
