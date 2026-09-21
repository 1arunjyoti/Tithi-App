import 'solar_models.dart';

// Phase 6a: bounded in-memory cache for resolved solar-system data.
// Positions move negligibly within a day, so entries are keyed by
// day + view mode + rounded location. Date scrubbing, animation replays,
// and back-navigation hit this instead of redoing the batched FFI call.

const int solarCacheMax = 60;

final Map<String, SolarSystemData> _solarCache = {};

String solarCacheKey(
  DateTime day,
  SolarSystemViewMode viewMode,
  double latitude,
  double longitude,
) {
  final d = DateTime(day.year, day.month, day.day);
  return '${d.year}-${d.month}-${d.day}_${viewMode.index}_'
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
