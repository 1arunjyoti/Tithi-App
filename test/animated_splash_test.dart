import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tithi/theme/app_theme.dart';
import 'package:tithi/widgets/animated_splash.dart';

Widget _splash({required bool reduceMotion}) {
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: reduceMotion),
      child: const AnimatedSplash(),
    ),
  );
}

void main() {
  group('native splash config', () {
    test('platform splash is a single static mandala', () {
      final config = File('flutter_native_splash.yaml').readAsStringSync();
      // One static platform splash, no Flutter splash phase.
      expect(config, contains('image: "assets/splash/splash_icon.png"'));
      expect(File('assets/splash/splash_icon.png').existsSync(), isTrue);

      for (final name in [
        'drawable/launch_background.xml',
        'drawable-v21/launch_background.xml',
        'drawable-night/launch_background.xml',
        'drawable-night-v21/launch_background.xml',
      ]) {
        expect(
          File('android/app/src/main/res/$name').readAsStringSync(),
          contains('@drawable/splash'),
          reason: '$name must paint the static native mandala',
        );
      }
      for (final name in [
        'values-v31/styles.xml',
        'values-night-v31/styles.xml',
      ]) {
        expect(
          File('android/app/src/main/res/$name').readAsStringSync(),
          contains('windowSplashScreenAnimatedIcon'),
          reason: name,
        );
      }
    });
  });

  group('native splash colour', () {
    // `#RRGGBB` as the native config writes it.
    String hex(Color color) =>
        '#${color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';

    test('every dark-mode native colour stays neutral', () {
      final config = File('flutter_native_splash.yaml').readAsStringSync();
      // MIUI 13 force-inverts saturated colours anywhere in the native splash
      // — legacy bitmap, Android 12 background or icon tile — and paints
      // magenta. #10002B belongs only in Flutter, never in these resources.
      expect(config, contains('  color: "#ffffff"'));
      expect(config, contains('  color_dark: "#121212"'));
      expect(config, contains('    color: "${hex(AppTheme.splashBackgroundLight)}"'));
      expect(config, contains('    color_dark: "#121212"'));
    });

    test('NormalTheme keeps the platform default window background', () {
      // Restored to the known-good baseline: MIUI 13 cannot resolve an app
      // @color resource in its earliest starting window and paints a fallback
      // (white in light mode, magenta in dark mode).
      for (final name in [
        'values/styles.xml',
        'values-v31/styles.xml',
        'values-night/styles.xml',
        'values-night-v31/styles.xml',
      ]) {
        final xml = File('android/app/src/main/res/$name').readAsStringSync();
        final match = RegExp(
          r'<style name="NormalTheme"[\s\S]*?windowBackground">([^<]+)<',
        ).firstMatch(xml);
        expect(match, isNotNull, reason: '$name has no NormalTheme window');
        expect(match!.group(1), '?android:colorBackground', reason: name);
      }
    });

    test('splash_background colour resource holds the theme colours', () {
      // The splash colour lives in exactly two places natively, so the Flutter
      // splash and the native window cannot drift apart.
      expect(
        File('android/app/src/main/res/values/colors.xml').readAsStringSync(),
        contains(
          '<color name="splash_background">'
          '${hex(AppTheme.splashBackgroundLight)}</color>',
        ),
      );
      expect(
        File(
          'android/app/src/main/res/values-night/colors.xml',
        ).readAsStringSync(),
        contains(
          '<color name="splash_background">'
          '${hex(AppTheme.splashBackgroundDark)}</color>',
        ),
      );
    });

    test('v31 LaunchTheme keeps the minimal, known-good MIUI structure', () {
      // The working baseline uses platform theme parents and does NOT point
      // windowBackground/colorBackground at an app @color resource: MIUI 13
      // cannot resolve those in the pre-process starting window and paints
      // magenta in dark mode. Only the splash colour value is customised.
      final expected = {
        'values-v31/styles.xml': (
          parent: '@android:style/Theme.Light.NoTitleBar',
          colour: AppTheme.splashBackgroundLight,
        ),
        'values-night-v31/styles.xml': (
          parent: '@android:style/Theme.Black.NoTitleBar',
          // Neutral, not AppTheme.splashBackgroundDark: MIUI 13 force-inverts
          // saturated colours anywhere in the splash and paints magenta.
          colour: const Color(0xFF121212),
        ),
      };
      expected.forEach((name, spec) {
        final xml = File('android/app/src/main/res/$name').readAsStringSync();
        final launch = RegExp(
          r'<style name="LaunchTheme"[\s\S]*?</style>',
        ).firstMatch(xml);
        expect(launch, isNotNull, reason: '$name has no LaunchTheme');
        final style = launch!.group(0)!;
        expect(
          style,
          contains('<style name="LaunchTheme" parent="${spec.parent}">'),
          reason: name,
        );
        for (final item in [
          'android:windowBackground',
          'android:colorBackground',
          'android:opacity',
        ]) {
          expect(
            style,
            isNot(contains('<item name="$item">')),
            reason: '$name must not set $item in the starting window',
          );
        }
        expect(
          style,
          contains(
            '<item name="android:windowSplashScreenBackground">'
            '${hex(spec.colour)}</item>',
          ),
          reason: '$name: windowSplashScreenBackground must use its literal '
              'per-mode colour',
        );
        expect(
          style,
          contains('<item name="android:forceDarkAllowed">false</item>'),
          reason: name,
        );
        expect(
          style,
          contains(
            '<item name="android:windowSplashScreenAnimatedIcon">'
            '@drawable/android12splash</item>',
          ),
          reason: name,
        );
      });
    });
  });

  group('splashHoldDuration', () {
    final started = DateTime(2026, 11, 22, 9);

    test('returns the unelapsed part of the minimum', () {
      expect(
        splashHoldDuration(
          startedAt: started,
          now: started.add(const Duration(milliseconds: 350)),
          minimum: const Duration(milliseconds: 1000),
          reduceMotion: false,
        ),
        const Duration(milliseconds: 650),
      );
    });

    test('is zero once the minimum has elapsed', () {
      expect(
        splashHoldDuration(
          startedAt: started,
          now: started.add(const Duration(milliseconds: 1400)),
          minimum: const Duration(milliseconds: 1000),
          reduceMotion: false,
        ),
        Duration.zero,
      );
    });

    test('is always zero under Reduce Motion', () {
      expect(
        splashHoldDuration(
          startedAt: started,
          now: started,
          minimum: const Duration(seconds: 3),
          reduceMotion: true,
        ),
        Duration.zero,
      );
    });
  });

  group('AnimatedSplash', () {
    testWidgets('shows the mandala, app name and tagline', (tester) async {
      await tester.pumpWidget(_splash(reduceMotion: false));

      expect(find.byType(Image), findsOneWidget);
      expect(find.text('Tithi'), findsOneWidget);
      expect(find.text('Vedic calendar for modern life'), findsOneWidget);
      final image = tester.widget<Image>(find.byType(Image));
      expect(image.width, kSplashLogoSize);
    });

    testWidgets('rotates and breathes while motion is allowed', (tester) async {
      await tester.pumpWidget(_splash(reduceMotion: false));
      await tester.pump();

      // Keyed finders: Material's own route transition also has rotation and
      // scale widgets, so a byType finder would be ambiguous.
      final rotation = tester.widget<RotationTransition>(
        find.byKey(const ValueKey('splash-rotation')),
      );
      expect(rotation.turns, isA<AnimationController>());
      expect((rotation.turns as AnimationController).isAnimating, isTrue);

      final breathe = find.byKey(const ValueKey('splash-breathe'));
      expect(breathe, findsOneWidget);
      final before = tester.widget<ScaleTransition>(breathe).scale.value;
      await tester.pump(const Duration(milliseconds: 300));
      final after = tester.widget<ScaleTransition>(breathe).scale.value;
      expect(after, isNot(before));
    });

    testWidgets('Reduce Motion shows a static mark at full opacity', (
      tester,
    ) async {
      await tester.pumpWidget(_splash(reduceMotion: true));
      await tester.pump();

      expect(find.byKey(const ValueKey('splash-rotation')), findsNothing);
      expect(find.byKey(const ValueKey('splash-breathe')), findsOneWidget);
      final entrance = tester.widget<FadeTransition>(
        find.byKey(const ValueKey('splash-entrance')),
      );
      expect(entrance.opacity.value, 1);
    });

    testWidgets('paints a flat, native-matched background in dark mode', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(platformBrightness: Brightness.dark),
            child: AnimatedSplash(),
          ),
        ),
      );

      final background = tester.widget<Container>(find.byType(Container).first);
      // Must equal the native dark background, not the brand purple: MIUI
      // force-inverts the brand colour into magenta, so native is #121212.
      expect(background.color, const Color(0xFF121212));
      // Impeller on Adreno 618 can render a gradient as a solid wrong colour.
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is DecoratedBox &&
              widget.decoration is BoxDecoration &&
              (widget.decoration as BoxDecoration).gradient != null,
        ),
        findsNothing,
        reason: 'no gradient may appear in the startup path',
      );
    });
  });
}
