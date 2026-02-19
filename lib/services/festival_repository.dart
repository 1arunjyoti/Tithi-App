import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/festival.dart';
import 'storage_service.dart';

/// Repository for handling Festival data persistence with Hive
class FestivalRepository {
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
    } else {
      debugPrint(
        'Loaded ${box.length} festivals from Hive cache (version $storedVersion)',
      );
    }

    // Cache the list after init
    _cachedFestivals = box.values.toList();
  }

  /// Get all festivals from the box (cached)
  List<Festival> getAll() {
    if (_cachedFestivals != null) {
      return _cachedFestivals!;
    }
    final box = StorageService().getFestivalsBox();
    _cachedFestivals = box.values.toList();
    return _cachedFestivals!;
  }

  /// Seed data from the asset JSON file
  Future<void> _seedData(Box<Festival> box, String jsonString) async {
    debugPrint('Seeding festivals from JSON to Hive...');
    try {
      final List<dynamic> jsonList = json.decode(jsonString);
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

  int _versionFromJsonContent(String jsonContent) {
    var hash = 0;
    for (final rune in jsonContent.runes) {
      hash = ((hash * 31) + rune) & 0x7fffffff;
    }
    return hash;
  }
}
