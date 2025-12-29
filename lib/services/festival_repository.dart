import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/festival.dart';

/// Repository for handling Festival data persistence with Hive
class FestivalRepository {
  static const String boxName = 'festivals';

  /// Cached festival list to avoid repeated toList() calls
  List<Festival>? _cachedFestivals;

  /// Initialize the repository
  ///
  /// Opens the Hive box and seeds data from JSON if the box is empty.
  Future<void> init() async {
    final box = await Hive.openBox<Festival>(boxName);

    if (box.isEmpty) {
      // Seed data from JSON
      await _seedData(box);
    } else {
      debugPrint('Loaded ${box.length} festivals from Hive cache');
    }

    // Cache the list after init
    _cachedFestivals = box.values.toList();
  }

  /// Get all festivals from the box (cached)
  List<Festival> getAll() {
    if (_cachedFestivals != null) {
      return _cachedFestivals!;
    }
    // Fallback if cache is null (shouldn't happen after init)
    final box = Hive.box<Festival>(boxName);
    _cachedFestivals = box.values.toList();
    return _cachedFestivals!;
  }

  /// Seed data from the asset JSON file
  Future<void> _seedData(Box<Festival> box) async {
    debugPrint('Seeding festivals from JSON to Hive...');
    try {
      final jsonString = await rootBundle.loadString('assets/festivals.json');
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
}
