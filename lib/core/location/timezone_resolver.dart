import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone_finder/timezone_finder.dart';

import 'location_defaults.dart';

/// Legacy IANA aliases some Android ROMs still report.
///
/// `package:timezone` only knows canonical names, so an Indian ROM reporting
/// `Asia/Calcutta` (renamed in 2001) must be normalized before use.
const Map<String, String> kLegacyTimezoneAliases = {
  'Asia/Calcutta': 'Asia/Kolkata',
};

/// Attribution required by the ODbL licence of the bundled boundary data.
///
/// Shown on the About screen; keep it in sync with the package readme.
const String kTimezoneBoundaryAttribution =
    'Time zone boundaries: © OpenStreetMap contributors (ODbL), '
    'built by Timezone Boundary Builder.';

/// Where a persisted zone identifier came from.
///
/// Persisted next to the zone so a later upgrade can re-resolve values the
/// app guessed (device zone) without overwriting an explicit choice.
enum TimezoneSource {
  /// Looked up from the place's coordinates with the bundled boundaries.
  place,

  /// Supplied explicitly by a caller (a user or data override).
  user,

  /// Not derived from the place: the device zone or the app default. Safe to
  /// retry once a real lookup is possible.
  device;

  /// Value written to Hive. Stable once shipped - do not rename.
  String get storageValue => switch (this) {
    TimezoneSource.place => 'place',
    TimezoneSource.user => 'user',
    TimezoneSource.device => 'device',
  };

  /// Parses a persisted marker. Null for missing or unknown values, which
  /// callers must treat as "legacy, may be re-resolved".
  static TimezoneSource? parse(Object? raw) {
    if (raw is! String) return null;
    for (final source in TimezoneSource.values) {
      if (source.storageValue == raw) return source;
    }
    return null;
  }
}

/// A resolved zone plus the provenance of the answer.
typedef PlaceTimezone = ({String id, TimezoneSource source});

/// Normalizes a stored or platform-reported zone identifier.
///
/// Trims whitespace, maps legacy aliases, and returns an empty string for
/// blank input so callers can treat "missing" and "empty" the same way.
String canonicalTimezoneId(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return '';
  return kLegacyTimezoneAliases[trimmed] ?? trimmed;
}

/// Resolves the IANA time zone for a place from its coordinates.
///
/// Uses the bundled timezone boundary data (compiled in, no network), so the
/// answer is the zone the place actually observes even when the device is in
/// another zone. Requires tzdata initialized from
/// `package:timezone/data/latest_all.dart` (see `AppBootstrap.initTimezones`).
///
/// Falls back, in order, to [deviceTimezone] and then [kDefaultTimezoneId]
/// when the coordinate has no land polygon (open ocean, or more than ~22 km
/// offshore), when the boundary identifier is missing from the loaded tzdb,
/// or when tzdata was never initialized. The returned [TimezoneSource] says
/// which happened, so a fallback can be retried later.
///
/// [deviceTimezone] is injectable so tests do not depend on the platform
/// channel.
Future<PlaceTimezone> resolvePlaceTimezone(
  double latitude,
  double longitude, {
  Future<String> Function()? deviceTimezone,
}) async {
  // Never ask the platform about a coordinate we cannot trust.
  if (!_isValidCoordinate(latitude, longitude)) {
    return (id: kDefaultTimezoneId, source: TimezoneSource.device);
  }

  try {
    // GeoJSON argument order: longitude first, then latitude.
    final location = findLocation(longitude, latitude);
    final canonical = canonicalTimezoneId(location?.name ?? '');
    if (canonical.isNotEmpty) {
      return (id: canonical, source: TimezoneSource.place);
    }
  } catch (_) {
    // Out-of-range values are guarded above, so this is a missing boundary
    // identifier or an uninitialized tzdb: fall through to the device zone.
  }

  try {
    final raw = await (deviceTimezone ?? _deviceTimezoneId)();
    final canonical = canonicalTimezoneId(raw);
    if (canonical.isNotEmpty) {
      return (id: canonical, source: TimezoneSource.device);
    }
  } catch (_) {
    // Platform channel unavailable (tests, unsupported target): use the
    // app's primary-audience default rather than failing the location.
  }
  return (id: kDefaultTimezoneId, source: TimezoneSource.device);
}

/// Decodes the boundary index now, so the first [resolvePlaceTimezone] does not
/// pay for it. Harmless if called again.
Future<void> warmPlaceTimezoneIndex() => ensurePreloaded();

Future<String> _deviceTimezoneId() async {
  final info = await FlutterTimezone.getLocalTimezone();
  return info.identifier;
}

bool _isValidCoordinate(double latitude, double longitude) {
  return latitude.isFinite &&
      longitude.isFinite &&
      latitude >= -90 &&
      latitude <= 90 &&
      longitude >= -180 &&
      longitude <= 180;
}
