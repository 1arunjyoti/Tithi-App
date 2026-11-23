import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../models/festival.dart';
import '../core/perf/startup_timeline.dart';
import 'storage_service.dart';

/// Repository for handling Festival data persistence with Hive
class FestivalRepository {
  // OPT-6: singleton so the in-memory [_cachedFestivals] list is shared across
  // all call sites (previously each Provider.read created a new instance and
  // a new cache that started as null).
  static final FestivalRepository _instance = FestivalRepository._internal();
  factory FestivalRepository() => _instance;
  FestivalRepository._internal();
  static const String boxName = 'festivals';
  static const String settingsBoxName = 'festival_settings';
  // Increment when existing festival records need to be re-seeded even if
  // the asset fingerprint is unchanged.
  static const int _festivalSeedVersion = 2;

  /// Settings key holding the fingerprint of the catalog the box was seeded
  /// from (also the value the reseed check compares).
  static const String _versionKey = 'version';

  /// App build that produced [_versionKey]. The bundled JSON can only change
  /// when the APK does, so a matching build means the fingerprint can be
  /// reused instead of re-hashing 230 KB on every launch.
  ///
  /// Consequence for maintainers: editing `assets/festivals.json` without
  /// bumping `version`+`build number` in pubspec.yaml keeps the old catalog on
  /// installed devices (only a fresh install re-reads it). Bump the build.
  static const String _versionBuildKey = 'version_build';

  /// Value of [_festivalSeedVersion] at the time [_versionKey] was written.
  static const String _versionSeedKey = 'version_seed';

  /// Cached festival list to avoid repeated toList() calls
  List<Festival>? _cachedFestivals;

  /// Fingerprint of the bundled catalog this session seeded/loaded.
  ///
  /// Persisted snapshots of derived data (the all-festivals year list) include
  /// it in their key, so editing `assets/festivals.json` invalidates them even
  /// when the calculation version did not change.
  int _catalogVersion = 0;
  int get catalogVersion => _catalogVersion;

  /// Initialize the repository
  ///
  /// Opens the Hive box and seeds data from JSON if the box is empty
  /// or if the festivals version has changed.
  Future<void> init() async {
    final storageService = StorageService();
    final box = await storageService.openFestivalsBox();
    final settingsBox = await storageService.openFestivalSettingsBox();

    final storedVersion = settingsBox.get(_versionKey, defaultValue: 0) as int;
    final storedSeed = settingsBox.get(_versionSeedKey, defaultValue: 0) as int;
    final storedBuild = settingsBox.get(_versionBuildKey) as String?;
    final build = await _currentBuildStamp();

    // The asset is only worth reading when this build has not already hashed
    // it, the box still holds that seed, and the seed rules have not changed.
    final canTrustFingerprint =
        build != null &&
        build == storedBuild &&
        storedSeed == _festivalSeedVersion &&
        storedVersion != 0 &&
        box.isNotEmpty;

    String? jsonString;
    var festivalsVersion = storedVersion;
    if (!canTrustFingerprint) {
      jsonString = await _loadCatalogAsset();
      festivalsVersion = _versionFromJsonContent(jsonString);
    }

    final needsReseed = box.isEmpty || storedVersion != festivalsVersion;

    if (needsReseed) {
      // The trusted path does not hold the JSON; a reseed always needs it.
      jsonString ??= await _loadCatalogAsset();
      _catalogVersion = festivalsVersion;
      debugPrint(
        'Festival data needs update (stored version: $storedVersion, current: $festivalsVersion)',
      );
      // Clear old data and re-seed
      await box.clear();
      await _seedData(box, jsonString);
      _cachedFestivals = List<Festival>.unmodifiable(box.values);
    } else {
      _catalogVersion = festivalsVersion;
      try {
        _cachedFestivals = List<Festival>.unmodifiable(box.values);
        debugPrint(
          'Loaded ${box.length} festivals from Hive cache (version $storedVersion)',
        );
      } catch (e) {
        // The cached box was written by an older adapter (e.g. before a new
        // non-nullable HiveField landed) and can no longer be read. Wipe and
        // re-seed from the asset JSON rather than crashing on upgrade.
        debugPrint('Festival cache unreadable ($e); re-seeding from JSON...');
        jsonString ??= await _loadCatalogAsset();
        await box.clear();
        await _seedData(box, jsonString);
        await settingsBox.put(_versionKey, festivalsVersion);
        _cachedFestivals = List<Festival>.unmodifiable(box.values);
      }
    }

    // Record what this build verified, so the next launch can skip the hash.
    // Written on the trusted path too: it refreshes the stamp after an upgrade
    // that reused a matching build string (test runners, sideloads).
    await settingsBox.put(_versionKey, festivalsVersion);
    await settingsBox.put(_versionSeedKey, _festivalSeedVersion);
    if (build != null) await settingsBox.put(_versionBuildKey, build);

    StartupTimeline.mark('festival-init', {
      'reseeds': needsReseed,
      'count': _cachedFestivals?.length ?? 0,
      'hashed': jsonString != null,
    });
  }

  /// Reads the bundled catalog, reporting the transfer so a cold start shows
  /// whether the 230 KB asset was touched at all.
  Future<String> _loadCatalogAsset() async {
    final jsonString = await rootBundle.loadString('assets/festivals.json');
    StartupTimeline.mark('festival-asset', {
      'kb': (jsonString.length / 1024).round(),
    });
    return jsonString;
  }

  /// Identity of the installed build, or null when it cannot be read (tests,
  /// plugin unavailable). A null stamp always falls back to hashing.
  Future<String?> _currentBuildStamp() async {
    try {
      final info = await PackageInfo.fromPlatform();
      return '${info.version}+${info.buildNumber}';
    } on Object {
      return null;
    }
  }

  /// In-memory list without touching Hive (and without caching): the safe
  /// read while [init] is still seeding on a fresh install.
  List<Festival> peekCached() => _cachedFestivals ?? const [];

  /// Get all festivals from the box (cached).
  /// PERF-4: Returns an unmodifiable view to avoid unnecessary list copies.
  ///
  /// Never caches an empty box: on a fresh install the box is open but
  /// empty until [init] finishes seeding, and caching that transient []
  /// would stick (see [festivalProvider]).
  List<Festival> getAll() {
    if (_cachedFestivals != null) {
      return _cachedFestivals!;
    }
    final box = StorageService().getFestivalsBox();
    if (box.isEmpty) {
      return const [];
    }
    _cachedFestivals = List<Festival>.unmodifiable(box.values);
    return _cachedFestivals!;
  }

  /// Seed data from the asset JSON file
  Future<void> _seedData(Box<Festival> box, String jsonString) async {
    debugPrint('Seeding festivals from JSON to Hive...');
    try {
      // Decode the whole catalog on a background isolate: on the main
      // thread this parse drops several frames on first launch (see the
      // "Skipped N frames" bursts). jsonDecode is a top-level function so
      // it qualifies as a compute callback; the small per-item fromJson
      // mapping + the single batched putAll stay on the main isolate
      // (Hive boxes live there).
      final List<dynamic> jsonList =
          await compute(jsonDecode, jsonString) as List<dynamic>;
      final festivals = jsonList.map((j) => Festival.fromJson(j)).toList();

      // Use festival ID as key for O(1) lookup
      final Map<String, Festival> festivalMap = {
        for (var f in festivals) f.id: f,
      };

      await box.putAll(festivalMap);
      debugPrint('Successfully seeded ${festivals.length} festivals to Hive');
    } catch (e) {
      debugPrint('Error seeding festival data: $e');
      rethrow;
    }
  }

  /// Computes a version fingerprint from the JSON content.
  ///
  /// SMELL-04: The original 31-bit polynomial hash alone had a non-trivial
  /// collision probability for large JSON files.  We XOR it with a shifted
  /// content-length term so that any edit which changes the byte-count (the
  /// overwhelming majority of real edits) is caught even if the hash
  /// collides.
  int _versionFromJsonContent(String jsonContent) {
    var hash = 0;
    for (final rune in jsonContent.runes) {
      hash = ((hash * 31) + rune) & 0x7fffffff;
    }
    // Mix in content length to reduce collision probability.
    return hash ^ ((jsonContent.length & 0x3fff) << 17) ^ _festivalSeedVersion;
  }
}
