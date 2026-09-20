/// Abhijit, Brahma Muhurta, Madhyahna, Nishita, Godhuli and Pradosha.
///
/// Pure sunrise/sunset arithmetic — no ephemeris calls beyond the anchors
/// the sheet already resolves. Day length D = sunset − sunrise, night
/// length N = nextSunrise − sunset. All window endpoints are rounded to the
/// nearest minute (half up) for display.
///
/// Formulas (DrikPanchang conventions):
/// - Abhijit: 8th of 15 day-muhurtas [sunrise + 7D/15, sunrise + 8D/15].
/// - Brahma Muhurta: night-based default [sunrise − 2N/15, sunrise − N/15];
///   fixed-clock option [sunrise − 96min, sunrise − 48min].
/// - Madhyahna instant: (sunrise + sunset) / 2; Madhyahna window (the
///   Ganesh-Chaturthi "Madhyahna Puja Muhurat"): middle fifth of the day,
///   [sunrise + 2D/5, sunrise + 3D/5].
/// - Nishita: 8th of 15 night-muhurtas [sunset + 7N/15, sunset + 8N/15].
/// - Godhuli: [sunset, sunset + D/30] (starts exactly at sunset, one
///   day-ghati long).
/// - Pradosha: classical default [sunset, sunset + N/5] (6 night-ghatis);
///   [PradoshaConvention] selects the 96-minute or ±45-minute variants.
///   On Trayodashi ([tithiNumber] == 13) the end clips at [tithiEnd] when
///   the tithi changes mid-window (Pradosh vrata rule).
///   Divisor verified against DrikPanchang Pradosh pages (Airdrie Jan 2026:
///   187-min window = N/5 exactly; shorter listed windows end exactly at
///   the Trayodashi end, confirming the clipping rule).
enum PradoshaConvention { classical, twoMuhurtas, plusMinus45 }

class AuspiciousTimings {
  const AuspiciousTimings({
    required this.abhijit,
    required this.brahmaMuhurta,
    required this.madhyahnaInstant,
    required this.madhyahnaWindow,
    required this.nishita,
    required this.godhuli,
    required this.pradosha,
  });

  final ({DateTime start, DateTime end}) abhijit;
  final ({DateTime start, DateTime end}) brahmaMuhurta;
  final DateTime madhyahnaInstant;
  final ({DateTime start, DateTime end}) madhyahnaWindow;
  final ({DateTime start, DateTime end}) nishita;
  final ({DateTime start, DateTime end}) godhuli;
  final ({DateTime start, DateTime end}) pradosha;

  /// Abhijit is avoided on Wednesdays (Rahu-like influence that day).
  static bool abhijitAvoided(DateTime date) =>
      date.weekday == DateTime.wednesday;

  /// Abhijit is noted as more auspicious on Tue/Thu/Sat.
  static bool abhijitBoosted(DateTime date) =>
      date.weekday == DateTime.tuesday ||
      date.weekday == DateTime.thursday ||
      date.weekday == DateTime.saturday;

  static AuspiciousTimings calculate({
    required DateTime date,
    required DateTime sunrise,
    required DateTime sunset,
    required DateTime nextSunrise,
    bool useFixedBrahmaMuhurta = false,
    PradoshaConvention pradoshaConvention = PradoshaConvention.classical,
    int? tithiNumber,
    DateTime? tithiEnd,
  }) {
    final dayMicros = sunset.difference(sunrise).inMicroseconds;
    final nightMicros = nextSunrise.difference(sunset).inMicroseconds;

    DateTime at(DateTime base, double fractionOfDay, double fractionOfNight) {
      return _roundToMinute(
        base.add(
          Duration(
            microseconds:
                (dayMicros * fractionOfDay + nightMicros * fractionOfNight)
                    .round(),
          ),
        ),
      );
    }

    final abhijit = (
      start: at(sunrise, 7 / 15, 0),
      end: at(sunrise, 8 / 15, 0),
    );
    final brahmaMuhurta = useFixedBrahmaMuhurta
        ? (
            start: _roundToMinute(
              sunrise.subtract(const Duration(minutes: 96)),
            ),
            end: _roundToMinute(sunrise.subtract(const Duration(minutes: 48))),
          )
        : (start: at(sunrise, 0, -2 / 15), end: at(sunrise, 0, -1 / 15));
    final madhyahnaInstant = _roundToMinute(
      sunrise.add(Duration(microseconds: dayMicros ~/ 2)),
    );
    final madhyahnaWindow = (
      start: at(sunrise, 2 / 5, 0),
      end: at(sunrise, 3 / 5, 0),
    );
    final nishita = (
      start: at(sunset, 0, 7 / 15),
      end: at(sunset, 0, 8 / 15),
    );
    final godhuli = (start: _roundToMinute(sunset), end: at(sunset, 1 / 30, 0));

    var pradosha = switch (pradoshaConvention) {
      PradoshaConvention.classical => (
        start: _roundToMinute(sunset),
        end: at(sunset, 0, 1 / 5),
      ),
      PradoshaConvention.twoMuhurtas => (
        start: _roundToMinute(sunset),
        end: _roundToMinute(sunset.add(const Duration(minutes: 96))),
      ),
      PradoshaConvention.plusMinus45 => (
        start: _roundToMinute(sunset.subtract(const Duration(minutes: 45))),
        end: _roundToMinute(sunset.add(const Duration(minutes: 45))),
      ),
    };
    // Pradosh-vrata clipping: on Trayodashi the window ends when the
    // tithi flips to Chaturdashi mid-window.
    if (tithiNumber == 13 &&
        tithiEnd != null &&
        tithiEnd.isAfter(pradosha.start) &&
        tithiEnd.isBefore(pradosha.end)) {
      pradosha = (start: pradosha.start, end: tithiEnd);
    }

    return AuspiciousTimings(
      abhijit: abhijit,
      brahmaMuhurta: brahmaMuhurta,
      madhyahnaInstant: madhyahnaInstant,
      madhyahnaWindow: madhyahnaWindow,
      nishita: nishita,
      godhuli: godhuli,
      pradosha: pradosha,
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
