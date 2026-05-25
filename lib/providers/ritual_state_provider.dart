import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import '../services/storage_service.dart';

/// Provider to manage the completion state of rituals
final ritualStateProvider =
    NotifierProvider<RitualStateNotifier, Map<String, bool>>(
      RitualStateNotifier.new,
    );

class RitualStateNotifier extends Notifier<Map<String, bool>> {
  Box? _box;

  @override
  Map<String, bool> build() {
    // Start with empty state and load asynchronously
    // We don't await here to keep initial build synchronous
    _init();
    return {};
  }

  /// Initialize the Hive box and load saved states
  Future<void> _init() async {
    if (_box != null) return;
    _box = await StorageService().openRitualCompletionBox();
    _loadState();
  }

  void _loadState() {
    if (_box == null) return;

    final Map<String, bool> loadedState = {};
    for (var key in _box!.keys) {
      if (key is String) {
        final val = _box!.get(key);
        if (val is bool) {
          loadedState[key] = val;
        }
      }
    }
    state = loadedState;
  }

  /// Toggle the completion status of a ritual.
  /// Guards against the race where [_init] has not yet completed by awaiting
  /// it when [_box] is still null (BUG-MEDIUM-6).
  Future<void> toggleRitual(String id) async {
    if (_box == null) await _init();
    if (_box == null) {
      // _init failed — nothing we can persist.
      return;
    }

    final currentState = state[id] ?? false;
    final newState = !currentState;

    // Update state
    state = {...state, id: newState};

    // Persist to Hive
    await _box!.put(id, newState);
  }

  /// Check if a ritual is completed
  bool isCompleted(String id) {
    return state[id] ?? false;
  }
}
