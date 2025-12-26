import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../theme/app_theme.dart';

/// Provider for the current theme based on time (Day/Night)
final themeProvider = Provider<ThemeData>((ref) {
  // We can add a timer here to update theme automatically if needed,
  // but for now, checking on build/rebuild is sufficient.
  // To make it reactive to time changes, we could use a StreamProvider.
  // For simplicity and performance, we'll stick to build-time check or
  // maybe a minute-ticker if strictly required.
  // Given user request "based on the time(day and night)", simple check is good.

  final now = DateTime.now();
  final isDay = now.hour >= 6 && now.hour < 18; // 6 AM to 6 PM is Day

  return isDay ? AppTheme.shuklaTheme : AppTheme.pureDarkTheme;
});

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

/// Combined theme provider that respects manual override
/// Overrides: 'Shukla', 'PureDark', 'Krishna'
final effectiveThemeProvider = Provider<ThemeData>((ref) {
  final override = ref.watch(themeOverrideProvider);

  if (override != null) {
    switch (override) {
      case 'Shukla':
        return AppTheme.shuklaTheme;
      case 'PureDark':
        return AppTheme.pureDarkTheme;
      case 'Krishna':
        return AppTheme.krishnaTheme;
      default:
        // Fallback or legacy handling
        return AppTheme.shuklaTheme;
    }
  }

  return ref.watch(themeProvider);
});
