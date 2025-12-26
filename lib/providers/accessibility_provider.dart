import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

class AccessibilityState {
  final bool reduceMotion;
  final bool hapticFeedback;
  final bool highContrast;
  final bool largeText;

  const AccessibilityState({
    this.reduceMotion = false,
    this.hapticFeedback = true,
    this.highContrast = false,
    this.largeText = false,
  });

  AccessibilityState copyWith({
    bool? reduceMotion,
    bool? hapticFeedback,
    bool? highContrast,
    bool? largeText,
  }) {
    return AccessibilityState(
      reduceMotion: reduceMotion ?? this.reduceMotion,
      hapticFeedback: hapticFeedback ?? this.hapticFeedback,
      highContrast: highContrast ?? this.highContrast,
      largeText: largeText ?? this.largeText,
    );
  }
}

class AccessibilityNotifier extends Notifier<AccessibilityState> {
  static const _boxName = 'settings';
  static const _key = 'accessibility_prefs';

  @override
  AccessibilityState build() {
    // We assume the box is open in main.dart, similar to theme settings
    if (!Hive.isBoxOpen(_boxName)) {
      return const AccessibilityState();
    }
    final box = Hive.box(_boxName);
    final rawMap = box.get(_key, defaultValue: {});
    final map = Map<String, dynamic>.from(rawMap as Map);

    return AccessibilityState(
      reduceMotion: map['reduceMotion'] as bool? ?? false,
      hapticFeedback: map['hapticFeedback'] as bool? ?? true,
      highContrast: map['highContrast'] as bool? ?? false,
      largeText: map['largeText'] as bool? ?? false,
    );
  }

  Future<void> _save() async {
    if (!Hive.isBoxOpen(_boxName)) return;
    final box = Hive.box(_boxName);
    await box.put(_key, {
      'reduceMotion': state.reduceMotion,
      'hapticFeedback': state.hapticFeedback,
      'highContrast': state.highContrast,
      'largeText': state.largeText,
    });
  }

  void toggleReduceMotion(bool value) {
    state = state.copyWith(reduceMotion: value);
    _save();
  }

  void toggleHapticFeedback(bool value) {
    state = state.copyWith(hapticFeedback: value);
    _save();
  }

  void toggleHighContrast(bool value) {
    state = state.copyWith(highContrast: value);
    _save();
  }

  void toggleLargeText(bool value) {
    state = state.copyWith(largeText: value);
    _save();
  }
}

final accessibilityProvider =
    NotifierProvider<AccessibilityNotifier, AccessibilityState>(
      AccessibilityNotifier.new,
    );
