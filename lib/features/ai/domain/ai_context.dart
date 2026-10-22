import '../../../models/festival.dart';
import '../../../models/hindu_month_system.dart';
import '../../../models/panchang_data.dart';
import '../../../services/auspicious_timings.dart';
import '../../../services/inauspicious_timings.dart';

// Serialises panchang values Tithi has ALREADY computed into the compact
// block that is handed to an external AI app.
//
// HARD RULE: every line below comes from [PanchangData] / [Festival], from a
// value Tithi computed elsewhere ([AuspiciousTimings], [InauspiciousTimings])
// or from the user's own settings ([HinduMonthSystem]). This file must never
// derive a tithi boundary, muhurta window or any other timing. The assistant
// explains these numbers; it does not produce them.
//
// The Conventions line exists because the same day is named differently by
// different traditions: an assistant told only "Masa: Ashwin" answers as if
// Amanta + Lahiri were universal, and a Purnimant user gets a confident wrong
// answer. Naming the convention lets it explain the difference instead.
//
// The block is written in English on purpose: the canonical names are what a
// model reasons over most reliably, and the prompt carries an explicit
// "answer in <language>" instruction so the reply still matches the app
// language (see `ai_prompt.dart`).
//
// Everything here is pure (no BuildContext, no I/O) so the payload can be
// golden-tested and so a future AppFunctions bridge can reuse it verbatim.

// English date formatting for the payload, hand-rolled on purpose:
//   * `intl` needs `initializeDateFormatting('en')` before use, which would
//     make this pure module depend on bootstrap order (and silently throw in
//     unit tests);
//   * the payload must not follow the app locale, or a Hindi user would send
//     localized month names the model then has to translate.
// The string output is pinned by tests.

const List<String> _weekdayShort = [
  'Mon',
  'Tue',
  'Wed',
  'Thu',
  'Fri',
  'Sat',
  'Sun',
];

const List<String> _monthShort = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

const List<String> _monthLong = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

/// Maximum number of ritual steps passed through for a festival.
const int kAiFestivalRitualLimit = 6;

String _twoDigits(int value) => value.toString().padLeft(2, '0');

String _dateLine(DateTime date) =>
    '${_weekdayShort[date.weekday - 1]}, ${date.day} '
    '${_monthShort[date.month - 1]} ${date.year}';

String _shortDate(DateTime date) =>
    '${date.day} ${_monthShort[date.month - 1]}';

String _monthLabel(DateTime date) =>
    '${_monthLong[date.month - 1]} ${date.year}';

String _timeOrUnknown(DateTime? time) => time == null
    ? 'unknown'
    : '${_twoDigits(time.hour)}:${_twoDigits(time.minute)}';

String _pakshaDescription(String paksha) => switch (paksha) {
  'Shukla' => 'the waxing fortnight',
  'Krishna' => 'the waning fortnight',
  _ => paksha,
};

/// How the user's chosen month system names masa, in canonical English.
String _monthSystemHint(HinduMonthSystem system) => switch (system) {
  HinduMonthSystem.amanta => 'Amanta month system (months end at Amavasya)',
  HinduMonthSystem.purnimant =>
    'Purnimant month system (months end at Purnima)',
};

/// The "Conventions:" line: what the numbers below assume.
///
/// `null` is for payloads that carry no masa (the month digest), where naming
/// the month system would only add a fact the reader cannot use.
String _conventionsLine(HinduMonthSystem? monthSystem) {
  final parts = <String>[
    if (monthSystem != null) _monthSystemHint(monthSystem),
    if (monthSystem == null)
      'tithis are taken at sunrise'
    else
      'tithi, nakshatra and masa are taken at sunrise',
    'Swiss Ephemeris with Lahiri ayanamsa',
  ];
  return 'Conventions: ${parts.join('; ')}.';
}

String _window(({DateTime start, DateTime end}) window) =>
    '${_timeOrUnknown(window.start)}-${_timeOrUnknown(window.end)}';

/// The auspicious windows Tithi already shows in the tithi sheet.
///
/// Passed in rather than calculated here: this file only serialises. Abhijit
/// carries its weekday caveat so the assistant cannot present a window the app
/// itself marks as avoided that day. Order is chronological by start, with
/// Nishita last because it falls after midnight.
List<String> _timingLines(DateTime date, AuspiciousTimings timings) {
  return <String>[
    'Auspicious timings (computed by Tithi):',
    '- Brahma muhurta: ${_window(timings.brahmaMuhurta)}',
    '- Madhyahna: ${_window(timings.madhyahnaWindow)}',
    '- Abhijit muhurta: ${_window(timings.abhijit)}'
        '${AuspiciousTimings.abhijitAvoided(date) ? ' (avoided on Wednesdays)' : ''}',
    '- Godhuli: ${_window(timings.godhuli)}',
    '- Pradosha: ${_window(timings.pradosha)}',
    '- Nishita: ${_window(timings.nishita)}',
  ];
}

/// The day's "avoid starting new work" windows, in chronological order.
///
/// Same rationale as the auspicious block: without these the assistant answers
/// "is 3pm a good time?" from general knowledge, which is exactly the guess
/// this feature exists to replace.
List<String> _inauspiciousLines(InauspiciousTimings timings) {
  final windows = <(String, ({DateTime start, DateTime end}))>[
    ('Rahu Kalam', timings.rahu),
    ('Yamaganda', timings.yamaganda),
    ('Gulika Kalam', timings.gulika),
  ]..sort((a, b) => a.$2.start.compareTo(b.$2.start));

  return <String>[
    'Inauspicious timings (computed by Tithi; avoid starting new work):',
    for (final (label, window) in windows) '- $label: ${_window(window)}',
  ];
}

/// Strips the surrounding whitespace and collapses internal newlines so a
/// multi-paragraph description stays one readable line in the preview.
String _oneLine(String value) {
  return value.replaceAll(RegExp(r'\s+'), ' ').trim();
}

/// "Tithi, paksha and a one-line note when a boundary falls inside the day."
String _tithiDescription(PanchangData panchang) {
  if (!panchang.isShukla && !panchang.isKrishna) return panchang.tithiName;
  return '${panchang.paksha} ${panchang.tithiName} — '
      '${panchang.tithiNumber} of 15 in '
      '${_pakshaDescription(panchang.paksha)}';
}

String _festivalNames(Iterable<Festival> festivals) {
  final names = festivals
      .map((festival) => _oneLine(festival.name))
      .where((name) => name.isNotEmpty)
      .toList();
  return names.isEmpty ? 'none' : names.join(', ');
}

String _joinNonEmpty(List<String> lines) {
  return lines.where((line) => line.trim().isNotEmpty).join('\n');
}

/// Context block for a single day.
///
/// [heading] lets callers distinguish "today" from a past/future date without
/// duplicating the body. [timings] and [inauspicious] are what the tithi sheet
/// already computed; pass them whenever they exist so timing questions are
/// answered from Tithi's numbers instead of the model's general knowledge.
String buildDayContext({
  required PanchangData panchang,
  required String city,
  required String timeZone,
  required HinduMonthSystem monthSystem,
  AuspiciousTimings? timings,
  InauspiciousTimings? inauspicious,
  String heading = "Today's panchang (calculated offline by Tithi)",
}) {
  final lines = <String>[
    heading,
    'Date: ${_dateLine(panchang.date)}',
    'City: $city',
    'Time zone: $timeZone',
    _conventionsLine(monthSystem),
    'Tithi: ${_tithiDescription(panchang)}',
  ];

  if (panchang.masa.isNotEmpty) {
    lines.add('Masa: ${panchang.masa}');
  }
  if (panchang.nakshatra != null && panchang.nakshatra!.isNotEmpty) {
    lines.add('Nakshatra at sunrise: ${panchang.nakshatra}');
  }

  lines
    ..add('Sunrise: ${_timeOrUnknown(panchang.sunrise)}')
    ..add('Sunset: ${_timeOrUnknown(panchang.sunset)}');

  // Only when the transition EXITS the displayed label: after a live flip the
  // stored instant is the label's start, and wording it as an "end" would be
  // wrong (see PanchangData.transitionExitsLabel).
  if (panchang.transitionExitsLabel) {
    final end = panchang.tithiTransitionTime;
    if (end != null) {
      lines.add(
        'Tithi change: ${panchang.tithiName} ends at '
        '${_timeOrUnknown(end)}, '
        '${panchang.transitionTithiName} begins',
      );
    }
  }

  if (timings != null) lines.addAll(_timingLines(panchang.date, timings));
  if (inauspicious != null) lines.addAll(_inauspiciousLines(inauspicious));

  lines.add('Festivals: ${_festivalNames(panchang.festivals)}');
  return _joinNonEmpty(lines);
}

/// Context block for a festival, optionally anchored to the day it falls on.
///
/// The curated description and rituals are included so the assistant grounds
/// its answer in Tithi's own text instead of generic web folklore.
String buildFestivalContext({
  required Festival festival,
  required String city,
  required String timeZone,
  required HinduMonthSystem monthSystem,
  PanchangData? panchang,
}) {
  final lines = <String>[
    'Festival: ${_oneLine(festival.name)}',
    if (festival.category.isNotEmpty) 'Category: ${festival.category}',
    if (panchang != null) 'Date: ${_dateLine(panchang.date)}',
    'City: $city',
    'Time zone: $timeZone',
    _conventionsLine(monthSystem),
  ];

  if (panchang != null) {
    lines
      ..add('Tithi that day: ${_tithiDescription(panchang)}')
      ..add('Sunrise: ${_timeOrUnknown(panchang.sunrise)}')
      ..add('Sunset: ${_timeOrUnknown(panchang.sunset)}');
    // "Why is it on this date?" is a masa question; the name alone is
    // ambiguous without the convention stated above.
    if (panchang.masa.isNotEmpty) {
      lines.add('Masa that day: ${panchang.masa}');
    }
  }

  final description = _oneLine(festival.purpose.description);
  if (description.isNotEmpty) {
    lines.add("About (from Tithi's festival data): $description");
  }

  final additional = _oneLine(festival.purpose.additionalDescription);
  if (additional.isNotEmpty) {
    lines.add('More: $additional');
  }

  final steps = festival.rituals.steps
      .map(_oneLine)
      .where((step) => step.isNotEmpty)
      .take(kAiFestivalRitualLimit)
      .toList();
  if (steps.isNotEmpty) {
    lines.add('Observance: ${steps.join('; ')}');
  }

  final fasting = _oneLine(festival.rituals.fasting ?? '');
  if (fasting.isNotEmpty) {
    lines.add('Fasting: $fasting');
  }

  final mantra = _oneLine(festival.rituals.mantra);
  if (mantra.isNotEmpty) {
    lines.add('Mantra: $mantra');
  }

  return _joinNonEmpty(lines);
}

/// Context block for a whole month: festivals first, then the notable tithis
/// (Purnima, Amavasya, Ekadashi) a reader plans around.
///
/// [days] is expected to be the month's calendar days (the same collection
/// `monthlyPanchangProvider` publishes). Ordering is normalised here so the
/// digest is stable regardless of the caller's iteration order.
String buildMonthContext({
  required DateTime month,
  required Iterable<PanchangData> days,
  required String city,
  required String timeZone,
}) {
  final sorted = days.toList()..sort((a, b) => a.date.compareTo(b.date));

  // Keep the digest inside the requested month: the calendar collection also
  // carries the neighbouring months' overflow days that fill the grid.
  final inMonth = sorted
      .where((day) => day.date.year == month.year && day.date.month == month.month)
      .toList();

  final festivals = <String>[];
  for (final day in inMonth) {
    for (final festival in day.festivals) {
      final name = _oneLine(festival.name);
      if (name.isEmpty) continue;
      festivals.add(
        '- ${_shortDate(day.date)}: $name '
        '(${day.paksha} ${day.tithiName})',
      );
    }
  }

  final purnima = <String>[];
  final amavasya = <String>[];
  final ekadashi = <String>[];
  for (final day in inMonth) {
    final label = _shortDate(day.date);
    switch (day.tithiIndex) {
      case 15:
        purnima.add(label);
      case 30:
        amavasya.add(label);
      case 11:
      case 26:
        ekadashi.add(label);
    }
  }

  final tithis = <String>[
    if (purnima.isNotEmpty) '- Purnima: ${purnima.join(', ')}',
    if (amavasya.isNotEmpty) '- Amavasya: ${amavasya.join(', ')}',
    if (ekadashi.isNotEmpty) '- Ekadashi: ${ekadashi.join(', ')}',
  ];

  return _joinNonEmpty([
    'Month: ${_monthLabel(month)}',
    'City: $city',
    'Time zone: $timeZone',
    _conventionsLine(null),
    'Festivals this month:',
    if (festivals.isEmpty) '- none' else ...festivals,
    'Notable tithis:',
    if (tithis.isEmpty) '- none' else ...tithis,
  ]);
}
