import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Bundled cross-script type system for Tithi.
///
/// Three tiers, each with an explicit Indic fallback chain so a mixed string
/// ("Kartika Chaturthi • कार्तिक चतुर्थी") never drops to the platform's
/// generic system font:
///
///  * [display] - Newsreader serif + Tiro Indic serifs. Cultural titles
///    (tithi names, festival names) and screen/sheet headings.
///  * [ui] - Plus Jakarta Sans + Noto Sans Indic. Body copy, navigation,
///    calendar labels and anything that needs aligned digits
///    ([tabularFigures] is on by default).
///  * [telemetry] - Space Grotesk. Uppercase eyebrows, percentages,
///    transition timestamps; the "this is computed, not printed" signal.
///  * [shloka] - Tiro Devanagari Sanskrit + Tiro Bangla, for verse text.
///
/// The files live in `assets/fonts/` and are registered in `pubspec.yaml`.
/// Everything is local: there is no runtime font fetching, so first paint is
/// identical offline. Adding a script means adding the family to
/// `pubspec.yaml` and to the matching fallback list here - nothing else.
///
/// Line heights: Indic scripts have tall upper matras and deep descenders, so
/// [display] and [shloka] default to a loose 1.35-1.5 line box. Do not tighten
/// them below ~1.3 or top matras clip in Devanagari/Bengali.
class AppTypography {
  const AppTypography._();

  // Families (must match `pubspec.yaml`).
  static const String displayFamily = 'Newsreader';
  static const String uiFamily = 'PlusJakartaSans';
  static const String telemetryFamily = 'SpaceGrotesk';
  static const String shlokaFamily = 'TiroDevanagariSanskrit';

  /// Pan-Indic editorial serifs, in script priority order. Tiro shares one
  /// design DNA across Devanagari/Bangla/Tamil/Telugu; Malayalam has no Tiro,
  /// so Noto Serif Malayalam carries it.
  static const List<String> indicSerifFallback = <String>[
    'TiroDevanagariHindi',
    'TiroBangla',
    'TiroTamil',
    'TiroTelugu',
    'NotoSerifMalayalam',
  ];

  /// Uniform-stroke Indic sans suite for UI text and dense conjuncts.
  static const List<String> indicSansFallback = <String>[
    'NotoSansDevanagari',
    'NotoSansBengali',
    'NotoSansTamil',
    'NotoSansTelugu',
    'NotoSansMalayalam',
  ];

  /// Aligns digits column-to-column (calendar dates, countdowns, percentages).
  static const List<FontFeature> tabularFigures = <FontFeature>[
    FontFeature.tabularFigures(),
  ];

  /// Families whose OFL text ships in `assets/licenses/`. Keep in sync with
  /// the `fonts:` block in `pubspec.yaml`.
  static const List<String> _licensedFamilies = <String>[
    'Newsreader',
    'TiroDevanagariHindi',
    'TiroDevanagariSanskrit',
    'TiroBangla',
    'TiroTamil',
    'TiroTelugu',
    'NotoSerifMalayalam',
    'PlusJakartaSans',
    'NotoSansDevanagari',
    'NotoSansBengali',
    'NotoSansTamil',
    'NotoSansTelugu',
    'NotoSansMalayalam',
    'SpaceGrotesk',
  ];

  /// Registers the bundled fonts' SIL OFL texts with the app's license page
  /// (`showLicensePage` / About). Call once during startup; it is lazy, so no
  /// asset is read until the license page is opened.
  static void registerFontLicenses() {
    for (final family in _licensedFamilies) {
      LicenseRegistry.addLicense(() async* {
        final text = await rootBundle.loadString(
          'assets/licenses/OFL-$family.txt',
        );
        yield LicenseEntryWithLineBreaks(<String>[family], text);
      });
    }
  }

  /// Newsreader's hairlines go faint below ~18pt on low-DPI Android screens,
  /// so [display] refuses to render smaller than this and drops to [ui]
  /// automatically. Never send a display style below this size by hand.
  static const double displayMinimumSize = 18.0;

  /// Cultural/editorial display style.
  ///
  /// Sizes under [displayMinimumSize] silently switch to the UI sans (the
  /// small-serif legibility rule); pass the size so the guard can apply.
  static TextStyle display({
    double? fontSize,
    FontWeight fontWeight = FontWeight.w600,
    Color? color,
    double? height = 1.35,
    double? letterSpacing,
    FontStyle? fontStyle,
    TextDecoration? decoration,
    Color? decorationColor,
    List<FontFeature>? fontFeatures,
  }) {
    if (fontSize != null && fontSize < displayMinimumSize) {
      return ui(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        height: height,
        letterSpacing: letterSpacing,
        fontStyle: fontStyle,
        decoration: decoration,
        decorationColor: decorationColor,
      );
    }
    return TextStyle(
      fontFamily: displayFamily,
      fontFamilyFallback: indicSerifFallback,
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
      fontStyle: fontStyle,
      decoration: decoration,
      decorationColor: decorationColor,
      fontFeatures: fontFeatures,
    );
  }

  /// Body/navigation style with tabular digits by default.
  static TextStyle ui({
    double? fontSize,
    FontWeight fontWeight = FontWeight.w400,
    Color? color,
    double? height,
    double? letterSpacing,
    FontStyle? fontStyle,
    TextDecoration? decoration,
    Color? decorationColor,
    bool tabularNumbers = true,
  }) {
    return TextStyle(
      fontFamily: uiFamily,
      fontFamilyFallback: indicSansFallback,
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
      fontStyle: fontStyle,
      decoration: decoration,
      decorationColor: decorationColor,
      fontFeatures: tabularNumbers ? tabularFigures : null,
    );
  }

  /// Uppercase eyebrows, illumination percentages and ephemeris timestamps.
  static TextStyle telemetry({
    double? fontSize,
    FontWeight fontWeight = FontWeight.w600,
    Color? color,
    double letterSpacing = 0.8,
    double? height,
  }) {
    return TextStyle(
      fontFamily: telemetryFamily,
      // Space Grotesk has no Indic coverage; fall back to the UI sans suite so
      // a localized label never renders in the system font.
      fontFamilyFallback: indicSansFallback,
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: letterSpacing,
      height: height,
      fontFeatures: tabularFigures,
    );
  }

  /// Verse text: Tiro Devanagari Sanskrit first, with the pan-Indic serifs
  /// behind it for Bengali/Tamil/Telugu/Malayalam shlokas.
  static TextStyle shloka({
    double? fontSize,
    FontWeight fontWeight = FontWeight.w600,
    Color? color,
    double? height = 1.6,
  }) {
    return TextStyle(
      fontFamily: shlokaFamily,
      fontFamilyFallback: indicSerifFallback,
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: height,
    );
  }

  /// Applies the UI family + Indic fallbacks to a Material [TextTheme] and
  /// turns on tabular figures for every role, so calendar days, countdowns and
  /// percentages line up without every call site asking for it.
  ///
  /// Start from `ThemeData.light().textTheme` / `.dark().textTheme` to keep
  /// Material's type scale unchanged.
  static TextTheme uiTextTheme(TextTheme base) {
    final themed = base.apply(
      fontFamily: uiFamily,
      fontFamilyFallback: indicSansFallback,
    );
    TextStyle? tabular(TextStyle? style) =>
        style?.copyWith(fontFeatures: tabularFigures);
    return themed.copyWith(
      displayLarge: tabular(themed.displayLarge),
      displayMedium: tabular(themed.displayMedium),
      displaySmall: tabular(themed.displaySmall),
      headlineLarge: tabular(themed.headlineLarge),
      headlineMedium: tabular(themed.headlineMedium),
      headlineSmall: tabular(themed.headlineSmall),
      titleLarge: tabular(themed.titleLarge),
      titleMedium: tabular(themed.titleMedium),
      titleSmall: tabular(themed.titleSmall),
      bodyLarge: tabular(themed.bodyLarge),
      bodyMedium: tabular(themed.bodyMedium),
      bodySmall: tabular(themed.bodySmall),
      labelLarge: tabular(themed.labelLarge),
      labelMedium: tabular(themed.labelMedium),
      labelSmall: tabular(themed.labelSmall),
    );
  }
}
