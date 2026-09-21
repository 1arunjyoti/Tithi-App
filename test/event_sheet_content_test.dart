import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tithi/features/event_detail/domain/event_content.dart';
import 'package:tithi/l10n/app_localizations.dart';
import 'package:tithi/models/festival.dart';
import 'package:tithi/models/hindu_month_system.dart';
import 'package:tithi/models/panchang_data.dart';

void main() {
  late AppLocalizations l10n;

  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
  });

  Festival festival({
    String id = 'f1',
    String name = 'Test Festival',
    String masa = 'Shravana',
    String paksha = 'Shukla',
    int tithi = 4,
    String conditions = 'Lunar',
    String fasting = '',
    String mantra = '',
    String additionalDescription = '',
    List<String> steps = const [],
    String category = '',
  }) {
    return Festival(
      id: id,
      name: name,
      category: category,
      nameRegional: const NameRegional(nameEnglish: 'Test Festival'),
      visuals: const Visuals(),
      purpose: Purpose(
        description: 'A test festival.',
        additionalDescription: additionalDescription,
      ),
      panchangRules: PanchangRules(
        masa: masa,
        paksha: paksha,
        tithi: tithi,
        conditions: conditions,
      ),
      rituals: Rituals(
        steps: steps,
        mantra: mantra,
        fasting: fasting.isEmpty ? null : fasting,
      ),
      media: const Media(),
    );
  }

  PanchangData day({
    int tithiNumber = 4,
    String paksha = 'Shukla',
    double rawTithi = 4.5,
    String masa = 'Shravana',
  }) {
    return PanchangData(
      date: DateTime(2026, 8, 22),
      rawTithi: rawTithi,
      tithiNumber: tithiNumber,
      tithiName: '',
      paksha: paksha,
      masa: masa,
    );
  }

  group('observedTithi resolution', () {
    test('lunar festival follows its own tithi with timings', () {
      // Arrange
      final f = festival();
      final p = day();

      // Act
      final observed = observedTithi(festival: f, panchang: p);

      // Assert
      expect(observed.paksha, equals('Shukla'));
      expect(observed.index, equals(4));
      expect(observed.showTimings, isTrue);
      expect(observed.nakshatraObserved, isFalse);
    });

    test('solar festival stays day-based with no timings', () {
      // Arrange
      final f = festival(conditions: 'Solar');
      final p = day(tithiNumber: 10);

      // Act
      final observed = observedTithi(festival: f, panchang: p);

      // Assert
      expect(observed.paksha, equals(p.paksha));
      expect(observed.index, equals(p.tithiIndex));
      expect(observed.showTimings, isFalse);
    });

    test('nakshatra-observed festival stays day-based with no timings', () {
      // Arrange
      final f = festival(conditions: 'Mula Nakshatra');
      final p = day();

      // Act
      final observed = observedTithi(festival: f, panchang: p);

      // Assert
      expect(observed.nakshatraObserved, isTrue);
      expect(observed.showTimings, isFalse);
      expect(observed.index, equals(p.tithiIndex));
    });

    test('krishna observance maps to the 16-30 index', () {
      // Arrange
      final f = festival(paksha: 'Krishna', tithi: 8);
      final p = day(tithiNumber: 8, paksha: 'Krishna', rawTithi: 23.5);

      // Act
      final observed = observedTithi(festival: f, panchang: p);

      // Assert
      expect(observed.paksha, equals('Krishna'));
      expect(observed.index, equals(23));
    });
  });

  group('eventSheetContent labels', () {
    test('tithi label honors the display mode', () {
      // Arrange
      final f = festival(paksha: 'Krishna', tithi: 8);
      final p = day(tithiNumber: 8, paksha: 'Krishna', rawTithi: 23.5);

      // Act
      final pakshaBased = eventSheetContent(
        festival: f,
        panchang: p,
        monthSystem: HinduMonthSystem.amanta,
        continuousTithi: false,
        l10n: l10n,
      );
      final continuous = eventSheetContent(
        festival: f,
        panchang: p,
        monthSystem: HinduMonthSystem.amanta,
        continuousTithi: true,
        l10n: l10n,
      );

      // Assert
      expect(pakshaBased.displayTithiNum, equals(8));
      expect(continuous.displayTithiNum, equals(23));
      expect(continuous.tithiLabel, contains('23'));
      expect(continuous.pakshaLabel, contains('Krishna'));
    });

    test('empty masa and category fall back cleanly', () {
      // Arrange
      final f = festival();
      final p = day(masa: '');

      // Act
      final c = eventSheetContent(
        festival: f,
        panchang: p,
        monthSystem: HinduMonthSystem.amanta,
        continuousTithi: false,
        l10n: null,
      );

      // Assert
      expect(c.masaLabel, isNull);
      expect(c.categoryLabel, equals('General'));
      expect(c.tithiLabel, contains('T4'));
    });

    test('flags gate the optional sections', () {
      // Arrange
      final f = festival(
        fasting: 'No grains',
        mantra: 'Om',
        additionalDescription: 'More.',
        steps: ['Light a lamp'],
      );
      final p = day();

      // Act
      final c = eventSheetContent(
        festival: f,
        panchang: p,
        monthSystem: HinduMonthSystem.amanta,
        continuousTithi: false,
        l10n: l10n,
      );

      // Assert
      expect(c.hasFasting, isTrue);
      expect(c.hasMantra, isTrue);
      expect(c.hasAdditionalDesc, isTrue);
    });
  });

  group('label helpers', () {
    test('regionalNamesOf gathers set names in order', () {
      // Arrange
      // ignore: prefer_const_constructors
      final f = Festival(
        id: 'f',
        name: 'F',
        nameRegional: const NameRegional(
          nameEnglish: 'F',
          nameBengali: 'বাংলা',
          nameTelugu: 'తెలుగు',
        ),
        visuals: const Visuals(),
        purpose: const Purpose(description: 'd'),
        panchangRules: const PanchangRules(
          masa: 'Shravana',
          paksha: 'Shukla',
          tithi: 4,
          conditions: 'Lunar',
        ),
        rituals: const Rituals(steps: []),
        media: const Media(),
      );

      // Act
      final names = regionalNamesOf(f);

      // Assert
      expect(names, equals(['বাংলা', 'తెలుగు']));
    });

    test('capitalizedMasaLabel has no underscores', () {
      // Act
      final label = capitalizedMasaLabel(
        masa: 'Shravana',
        paksha: 'Shukla',
        monthSystem: HinduMonthSystem.amanta,
      );

      // Assert
      expect(label.contains('_'), isFalse);
      expect(label[0], equals(label[0].toUpperCase()));
    });

    test('ruleTithiLabel maps krishna in continuous mode', () {
      // Arrange
      final f = festival(paksha: 'Krishna', tithi: 8);

      // Act
      final continuous = ruleTithiLabel(
        festival: f,
        continuous: true,
        l10n: l10n,
      );
      final based = ruleTithiLabel(
        festival: f,
        continuous: false,
        l10n: l10n,
      );
      final noL10n = ruleTithiLabel(
        festival: f,
        continuous: false,
        l10n: null,
      );

      // Assert
      expect(continuous, contains('23'));
      expect(based, contains('8'));
      expect(noL10n, equals('Tithi 8'));
    });
  });
}
