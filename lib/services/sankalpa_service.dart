import 'package:hive_flutter/hive_flutter.dart';
import '../models/sankalpa.dart';

class SankalpaService {
  static const String _boxName = 'sankalpas';

  Future<void> init() async {
    if (!Hive.isBoxOpen(_boxName)) {
      await Hive.openBox<Sankalpa>(_boxName);
    }
  }

  Box<Sankalpa> get _box => Hive.box<Sankalpa>(_boxName);

  /// Get all sankalpas
  List<Sankalpa> getAllSankalpas() {
    return _box.values.toList();
  }

  /// Get active sankalpas (not completed and end date not passed)
  List<Sankalpa> getActiveSankalpas() {
    // final now = DateTime.now();
    return _box.values.where((s) {
      if (s.isCompleted) return false;
      // Optional: Check if expired? For now, just explicit completion check
      // OR maybe strict date check: s.endDate != null && s.endDate!.isAfter(now)
      return true;
    }).toList();
  }

  /// Get completed sankalpas
  List<Sankalpa> getCompletedSankalpas() {
    return _box.values.where((s) => s.isCompleted).toList();
  }

  /// Add a new sankalpa
  Future<void> addSankalpa(Sankalpa sankalpa) async {
    await _box.put(sankalpa.id, sankalpa);
  }

  /// Update an existing sankalpa
  Future<void> updateSankalpa(Sankalpa sankalpa) async {
    await _box.put(sankalpa.id, sankalpa);
  }

  /// Delete a sankalpa
  Future<void> deleteSankalpa(String id) async {
    await _box.delete(id);
  }

  /// Mark daily progress for a sankalpa
  Future<void> markDailyCompletion(String id, DateTime date) async {
    final sankalpa = _box.get(id);
    if (sankalpa != null) {
      // Create a new list to ensure Hive detects the change
      final newCompletions = List<DateTime>.from(sankalpa.dailyCompletions);

      // Check if already completed for this day (ignore time)
      final existingDate = newCompletions.any(
        (d) =>
            d.year == date.year && d.month == date.month && d.day == date.day,
      );

      if (!existingDate) {
        newCompletions.add(date);
        final updated = sankalpa.copyWith(dailyCompletions: newCompletions);
        await updateSankalpa(updated);
      }
    }
  }

  /// Toggle completion status
  Future<void> toggleCompletion(String id) async {
    final sankalpa = _box.get(id);
    if (sankalpa != null) {
      final updated = sankalpa.copyWith(isCompleted: !sankalpa.isCompleted);
      await updateSankalpa(updated);
    }
  }
}
