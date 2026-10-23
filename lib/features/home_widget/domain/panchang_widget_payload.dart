import 'package:flutter/foundation.dart';

import '../../../l10n/app_localizations.dart';
import '../../../models/panchang_data.dart';
import '../../../services/auspicious_timings.dart';
import '../../../services/inauspicious_timings.dart';
import '../../../services/sunrise_calculator.dart';
import '../../../utils/tithi_localization.dart';
import '../../hero/domain/hero_content.dart';

// Payload builders for the panchang home-screen widgets (hero card and the
// three timing widgets). The native Android widgets are dumb renderers: every
// user-visible string is resolved here, in the app language, so the widget
// never has to duplicate localization or astronomy.
//
// Kept free of Riverpod/BuildContext so the payloads are unit-testable and the
// sync provider stays a thin composition layer.

/// SharedPreferences key for the hero-widget payload.
const String kHeroWidgetDataKey = 'hero_widget_data';

/// SharedPreferences key for the timing-widget payload (all three timing
/// widgets read the same document and filter by section).
const String kTimingsWidgetDataKey = 'timings_widget_data';

/// How many upcoming days are sent to the timing widgets. Two lets the native
/// midnight refresh roll over to tomorrow without waiting for the app.
const int kTimingsWidgetDayCount = 2;

/// Builds the hero-card widget payload.
///
/// [content] is the app hero view-model, so the widget mirrors the in-app card
/// (same tag, title, phase and transition chip). [formatTime] formats a
/// sunrise/sunset instant in the app locale.
Map<String, dynamic> buildHeroWidgetPayload({
  required PanchangData panchang,
  required HeroContent content,
  required AppLocalizations l10n,
  required String detail,
  required List<String> festivals,
  required String lang,
  required String refreshLabel,
  required String Function(DateTime time) formatTime,
  String location = '',
}) {
  // The hero renders the inline icon (a WidgetSpan with padding) between
  // `text` and `highlight`; the widget has no such spacer, so add one space
  // there to keep "Next tithi Ekadashi at 1:02 PM" readable. The native side
  // gets the parts separately so it can accent the tithi name without trying
  // to split a localized sentence.
  final firstChip = content.chips.isEmpty ? null : content.chips.first;
  final chip = firstChip == null
      ? ''
      : firstChip.inlineIcon
      ? '${firstChip.text} ${firstChip.highlight ?? ''}${firstChip.suffix ?? ''}'
            .trim()
      : '${firstChip.text}${firstChip.highlight ?? ''}'
                '${firstChip.suffix ?? ''}'
            .trim();

  return {
    'date': _isoDate(panchang.date),
    'tag': content.tagLabel,
    'weekday': content.weekday,
    'secondaryKind': content.secondaryKind.name,
    'secondary': content.secondaryText ?? '',
    'illumination': content.illumination,
    'isShukla': content.isShukla,
    'location': location.trim(),
    'title': content.title,
    'phase': content.subLabel,
    'detail': detail.trim(),
    // The native card has one artwork slot; use the headline (first sorted)
    // festival instead of cramming every name into a 70dp pill.
    'festival': festivals.isEmpty ? '' : festivals.first,
    'chip': chip,
    'chipText': firstChip?.text ?? '',
    'chipHighlight': firstChip?.highlight ?? '',
    'chipSuffix': firstChip?.suffix ?? '',
    'chipInlineIcon': firstChip?.inlineIcon ?? false,
    'sunLine': panchang.sunrise == null || panchang.sunset == null
        ? ''
        : '${l10n.sunrise} ${formatTime(panchang.sunrise!)} · '
              '${l10n.sunset} ${formatTime(panchang.sunset!)}',
    'lang': lang,
    'refreshLabel': refreshLabel,
  };
}

/// Builds the timing-widget payload consumed by the auspicious,
/// inauspicious and combined widgets.
///
/// Each day carries every window (both sections) plus ISO start/end instants
/// so the native side can highlight the current window and arm a refresh at
/// the next boundary without re-running astronomy.
Map<String, dynamic> buildTimingsWidgetPayload({
  required List<PanchangData> days,
  required ({double latitude, double longitude}) coordinates,
  required AppLocalizations l10n,
  required String lang,
  required String refreshLabel,
}) {
  String time(DateTime value) =>
      formatLocalizedDate(value, 'jm', l10n.localeName);
  String dateLabel(DateTime value) =>
      formatLocalizedDate(value, 'EEE, d MMM', l10n.localeName);

  final dayPayloads = <Map<String, dynamic>>[];
  for (final day in days.take(kTimingsWidgetDayCount)) {
    final sunrise = day.sunrise;
    final sunset = day.sunset;
    if (sunrise == null || sunset == null) continue;

    try {
      final inauspicious = InauspiciousTimings.calculate(
        date: day.date,
        sunrise: sunrise,
        sunset: sunset,
      );
      // Same inputs as the tithi detail sheet: next sunrise bounds the night
      // windows, and a tithi that flips mid-window clips Pradosha.
      // Calendar-day arithmetic, not +24h: across a DST transition a
      // Duration(days: 1) can land on the previous calendar day.
      final nextSunrise = SunriseCalculator.calculateSunriseIST(
        date: DateTime(day.date.year, day.date.month, day.date.day + 1),
        latitude: coordinates.latitude,
        longitude: coordinates.longitude,
      );
      final tithiEnd = day.transitionExitsLabel
          ? day.tithiTransitionTime
          : null;
      final auspicious = AuspiciousTimings.calculate(
        date: day.date,
        sunrise: sunrise,
        sunset: sunset,
        nextSunrise: nextSunrise,
        tithiNumber: day.tithiNumber,
        tithiEnd: tithiEnd,
      );

      Map<String, dynamic> row(
        String section,
        String name,
        ({DateTime start, DateTime end}) window, {
        String note = '',
      }) => {
        'section': section,
        'name': name,
        'time': '${time(window.start)} – ${time(window.end)}',
        'start': window.start.toIso8601String(),
        'end': window.end.toIso8601String(),
        'note': note,
      };

      dayPayloads.add({
        'date': _isoDate(day.date),
        'dateLabel': dateLabel(day.date),
        'sunLine':
            '${l10n.sunrise} ${time(sunrise)} · '
            '${l10n.sunset} ${time(sunset)}',
        'rows': [
          row(
            'auspicious',
            l10n.abhijit,
            auspicious.abhijit,
            note: AuspiciousTimings.abhijitAvoided(day.date)
                ? l10n.abhijitAvoided
                : '',
          ),
          row('auspicious', l10n.brahmaMuhurta, auspicious.brahmaMuhurta),
          row('auspicious', l10n.madhyahna, auspicious.madhyahnaWindow),
          row('auspicious', l10n.nishita, auspicious.nishita),
          row('auspicious', l10n.godhuli, auspicious.godhuli),
          row('auspicious', l10n.pradosha, auspicious.pradosha),
          row('inauspicious', l10n.rahuKalam, inauspicious.rahu),
          row('inauspicious', l10n.yamaganda, inauspicious.yamaganda),
          row('inauspicious', l10n.gulikaKalam, inauspicious.gulika),
        ],
      });
    } catch (e) {
      // One malformed day must not blank the other (or crash the app build).
      debugPrint('Timings widget payload skipped ${day.date}: $e');
    }
  }

  return {
    'lang': lang,
    'refreshLabel': refreshLabel,
    'auspiciousTitle': l10n.auspiciousTimings,
    'inauspiciousTitle': l10n.inauspiciousTimings,
    'combinedTitle': l10n.widgetCombinedLabel,
    'days': dayPayloads,
  };
}

String _isoDate(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';
