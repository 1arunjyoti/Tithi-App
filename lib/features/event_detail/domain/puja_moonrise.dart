import '../../../services/moon_events_service.dart';

// Moonrise anchoring a puja / paran window. Shared by the event sheet's Puja
// Samay card and the featured festival card so both resolve the same instant
// and both degrade the same way when the ephemeris cannot answer.

/// Moonrise that anchors a puja or paran window on [date] at the place.
///
/// The day's own rise wins; when the Moon does not rise before midnight, the
/// previous rise still governs the night's window (Karva Chauth waits for a
/// moon that rises after the fasting day has ended). Ephemeris failures return
/// null so callers hide the window instead of throwing mid-build.
DateTime? pujaMoonrise({
  required DateTime date,
  required double latitude,
  required double longitude,
}) {
  try {
    return moonEventsService.moonrise(
          date: date,
          latitude: latitude,
          longitude: longitude,
        ) ??
        moonEventsService.findPreviousRise(
          date: date,
          latitude: latitude,
          longitude: longitude,
        );
  } catch (_) {
    return null;
  }
}
