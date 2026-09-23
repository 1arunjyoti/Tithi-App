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
          nameHindi: 'हिन्दी',
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
      expect(names, equals(['हिन्दी', 'বাংলা', 'తెలుగు']));
    });

    test('nameSanskrit treats empty strings as absent', () {
      // Arrange
      // ignore: prefer_const_constructors
      Festival withRegional(NameRegional regional) => Festival(
        id: 'f',
        name: 'F',
        nameRegional: regional,
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

      // Act + Assert
      expect(
        withRegional(
          const NameRegional(
            nameEnglish: 'F',
            nameSanskrith: 'गणेश चतुर्थी',
          ),
        ).nameSanskrit,
        equals('गणेश चतुर्थी'),
      );
      expect(
        withRegional(
          const NameRegional(nameEnglish: 'F', nameSanskrith: ''),
        ).nameSanskrit,
        isNull,
      );
    });

    test('festivalDisplayName follows the app language', () {
      // Arrange
      const regional = NameRegional(
        nameEnglish: 'Ganesh Chaturthi',
        nameSanskrith: 'गणेश चतुर्थी',
        nameHindi: 'गणेश चतुर्थी हिंदी',
        nameBengali: 'গণেশ চতুর্থী',
      );
      final f = festival();

      // Act + Assert: use a festival carrying each script name.
      // ignore: prefer_const_constructors
      final named = Festival(
        id: 'f',
        name: 'Ganesh Chaturthi',
        nameRegional: regional,
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
      expect(f.name, equals('Test Festival'));
      expect(
        festivalDisplayName(festival: named, locale: 'bn'),
        equals('গণেশ চতুর্থী'),
      );
      expect(
        festivalDisplayName(festival: named, locale: 'hi'),
        equals('गणेश चतुर्थी हिंदी'),
      );
      expect(
        festivalDisplayName(festival: named, locale: 'sa'),
        equals('गणेश चतुर्थी'),
      );
      expect(
        festivalDisplayName(festival: named, locale: 'en'),
        equals('Ganesh Chaturthi'),
      );
      // Unknown locales and missing names fall back to English.
      expect(
        festivalDisplayName(festival: named, locale: 'te'),
        equals('Ganesh Chaturthi'),
      );
      expect(
        festivalDisplayName(festival: f, locale: 'bn'),
        equals('Test Festival'),
      );
    });

    test('heroLanguageChips swaps the title language for English', () {
      // Arrange
      // ignore: prefer_const_constructors
      Festival named(NameRegional regional) => Festival(
        id: 'f',
        name: 'Ganesh Chaturthi',
        nameRegional: regional,
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
      final full = named(
        const NameRegional(
          nameEnglish: 'Ganesh Chaturthi',
          nameSanskrith: 'गणेश चतुर्थी',
          nameHindi: 'गणेश चतुर्थी हिंदी',
          nameBengali: 'গণেশ চতুর্থী',
          nameTelugu: 'వినాయక చవితి',
        ),
      );

      // Act + Assert
      // Bengali title: Bengali chip drops out, English leads.
      expect(
        heroLanguageChips(festival: full, locale: 'bn'),
        equals([
          'Ganesh Chaturthi',
          'गणेश चतुर्थी हिंदी',
          'వినాయక చవితి',
        ]),
      );
      // Hindi title: same swap for Hindi.
      expect(
        heroLanguageChips(festival: full, locale: 'hi'),
        equals(['Ganesh Chaturthi', 'গণেশ চতুর্থী', 'వినాయక చవితి']),
      );
      // English title: no English chip, regionals untouched.
      expect(
        heroLanguageChips(festival: full, locale: 'en'),
        equals(['गणेश चतुर्थी हिंदी', 'গণেশ চতুর্থী', 'వినాయక చవితి']),
      );
      // Missing Bengali name: title falls back to English, so no swap.
      final noBengali = named(
        const NameRegional(
          nameEnglish: 'Ganesh Chaturthi',
          nameHindi: 'गणेश चतुर्थी हिंदी',
        ),
      );
      expect(
        heroLanguageChips(festival: noBengali, locale: 'bn'),
        equals(['गणेश चतुर्थी हिंदी']),
      );
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

  group('observance banner', () {
    // ignore: prefer_const_constructors
    Festival ruled({
      String? timingOverride,
      String conditions = 'Lunar',
      int tithi = 4,
    }) => Festival(
      id: 'f',
      name: 'F',
      nameRegional: const NameRegional(nameEnglish: 'F'),
      visuals: const Visuals(),
      purpose: const Purpose(description: 'd'),
      panchangRules: PanchangRules(
        masa: 'Shravana',
        paksha: 'Shukla',
        tithi: tithi,
        conditions: conditions,
        timingOverride: timingOverride,
      ),
      rituals: const Rituals(steps: []),
      media: const Media(),
    );

    test('rule key defaults to udaya and passes known checkpoints through', () {
      // Arrange + Act + Assert
      expect(observanceRuleKey(ruled()), equals('udaya'));
      expect(observanceRuleKey(ruled(timingOverride: 'madhyahna')), equals('madhyahna'));
      expect(observanceRuleKey(ruled(timingOverride: 'aparahna')), equals('aparahna'));
      expect(observanceRuleKey(ruled(timingOverride: 'nishita')), equals('nishita'));
      // Unknown values fall back rather than rendering a wrong rule.
      expect(observanceRuleKey(ruled(timingOverride: 'bogus')), equals('udaya'));
    });

    test('rule label localizes with an English fallback', () {
      // Arrange + Act + Assert
      expect(
        observanceRuleLabel('madhyahna', l10n),
        equals('the tithi prevailing at Madhyahna (midday)'),
      );
      expect(
        observanceRuleLabel('aparahna', l10n),
        equals('the tithi prevailing at Aparahna (afternoon)'),
      );
      expect(
        observanceRuleLabel('udaya', null),
        equals('the tithi prevailing at sunrise'),
      );
      expect(
        observanceRuleLabel('bogus', null),
        equals('the tithi prevailing at sunrise'),
      );
    });

    test('banner shows for lunar festivals, even default udaya ones', () {
      // Arrange + Act + Assert
      expect(showsObservanceBanner(ruled()), isTrue);
      expect(
        showsObservanceBanner(ruled(timingOverride: 'madhyahna')),
        isTrue,
      );
    });

    test('banner hides where no tithi checkpoint applies', () {
      // Arrange + Act + Assert
      expect(showsObservanceBanner(ruled(conditions: 'Solar')), isFalse);
      expect(
        showsObservanceBanner(ruled(conditions: 'Mula Nakshatra')),
        isFalse,
      );
      expect(showsObservanceBanner(ruled(tithi: 0)), isFalse);
    });
  });
}
