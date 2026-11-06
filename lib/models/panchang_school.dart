/// Calculation school used to derive every Panchang value.
///
/// A school is not a display preference: it changes the ephemeris, so tithi
/// boundaries, nakshatra, yoga, karana, sankranti and the Bengali calendar all
/// move together. Caches must key on it (see `locationSignature`).
///
/// The two schools differ in *planetary theory*, not just ayanamsa:
///
/// - [bisuddha] is the modern Drik Ganita: Swiss Ephemeris positions reduced
///   with the Lahiri ayanamsa. This is what Tithi has always shipped and it
///   remains the default.
/// - [suryasiddhanta] is the traditional mean-motion theory of the Surya
///   Siddhanta: mean longitudes from the Kali epoch revolutions, corrected with
///   the manda (equation-of-centre) term only. It is computed in pure Dart and
///   needs no ephemeris files.
///
/// The order is append-only. `PanchangProfile` stores the `.name`, but the
/// settings box stores an index in `CalendarPreferences`, so reordering would
/// silently remap a stored preference.
enum PanchangSchool {
  /// Drik Ganita with the Lahiri ayanamsa (Swiss Ephemeris).
  bisuddha,

  /// Traditional Surya Siddhanta mean-motion theory.
  suryasiddhanta,
}

extension PanchangSchoolExt on PanchangSchool {
  String get label => switch (this) {
    PanchangSchool.bisuddha => 'Bisuddhasiddhanta',
    PanchangSchool.suryasiddhanta => 'Suryasiddhanta',
  };

  String get shortLabel => switch (this) {
    PanchangSchool.bisuddha => 'Drik',
    PanchangSchool.suryasiddhanta => 'Surya Siddhanta',
  };

  String get description => switch (this) {
    PanchangSchool.bisuddha =>
      'Drik Ganita with Lahiri ayanamsa (modern, matches Drik Panjika)',
    PanchangSchool.suryasiddhanta =>
      'Traditional mean-motion theory (matches Surya Siddhanta panjikas '
          'such as Gupta Press)',
  };

  /// True when the school needs the Swiss Ephemeris files for positions.
  ///
  /// Surya Siddhanta positions are computed in pure Dart, but solar rise/set
  /// still uses the native calculator, so initialization is unaffected.
  bool get usesSwissPositions => this == PanchangSchool.bisuddha;
}

/// Parses a stored school identifier, falling back to [fallback].
PanchangSchool panchangSchoolFromName(
  Object? raw, {
  PanchangSchool fallback = PanchangSchool.bisuddha,
}) {
  if (raw is! String) return fallback;
  for (final school in PanchangSchool.values) {
    if (school.name == raw) return school;
  }
  return fallback;
}
