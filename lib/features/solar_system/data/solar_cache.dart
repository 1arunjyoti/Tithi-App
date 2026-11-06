import 'solar_models.dart';

// Phase 6a: bounded in-memory cache for resolved solar-system data.
// Positions move slowly, so entries are keyed by hour + view mode + rounded
// location. Date scrubbing, animation replays, and back-navigation hit this
// instead of redoing the batched FFI call.

const int solarCacheMax = 60;

final Map<String, SolarSystemData> _solarCache = {};

String solarCacheKey(
  DateTime instant,
  SolarSystemViewMode viewMode,
  double latitude,
  double longitude,
) {
  final hour = DateTime(
    instant.year,
    instant.month,
    instant.day,
    instant.hour,
  );
  return '${hour.year}-${hour.month}-${hour.day}-${hour.hour}_'
      '${viewMode.index}_'
      '${latitude.toStringAsFixed(2)}_${longitude.toStringAsFixed(2)}';
}

SolarSystemData? cachedSolarData(String key) => _solarCache[key];

void storeSolarData(String key, SolarSystemData data) {
  if (_solarCache.length >= solarCacheMax) {
    final toRemove = _solarCache.keys.take(solarCacheMax ~/ 5).toList();
    for (final k in toRemove) {
      _solarCache.remove(k);
    }
  }
  _solarCache[key] = data;
}
