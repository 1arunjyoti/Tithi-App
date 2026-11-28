import '../../features/moon/domain/full_moon_names.dart';
import '../../l10n/app_localizations.dart';
import '../../models/eclipse.dart';

/// One scheduled moon/eclipse alert, with the civil day it belongs to.
class MoonNotification {
  const MoonNotification({
    required this.date,
    required this.title,
    required this.body,
  });

  final DateTime date;
  final String title;
  final String body;
}

/// Builds the alert list for the next [days] civil days from [from].
///
/// Pure so the background isolate and tests can verify titles, the Blue Moon
/// override and window filtering without touching Swiss Ephemeris. Instants
/// from the services are converted to the device's local calendar day here -
/// eclipse times arrive in UTC.
List<MoonNotification> buildMoonNotifications({
  required List<DateTime> purnimas,
  required List<DateTime> amavasyas,
  required List<Eclipse> eclipses,
  required DateTime from,
  required int days,
  required AppLocalizations l10n,
  DateTime Function(DateTime instant)? toLocal,
}) {
  final start = DateTime(from.year, from.month, from.day);
  final end = start.add(Duration(days: days));
  final blue = blueMoonPurnimas(purnimas);
  final convert = toLocal ?? (instant) => instant.toLocal();

  bool inWindow(DateTime instant) {
    final local = convert(instant);
    final day = DateTime(local.year, local.month, local.day);
    return !day.isBefore(start) && day.isBefore(end);
  }

  final events = <MoonNotification>[];

  for (final purnima in purnimas.where(inWindow)) {
    final local = convert(purnima);
    final isBlue = blue.any(
      (p) =>
          p.year == local.year && p.month == local.month && p.day == local.day,
    );
    final name = traditionalFullMoonName(local.month, l10n);
    final body = isBlue
        ? l10n.blueMoonNotificationBody
        : name == null
        ? l10n.fullMoonNotificationBody
        : '${l10n.fullMoonNotificationBody} $name';
    events.add(
      MoonNotification(
        date: local,
        title: isBlue
            ? l10n.blueMoonNotificationTitle
            : l10n.fullMoonNotificationTitle,
        body: body,
      ),
    );
  }

  for (final amavasya in amavasyas.where(inWindow)) {
    events.add(
      MoonNotification(
        date: convert(amavasya),
        title: l10n.newMoonNotificationTitle,
        body: l10n.newMoonNotificationBody,
      ),
    );
  }

  for (final eclipse in eclipses.where((e) => inWindow(e.maxEclipseTime))) {
    events.add(
      MoonNotification(
        date: convert(eclipse.maxEclipseTime),
        title: l10n.eclipseNotificationTitle,
        body: l10n.eclipseNotificationBody,
      ),
    );
  }

  events.sort((a, b) {
    final byDate = a.date.compareTo(b.date);
    return byDate != 0 ? byDate : a.title.compareTo(b.title);
  });
  return events;
}
