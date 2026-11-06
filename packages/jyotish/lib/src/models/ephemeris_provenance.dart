/// Which ephemeris backend actually produced a calculation.
enum EphemerisBackend {
  /// No backend was requested; Swiss Ephemeris chose one.
  automatic('Automatic'),

  /// JPL DE ephemeris.
  jpl('JPL'),

  /// Swiss Ephemeris `.se1` data.
  swiss('Swiss Ephemeris'),

  /// Moshier analytical fallback.
  moshier('Moshier'),

  /// The native return flags did not contain a recognised backend.
  unknown('Unknown');

  const EphemerisBackend(this.label);

  /// Human-readable name for logs and UI.
  final String label;

  /// Reads the backend bits from a `swe_calc_ut()` return value.
  ///
  /// Swiss Ephemeris uses `SEFLG_JPLEPH`, `SEFLG_SWIEPH` and `SEFLG_MOSEPH`;
  /// a zero backend field means the library chose the backend itself.
  static EphemerisBackend fromFlags(int flags) {
    return switch (flags & 0x07) {
      1 => jpl,
      2 => swiss,
      4 => moshier,
      0 => automatic,
      _ => unknown,
    };
  }
}

/// Provenance for one calculated position.
///
/// [requestedFlags] is the flag set sent to `swe_calc_ut()`; [returnedFlags]
/// is the flag set Swiss Ephemeris reports for the calculation that actually
/// happened. The two differ when a requested file is unavailable and the
/// library falls back to Moshier - the case [usedFallback] identifies.
class EphemerisProvenance {
  const EphemerisProvenance({
    required this.requestedFlags,
    required this.returnedFlags,
    required this.backend,
    this.warning,
  });

  /// Flags requested by the caller.
  final int requestedFlags;

  /// Flags reported by `swe_calc_ut()` for the calculation that ran.
  final int returnedFlags;

  /// Backend that actually produced the position.
  final EphemerisBackend backend;

  /// Native warning/error text, preserved even on success.
  final String? warning;

  /// Backend the caller asked for, derived from [requestedFlags].
  EphemerisBackend get requestedBackend =>
      EphemerisBackend.fromFlags(requestedFlags);

  /// True when the result came from Swiss `.se1` files.
  bool get isSwissEphemeris => backend == EphemerisBackend.swiss;

  /// True when the result came from JPL or Swiss data rather than Moshier.
  bool get isHighPrecision =>
      backend == EphemerisBackend.swiss || backend == EphemerisBackend.jpl;

  /// True when the library used the analytical Moshier fallback.
  ///
  /// This is the flag a caller should check before presenting a result as
  /// Swiss Ephemeris output.
  bool get usedFallback => backend == EphemerisBackend.moshier;

  @override
  String toString() {
    final warningText = warning == null ? '' : ', warning: $warning';
    return 'EphemerisProvenance(requested: $requestedBackend, '
        'actual: $backend, returnedFlags: $returnedFlags$warningText)';
  }
}
