import 'package:hive/hive.dart';

import '../../../models/panchang_data.dart';
import '../../../models/panchang_profile.dart';
import '../../../models/panchang_school.dart';
import '../../../core/format/date_only.dart';
import '../../../services/storage_service.dart';
import '../../../utils/date_utils.dart';

const panchangLocationSignatureKey = '__location_signature__';

// Sync in-memory cache for selected-date UI (EventList + Paksha).
//
// The adaptive Hindu/Bengali grid publishes its already-resolved, filtered
// day records here. A date tap can then refine only that day's transition
// instead of making panchangForDateProvider start a second, Gregorian-month
// batch. The cache also remains the stale-content fallback while that small
// refinement completes.
final Map<DateTime, PanchangData> panchangUiCache = {};
const int panchangUiCacheMax = 100;

// P0: day truncation is dateOnly() (core/format/date_only.dart).

/// Last successful [PanchangData] for [date], if any.
PanchangData? cachedPanchangUiSync(DateTime date) {
  return panchangUiCache[dateOnly(date)];
}

/// Drops every process-local UI day.
///
/// Called when the calculation school changes: the UI cache is keyed by date
/// only, so a day computed by the other school would otherwise be served
/// unchanged.
void clearPanchangUiCache() => panchangUiCache.clear();

void storePanchangUiSync(DateTime date, PanchangData data) {
  final normalizedDate = dateOnly(date);
  final existing = panchangUiCache[normalizedDate];
  // The adaptive month batch deliberately omits the expensive intraday
  // transition search. Do not replace a previously refined result with that
  // cheaper record when an adaptive grid rebuilds.
  if (existing?.hasTithiTransition == true && !data.hasTithiTransition) {
    data = data.copyWith(
      tithiTransitionTime: existing!.tithiTransitionTime,
      transitionTithiIndex: existing.transitionTithiIndex,
    );
  }
  if (panchangUiCache.length >= panchangUiCacheMax) {
    final toRemove =
        panchangUiCache.keys.take(panchangUiCacheMax ~/ 5).toList();
    for (final k in toRemove) {
      panchangUiCache.remove(k);
    }
  }
  panchangUiCache[normalizedDate] = data;
}

String panchangDateKeyLocal(DateTime date) => panchangDateKey(date);

/// Bumped when a cached day's *inputs* change without a calculation-version
/// bump, so old entries become misses.
///
/// 2: the place zone is resolved from the coordinates (it used to be the
/// device zone), so days cached while the device was in another zone hold
/// instants in the wrong zone.
/// 3: the place clock decides which zone a day is computed in (live location
/// uses the device zone, a manually picked place uses its own), so a day
/// cached under the previous policy can hold instants resolved in the other
/// zone for the same key.
const int kPlaceContextVersion = 3;

/// Calculation school currently in force for cache signatures.
///
/// The Panchang caches are already process-wide statics, so the school that
/// produced an entry has to live next to them. [CalendarPreferencesNotifier]
/// sets this when the persisted preference changes, and the notification
/// isolate sets it after reading preferences, before it computes anything.
///
/// Keeping it out of every call site avoids threading a parameter through the
/// dozen cache-key builders that all sit below the settings layer.
PanchangSchool get activePanchangSchool => _activePanchangSchool;
set activePanchangSchool(PanchangSchool school) => _activePanchangSchool =
    school;
PanchangSchool _activePanchangSchool = PanchangSchool.bisuddha;

String locationSignature(
  double latitude,
  double longitude, {
  PanchangSchool? school,
}) {
  final resolved = school ?? _activePanchangSchool;
  return '${latitude.toStringAsFixed(4)}_${longitude.toStringAsFixed(4)}'
      '_v$kPanchangCalculationVersion'
      '_p$kPlaceContextVersion'
      '_s${resolved.name}';
}

String buildCacheKey(
  DateTime date,
  double latitude,
  double longitude, [
  String suffix = '',
]) {
  return '${panchangDateKeyLocal(date)}_${locationSignature(latitude, longitude)}${suffix.isNotEmpty ? "_$suffix" : ""}';
}

/// Shared preparation for the Hive panchang cache box (also used by the
/// calendar's adaptive cell computation so festival flags skip the
/// single-day transition search).
Future<Box<dynamic>> preparePanchangCacheBox(
  double latitude,
  double longitude,
) async {
  final cacheBox = await StorageService().openPanchangCacheBox();
  final expectedSignature = locationSignature(latitude, longitude);
  final storedSignature =
      cacheBox.get(panchangLocationSignatureKey) as String?;

  if (storedSignature != expectedSignature) {
    await cacheBox.clear();
    await cacheBox.put(panchangLocationSignatureKey, expectedSignature);
  }

  return cacheBox;
}

double? getCachedRawTithi(
  Box<dynamic> cacheBox,
  DateTime date,
  double latitude,
  double longitude, {
  String suffix = '',
}) {
  final cached = cacheBox.get(buildCacheKey(date, latitude, longitude, suffix));
  if (cached is num) {
    return cached.toDouble();
  }
  return null;
}

Future<void> storeCachedRawTithi(
  Box<dynamic> cacheBox,
  DateTime date,
  double latitude,
  double longitude,
  double rawTithi, {
  String suffix = '',
}) async {
  await cacheBox.put(
    buildCacheKey(date, latitude, longitude, suffix),
    rawTithi,
  );
}

// ---------------------------------------------------------------------------
// Shared Hive access for the Hindu/Bengali calendar services.
// The monthly batch writes sunrise raw-tithi ('') and sunrise masa ('masa2')
// per date+location; the lunar services read those same entries (and write
// back their own FFI results) so Gregorian usage warms Hindu/Bengali month
// grids and vice versa. Without this sharing, every cold lunar-month slice
// redozens of sequential masa/tithi resolutions (~hundreds of blocking FFI
// calls) while Gregorian month turns read straight from this box.
// ---------------------------------------------------------------------------

/// Suffix of the sunrise-masa entry (versioned: bump when masa attribution
/// logic changes, in lockstep with the batch path's key above).
const String panchangMasaCacheSuffix = 'masa2';

/// Key builder identical to the batch path's (date + 4dp location + suffix).
String panchangCacheKey(
  DateTime date,
  double latitude,
  double longitude, [
  String suffix = '',
]) => buildCacheKey(date, latitude, longitude, suffix);

/// Null-safe reads (a wrong-typed entry degrades to a miss, never a throw).
double? readPanchangCacheDouble(Box<dynamic> cacheBox, String key) {
  final cached = cacheBox.get(key);
  return cached is num ? cached.toDouble() : null;
}

/// Null-safe reads (a wrong-typed entry degrades to a miss, never a throw).
String? readPanchangCacheString(Box<dynamic> cacheBox, String key) {
  final cached = cacheBox.get(key);
  return cached is String ? cached : null;
}
