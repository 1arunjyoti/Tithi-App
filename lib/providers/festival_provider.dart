import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/festival.dart';

/// Provider that loads and caches all festivals from festivals.json
final festivalProvider = FutureProvider<List<Festival>>((ref) async {
  final jsonString = await rootBundle.loadString('assets/festivals.json');
  final List<dynamic> jsonList = json.decode(jsonString);
  return jsonList.map((j) => Festival.fromJson(j)).toList();
});

/// Provider that returns only major festivals
final majorFestivalsProvider = Provider<AsyncValue<List<Festival>>>((ref) {
  return ref
      .watch(festivalProvider)
      .whenData(
        (festivals) => festivals.where((f) => f.category == 'major').toList(),
      );
});

/// Provider that returns only recurring vrats
final vratProvider = Provider<AsyncValue<List<Festival>>>((ref) {
  return ref
      .watch(festivalProvider)
      .whenData(
        (festivals) => festivals
            .where((f) => f.category == 'vrat' || f.recurring)
            .toList(),
      );
});
