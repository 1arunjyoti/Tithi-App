import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/festival.dart';
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

  /// Cached festival list to avoid repeated toList() calls
  List<Festival>? _cachedFestivals;

  /// Initialize the repository
  ///
  /// Opens the Hive box and seeds data from JSON if the box is empty
  /// or if the festivals version has changed.
  Future<void> init() async {
    final storageService = StorageService();
    final box = await storageService.openFestivalsBox();
    final settingsBox = await storageService.openFestivalSettingsBox();

    final jsonString = await rootBundle.loadString('assets/festivals.json');
    final festivalsVersion = _versionFromJsonContent(jsonString);

    final storedVersion = settingsBox.get('version', defaultValue: 0);
    final needsReseed = box.isEmpty || storedVersion != festivalsVersion;

    if (needsReseed) {
      debugPrint(
        'Festival data needs update (stored version: $storedVersion, current: $festivalsVersion)',
      );
      // Clear old data and re-seed
      await box.clear();
      await _seedData(box, jsonString);
      // Update stored version
      await settingsBox.put('version', festivalsVersion);
      // Cache the list after init (unmodifiable to avoid accidental mutation)
      _cachedFestivals = List<Festival>.unmodifiable(box.values);
    } else {
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
        await box.clear();
        await _seedData(box, jsonString);
        await settingsBox.put('version', festivalsVersion);
        _cachedFestivals = List<Festival>.unmodifiable(box.values);
      }
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
      // (Hive boxes live there). No worse on web, where compute runs
      // inline just like before.
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
    return hash ^ ((jsonContent.length & 0x3fff) << 17);
  }
}
