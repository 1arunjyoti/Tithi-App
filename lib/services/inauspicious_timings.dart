/// Rahu Kalam, Yamaganda and Gulika Kalam from sunrise/sunset.
///
/// Pure arithmetic — no ephemeris calls beyond the sunrise/sunset the sheet
/// already resolves. The day (sunrise → sunset) is divided into 8 equal
/// segments; each period occupies the fixed 1-based segment for the weekday
/// (tables below). Segment *n* spans [boundary(n − 1), boundary(n)].
///
/// Boundaries are rounded to the nearest minute (half up) for display, e.g.
/// a 9:58:30 edge renders as 9:59.
///
/// Set [useNominalDay] to divide a nominal 6:00–18:00 day instead of the
/// actual sunrise/sunset (some older almanacs do this). Defaults to actual.
class InauspiciousTimings {
  const InauspiciousTimings({
    required this.sunrise,
    required this.sunset,
    required this.boundaries,
    required this.rahuSegment,
    required this.yamagandaSegment,
    required this.gulikaSegment,
  });

  /// Day start used for the division (actual or nominal sunrise).
  final DateTime sunrise;

  /// Day end used for the division (actual or nominal sunset).
  final DateTime sunset;

  /// The 9 rounded segment boundaries: segment *n* (1-based) is
  /// [boundaries[n − 1], boundaries[n]].
  final List<DateTime> boundaries;

  /// 1-based segments for [date]'s weekday.
  final int rahuSegment;
  final int yamagandaSegment;
  final int gulikaSegment;

  /// Range of the 1-based [segment].
  ({DateTime start, DateTime end}) rangeOf(int segment) =>
      (start: boundaries[segment - 1], end: boundaries[segment]);

  ({DateTime start, DateTime end}) get rahu => rangeOf(rahuSegment);
  ({DateTime start, DateTime end}) get yamaganda =>
      rangeOf(yamagandaSegment);
  ({DateTime start, DateTime end}) get gulika => rangeOf(gulikaSegment);

  /// 1-based Rahu Kalam segment by weekday ([DateTime.monday] == 1 ..
  /// [DateTime.sunday] == 7).
  static const Map<int, int> rahuSegments = {
    DateTime.monday: 2,
    DateTime.tuesday: 7,
    DateTime.wednesday: 5,
    DateTime.thursday: 6,
    DateTime.friday: 4,
    DateTime.saturday: 3,
    DateTime.sunday: 8,
  };

  /// 1-based Yamaganda segment by weekday.
  static const Map<int, int> yamagandaSegments = {
    DateTime.monday: 4,
    DateTime.tuesday: 3,
    DateTime.wednesday: 2,
    DateTime.thursday: 1,
    DateTime.friday: 7,
    DateTime.saturday: 6,
    DateTime.sunday: 5,
  };

  /// 1-based Gulika Kalam segment by weekday, Maandi convention
  /// (matches DrikPanchang: Monday 6th ≈ 13:00–14:31, not the minority
  /// table's 7th). Do not "correct" back without checking the reference.
  static const Map<int, int> gulikaSegments = {
    DateTime.monday: 6,
    DateTime.tuesday: 5,
    DateTime.wednesday: 4,
    DateTime.thursday: 3,
    DateTime.friday: 2,
    DateTime.saturday: 1,
    DateTime.sunday: 7,
  };

  /// Divides the day for [date] ([date]'s weekday picks the segments).
  ///
  /// [sunrise]/[sunset] are the location's actual times; pass anything —
  /// only the wall-clock instants matter. All boundaries are minute-
  /// rounded (see class docs).
  static InauspiciousTimings calculate({
    required DateTime date,
    required DateTime sunrise,
    required DateTime sunset,
    bool useNominalDay = false,
  }) {
    final dayStart = useNominalDay
        ? DateTime(date.year, date.month, date.day, 6)
        : sunrise;
    final dayEnd = useNominalDay
        ? DateTime(date.year, date.month, date.day, 18)
        : sunset;
    final segMinutes = dayEnd.difference(dayStart).inSeconds / 60 / 8;
    final boundaries = List<DateTime>.generate(9, (i) {
      final at = dayStart.add(
        Duration(microseconds: (segMinutes * i * 60 * 1000000).round()),
      );
      return _roundToMinute(at);
    });
    return InauspiciousTimings(
      sunrise: _roundToMinute(dayStart),
      sunset: _roundToMinute(dayEnd),
      boundaries: boundaries,
      rahuSegment: rahuSegments[date.weekday]!,
      yamagandaSegment: yamagandaSegments[date.weekday]!,
      gulikaSegment: gulikaSegments[date.weekday]!,
    );
  }

  /// Rounds to the nearest minute, halves up (9:58:30 → 9:59).
  static DateTime _roundToMinute(DateTime t) {
    final truncated = DateTime(t.year, t.month, t.day, t.hour, t.minute);
    return t.second >= 30
        ? truncated.add(const Duration(minutes: 1))
        : truncated;
  }
}
