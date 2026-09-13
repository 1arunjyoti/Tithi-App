import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/shloka.dart';

class ShlokaService {
  static final ShlokaService _instance = ShlokaService._internal();
  factory ShlokaService() => _instance;
  ShlokaService._internal();

  List<Shloka> _shlokas = [];

  /// Single-flight init memo: concurrent callers share one asset load, and
  /// a failed load settles (to an empty list) instead of retrying the
  /// asset read + full parse on every provider rebuild.
  Future<void>? _initFuture;

  /// Load shlokas from the JSON asset. Never throws: a missing or corrupt
  /// asset yields an empty list (callers treat null/empty as "no verse").
  Future<void> init() => _initFuture ??= _load();

  Future<void> _load() async {
    try {
      final String response = await rootBundle.loadString(
        'assets/data/shlokas.json',
      );
      _shlokas = parseShlokas(json.decode(response));
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error loading shlokas: $e');
      }
      _shlokas = [];
    }
  }

  /// Parses decoded JSON into verses, skipping corrupt entries instead of
  /// dropping the whole list when a single entry has the wrong shape.
  /// Returns an empty list when the root is not a JSON array.
  static List<Shloka> parseShlokas(Object? decoded) {
    if (decoded is! List) return const [];
    final shlokas = <Shloka>[];
    for (final entry in decoded) {
      try {
        if (entry is Map<String, dynamic>) {
          shlokas.add(Shloka.fromJson(entry));
        } else if (entry is Map) {
          shlokas.add(Shloka.fromJson(Map<String, dynamic>.from(entry)));
        }
      } catch (_) {
        continue;
      }
    }
    return shlokas;
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
