import 'package:flutter_test/flutter_test.dart';
import 'package:tithi/features/ai/domain/ai_context.dart';
import 'package:tithi/features/ai/domain/ai_prompt.dart';
import 'package:tithi/models/festival.dart';
import 'package:tithi/models/hindu_month_system.dart';
import 'package:tithi/models/panchang_data.dart';
import 'package:tithi/services/auspicious_timings.dart';
import 'package:tithi/services/inauspicious_timings.dart';

// The AI hand-off hands a string to a third-party app. These tests pin two
// promises made to the user in the consent dialog:
//   1. the payload never contains coordinates, and
//   2. the payload carries only values Tithi computed (no invented timings).

PanchangData _day({
  DateTime? date,
  String paksha = 'Shukla',
  int tithiNumber = 3,
  double rawTithi = 3.2,
  String? nakshatra = 'Rohini',
  DateTime? tithiTransitionTime,
  int? transitionTithiIndex,
  List<Festival> festivals = const [],
}) {
  final day = date ?? DateTime(2026, 10, 24);
  return PanchangData(
    date: day,
    rawTithi: rawTithi,
    tithiNumber: tithiNumber,
    tithiName: PanchangData.tithiNameFor(tithiNumber, paksha),
    paksha: paksha,
    masa: 'Ashwin',
    festivals: festivals,
    sunrise: DateTime(day.year, day.month, day.day, 6, 34),
    sunset: DateTime(day.year, day.month, day.day, 18, 12),
    nakshatra: nakshatra,
    tithiTransitionTime: tithiTransitionTime,
    transitionTithiIndex: transitionTithiIndex,
  );
}

Festival _festival({
  String name = 'Diwali',
  String description = 'The festival of lights.',
  String additionalDescription = '',
  List<String> steps = const ['Light diyas', 'Offer sweets'],
  String? fasting,
  String mantra = '',
}) {
  return Festival.fromJson({
    'id': 'diwali',
    'name': name,
    'category': 'major',
    'purpose': {
      'description': description,
      'additional_description': additionalDescription,
    },
    'rituals': {
      'steps': steps,
      'mantra': mantra,
      'fasting': fasting,
    },
  });
}

/// Fixed windows so the payload assertions do not depend on the arithmetic
/// (which `auspicious_timings_test.dart` already pins).
AuspiciousTimings _timings({required DateTime day}) {
  DateTime at(int hour, int minute) =>
      DateTime(day.year, day.month, day.day, hour, minute);
  return AuspiciousTimings(
    abhijit: (start: at(11, 52), end: at(12, 26)),
    brahmaMuhurta: (start: at(4, 40), end: at(5, 25)),
    madhyahnaInstant: at(12, 23),
    madhyahnaWindow: (start: at(11, 32), end: at(12, 52)),
    nishita: (start: at(0, 2), end: at(0, 45)),
    godhuli: (start: at(18, 12), end: at(18, 28)),
    pradosha: (start: at(18, 12), end: at(19, 24)),
  );
}

/// Explicit boundaries (9 of them, so segments are stable) in a deliberately
/// non-chronological assignment: Rahu 2nd, Yamaganda 4th, Gulika 3rd.
InauspiciousTimings _inauspicious({required DateTime day}) {
  DateTime at(int hour, int minute) =>
      DateTime(day.year, day.month, day.day, hour, minute);
  return InauspiciousTimings(
    sunrise: at(6, 34),
    sunset: at(18, 12),
    boundaries: [
      at(6, 34),
      at(8, 2),
      at(9, 30),
      at(10, 58),
      at(12, 26),
      at(13, 54),
      at(15, 22),
      at(16, 50),
      at(18, 12),
    ],
    rahuSegment: 2,
    yamagandaSegment: 4,
    gulikaSegment: 3,
  );
}

void main() {
  group('buildDayContext', () {
    test('carries the computed panchang fields', () {
      final context = buildDayContext(
        panchang: _day(),
        city: 'Pune',
        timeZone: 'Asia/Kolkata',
        monthSystem: HinduMonthSystem.amanta,
      );

      expect(context, contains('Date: Sat, 24 Oct 2026'));
      expect(context, contains('City: Pune'));
      expect(context, contains('Time zone: Asia/Kolkata'));
      expect(context, contains('Shukla Tritiya'));
      expect(context, contains('Nakshatra at sunrise: Rohini'));
      expect(context, contains('Sunrise: 06:34'));
      expect(context, contains('Sunset: 18:12'));
      expect(context, contains('Festivals: none'));
    });

    test('never contains coordinates', () {
      final context = buildDayContext(
        panchang: _day(),
        city: 'Pune',
        timeZone: 'Asia/Kolkata',
        monthSystem: HinduMonthSystem.amanta,
      );

      // A decimal with four or more places is how a lat/long would leak in.
      expect(RegExp(r'\d+\.\d{4,}').hasMatch(context), isFalse);
    });

    test('omits nakshatra when the day has none', () {
      final context = buildDayContext(
        panchang: _day(nakshatra: null),
        city: 'Pune',
        timeZone: 'Asia/Kolkata',
        monthSystem: HinduMonthSystem.amanta,
        heading: 'Panchang (calculated offline by Tithi)',
      );

      expect(context, isNot(contains('Nakshatra')));
    });

    test('names the tithi boundary only when it ends the displayed label', () {
      final exiting = buildDayContext(
        panchang: _day(
          tithiTransitionTime: DateTime(2026, 10, 24, 15, 42),
          transitionTithiIndex: 4,
        ),
        city: 'Pune',
        timeZone: 'Asia/Kolkata',
        monthSystem: HinduMonthSystem.amanta,
      );
      expect(exiting, contains('Tritiya ends at 15:42, Chaturthi begins'));

      // Same stored instant, but the label already flipped to Chaturthi: the
      // instant is the label's beginning, so no "ends" line is allowed.
      final entering = buildDayContext(
        panchang: _day(
          tithiNumber: 4,
          tithiTransitionTime: DateTime(2026, 10, 24, 15, 42),
          transitionTithiIndex: 4,
        ),
        city: 'Pune',
        timeZone: 'Asia/Kolkata',
        monthSystem: HinduMonthSystem.amanta,
      );
      expect(entering, isNot(contains('Tithi change')));
    });

    test('lists the day\'s festivals', () {
      final context = buildDayContext(
        panchang: _day(festivals: [_festival()]),
        city: 'Pune',
        timeZone: 'Asia/Kolkata',
        monthSystem: HinduMonthSystem.amanta,
      );

      expect(context, contains('Festivals: Diwali'));
    });

    test('states the conventions the numbers were computed with', () {
      final amanta = buildDayContext(
        panchang: _day(),
        city: 'Pune',
        timeZone: 'Asia/Kolkata',
        monthSystem: HinduMonthSystem.amanta,
      );
      expect(amanta, contains('Amanta month system (months end at Amavasya)'));
      expect(amanta, contains('taken at sunrise'));
      expect(amanta, contains('Swiss Ephemeris with Lahiri ayanamsa'));

      // The same day is named differently by the other system; the assistant
      // must be told which one produced the masa.
      final purnimant = buildDayContext(
        panchang: _day(),
        city: 'Pune',
        timeZone: 'Asia/Kolkata',
        monthSystem: HinduMonthSystem.purnimant,
      );
      expect(
        purnimant,
        contains('Purnimant month system (months end at Purnima)'),
      );
      expect(purnimant, isNot(contains('Amanta')));
    });

    test('carries the auspicious windows the sheet already computed', () {
      final context = buildDayContext(
        panchang: _day(),
        city: 'Pune',
        timeZone: 'Asia/Kolkata',
        monthSystem: HinduMonthSystem.amanta,
        timings: _timings(day: DateTime(2026, 10, 24)),
      );

      expect(context, contains('Auspicious timings (computed by Tithi):'));
      expect(context, contains('- Abhijit muhurta: 11:52-12:26'));
      expect(context, contains('- Brahma muhurta: 04:40-05:25'));
      expect(context, contains('- Madhyahna: 11:32-12:52'));
      expect(context, contains('- Godhuli: 18:12-18:28'));
      expect(context, contains('- Pradosha: 18:12-19:24'));
      expect(context, contains('- Nishita: 00:02-00:45'));
      // 24 Oct 2026 is a Saturday: no caveat.
      expect(context, isNot(contains('avoided on Wednesdays')));
    });

    test('marks Abhijit as avoided on its weekday instead of offering it', () {
      // 21 Oct 2026 is a Wednesday.
      final context = buildDayContext(
        panchang: _day(date: DateTime(2026, 10, 21)),
        city: 'Pune',
        timeZone: 'Asia/Kolkata',
        monthSystem: HinduMonthSystem.amanta,
        timings: _timings(day: DateTime(2026, 10, 21)),
      );

      expect(context, contains('(avoided on Wednesdays)'));
    });

    test('carries the inauspicious windows in chronological order', () {
      final context = buildDayContext(
        panchang: _day(),
        city: 'Pune',
        timeZone: 'Asia/Kolkata',
        monthSystem: HinduMonthSystem.amanta,
        inauspicious: _inauspicious(day: DateTime(2026, 10, 24)),
      );

      expect(
        context,
        contains(
          'Inauspicious timings (computed by Tithi; avoid starting new work):',
        ),
      );
      expect(context, contains('- Rahu Kalam: 08:02-09:30'));
      expect(context, contains('- Gulika Kalam: 09:30-10:58'));
      expect(context, contains('- Yamaganda: 10:58-12:26'));

      // Segment numbers are weekday tables, not times: the payload sorts by
      // start so the list reads as a timeline.
      expect(
        context.indexOf('- Rahu Kalam'),
        lessThan(context.indexOf('- Gulika Kalam')),
      );
      expect(
        context.indexOf('- Gulika Kalam'),
        lessThan(context.indexOf('- Yamaganda')),
      );
    });

    test('omits timings when the caller has none', () {
      final context = buildDayContext(
        panchang: _day(),
        city: 'Pune',
        timeZone: 'Asia/Kolkata',
        monthSystem: HinduMonthSystem.amanta,
      );

      expect(context, isNot(contains('Auspicious timings')));
      expect(context, isNot(contains('Inauspicious timings')));
    });
  });

  group('buildFestivalContext', () {
    test('grounds the answer in the curated description and rituals', () {
      final context = buildFestivalContext(
        festival: _festival(
          additionalDescription: 'Also known as Deepavali.',
          fasting: 'Some observe a partial fast.',
          mantra: 'Om Sri Lakshmyai Namah',
        ),
        panchang: _day(paksha: 'Krishna', tithiNumber: 15, rawTithi: 29.9),
        city: 'Pune',
        timeZone: 'Asia/Kolkata',
        monthSystem: HinduMonthSystem.amanta,
      );

      expect(context, contains('Festival: Diwali'));
      expect(context, contains("About (from Tithi's festival data): The festival of lights."));
      expect(context, contains('More: Also known as Deepavali.'));
      expect(context, contains('Observance: Light diyas; Offer sweets'));
      expect(context, contains('Fasting: Some observe a partial fast.'));
      expect(context, contains('Mantra: Om Sri Lakshmyai Namah'));
      // The anchor day's panchang is included so "when" is never guessed.
      expect(context, contains('Krishna Amavasya'));
      // ... and so is the masa plus the convention that named it.
      expect(context, contains('Masa that day: Ashwin'));
      expect(context, contains('Amanta month system'));
    });

    test('drops empty optional fields instead of emitting blank labels', () {
      final context = buildFestivalContext(
        festival: _festival(steps: const []),
        city: 'Pune',
        timeZone: 'Asia/Kolkata',
        monthSystem: HinduMonthSystem.amanta,
      );

      expect(context, isNot(contains('Observance:')));
      expect(context, isNot(contains('Fasting:')));
      expect(context, isNot(contains('Mantra:')));
      expect(context, isNot(contains('More:')));
      // No panchang passed: no date/tithi lines either.
      expect(context, isNot(contains('Tithi that day:')));
      expect(context, isNot(contains('Date:')));
    });

    test('caps ritual steps so the prompt stays short', () {
      final context = buildFestivalContext(
        festival: _festival(
          steps: List<String>.generate(12, (i) => 'Step $i'),
        ),
        city: 'Pune',
        timeZone: 'Asia/Kolkata',
        monthSystem: HinduMonthSystem.amanta,
      );

      expect(context, contains('Step 5'));
      expect(context, isNot(contains('Step 6')));
    });
  });

  group('buildMonthContext', () {
    test('keeps only the requested month and lists notable tithis', () {
      final days = [
        _day(date: DateTime(2026, 10, 31)), // previous-month grid overflow
        _day(
          date: DateTime(2026, 11, 5),
          tithiNumber: 15,
          rawTithi: 14.9,
        ),
        _day(
          date: DateTime(2026, 11, 20),
          paksha: 'Krishna',
          tithiNumber: 15,
          rawTithi: 29.9,
        ),
        _day(
          date: DateTime(2026, 11, 15),
          tithiNumber: 11,
          rawTithi: 10.9,
          festivals: [_festival()],
        ),
      ];

      final context = buildMonthContext(
        month: DateTime(2026, 11),
        days: days,
        city: 'Pune',
        timeZone: 'Asia/Kolkata',
      );

      expect(context, contains('Month: November 2026'));
      expect(context, contains('- 15 Nov: Diwali'));
      expect(context, contains('- Purnima: 5 Nov'));
      expect(context, contains('- Amavasya: 20 Nov'));
      expect(context, contains('- Ekadashi: 15 Nov'));
      // The October overflow day must not appear anywhere.
      expect(context, isNot(contains('31 Oct')));
    });

    test('says none when the month has nothing to report', () {
      final context = buildMonthContext(
        month: DateTime(2026, 11),
        days: const [],
        city: 'Pune',
        timeZone: 'Asia/Kolkata',
      );

      expect(context, contains('Festivals this month:\n- none'));
      expect(context, contains('Notable tithis:\n- none'));
    });

    test('lists every festival in the month, including minor vrats', () {
      // Regression: a cap used to truncate the digest at 15 entries, so a
      // busy month (Ashwin has 28 entries in the shipped data) silently lost
      // festivals. Completeness wins over prompt brevity.
      final days = <PanchangData>[
        for (var day = 1; day <= 25; day++)
          _day(
            date: DateTime(2026, 11, day),
            festivals: [_festival(name: 'Festival $day')],
          ),
      ];

      final context = buildMonthContext(
        month: DateTime(2026, 11),
        days: days,
        city: 'Pune',
        timeZone: 'Asia/Kolkata',
      );

      for (var day = 1; day <= 25; day++) {
        expect(context, contains('Festival $day (Shukla Tritiya)'));
      }
      expect(context, contains('- 25 Nov: Festival 25'));
    });

    test('preserves the panchang order for same-day festivals', () {
      final days = <PanchangData>[
        _day(
          date: DateTime(2026, 11, 8),
          festivals: [
            _festival(name: 'Lakshmi Puja'),
            _festival(),
          ],
        ),
      ];

      final context = buildMonthContext(
        month: DateTime(2026, 11),
        days: days,
        city: 'Pune',
        timeZone: 'Asia/Kolkata',
      );

      expect(
        context.indexOf('Lakshmi Puja'),
        lessThan(context.indexOf('- 8 Nov: Diwali')),
      );
    });

    test('names the ephemeris conventions but no month system', () {
      final context = buildMonthContext(
        month: DateTime(2026, 11),
        days: const [],
        city: 'Pune',
        timeZone: 'Asia/Kolkata',
      );

      // The digest carries no masa, so naming the month system would only be a
      // fact the reader cannot use.
      expect(context, contains('tithis are taken at sunrise'));
      expect(context, contains('Swiss Ephemeris with Lahiri ayanamsa'));
      expect(context, isNot(contains('month system')));
    });
  });

  group('buildAiPrompt', () {
    test('wraps the context, keeps the question and asks for the language', () {
      final prompt = buildAiPrompt(
        intent: AiIntent.todayPanchang,
        context: 'Date: Sat, 24 Oct 2026\nTithi: Shukla Tritiya',
        languageName: 'Hindi',
        question: 'Can I do puja at 7pm?',
      );

      expect(prompt, contains('--- PANCHANG DATA'));
      expect(prompt, contains('Tithi: Shukla Tritiya'));
      expect(prompt, contains('--- END PANCHANG DATA ---'));
      expect(prompt, contains('Question: Can I do puja at 7pm?'));
      expect(prompt.trimRight(), endsWith('Answer in Hindi.'));
      // The anti-hallucination rule must travel with every prompt.
      expect(prompt, contains('Do not invent'));
      expect(prompt, contains('do not replace them'));
      // ... and so must the "do not present Tithi's convention as universal"
      // rule (the payload now carries a Conventions line for it to refer to).
      expect(prompt, contains('If the user follows a different tradition'));
    });

    test('omits the question line when the field is blank', () {
      final prompt = buildAiPrompt(
        intent: AiIntent.monthDigest,
        context: 'Month: November 2026',
        languageName: 'English',
        question: '   ',
      );

      expect(prompt, isNot(contains('Question:')));
      expect(prompt.trimRight(), endsWith('Answer in English.'));
    });

    test('uses an intent-specific instruction', () {
      final festival = buildAiPrompt(
        intent: AiIntent.festival,
        context: 'Festival: Diwali',
        languageName: 'Bengali',
      );

      expect(festival, contains('Help the user understand this festival'));
      expect(festival.trimRight(), endsWith('Answer in Bengali.'));
    });

    test('maps locale codes to the assistant language name', () {
      expect(aiLanguageName('en'), 'English');
      expect(aiLanguageName('hi'), 'Hindi');
      expect(aiLanguageName('bn'), 'Bengali');
      expect(aiLanguageName('sa'), 'Sanskrit');
      expect(aiLanguageName('fr'), 'English');
    });
  });
}
