# AGENTS.md - Tithi Project Development Guide

## Build, Lint, and Test Commands

### Running the App
```bash
flutter run                          # Run on connected device/emulator
flutter run -d <device_id>           # Run on specific device
flutter build apk --debug           # Build debug APK
flutter build apk --release         # Build release APK
flutter build appbundle --release   # Build Android App Bundle
```

### Linting and Analysis
```bash
flutter analyze                     # Run static analysis (linter)
flutter analyze lib/                # Analyze specific directory
flutter analyze lib/services/      # Analyze specific folder
```

The project uses `flutter_lints` with custom rules defined in `analysis_options.yaml`:
- `prefer_const_constructors`: Use const constructors where possible
- `prefer_const_literals_to_create_immutables`: Use const for list/set literals
- `prefer_const_declarations`: Use const for compile-time constants
- `use_key_in_widget_constructors`: Always provide keys in widget constructors
- `avoid_unnecessary_containers`: Avoid wrapping widgets in unnecessary containers
- `sized_box_for_whitespace`: Use SizedBox instead of Container for spacing
- `prefer_is_empty`: Use `.isEmpty` instead of `.length == 0`
- `prefer_is_not_empty`: Use `.isNotEmpty` instead of `.length > 0`
- `avoid_redundant_argument_values`: Avoid redundant argument values
- `unawaited_futures`: Always handle async results properly

### Running Tests
```bash
flutter test                        # Run all tests
flutter test test/panchang_data_test.dart          # Run single test file
flutter test test/panchang_data_test.dart -n "PanchangData Model Tests"  # Run specific test group
flutter test test/panchang_data_test.dart --name "fromRawTithi creates"  # Run tests matching pattern
flutter test --reporter expanded     # Run with expanded output
flutter test --reporter compact     # Run with compact output
```

### Code Generation
```bash
flutter pub run build_runner build  # Run build_runner for code generation
flutter pub run build_runner watch  # Watch mode for code generation
flutter pub run build_runner build --delete-conflicting-outputs  # Force regenerate
```

This project uses Hive for local storage - run build_runner after modifying models.

---

## Code Style Guidelines

### General Principles
- Follow Flutter and Dart conventions as defined in the official style guide
- Use `flutter analyze` to check code before committing
- Keep files under 500 lines when possible
- Use meaningful, descriptive names

### Project Structure
```
lib/
├── main.dart              # App entry point
├── theme/                 # Theme definitions
├── models/               # Data models (with Hive adapters)
├── services/             # Business logic services
├── providers/            # Riverpod providers
├── screens/              # Screen widgets
├── widgets/              # Reusable widgets
└── l10n/                 # Localization files
```

### Imports
- Use relative imports for same-package imports
- Use package imports for cross-package imports
- Order imports: dart: → package: → relative
- Group imports by package with blank line separation

```dart
// Good import order
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/festival.dart';
import '../providers/festival_provider.dart';
import '../theme/app_theme.dart';
```

### Naming Conventions
- **Files**: snake_case (e.g., `home_screen.dart`, `panchang_data.dart`)
- **Classes**: PascalCase (e.g., `class HomeScreen`, `class FestivalData`)
- **Constants**: camelCase with k prefix (e.g., `kDefaultLocation`)
- **Enums**: PascalCase with values in PascalCase (e.g., `enum ThemeMode { light, dark }`)
- **Private members**: Prefix with underscore (e.g., `_internalState`)

### Types and Type Safety
- Always provide explicit return types for public functions
- Use `void` return type explicitly for side-effect-only functions
- Prefer `final` over `var` for immutable variables
- Use `const` constructors wherever possible
- Enable strict typing in analysis_options.yaml

```dart
// Good
Widget build(BuildContext context) {
  final List<Festival> festivals = [];
  const Duration timeout = Duration(seconds: 30);
  return const SizedBox.shrink();
}

// Avoid
var festivals = [];
Widget build(context) => new SizedBox();
```

### Widgets
- Use `const` constructors for StatelessWidgets
- Prefer composition over inheritance
- Extract widgets into separate files when > 50 lines
- Use trailing commas for better formatting

```dart
// Good
class CalendarWidget extends StatelessWidget {
  const CalendarWidget({super.key, required this.selectedDate});

  final DateTime selectedDate;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Calendar(
        selectedDate: selectedDate,
      ),
    );
  }
}
```

### Error Handling
- Use try-catch for expected error conditions
- Provide meaningful error messages
- Use Result types or sealed classes for error states
- Never swallow exceptions silently

```dart
// Good - handle errors explicitly
try {
  final result = await service.fetchData();
  return Result.success(result);
} on NetworkException catch (e) {
  return Result.failure(NetworkError(e.message));
} catch (e) {
  return Result.failure(UnknownError(e.toString()));
}
```

### Async/Await
- Always handle futures properly with await or unawaited_futures lint
- Use try-catch for async operations
- Show loading states during async operations

### Riverpod Providers
- Use `flutter_riverpod` for all state management
- Prefix provider names with descriptive scope (e.g., `panchangProvider`, `locationProvider`)
- Use `ConsumerWidget` or `ConsumerStatefulWidget` for reactive UI
- Prefer `ref.watch` over `ref.read` for UI that rebuilds

```dart
// Good provider definition
final panchangProvider = StateNotifierProvider<PanchangNotifier, PanchangState>((ref) {
  return PanchangNotifier(ref.read(locationServiceProvider));
});

// Good provider consumption
final panchang = ref.watch(panchangProvider);
```

### Testing
- Follow AAA pattern: Arrange, Act, Assert
- Use descriptive test names that explain expected behavior
- Group related tests with `group()`
- Use `setUp()` for common test fixtures

```dart
group('PanchangData Model Tests', () {
  test('fromRawTithi creates correct Shukla Paksha data', () {
    // Arrange
    final testDate = DateTime(2024, 3, 15);
    
    // Act
    final panchang = PanchangData.fromRawTithi(
      date: testDate,
      rawTithi: 8.5,
      masa: 'Chaitra',
      allFestivals: [],
      sunrise: sunrise,
      sunset: sunset,
    );
    
    // Assert
    expect(panchang.paksha, equals('Shukla'));
    expect(panchang.tithiNumber, equals(8));
  });
});
```

---

## Platform-Specific Code

There is no web target and no stub / conditional-export layer. Native functionality
lives behind plain imports and is dispatched with runtime checks:

- `lib/services/panchang_init/` - copies the bundled ephemeris files into the app's
  documents directory before the panchang service initializes
- `lib/services/share_file/` - temp/documents file helpers used by sharing and export
- `lib/widgets/native_screens/` - barrel for the FFI-dependent screens
  (eclipse, solar system)
- `packages/jyotish/` - Swiss Ephemeris FFI bindings (requires NDK)

Because these use `dart:io`, gate the platform-specific entry point with a runtime
check instead of a conditional import:

```dart
// dart:io guard
if (!Platform.isAndroid) return;

// flutter/foundation guard
if (defaultTargetPlatform != TargetPlatform.android) {
  await openReleasesPage();
  return;
}
```

Both forms compile on every target; the guard only decides what runs. Capability
questions belong to the service (e.g. `HomeWidgetService.isWidgetSupported()`,
`AppUpdateService.supportsInAppInstall`), not to the UI, so screens stay
platform-agnostic.

---

## Working with the jyotish Package

The `packages/jyotish/` directory contains:
- Dart FFI bindings to Swiss Ephemeris
- Native Android code (Kotlin/JNI)
- Hindu calendar calculation logic

To rebuild native bindings:
```bash
cd packages/jyotish
flutter pub get
# Requires NDK installed
```

---

## Resources
- Festival data guide: docs/FESTIVALS_Modification_GUIDE.md
- Festival artwork guide (compression script, 800px / 200 KB budget): docs/FESTIVAL_ARTWORK_GUIDE.md
- Flutter Docs: https://flutter.dev/docs
- Riverpod Docs: https://riverpod.dev/docs
- Dart Lints: https://dart.dev/tools/linter-rules
- Hive Docs: https://docs.hivedb.dev/
