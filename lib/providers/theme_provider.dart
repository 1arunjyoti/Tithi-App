import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../theme/app_theme.dart';

/// Notifier for manually overriding theme with Hive persistence
class ThemeOverrideNotifier extends Notifier<String?> {
  static const _boxName = 'settings';
  static const _key = 'theme_override';

  @override
  String? build() {
    // Box is already opened in main.dart
    final box = Hive.box(_boxName);
    return box.get(_key) as String?;
  }

  void setOverride(String? override) {
    final box = Hive.box(_boxName);
    if (override == null) {
      box.delete(_key);
    } else {
      box.put(_key, override);
    }
    state = override;
  }
}

/// Provider for manually overriding theme (for testing/preferences)
final themeOverrideProvider = NotifierProvider<ThemeOverrideNotifier, String?>(
  ThemeOverrideNotifier.new,
);

/// Determines the ThemeMode to use
/// Returns ThemeMode.system if no override is set (Auto)
final themeModeProvider = Provider<ThemeMode>((ref) {
  final override = ref.watch(themeOverrideProvider);

  if (override == null) {
    return ThemeMode.system;
  }

  // 'Shukla' is our Light theme
  if (override == 'Shukla') {
    return ThemeMode.light;
  }

  // 'PureDark' and 'Krishna' are Dark themes
  return ThemeMode.dark;
});

/// Determines which Dark Theme data to use
/// This allows switching between Pure Dark and Krishna themes while in Dark Mode
final darkThemeProvider = Provider<ThemeData>((ref) {
  final override = ref.watch(themeOverrideProvider);

  if (override == 'Krishna') {
    return AppTheme.krishnaTheme;
  }

  // Default to Pure Dark for system dark mode or explicit PureDark selection
  return AppTheme.pureDarkTheme;
});
