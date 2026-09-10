import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/storage_service.dart';

class AccessibilityState {
  final bool reduceMotion;
  final bool hapticFeedback;
  final bool highContrast;
  final bool largeText;

  const AccessibilityState({
    this.reduceMotion = false,
    this.hapticFeedback = !kIsWeb,
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
  static const _key = 'accessibility_prefs';

  @override
  AccessibilityState build() {
    final box = StorageService().getSettingsBox();
    final rawMap = box.get(_key, defaultValue: {});
    final map = Map<String, dynamic>.from(rawMap as Map);

    return AccessibilityState(
      reduceMotion: map['reduceMotion'] as bool? ?? false,
      hapticFeedback: map['hapticFeedback'] as bool? ?? !kIsWeb,
      highContrast: map['highContrast'] as bool? ?? false,
      largeText: map['largeText'] as bool? ?? false,
    );
  }

  Future<void> _save() async {
    final box = StorageService().getSettingsBox();
    await box.put(_key, {
      'reduceMotion': state.reduceMotion,
      'hapticFeedback': state.hapticFeedback,
      'highContrast': state.highContrast,
      'largeText': state.largeText,
    });
  }

  Future<void> toggleReduceMotion(bool value) async {
    state = state.copyWith(reduceMotion: value);
    await _save();
  }

  Future<void> toggleHapticFeedback(bool value) async {
    state = state.copyWith(hapticFeedback: value);
    await _save();
  }

  Future<void> toggleHighContrast(bool value) async {
    state = state.copyWith(highContrast: value);
    await _save();
  }

  Future<void> toggleLargeText(bool value) async {
    state = state.copyWith(largeText: value);
    await _save();
  }
}

final accessibilityProvider =
    NotifierProvider<AccessibilityNotifier, AccessibilityState>(
      AccessibilityNotifier.new,
    );
