import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format/date_only.dart';
import '../../../providers/panchang_provider.dart';
import '../../../services/moon_distance_service.dart';
import '../../../services/moon_events_service.dart';
import '../../../services/solar_events_service.dart';
import '../domain/moon_viewing.dart';

/// The date the Moon hero and its detail cards describe.
///
/// Separate from the scrub offset so the date picker can jump to any date
/// while the drag gesture stays a ±15-day convenience around today.
class MoonSelectedDateNotifier extends Notifier<DateTime> {
  @override
  DateTime build() => dateOnly(DateTime.now());

  void setDate(DateTime date) => state = dateOnly(date);

  void stepDays(int days) =>
      state = DateTime(state.year, state.month, state.day + days);

  void resetToToday() => state = dateOnly(DateTime.now());
}

final moonSelectedDateProvider =
    NotifierProvider<MoonSelectedDateNotifier, DateTime>(
      MoonSelectedDateNotifier.new,
    );

/// Moon rise/set for one civil day, including the prev/next-day fallbacks.
class MoonSkyTimes {
  const MoonSkyTimes({
    this.rise,
    this.set,
    this.riseIsFallback = false,
    this.setIsFallback = false,
  });

  final DateTime? rise;
  final DateTime? set;

  /// True when the Moon did not rise on the civil day and the previous rise
  /// is shown instead (with its own date).
  final bool riseIsFallback;

  /// True when the next set is shown because the Moon did not set that day.
  final bool setIsFallback;
}

/// Exact lunar timings from the native Swiss Ephemeris seam.
final moonSkyTimesProvider = FutureProvider.family<MoonSkyTimes, DateTime>((
  ref,
  date,
) async {
  await ref.watch(panchangInitProvider.future);
  final context = ref.watch(resolvedSolarContextProvider);
  final events = moonEventsService.forDate(
    date: date,
    latitude: context.latitude,
    longitude: context.longitude,
    altitudeMeters: context.altitudeMeters,
    timezoneId: context.timezoneId,
  );
  final rise = events.moonrise;
  final sameDaySet = events.moonset;
  final resolvedRise =
      rise ??
      moonEventsService.findPreviousRise(
        date: date,
        latitude: context.latitude,
        longitude: context.longitude,
        altitudeMeters: context.altitudeMeters,
        timezoneId: context.timezoneId,
      );
  DateTime? nextSetAfter(DateTime day) => moonEventsService.findNextSet(
    date: day,
    latitude: context.latitude,
    longitude: context.longitude,
    altitudeMeters: context.altitudeMeters,
    timezoneId: context.timezoneId,
  );

  // The civil-day set is usually the morning one, i.e. *before* this evening's
  // rise. Pair the rise with the next set instead, or the viewing window sees
  // a backwards interval and reports "below the horizon" every day.
  final resolvedSet = resolvedRise == null
      ? sameDaySet ?? nextSetAfter(date)
      : setFollowingRise(
          rise: resolvedRise,
          sameDaySet: sameDaySet,
          nextSet: nextSetAfter(resolvedRise),
        );
  return MoonSkyTimes(
    rise: resolvedRise,
    set: resolvedSet,
    riseIsFallback: rise == null,
    setIsFallback:
        sameDaySet == null ||
        (resolvedSet != null && resolvedSet != sameDaySet),
  );
});

/// Longest Moon-above-horizon / Sun-below-horizon overlap of [date].
///
/// Returns null at polar latitudes where the Sun never sets/rises, or on days
/// when the Moon is down all night (new moon).
final moonViewingWindowProvider =
    FutureProvider.family<MoonViewingWindow?, DateTime>((ref, date) async {
      final sky = await ref.watch(moonSkyTimesProvider(date).future);
      final context = ref.watch(resolvedSolarContextProvider);
      try {
        final solar = solarEventsService.forDate(
          date: date,
          latitude: context.latitude,
          longitude: context.longitude,
          altitudeMeters: context.altitudeMeters,
          timezoneId: context.timezoneId,
        );
        return bestMoonViewingWindow(
          moonrise: sky.rise,
          moonset: sky.set,
          morningSunrise: solar.sunrise,
          eveningSunset: solar.sunset,
          nextSunrise: solar.nextSunrise,
        );
      } on SolarEventUnavailable {
        return null;
      }
    });

final moonDistanceServiceProvider = Provider<MoonDistanceService>(
  (ref) => MoonDistanceService(),
);

/// Geocentric Moon distance at local noon on [date] (null when FFI is absent).
final moonDistanceInfoProvider =
    FutureProvider.family<MoonDistanceInfo?, DateTime>((ref, date) async {
      await ref.watch(panchangInitProvider.future);
      return ref
          .watch(moonDistanceServiceProvider)
          .distanceAt(DateTime(date.year, date.month, date.day, 12));
    });
