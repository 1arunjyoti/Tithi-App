import '../../../l10n/app_localizations.dart';
import '../../../models/festival.dart';
import '../../../services/auspicious_timings.dart';

// Puja-kala window + paran instant resolution for the event sheet's Puja
// Samay card. Pure: every ephemeris input is passed in (the sheet watches
// the providers); no BuildContext — unit-testable like event_content.dart.

/// Normalized puja kala or null (no Puja Samay card). Unknown values fall
/// back to null rather than rendering a wrong window.
String? normalizedPujaKala(Festival festival) {
  const known = {
    'madhyahna',
    'nishita',
    'pradosha',
    'moonrise',
    'sunrise',
    'sunset',
    'sandhi_junction',
  };
  final raw = festival.panchangRules.pujaKala;
  return raw != null && known.contains(raw) ? raw : null;
}

/// Normalized paran rule or null (no fast, or breaking isn't time-critical).
/// Unknown values fall back to null.
String? normalizedParanRule(Festival festival) {
  const known = {
    'moonrise',
    'next_sunrise',
    'after_puja_kala',
    'dwadashi_window',
  };
  final raw = festival.panchangRules.paranRule;
  return raw != null && known.contains(raw) ? raw : null;
}

/// Window kalas render the two-cell span card; sunrise/sunset resolve to a
/// single instant ([resolvePujaInstant]).
bool isPujaWindowKala(String kala) =>
    kala == 'madhyahna' ||
    kala == 'nishita' ||
    kala == 'pradosha' ||
    kala == 'moonrise' ||
    kala == 'sandhi_junction';

/// Display name for a kala, reusing the sheet's existing labels with an
/// English fallback like the sheet widgets (nullable l10n).
String pujaKalaLabel(String kala, AppLocalizations? l10n) {
  return switch (kala) {
    'madhyahna' => l10n?.madhyahna ?? 'Madhyahna',
    'nishita' => l10n?.nishita ?? 'Nishita',
    'pradosha' => l10n?.pradosha ?? 'Pradosha',
    'sunrise' => l10n?.sunrise ?? 'Sunrise',
    'sunset' => l10n?.sunset ?? 'Sunset',
    'moonrise' => l10n?.moonrise ?? 'Moonrise',
    'sandhi_junction' => l10n?.sandhiJunction ?? 'Sandhi',
    _ => kala,
  };
}

/// Span for a window kala: the display instant plus the Begins/Ends range.
/// Null when required inputs are missing (caller hides the card).
///
/// - madhyahna/nishita/pradosha: day-view windows; the instant is the
///   window midpoint (which is exactly the madhyahna instant). The Pradosh
///   auto-clip inside [AuspiciousTimings] stays disabled (tithiNumber left
///   null): clipping is driven solely by [clipToTithi].
/// - moonrise: 48-minute grace window from the rise itself.
/// - sandhi_junction: 48-minute span centered on the tithi-sandhi
///   (flanking junction, gandantha-style).
typedef PujaKalaSpan = ({DateTime instant, DateTime start, DateTime end});

PujaKalaSpan? resolvePujaKala({
  required String kala,
  required DateTime date,
  required DateTime? sunrise,
  required DateTime? sunset,
  required DateTime? nextSunrise,
  required DateTime? moonrise,
  required DateTime? tithiEnd,
  required bool clipToTithi,
}) {
  DateTime midpoint(DateTime s, DateTime e) =>
      s.add(Duration(microseconds: e.difference(s).inMicroseconds ~/ 2));

  switch (kala) {
    case 'madhyahna' || 'nishita' || 'pradosha':
      if (sunrise == null || sunset == null || nextSunrise == null) {
        return null;
      }
      final timings = AuspiciousTimings.calculate(
        date: date,
        sunrise: sunrise,
        sunset: sunset,
        nextSunrise: nextSunrise,
      );
      final window = switch (kala) {
        'madhyahna' => timings.madhyahnaWindow,
        'nishita' => timings.nishita,
        _ => timings.pradosha,
      };
      final instant = kala == 'madhyahna'
          ? timings.madhyahnaInstant
          : midpoint(window.start, window.end);
      final clipped = clipPujaWindow(
        start: window.start,
        end: window.end,
        clipToTithi: clipToTithi,
        tithiEnd: tithiEnd,
      );
      return (instant: instant, start: clipped.start, end: clipped.end);
    case 'moonrise':
      if (moonrise == null) return null;
      final end = moonrise.add(const Duration(minutes: 48));
      final clipped = clipPujaWindow(
        start: moonrise,
        end: end,
        clipToTithi: clipToTithi,
        tithiEnd: tithiEnd,
      );
      return (instant: moonrise, start: clipped.start, end: clipped.end);
    case 'sandhi_junction':
      if (tithiEnd == null) return null;
      final clipped = clipPujaWindow(
        start: tithiEnd.subtract(const Duration(minutes: 24)),
        end: tithiEnd.add(const Duration(minutes: 24)),
        clipToTithi: clipToTithi,
        tithiEnd: tithiEnd,
      );
      return (instant: tithiEnd, start: clipped.start, end: clipped.end);
    default:
      // sunrise/sunset are exact instants (resolvePujaInstant).
      return null;
  }
}

/// Whole ghatikas (24-minute units) in [start], [end] for the card's
/// duration note. Rounds like the timing arithmetic; minimum 1 so a
/// clipped sliver never reads "0 ghatikas".
int ghatikasBetween(DateTime start, DateTime end) {
  final minutes = end.difference(start).inMinutes;
  var count = (minutes / 24).round();
  if (count < 1) count = 1;
  return count;
}

/// Cut [start], [end] at [tithiEnd] when [clipToTithi] applies (the kalam
/// must stay inside the festival tithi, e.g. Pradosh Vrata in Trayodashi).
/// Mirrors the Pradosh auto-clip guard: only a strictly interior end clips.
({DateTime start, DateTime end}) clipPujaWindow({
  required DateTime start,
  required DateTime end,
  required bool clipToTithi,
  required DateTime? tithiEnd,
}) {
  if (clipToTithi &&
      tithiEnd != null &&
      tithiEnd.isAfter(start) &&
      tithiEnd.isBefore(end)) {
    return (start: start, end: tithiEnd);
  }
  return (start: start, end: end);
}

/// Resolve an exact-instant kala (Chhath arghya at sunrise/sunset). Null
/// for window kalas (use [resolvePujaKala]) or when the anchor is missing
/// (caller hides the card).
DateTime? resolvePujaInstant({
  required String kala,
  required DateTime? sunrise,
  required DateTime? sunset,
}) {
  return switch (kala) {
    'sunrise' => sunrise,
    'sunset' => sunset,
    _ => null,
  };
}
