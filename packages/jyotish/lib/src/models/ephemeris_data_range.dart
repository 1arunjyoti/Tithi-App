/// One loaded Swiss Ephemeris data file and the date range it covers.
///
/// [ifno] follows `swe_get_current_file_data`: 0 = planets, 1 = Moon,
/// 2 = main asteroids.
class EphemerisFileRange {
  const EphemerisFileRange({
    required this.ifno,
    required this.path,
    required this.startUtc,
    required this.endUtc,
    required this.denum,
  });

  /// File slot passed to `swe_get_current_file_data`.
  final int ifno;

  /// Loaded file path, as reported by Swiss Ephemeris.
  final String path;

  /// First instant covered by the file.
  final DateTime startUtc;

  /// Last instant covered by the file.
  final DateTime endUtc;

  /// File denumeration reported by Swiss Ephemeris.
  final int denum;

  /// True when the reported range describes a real interval.
  bool get isValid => endUtc.isAfter(startUtc);

  /// True when the file covers the whole calendar-year span.
  bool coversYears(int startYear, int endYear) =>
      isValid && startUtc.year <= startYear && endUtc.year >= endYear;

  @override
  String toString() => 'EphemerisFileRange(ifno: $ifno, path: $path, '
      '${startUtc.toIso8601String()} .. ${endUtc.toIso8601String()})';
}

/// The data files Swiss Ephemeris actually loaded for this process.
///
/// A missing entry means that file did not load and the library used its
/// analytical fallback; it is not a hardcoded claim about the package assets.
class EphemerisDataRange {
  const EphemerisDataRange({
    this.planets,
    this.moon,
    this.asteroids,
  });

  /// `sepl_*.se1` (planets).
  final EphemerisFileRange? planets;

  /// `semo_*.se1` (Moon).
  final EphemerisFileRange? moon;

  /// `seas_*.se1` (main asteroids).
  final EphemerisFileRange? asteroids;

  /// Every file that loaded, in slot order.
  List<EphemerisFileRange> get files => [
        if (planets != null) planets!,
        if (moon != null) moon!,
        if (asteroids != null) asteroids!,
      ];

  /// True when both files needed for a Sun/Moon Panchang are present.
  bool get hasPlanetsAndMoon =>
      (planets?.isValid ?? false) && (moon?.isValid ?? false);

  /// True when the planetary and lunar files cover the whole year span.
  bool coversYears(int startYear, int endYear) =>
      (planets?.coversYears(startYear, endYear) ?? false) &&
      (moon?.coversYears(startYear, endYear) ?? false);

  @override
  String toString() => 'EphemerisDataRange('
      'planets: ${planets ?? 'not loaded'}, '
      'moon: ${moon ?? 'not loaded'}, '
      'asteroids: ${asteroids ?? 'not loaded'})';
}
