import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:tithi/services/festival_calendar_export_service.dart';

Map<String, dynamic> _document(List<Map<String, dynamic>> festivals) => {
  'year': 2026,
  'festivals': festivals,
};

Map<String, dynamic> _festival(
  String id,
  String name, {
  String? date,
  Map<String, dynamic>? occurrenceOverrides,
}) => {
  'id': id,
  'name': name,
  'category': 'major',
  'occurrence': date == null
      ? null
      : <String, dynamic>{
          'date': date,
          'paksha': 'Shukla',
          'tithiNumber': 4,
          'tithiName': 'Chaturthi',
          'masaDisplay': 'Bhadrapada',
          'tithiBegins': '2026-09-14T07:06:00.000',
          'tithiEnds': '2026-09-15T07:44:00.000',
          'sunrise': '2026-09-14T06:07:00.000',
          'sunset': '2026-09-14T18:28:00.000',
          ...?occurrenceOverrides,
        },
};

List<String> _physicalLines(String ics) => ics.split('\r\n');

/// Inverse of RFC 5545 folding: drop the leading continuation space and
/// rejoin, which must reproduce the original content line.
String _unfold(Iterable<String> lines) => lines
    .map((line) => line.startsWith(' ') ? line.substring(1) : line)
    .join();

/// Returns the logical value of a property, rejoining any folded lines.
String _unfoldedProperty(List<String> lines, String key) {
  final index = lines.indexWhere((line) => line.startsWith('$key:'));
  expect(index, greaterThanOrEqualTo(0), reason: 'missing $key property');
  var end = index + 1;
  while (end < lines.length && lines[end].startsWith(' ')) {
    end++;
  }
  return _unfold(lines.sublist(index, end));
}

void main() {
  final service = FestivalCalendarExportService();
  final stamp = DateTime.utc(2026, 1, 2, 3, 4, 5);

  group('FestivalCalendarExportService.buildIcs', () {
    test('emits a CRLF-delimited VCALENDAR with a stable DTSTAMP', () {
      final ics = service.buildIcs(_document([]), now: stamp);

      expect(ics, contains('\r\n'));
      expect(ics.endsWith('END:VCALENDAR\r\n'), isTrue);
      final lines = _physicalLines(ics);
      expect(lines.first, equals('BEGIN:VCALENDAR'));
      expect(lines, contains('VERSION:2.0'));
      expect(lines, contains('PRODID:-//Tithi//Tithi Festival Calendar//EN'));
      expect(lines, contains('CALSCALE:GREGORIAN'));
      expect(lines, contains('X-WR-CALNAME:Tithi Festivals 2026'));
      expect(lines.lastWhere((l) => l.isNotEmpty), equals('END:VCALENDAR'));
    });

    test('creates one all-day VEVENT per festival with an occurrence', () {
      final ics = service.buildIcs(
        _document([
          _festival('ganesh_chaturthi', 'Ganesh Chaturthi', date: '2026-09-14'),
          _festival('no_date', 'No Date Festival'),
          _festival('bad_date', 'Bad Date Festival', date: 'not-a-date'),
          _festival('deepavali', 'Deepavali', date: '2026-11-08'),
        ]),
        now: stamp,
      );

      expect(_physicalLines(ics).where((l) => l == 'BEGIN:VEVENT').length, 2);
      expect(ics, contains('DTSTART;VALUE=DATE:20260914'));
      // All-day DTEND is exclusive, so the event covers just the one day.
      expect(ics, contains('DTEND;VALUE=DATE:20260915'));
      expect(ics, contains('DTSTART;VALUE=DATE:20261108'));
      expect(ics, contains('DTEND;VALUE=DATE:20261109'));
      expect(ics, isNot(contains('No Date Festival')));
      expect(ics, isNot(contains('Bad Date Festival')));
      expect(ics, contains('DTSTAMP:20260102T030405Z'));
      expect(ics, contains('SUMMARY:Ganesh Chaturthi'));
      expect(ics, contains('UID:ganesh_chaturthi-2026-0@tithi.app'));
      // UID follows the catalog position (3), not the emitted-event ordinal
      // (1), so an earlier festival losing its date does not renumber events.
      expect(ics, contains('UID:deepavali-2026-3@tithi.app'));
      expect(ics, contains('CATEGORIES:major'));
      expect(ics, contains('TRANSP:TRANSPARENT'));
    });

    test('description carries the Panchang timings on the observance date', () {
      final ics = service.buildIcs(
        _document([
          _festival('ganesh_chaturthi', 'Ganesh Chaturthi', date: '2026-09-14'),
        ]),
        now: stamp,
      );

      final description = _unfoldedProperty(_physicalLines(ics), 'DESCRIPTION');
      expect(description, contains(r'Tithi: Shukla Chaturthi (4)'));
      expect(description, contains(r'Month: Bhadrapada'));
      // The tithi ends on the next day, so both ends carry a date qualifier.
      expect(
        description,
        contains(r'Tithi timings: 09-14 07:06 - 09-15 07:44'),
      );
      expect(description, contains(r'Sunrise: 06:07'));
      expect(description, contains(r'Sunset: 18:28'));
      expect(description, contains(r'Source: Tithi - Vedic Calendar'));
    });

    test('escapes TEXT special characters in names and categories', () {
      final ics = service.buildIcs(
        _document([
          _festival(
            'weird',
            r'Semi; Comma, Back\slash',
            date: '2026-09-14',
          ),
        ]),
        now: stamp,
      );

      expect(
        _unfoldedProperty(_physicalLines(ics), 'SUMMARY'),
        equals(r'SUMMARY:Semi\; Comma\, Back\\slash'),
      );
    });

    test('folds long lines at 75 octets without breaking UTF-8 characters', () {
      final longName = 'गणेश चतुर्थी ' * 12; // multibyte, well over 75 bytes
      final ics = service.buildIcs(
        _document([_festival('long', longName, date: '2026-09-14')]),
        now: stamp,
      );
      final lines = _physicalLines(ics);

      final summaryIndex = lines.indexWhere(
        (line) => line.startsWith('SUMMARY:'),
      );
      expect(summaryIndex, greaterThanOrEqualTo(0));

      var end = summaryIndex + 1;
      while (end < lines.length && lines[end].startsWith(' ')) {
        end++;
      }
      final folded = lines.sublist(summaryIndex, end);
      expect(folded.length, greaterThan(1));
      for (final line in folded) {
        expect(utf8.encode(line).length, lessThanOrEqualTo(75));
      }
      expect(_unfold(folded), equals('SUMMARY:$longName'));
    });

    test('skips malformed rows without throwing', () {
      final document = <String, dynamic>{
        'year': 2026,
        'festivals': <dynamic>[
          null,
          'not a map',
          {'id': 42, 'name': 99, 'occurrence': 'not a map'},
          {'id': 'bad_date', 'name': 'Bad', 'occurrence': {'date': 20260914}},
          _festival('good', 'Good Festival', date: '2026-09-14'),
        ],
      };

      final ics = service.buildIcs(document, now: stamp);

      expect(
        _physicalLines(ics).where((line) => line == 'BEGIN:VEVENT').length,
        1,
      );
      expect(ics, contains('SUMMARY:Good Festival'));
      expect(FestivalCalendarExportService.countEvents(document), 1);
    });

    test('countEvents is zero when no festival has a resolvable date', () {
      final document = _document([
        _festival('first', 'First'),
        _festival('second', 'Second', date: 'not-a-date'),
      ]);

      expect(FestivalCalendarExportService.countEvents(document), 0);
      final ics = service.buildIcs(document, now: stamp);
      expect(ics, isNot(contains('BEGIN:VEVENT')));
      expect(ics, contains('END:VCALENDAR'));
    });

    test('UIDs stay put when an earlier festival loses its occurrence', () {
      final ics = service.buildIcs(
        _document([
          _festival('first', 'First'),
          _festival('second', 'Second', date: '2026-09-14'),
        ]),
        now: stamp,
      );

      expect(ics, contains('UID:second-2026-1@tithi.app'));
    });
  });

  group('FestivalCalendarExportService.buildDescription', () {
    test('omits timings that are not available', () {
      final description = FestivalCalendarExportService.buildDescription({
        'date': '2026-09-14',
        'tithiBegins': null,
        'sunrise': null,
        'sunset': null,
      });

      expect(description, isNot(contains('Tithi timings')));
      expect(description, isNot(contains('Sunrise')));
      expect(description, contains('Source: Tithi - Vedic Calendar'));
    });

    test('uses the display month when present', () {
      final description = FestivalCalendarExportService.buildDescription({
        'date': '2026-09-04',
        'masa': 'Shravana',
        'masaDisplay': 'Bhadrapada',
      });

      expect(description, contains(r'Month: Bhadrapada'));
      expect(description, isNot(contains(r'Month: Shravana')));
    });

    test('same-day tithi timings are not date-qualified', () {
      final description = FestivalCalendarExportService.buildDescription({
        'date': '2026-09-14',
        'tithiBegins': '2026-09-14T07:06:00.000',
        'tithiEnds': '2026-09-14T21:44:00.000',
      });

      expect(description, contains(r'Tithi timings: 07:06 - 21:44'));
    });

    test('ignores malformed field types instead of throwing', () {
      final description = FestivalCalendarExportService.buildDescription({
        'date': 20260914,
        'tithiName': 4,
        'masaDisplay': <String>[],
        'tithiBegins': false,
        'sunrise': DateTime(2026),
      });

      expect(description, isNot(contains('Tithi:')));
      expect(description, isNot(contains('Tithi timings')));
      expect(description, isNot(contains('Sunrise')));
      expect(description, contains('Source: Tithi - Vedic Calendar'));
    });
  });
}
