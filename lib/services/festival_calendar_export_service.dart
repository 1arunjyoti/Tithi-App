import 'dart:convert';

/// Builds an iCalendar (RFC 5545) file of festival dates from the document
/// produced by [FestivalExportService.exportYear].
///
/// Every festival with a resolved occurrence becomes one all-day event on its
/// observance date. The Panchang timings computed for that date (tithi span,
/// sunrise/sunset) go in the event description rather than as a timed event:
/// a tithi can cross midnight and the wall-clock instants are tied to the
/// coordinates recorded in the export, so an all-day event keeps the calendar
/// view correct in every timezone while still carrying the "festival timing"
/// details when the event is opened.
///
/// The builder is pure and has no Flutter/plugin dependencies so it can be
/// unit-tested without a device. Google Calendar imports the resulting `.ics`
/// file through "Create → Import & link" (or by opening the shared file).
class FestivalCalendarExportService {
  FestivalCalendarExportService();

  static const _prodId = '-//Tithi//Tithi Festival Calendar//EN';
  static const _calendarName = 'Tithi Festivals';
  static const _source = 'Source: Tithi - Vedic Calendar';

  /// Maximum bytes per physical line, per RFC 5545. Continuation lines start
  /// with a single space, which counts towards the limit.
  static const _maxLineBytes = 75;

  /// Builds the complete `.ics` document from [document].
  ///
  /// [now] is injectable so tests get a stable DTSTAMP. Pass a UTC value; an
  /// unspecified value uses the current UTC time. Malformed entries are
  /// skipped rather than throwing: one bad festival cannot discard the rest
  /// of the calendar.
  String buildIcs(Map<String, dynamic> document, {DateTime? now}) {
    final year = document['year'] ?? DateTime.now().year;
    final stamp = _formatStamp((now ?? DateTime.now()).toUtc());

    final lines = <String>[
      'BEGIN:VCALENDAR',
      'VERSION:2.0',
      'PRODID:$_prodId',
      'CALSCALE:GREGORIAN',
      'METHOD:PUBLISH',
      'X-WR-CALNAME:${_escapeText('$_calendarName $year')}',
    ];

    // UID uses the festival's position in the catalog, not the count of events
    // emitted so far: if an earlier festival loses its occurrence after a data
    // update, existing events keep their UIDs and re-import does not duplicate.
    final events = _events(document);
    for (final event in events) {
      // All-day events use an exclusive end date, hence +1 day.
      final dtend = event.date.add(const Duration(days: 1));

      lines
        ..add('BEGIN:VEVENT')
        ..add('UID:${_safeUid(event.id, year, event.sourceIndex)}')
        ..add('DTSTAMP:$stamp')
        ..add('DTSTART;VALUE=DATE:${_formatDay(event.date)}')
        ..add('DTEND;VALUE=DATE:${_formatDay(dtend)}')
        ..add('SUMMARY:${_escapeText(event.name)}')
        ..add('DESCRIPTION:${event.description}')
        ..add('TRANSP:TRANSPARENT');
      final category = event.category;
      if (category != null && category.isNotEmpty) {
        lines.add('CATEGORIES:${_escapeText(category)}');
      }
      lines.add('END:VEVENT');
    }

    lines.add('END:VCALENDAR');
    // CRLF everywhere, folded to 75 octets, with a trailing line break.
    return '${lines.map(_fold).expand((part) => part).join('\r\n')}\r\n';
  }

  /// Number of festivals that will actually produce an event. The settings UI
  /// uses this instead of the raw festival count so a year with no resolvable
  /// dates does not report a misleading success count. Counts rows directly
  /// rather than building descriptions just to throw them away.
  static int countEvents(Map<String, dynamic> document) {
    final rawFestivals = document['festivals'];
    if (rawFestivals is! List) return 0;
    var count = 0;
    for (final raw in rawFestivals) {
      final occurrence = _stringMap(_stringMap(raw)['occurrence']);
      if (_parseDay(_string(occurrence['date'])) != null) count++;
    }
    return count;
  }

  /// Extracts only well-formed rows. Every value read from the document goes
  /// through [_stringMap]/[_string], so unexpected types (a JSON decoder can
  /// produce `Map<dynamic, dynamic>`) never throw a cast error here.
  static List<_CalendarEvent> _events(Map<String, dynamic> document) {
    final rawFestivals = document['festivals'];
    if (rawFestivals is! List) return const <_CalendarEvent>[];

    final events = <_CalendarEvent>[];
    for (var i = 0; i < rawFestivals.length; i++) {
      final entry = _stringMap(rawFestivals[i]);
      final occurrence = _stringMap(entry['occurrence']);
      final date = _parseDay(_string(occurrence['date']));
      if (date == null) continue;

      final rawName = _string(entry['name']);
      final trimmed = rawName?.trim();
      events.add(_CalendarEvent(
        sourceIndex: i,
        id: _string(entry['id']),
        // Check emptiness on the trimmed value but keep the original text:
        // trimming would silently rewrite the exported festival name.
        name: trimmed == null || trimmed.isEmpty ? 'Festival' : rawName!,
        category: _string(entry['category']),
        date: date,
        description: buildDescription(occurrence),
      ));
    }
    return events;
  }

  /// Human-readable timing lines for an event description. Each line is
  /// escaped individually, then joined with the iCalendar `\n` escape so the
  /// folding step never has to reason about embedded newlines.
  static String buildDescription(Map<String, dynamic> occurrence) {
    final parts = <String>[];

    final tithiName = _string(occurrence['tithiName']);
    final paksha = _string(occurrence['paksha']);
    if (tithiName != null && tithiName.isNotEmpty) {
      final label = paksha != null && paksha.isNotEmpty
          ? '$paksha $tithiName'
          : tithiName;
      final number = occurrence['tithiNumber'];
      parts.add('Tithi: $label${number == null ? '' : ' ($number)'}');
    }

    final masa = _string(occurrence['masaDisplay']) ?? _string(occurrence['masa']);
    if (masa != null && masa.isNotEmpty) {
      parts.add('Month: $masa');
    }

    final beginsIso = _string(occurrence['tithiBegins']);
    final endsIso = _string(occurrence['tithiEnds']);
    final beginsTime = _timeOf(beginsIso);
    final endsTime = _timeOf(endsIso);
    if (beginsTime != null || endsTime != null) {
      // A tithi often ends on the next calendar day. Bare times would imply
      // it is a same-day window, so qualify both ends with MM-dd when they
      // fall on different dates.
      final beginsDate = _datePart(beginsIso);
      final endsDate = _datePart(endsIso);
      final spansDays =
          beginsDate != null && endsDate != null && beginsDate != endsDate;
      String qualified(String? iso, String time) {
        if (!spansDays || time == '--') return time;
        final day = _datePart(iso);
        return day == null ? time : '${day.substring(5)} $time';
      }

      parts.add(
        'Tithi timings: ${qualified(beginsIso, beginsTime ?? '--')} - '
        '${qualified(endsIso, endsTime ?? '--')}',
      );
    }

    final sunrise = _timeOf(_string(occurrence['sunrise']));
    final sunset = _timeOf(_string(occurrence['sunset']));
    if (sunrise != null) parts.add('Sunrise: $sunrise');
    if (sunset != null) parts.add('Sunset: $sunset');

    parts.add(_source);
    return parts.map(_escapeText).join(r'\n');
  }

  /// Never throws on an unexpected value type; keys are stringified so a
  /// decoded JSON map (whose keys can be `dynamic`) is safe to read below.
  static Map<String, dynamic> _stringMap(Object? value) {
    if (value is! Map) return const <String, dynamic>{};
    return value.map((key, val) => MapEntry(key.toString(), val));
  }

  static String? _string(Object? value) => value is String ? value : null;

  /// Extracts `HH:mm` from a local wall-clock ISO-8601 string such as
  /// `2026-09-14T07:06:00.000`. Returns null for absent/malformed values.
  static String? _timeOf(String? iso) {
    if (iso == null || iso.length < 16) return null;
    final time = iso.substring(11, 16);
    return RegExp(r'^\d{2}:\d{2}$').hasMatch(time) ? time : null;
  }

  static String? _datePart(String? iso) {
    if (iso == null || iso.length < 10) return null;
    final date = iso.substring(0, 10);
    return RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(date) ? date : null;
  }

  static DateTime? _parseDay(String? value) {
    if (value == null || !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) {
      return null;
    }
    try {
      return DateTime.parse(value);
    } on FormatException {
      return null;
    }
  }

  static String _formatDay(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}'
      '${date.month.toString().padLeft(2, '0')}'
      '${date.day.toString().padLeft(2, '0')}';

  static String _formatStamp(DateTime utc) =>
      '${_formatDay(utc)}T'
      '${utc.hour.toString().padLeft(2, '0')}'
      '${utc.minute.toString().padLeft(2, '0')}'
      '${utc.second.toString().padLeft(2, '0')}Z';

  static String _safeUid(String? id, Object? year, int index) {
    final base = (id ?? 'festival').replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
    return '$base-$year-$index@tithi.app';
  }

  /// Escapes a TEXT value: backslash, semicolon, comma and newlines.
  /// Backslashes must be handled first or later replacements get double-escaped.
  static String _escapeText(String value) => value
      .replaceAll('\\', r'\\')
      .replaceAll(';', r'\;')
      .replaceAll(',', r'\,')
      .replaceAll('\r\n', r'\n')
      .replaceAll('\n', r'\n')
      .replaceAll('\r', r'\n');

  /// Folds a content line into physical lines of at most 75 octets. Splitting
  /// works on UTF-8 bytes and never cuts a multi-byte character in half;
  /// continuation lines begin with one space (which is part of their budget).
  static List<String> _fold(String line) {
    final bytes = utf8.encode(line);
    if (bytes.length <= _maxLineBytes) return [line];

    final folded = <String>[];
    var start = 0;
    var isFirst = true;
    while (start < bytes.length) {
      var end = start + (isFirst ? _maxLineBytes : _maxLineBytes - 1);
      if (end > bytes.length) end = bytes.length;
      // Back off to the start of the current UTF-8 character.
      while (end < bytes.length && (bytes[end] & 0xC0) == 0x80) {
        end--;
      }
      final chunk = utf8.decode(bytes.sublist(start, end));
      folded.add('${isFirst ? '' : ' '}$chunk');
      start = end;
      isFirst = false;
    }
    return folded;
  }
}

/// One calendar-ready festival row. Kept private so the public API stays a
/// single `buildIcs` call plus the event count the settings UI needs.
class _CalendarEvent {
  const _CalendarEvent({
    required this.sourceIndex,
    required this.id,
    required this.name,
    required this.category,
    required this.date,
    required this.description,
  });

  /// Index in the original festival catalog; used for a re-import-stable UID.
  final int sourceIndex;
  final String? id;
  final String name;
  final String? category;
  final DateTime date;
  final String description;
}
