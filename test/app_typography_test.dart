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

    test(
      'the size ladder is sorted, whole-point and free of retired steps',
      () {
        const ladder = AppTypography.sizeLadder;
        expect(ladder, isNotEmpty);

        for (var i = 1; i < ladder.length; i++) {
          expect(
            ladder[i],
            greaterThan(ladder[i - 1]),
            reason: 'the ladder must stay ascending',
          );
          expect(
            ladder[i - 1],
            isNot(equals(ladder[i])),
            reason: 'two steps cannot share a size',
          );
        }

        for (final size in ladder) {
          expect(
            size % 1,
            equals(0),
            reason: '$size is fractional - half-point steps were folded away',
          );
        }

        // The values in use before consolidation must stay retired.
        for (final retired in <double>[
          9,
          10.5,
          11.5,
          12.5,
          13.5,
          14.5,
          17,
          19,
        ]) {
          expect(ladder, isNot(contains(retired)));
        }

        // Heading text is the smallest serif step; below the display floor the
        // serif silently turns sans, so the two numbers must not drift apart.
        expect(ladder, contains(AppTypography.sizeHeading));
        expect(
          AppTypography.sizeHeading,
          greaterThanOrEqualTo(AppTypography.displayMinimumSize),
        );
      },
    );

    test('the weight set stops at the heaviest bundled face', () {
      expect(AppTypography.regular, FontWeight.w400);
      expect(AppTypography.medium, FontWeight.w500);
      expect(AppTypography.semibold, FontWeight.w600);
      expect(AppTypography.bold, FontWeight.w700);
      expect(
        AppTypography.bold,
        FontWeight.bold,
        reason:
            'bold == w700; pubspec ships nothing heavier, so w800 was a '
            'phantom weight',
      );
    });

    test('uiTextTheme wires the family chain into every role', () {
      final themed = AppTypography.uiTextTheme(ThemeData.light().textTheme);
      final roles = <TextStyle?>[
        themed.displayLarge,
        themed.displayMedium,
        themed.displaySmall,
        themed.headlineLarge,
        themed.headlineMedium,
        themed.headlineSmall,
        themed.titleLarge,
        themed.titleMedium,
        themed.titleSmall,
        themed.bodyLarge,
        themed.bodyMedium,
        themed.bodySmall,
        themed.labelLarge,
        themed.labelMedium,
        themed.labelSmall,
      ];

      for (final role in roles) {
        expect(role?.fontFamily, AppTypography.uiFamily);
        expect(role?.fontFamilyFallback, AppTypography.indicSansFallback);
        expect(role?.fontFeatures, AppTypography.tabularFigures);
      }
    });

    testWidgets('all three palettes share one type map and ladder sizes', (
      tester,
    ) async {
      // The palettes used to hand-copy the role map; only the ink differs.
      final themes = <String, ThemeData>{
        'Shukla': AppTheme.shuklaTheme,
        'Krishna': AppTheme.krishnaTheme,
        'Pure Dark': AppTheme.pureDarkTheme,
      };

      for (final entry in themes.entries) {
        late ThemeData resolved;
        await tester.pumpWidget(
          MaterialApp(
            theme: entry.value,
            home: Builder(
              builder: (context) {
                resolved = Theme.of(context);
                return const SizedBox.shrink();
              },
            ),
          ),
        );

        final name = entry.key;
        expect(
          resolved.textTheme.headlineLarge?.fontFamily,
          AppTypography.displayFamily,
          reason: '$name headlines are serif',
        );
        expect(
          resolved.textTheme.headlineLarge?.fontWeight,
          AppTypography.bold,
          reason: '$name headlineLarge is the heaviest heading',
        );
        expect(
          resolved.textTheme.titleLarge?.fontSize,
          AppTypography.sizeHeadline,
          reason: '$name titleLarge keeps its 22pt step',
        );
        expect(
          resolved.textTheme.bodyLarge?.fontSize,
          AppTypography.sizeSubtitle,
          reason: '$name bodyLarge keeps the 16pt step',
        );
        expect(resolved.textTheme.bodyMedium?.fontSize, AppTypography.sizeBody);
        expect(
          resolved.appBarTheme.titleTextStyle?.fontSize,
          AppTypography.sizeHeadline,
          reason: '$name app-bar titles come from _appBarTitle',
        );
      }
    });
  });
}
