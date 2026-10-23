import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tithi/features/hero/domain/hero_content.dart';
import 'package:tithi/features/home_widget/domain/panchang_widget_payload.dart';
import 'package:tithi/l10n/app_localizations_en.dart';
import 'package:tithi/models/panchang_data.dart';

void main() {
  final l10n = AppLocalizationsEn();

  PanchangData day(DateTime date) => PanchangData.fromRawTithi(
    date: date,
    rawTithi: 22.5,
    masa: 'Kartika',
    allFestivals: [],
    sunrise: DateTime(date.year, date.month, date.day, 5, 24),
    sunset: DateTime(date.year, date.month, date.day, 17, 36),
  );

  group('Hero widget payload', () {
    test('mirrors the hero view-model and formats the sun line', () {
      // Arrange
      final panchang = day(DateTime(2026, 10, 3));
      const content = HeroContent(
        tagLabel: 'TODAY · 3 OCTOBER 2026',
        weekday: 'Saturday',
        secondaryKind: HeroSecondaryKind.gregorian,
        secondaryText: '3 October 2026',
        bengaliScript: false,
        illumination: 0.5,
        illuminationPct: '50.0',
        isShukla: false,
        title: 'Krishna Paksha · Saptami',
        subLabel: 'Waning · 50.0% illuminated',
        chips: [
          (
            icon: Icons.abc,
            text: 'Next tithi',
            highlight: 'Ashtami',
            suffix: ' at 1:02 PM',
            inlineIcon: true,
          ),
        ],
        artworks: [],
      );

      // Act
      final payload = buildHeroWidgetPayload(
        panchang: panchang,
        content: content,
        l10n: l10n,
        detail: 'Kartika · Anuradha',
        festivals: const ['Diwali', 'Govardhan Puja'],
        lang: 'en',
        refreshLabel: 'Open Tithi to refresh',
        formatTime: (time) =>
            '${time.hour}:${time.minute.toString().padLeft(2, '0')}',
        location: 'Kolkata',
      );

      // Assert
      expect(payload['date'], equals('2026-10-03'));
      expect(payload['tag'], equals('TODAY · 3 OCTOBER 2026'));
      expect(payload['weekday'], equals('Saturday'));
      expect(payload['secondaryKind'], equals('gregorian'));
      expect(payload['secondary'], equals('3 October 2026'));
      expect(payload['illumination'], equals(0.5));
      expect(payload['isShukla'], isFalse);
      expect(payload['location'], equals('Kolkata'));
      expect(payload['title'], equals('Krishna Paksha · Saptami'));
      expect(payload['detail'], equals('Kartika · Anuradha'));
      expect(payload['festival'], equals('Diwali'));
      // The inline icon becomes a real space in the widget; the native side
      // also receives the parts so it can accent the tithi name.
      expect(payload['chip'], equals('Next tithi Ashtami at 1:02 PM'));
      expect(payload['chipText'], equals('Next tithi'));
      expect(payload['chipHighlight'], equals('Ashtami'));
      expect(payload['chipSuffix'], equals(' at 1:02 PM'));
      expect(payload['chipInlineIcon'], isTrue);
      expect(payload['sunLine'], equals('Sunrise 5:24 · Sunset 17:36'));
      expect(payload['refreshLabel'], equals('Open Tithi to refresh'));
    });

    test('uses the headline festival only', () {
      // Arrange
      final panchang = day(DateTime(2026, 10, 3));
      const content = HeroContent(
        tagLabel: 'TODAY',
        weekday: 'Saturday',
        secondaryKind: HeroSecondaryKind.none,
        secondaryText: null,
        bengaliScript: false,
        illumination: 0.5,
        illuminationPct: '50.0',
        isShukla: false,
        title: 'Krishna Paksha · Saptami',
        subLabel: 'Waning',
        chips: [],
        artworks: [],
      );

      // Act
      final payload = buildHeroWidgetPayload(
        panchang: panchang,
        content: content,
        l10n: l10n,
        detail: '',
        festivals: const ['A', 'B', 'C', 'D'],
        lang: 'en',
        refreshLabel: 'Refresh',
        formatTime: (time) => 't',
      );

      // Assert
      expect(payload['festival'], equals('A'));
      expect(payload['chip'], isEmpty);
      expect(payload['chipText'], isEmpty);
      expect(payload['chipHighlight'], isEmpty);
      expect(payload['location'], isEmpty);
      expect(payload['detail'], isEmpty);
    });
  });

  group('Timing widget payload', () {
    test('emits both sections with ISO anchors', () {
      // Arrange
      final saturday = day(DateTime(2026, 10, 3));

      // Act
      final payload = buildTimingsWidgetPayload(
        days: [saturday],
        coordinates: (latitude: 28.6139, longitude: 77.2090),
        l10n: l10n,
        lang: 'en',
        refreshLabel: 'Open Tithi to refresh',
      );

      // Assert: 6 auspicious + 3 inauspicious, ordered like the sheet.
      final days = payload['days'] as List<dynamic>;
      expect(days, hasLength(1));
      final firstDay = days.first as Map<String, dynamic>;
      expect(firstDay['date'], equals('2026-10-03'));
      final rows = firstDay['rows'] as List<dynamic>;
      expect(rows, hasLength(9));
      final auspicious = rows
          .cast<Map<String, dynamic>>()
          .where((row) => row['section'] == 'auspicious')
          .toList();
      final inauspicious = rows
          .cast<Map<String, dynamic>>()
          .where((row) => row['section'] == 'inauspicious')
          .toList();
      expect(auspicious, hasLength(6));
      expect(inauspicious, hasLength(3));
      expect(auspicious.first['name'], equals(l10n.abhijit));
      expect(inauspicious.first['name'], equals(l10n.rahuKalam));
      expect(auspicious.first['start'], startsWith('2026-10-03T'));
      expect(auspicious.first['end'], startsWith('2026-10-03T'));
      expect(auspicious.first['time'], contains('–'));
      expect(payload['auspiciousTitle'], equals(l10n.auspiciousTimings));
      expect(payload['combinedTitle'], equals(l10n.widgetCombinedLabel));
    });

    test('marks Abhijit avoided on Wednesday', () {
      // Arrange: 2026-10-07 is a Wednesday.
      final wednesday = day(DateTime(2026, 10, 7));

      // Act
      final payload = buildTimingsWidgetPayload(
        days: [wednesday],
        coordinates: (latitude: 28.6139, longitude: 77.2090),
        l10n: l10n,
        lang: 'en',
        refreshLabel: 'Refresh',
      );

      // Assert
      final rows =
          ((payload['days'] as List<dynamic>).first
                  as Map<String, dynamic>)['rows']
              as List<dynamic>;
      final abhijit = rows.cast<Map<String, dynamic>>().first;
      expect(abhijit['note'], equals(l10n.abhijitAvoided));
    });

    test('skips a day without sunrise/sunset instead of failing', () {
      // Arrange: a polar/edge day with no sun anchors, then a normal day.
      final noSun = PanchangData.fromRawTithi(
        date: DateTime(2026, 10, 2),
        rawTithi: 21.5,
        masa: 'Kartika',
        allFestivals: [],
      );
      final valid = day(DateTime(2026, 10, 3));

      // Act
      final payload = buildTimingsWidgetPayload(
        days: [noSun, valid],
        coordinates: (latitude: 28.6139, longitude: 77.2090),
        l10n: l10n,
        lang: 'en',
        refreshLabel: 'Refresh',
      );

      // Assert: the unanchored day is dropped, the good day survives.
      final days = payload['days'] as List<dynamic>;
      expect(days, hasLength(1));
      expect(
        (days.single as Map<String, dynamic>)['date'],
        equals('2026-10-03'),
      );
    });

    test('sends today and tomorrow for native rollover', () {
      // Arrange
      final today = day(DateTime(2026, 10, 3));
      final tomorrow = day(DateTime(2026, 10, 4));
      final third = day(DateTime(2026, 10, 5));

      // Act: day count is capped at two.
      final payload = buildTimingsWidgetPayload(
        days: [today, tomorrow, third],
        coordinates: (latitude: 28.6139, longitude: 77.2090),
        l10n: l10n,
        lang: 'en',
        refreshLabel: 'Refresh',
      );

      // Assert
      final days = payload['days'] as List<dynamic>;
      expect(days, hasLength(kTimingsWidgetDayCount));
      expect((days[0] as Map<String, dynamic>)['date'], equals('2026-10-03'));
      expect((days[1] as Map<String, dynamic>)['date'], equals('2026-10-04'));
    });
  });
}
