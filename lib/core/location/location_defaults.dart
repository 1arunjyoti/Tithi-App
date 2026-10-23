// P0-1: single source of truth for the Delhi fallback location.
// Replaces ~66 scattered 28.6139/77.2090 literals (default args, ?? chains,
// Hive defaults). See also LocationData.defaultLocation for the model form.

/// Default latitude (Delhi) used when no location is available.
const double kDefaultLatitude = 28.6139;

/// Default longitude (Delhi) used when no location is available.
const double kDefaultLongitude = 77.2090;

/// Default altitude in metres above mean sea level (Delhi) used when no
/// location is available.
const double kDefaultAltitudeMeters = 216;

/// Default IANA time zone for the Delhi fallback.
const String kDefaultTimezoneId = 'Asia/Kolkata';
