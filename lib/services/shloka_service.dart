import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/shloka.dart';

class ShlokaService {
  static final ShlokaService _instance = ShlokaService._internal();
  factory ShlokaService() => _instance;
  ShlokaService._internal();

  List<Shloka> _shlokas = [];
  bool _isInitialized = false;

  /// Load shlokas from JSON asset
  Future<void> init() async {
    if (_isInitialized) return;

    try {
      final String response = await rootBundle.loadString(
        'assets/data/shlokas.json',
      );
      final List<dynamic> data = json.decode(response);
      _shlokas = data.map((e) => Shloka.fromJson(e)).toList();
      _isInitialized = true;
    } catch (e) {
      // Handle error or fallback
      if (kDebugMode) {
        print('Error loading shlokas: $e');
      }
      _shlokas = [];
    }
  }

  /// Get a consistent shloka for a given date.
  ///
  /// When [festivalIds] are provided, prefer shlokas tagged for those
  /// festivals. Falls back to the full list if no matches are found.
  Shloka? getShlokaForDate(
    DateTime date, {
    List<String> festivalIds = const [],
  }) {
    if (_shlokas.isEmpty) return null;

    var shlokaPool = _shlokas;
    if (festivalIds.isNotEmpty) {
      final normalizedIds = festivalIds
          .map((id) => id.trim())
          .where((id) => id.isNotEmpty)
          .toSet();
      if (normalizedIds.isNotEmpty) {
        final festivalPool = _shlokas
            .where((shloka) => shloka.festivalIds.any(normalizedIds.contains))
            .toList();
        if (festivalPool.isNotEmpty) {
          shlokaPool = festivalPool;
        }
      }
    }

    // Use date hash to pick a consistent shloka for the day.
    // This ensures all users (and re-opens) see the same shloka for the same day.
    final dayHash = date.year * 10000 + date.month * 100 + date.day;
    final index = dayHash % shlokaPool.length;
    return shlokaPool[index];
  }

  /// Get shloka for today
  Shloka? getShlokaForToday({List<String> festivalIds = const []}) {
    return getShlokaForDate(DateTime.now(), festivalIds: festivalIds);
  }

  /// Get a list of shlokas for the next N days
  /// [startDate] defaults to today if null
  List<Shloka> getShlokasForNextNDays(int n, {DateTime? startDate}) {
    if (_shlokas.isEmpty) return [];

    final start = startDate ?? DateTime.now();
    final List<Shloka> result = [];

    for (int i = 0; i < n; i++) {
      final date = start.add(Duration(days: i));
      final shloka = getShlokaForDate(date);
      if (shloka != null) {
        result.add(shloka);
      }
    }
    return result;
  }
}
