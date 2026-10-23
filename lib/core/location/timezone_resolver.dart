import 'package:flutter_timezone/flutter_timezone.dart';

import 'location_defaults.dart';

/// Legacy IANA aliases some Android ROMs still report.
///
/// `package:timezone` only knows canonical names, so an Indian ROM reporting
/// `Asia/Calcutta` (renamed in 2001) must be normalized before use.
const Map<String, String> kLegacyTimezoneAliases = {
  'Asia/Calcutta': 'Asia/Kolkata',
};

/// Normalizes a stored or platform-reported zone identifier.
///
/// Trims whitespace, maps legacy aliases, and returns an empty string for
/// blank input so callers can treat "missing" and "empty" the same way.
String canonicalTimezoneId(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return '';
  return kLegacyTimezoneAliases[trimmed] ?? trimmed;
}

/// Resolves the IANA time zone for a place.
///
/// **Phase 0 limitation:** this seeds the answer from the device zone, because
/// the app does not yet ship a coordinate-to-zone table. That is correct for
/// the India-first audience (where the device is normally on
/// `Asia/Kolkata`) but can be wrong for a place outside the device's zone.
/// Phase 1 replaces this with a place lookup; callers must not treat the
/// result as proof that the selected place uses that zone.
///
/// [deviceTimezone] is injectable so tests do not depend on the platform
/// channel.
Future<String> resolvePlaceTimezoneId(
  double latitude,
  double longitude, {
  Future<String> Function()? deviceTimezone,
}) async {
  if (!_isValidCoordinate(latitude, longitude)) {
    return kDefaultTimezoneId;
  }

  try {
    final raw = await (deviceTimezone ?? _deviceTimezoneId)();
    final canonical = canonicalTimezoneId(raw);
    if (canonical.isNotEmpty) return canonical;
  } catch (_) {
    // Platform channel unavailable (tests, unsupported target): use the
    // app's primary-audience default rather than failing the location.
  }
  return kDefaultTimezoneId;
}

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
