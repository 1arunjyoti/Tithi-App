import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tithi/theme/app_theme.dart';

void main() {
  group('AppTheme.systemUiOverlayStyle', () {
    test('both bars are transparent with no contrast scrim', () {
      for (final brightness in Brightness.values) {
        final style = AppTheme.systemUiOverlayStyle(brightness);

        expect(style.statusBarColor, Colors.transparent);
        expect(
          style.systemNavigationBarColor,
          Colors.transparent,
          reason:
              'The gesture handle must sit on the page background, not on a '
              'navigation-bar strip. The Activity sets the same value natively.',
        );
        expect(style.systemNavigationBarDividerColor, Colors.transparent);
        expect(
          style.systemStatusBarContrastEnforced,
          isFalse,
          reason: 'A contrast scrim would tint the area behind the status bar.',
        );
        expect(
          style.systemNavigationBarContrastEnforced,
          isFalse,
          reason: 'API 29+ would otherwise paint a translucent nav-bar scrim.',
        );
      }
    });

    test('icon brightness follows the theme brightness', () {
      final light = AppTheme.systemUiOverlayStyle(Brightness.light);
      expect(light.statusBarIconBrightness, Brightness.dark);
      expect(light.systemNavigationBarIconBrightness, Brightness.dark);
      expect(light.statusBarBrightness, Brightness.light);

      final dark = AppTheme.systemUiOverlayStyle(Brightness.dark);
      expect(dark.statusBarIconBrightness, Brightness.light);
      expect(dark.systemNavigationBarIconBrightness, Brightness.light);
      expect(dark.statusBarBrightness, Brightness.dark);
    });
  });
}
