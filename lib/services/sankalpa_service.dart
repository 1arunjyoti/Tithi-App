import 'package:hive/hive.dart';
import '../models/sankalpa.dart';
import 'storage_service.dart';

class SankalpaService {
  Box<Sankalpa>? _box;

  Future<void> init() async {
    _box ??= await StorageService().openSankalpasBox();
  }

  Box<Sankalpa> get _requireBox {
    final box = _box;
    if (box == null) {
      throw StateError('SankalpaService not initialized. Call init() first.');
    }
    return box;
  }

  /// Get all sankalpas
  List<Sankalpa> getAllSankalpas() {
    return _requireBox.values.toList();
  }

  /// Get active sankalpas (not completed and end date not passed)
  List<Sankalpa> getActiveSankalpas() {
    // final now = DateTime.now();
    return _requireBox.values.where((s) {
      if (s.isCompleted) return false;
      // Optional: Check if expired? For now, just explicit completion check
      // OR maybe strict date check: s.endDate != null && s.endDate!.isAfter(now)
      return true;
    }).toList();
  }

  /// Get completed sankalpas
  List<Sankalpa> getCompletedSankalpas() {
    return _requireBox.values.where((s) => s.isCompleted).toList();
  }

  /// Add a new sankalpa
  Future<void> addSankalpa(Sankalpa sankalpa) async {
    await _requireBox.put(sankalpa.id, sankalpa);
  }

  /// Update an existing sankalpa
  Future<void> updateSankalpa(Sankalpa sankalpa) async {
    await _requireBox.put(sankalpa.id, sankalpa);
  }

  /// Delete a sankalpa
  Future<void> deleteSankalpa(String id) async {
    await _requireBox.delete(id);
  }

  /// Mark daily progress for a sankalpa
  Future<void> markDailyCompletion(String id, DateTime date) async {
    final box = _requireBox;
    final sankalpa = box.get(id);
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
    final sankalpa = _requireBox.get(id);
    if (sankalpa != null) {
      final updated = sankalpa.copyWith(isCompleted: !sankalpa.isCompleted);
      await updateSankalpa(updated);
    }
  }
}
