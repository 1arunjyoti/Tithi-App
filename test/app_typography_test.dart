import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tithi/theme/app_theme.dart';
import 'package:tithi/theme/app_typography.dart';

void main() {
  group('AppTypography', () {
    test('three tiers map to bundled families with Indic fallbacks', () {
      // Arrange / Act
      final display = AppTypography.display();
      final ui = AppTypography.ui();
      final telemetry = AppTypography.telemetry();
      final shloka = AppTypography.shloka();

      // Assert - Latin faces
      expect(display.fontFamily, 'Newsreader');
      expect(ui.fontFamily, 'PlusJakartaSans');
      expect(telemetry.fontFamily, 'SpaceGrotesk');
      expect(shloka.fontFamily, 'TiroDevanagariSanskrit');

      // Assert - every Indic script has a harmonised fallback
      expect(
        display.fontFamilyFallback,
        containsAll(<String>[
          'TiroDevanagariHindi',
          'TiroBangla',
          'TiroTamil',
          'TiroTelugu',
          'NotoSerifMalayalam',
        ]),
      );
      expect(
        ui.fontFamilyFallback,
        containsAll(<String>[
          'NotoSansDevanagari',
          'NotoSansBengali',
          'NotoSansTamil',
          'NotoSansTelugu',
          'NotoSansMalayalam',
        ]),
      );
      expect(telemetry.fontFamilyFallback, AppTypography.indicSansFallback);
      expect(shloka.fontFamilyFallback, AppTypography.indicSerifFallback);
    });

    test('tabular figures are on for UI and telemetry text', () {
      expect(AppTypography.ui().fontFeatures, AppTypography.tabularFigures);
      expect(AppTypography.ui(tabularNumbers: false).fontFeatures, isNull);
      expect(
        AppTypography.telemetry().fontFeatures,
        AppTypography.tabularFigures,
      );
    });

    test('display styles under 18pt drop to the UI sans', () {
      // Newsreader hairlines go faint below 18pt, so the helper guards it.
      expect(AppTypography.displayMinimumSize, 18.0);
      expect(
        AppTypography.display(fontSize: 16).fontFamily,
        AppTypography.uiFamily,
      );
      expect(
        AppTypography.display(fontSize: 17.9).fontFamily,
        AppTypography.uiFamily,
      );
      expect(
        AppTypography.display(fontSize: 18).fontFamily,
        AppTypography.displayFamily,
      );
      expect(AppTypography.display().fontFamily, AppTypography.displayFamily);
    });

    testWidgets('no serif theme role resolves below the display floor', (
      tester,
    ) async {
      // Material resolves the null sizes from its type scale when the theme is
      // mounted (`Theme.of`), so assert on the resolved values: a serif role
      // that lands under 18pt would bypass the display guard.
      final themes = <String, ThemeData>{
        'Shukla': AppTheme.shuklaTheme,
        'Krishna': AppTheme.krishnaTheme,
        'Pure Dark': AppTheme.pureDarkTheme,
      };
      for (final entry in themes.entries) {
        late ThemeData resolved;
        late AppBarThemeData appBar;
        await tester.pumpWidget(
          MaterialApp(
            theme: entry.value,
            home: Builder(
              builder: (context) {
                resolved = Theme.of(context);
                appBar = resolved.appBarTheme;
                return const SizedBox.shrink();
              },
            ),
          ),
        );
        final roles = <String, TextStyle?>{
          'displayLarge': resolved.textTheme.displayLarge,
          'displayMedium': resolved.textTheme.displayMedium,
          'displaySmall': resolved.textTheme.displaySmall,
          'headlineLarge': resolved.textTheme.headlineLarge,
          'headlineMedium': resolved.textTheme.headlineMedium,
          'headlineSmall': resolved.textTheme.headlineSmall,
          'titleLarge': resolved.textTheme.titleLarge,
          'appBarTitle': appBar.titleTextStyle,
        };
        roles.forEach((role, style) {
          if (style?.fontFamily != AppTypography.displayFamily) return;
          expect(
            style!.fontSize,
            greaterThanOrEqualTo(AppTypography.displayMinimumSize),
            reason: '${entry.key} $role is serif and must meet the floor',
          );
        });
      }
    });

    test('display and shloka line boxes stay clear of matras', () {
      expect(AppTypography.display().height, greaterThanOrEqualTo(1.3));
      expect(AppTypography.shloka().height, greaterThanOrEqualTo(1.45));
    });

    testWidgets('theme text roles use the three tiers', (tester) async {
      // Arrange
      late BuildContext context;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.shuklaTheme,
          home: Builder(
            builder: (innerContext) {
              context = innerContext;
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      // Act
      final theme = Theme.of(context);

      // Assert - serif for titles, sans for body, both with fallbacks
      expect(
        theme.textTheme.headlineSmall?.fontFamily,
        AppTypography.displayFamily,
      );
      expect(
        theme.textTheme.titleLarge?.fontFamily,
        AppTypography.displayFamily,
      );
      expect(
        theme.appBarTheme.titleTextStyle?.fontFamily,
        AppTypography.displayFamily,
      );
      expect(theme.textTheme.bodyMedium?.fontFamily, AppTypography.uiFamily);
      expect(
        theme.textTheme.bodyMedium?.fontFamilyFallback,
        AppTypography.indicSansFallback,
      );
      expect(
        theme.textTheme.bodyMedium?.fontFeatures,
        AppTypography.tabularFigures,
      );
    });

    test('every bundled font asset exists and nothing fetches at runtime', () {
      // Arrange
      final pubspec = File('pubspec.yaml').readAsStringSync();
      final assets = RegExp(
        r'asset:\s*(assets/fonts/[^\s]+\.ttf)',
      ).allMatches(pubspec).map((match) => match.group(1)!).toSet();

      // Assert - assets on disk
      expect(assets.length, greaterThanOrEqualTo(14));
      for (final asset in assets) {
        expect(File(asset).existsSync(), isTrue, reason: 'Missing $asset');
      }

      // Assert - no runtime font package
      expect(pubspec.contains('google_fonts'), isFalse);

      // Assert - OFL license texts ship for every family
      final licenses = Directory(
        'assets/licenses',
      ).listSync().whereType<File>().where((f) => f.path.endsWith('.txt'));
      expect(licenses.length, greaterThanOrEqualTo(14));
    });
  });
}
