import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/accessibility_provider.dart';

/// Theme configuration for the Tithi app
/// Modern, vibrant design targeting younger generation
class AppTheme {
  // Common Shapes
  static final roundedShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(24),
  );

  /// OPT-3: static final fields so ThemeData + GoogleFonts text-theme objects
  /// are constructed exactly once (on first class access) rather than on every
  /// widget rebuild that calls AppTheme.shuklaTheme / krishnaTheme / pureDarkTheme.
  static final ThemeData shuklaTheme = _buildShuklaTheme();
  static final ThemeData krishnaTheme = _buildKrishnaTheme();
  static final ThemeData pureDarkTheme = _buildPureDarkTheme();

  /// Shukla Paksha (Waxing Moon) - Vibrant Warm Theme
  static ThemeData _buildShuklaTheme() {
    // Vibrant Orange/Gold Palette
    const primaryColor = Color(0xFFFF9F1C); // Vibrant Orange
    const secondaryColor = Color(0xFFFFBF69); // Mellow Yellow-Orange
    const accentColor = Color(0xFFCBF3F0); // Soft Cyan for contrast
    const backgroundColor = Color(0xFFFFFDF7); // Creamy White
    const surfaceColor = Colors.white;

    final baseTextTheme = GoogleFonts.poppinsTextTheme();

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.light(
        primary: primaryColor,
        secondary: secondaryColor,
        tertiary: accentColor,
        onSecondary: Colors.brown.shade900,
        onSurface: const Color(0xFF2D3436),
      ),
      scaffoldBackgroundColor: backgroundColor,
      appBarTheme: AppBarTheme(
        backgroundColor: backgroundColor,
        foregroundColor: const Color(0xFF2D3436),
        elevation: 0,
        centerTitle: true,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
        ),
        titleTextStyle: GoogleFonts.poppins(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: const Color(0xFF2D3436),
        ),
      ),
      cardTheme: CardThemeData(
        color: surfaceColor,
        elevation: 8,
        shadowColor: primaryColor.withValues(alpha: 0.15),
        shape: roundedShape,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 4,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: surfaceColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
      ),
      textTheme: baseTextTheme.copyWith(
        headlineLarge: GoogleFonts.poppins(
          fontWeight: FontWeight.bold,
          color: const Color(0xFF2D3436),
          height: 1.2,
        ),
        headlineMedium: GoogleFonts.poppins(
          fontWeight: FontWeight.w600,
          color: const Color(0xFF2D3436),
        ),
        titleLarge: GoogleFonts.poppins(
          fontWeight: FontWeight.w600,
          color: const Color(0xFF2D3436),
        ),
        bodyLarge: GoogleFonts.poppins(
          color: const Color(0xFF4A4A4A),
          fontSize: 16,
        ),
        bodyMedium: GoogleFonts.poppins(color: const Color(0xFF636E72)),
      ),
    );
  }

  /// Krishna Paksha (Waning Moon) - Deep Space / Neon Theme
  static ThemeData _buildKrishnaTheme() {
    // Cyber/Space Palette
    const primaryColor = Color(0xFF7B2CBF); // Deep Purple
    const secondaryColor = Color(0xFF9D4EDD); // Brighter Purple
    const accentColor = Color(0xFF4CC9F0); // Neon Cyan
    const backgroundColor = Color(0xFF10002B); // Deepest Void
    const surfaceColor = Color(0xFF240046); // Dark Violet Surface

    final baseTextTheme = GoogleFonts.poppinsTextTheme(
      ThemeData.dark().textTheme,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        primary: primaryColor,
        secondary: secondaryColor,
        tertiary: accentColor,
        surface: surfaceColor,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
      ),
      scaffoldBackgroundColor: backgroundColor,
      appBarTheme: AppBarTheme(
        backgroundColor: backgroundColor,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
        ),
        titleTextStyle: GoogleFonts.poppins(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
      cardTheme: CardThemeData(
        color: surfaceColor.withValues(alpha: 0.6), // Translucent look
        elevation: 4,
        shadowColor: Colors.black.withValues(alpha: 0.4),
        shape: roundedShape,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: accentColor,
        foregroundColor: Colors.black, // High contrast on Neon Cyan
        elevation: 8,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Color(0xFF240046),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
      ),
      textTheme: baseTextTheme.copyWith(
        headlineLarge: GoogleFonts.poppins(
          fontWeight: FontWeight.bold,
          color: Colors.white,
          height: 1.2,
        ),
        headlineMedium: GoogleFonts.poppins(
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
        titleLarge: GoogleFonts.poppins(
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
        bodyLarge: GoogleFonts.poppins(
          color: const Color(0xFFE0E0E0),
          fontSize: 16,
        ),
        bodyMedium: GoogleFonts.poppins(color: const Color(0xFFBDBDBD)),
      ),
    );
  }

  /// Pure Dark Theme (OLED Black) - Professional & Clean
  static ThemeData _buildPureDarkTheme() {
    // 1. Define a seed color for proper tonal generation (Saffron/Gold)
    const seedColor = Color(0xFFFFB74D);

    // 2. Generate dark color scheme
    final colorScheme = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: Brightness.dark,
      primary: const Color(
        0xFFFFA000,
      ), // Richer/Darker Gold for better contrast
      surface: const Color(0xFF141414), // Very dark grey for cards
      onSurface: const Color(0xFFE0E0E0), // High legibility white
    );

    final baseTextTheme = GoogleFonts.poppinsTextTheme(
      ThemeData.dark().textTheme,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: Colors.black,

      // Clean AppBar
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
        ),
        titleTextStyle: GoogleFonts.poppins(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),

      // Standard Card Style (Not Glassmorphic by default, just clean dark cards)
      cardTheme: CardThemeData(
        color: const Color(0xFF1E1E1E),
        elevation: 0,
        shape: roundedShape,
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      ),

      // Distinct FAB
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        elevation: 4,
      ),

      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Color(0xFF1E1E1E),
        modalBackgroundColor: Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
      ),

      textTheme: baseTextTheme.copyWith(
        headlineLarge: GoogleFonts.poppins(
          fontWeight: FontWeight.bold,
          color: Colors.white,
          height: 1.2,
        ),
        headlineMedium: GoogleFonts.poppins(
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
        titleLarge: GoogleFonts.poppins(
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
        bodyLarge: GoogleFonts.poppins(
          color: const Color(0xFFEEEEEE),
          fontSize: 16,
        ),
        bodyMedium: GoogleFonts.poppins(color: const Color(0xFFCCCCCC)),
      ),
    );
  }

  /// Get theme based on paksha
  static ThemeData getThemeForPaksha(String paksha) {
    if (paksha == 'Shukla') return shuklaTheme;
    // Default to Pure Dark for Krishna Paksha
    return pureDarkTheme;
  }

  /// True when High Contrast is requested (app setting propagated via
  /// MediaQuery, or the OS-level highContrast flag).
  static bool highContrastOf(BuildContext context) {
    return MediaQuery.maybeHighContrastOf(context) ?? false;
  }

  /// Alpha to use for de-emphasized text/icons. Returns 1.0 when High
  /// Contrast is on so secondary content stays legible.
  static double contrastAlpha(BuildContext context, double normal) {
    return highContrastOf(context) ? 1.0 : normal;
  }

  /// High-contrast wrapper for any base theme. Light becomes pure
  /// white/black; dark becomes black background, white text, and a
  /// brightened primary when the base uses deep purple.
  static ThemeData withHighContrast(ThemeData base) {
    final isDark = base.brightness == Brightness.dark;
    if (!isDark) {
      return base.copyWith(
        scaffoldBackgroundColor: Colors.white,
        colorScheme: base.colorScheme.copyWith(
          surface: Colors.white,
          onSurface: Colors.black,
        ),
        appBarTheme: base.appBarTheme.copyWith(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
        ),
        cardTheme: base.cardTheme.copyWith(color: Colors.white, elevation: 0),
        bottomSheetTheme: base.bottomSheetTheme.copyWith(
          backgroundColor: Colors.white,
        ),
        textTheme: base.textTheme.copyWith(
          bodyLarge: base.textTheme.bodyLarge?.copyWith(color: Colors.black),
          bodyMedium: base.textTheme.bodyMedium?.copyWith(
            color: Colors.black.withValues(alpha: 0.87),
          ),
        ),
      );
    }
    // Dark HC: flatten to black, force white text, brighten deep-purple
    // primary (Krishna #7B2CBF has ~1.5:1 on dark backgrounds).
    final basePrimary = base.colorScheme.primary;
    final brightPrimary = basePrimary == const Color(0xFF7B2CBF)
        ? const Color(0xFFC77DFF)
        : basePrimary;
    return base.copyWith(
      scaffoldBackgroundColor: Colors.black,
      colorScheme: base.colorScheme.copyWith(
        primary: brightPrimary,
        surface: Colors.black,
        onSurface: Colors.white,
        // Bright primaries (light purple / amber) need black text on top.
        onPrimary: Colors.black,
      ),
      appBarTheme: base.appBarTheme.copyWith(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      cardTheme: base.cardTheme.copyWith(color: Colors.black, elevation: 0),
      bottomSheetTheme: base.bottomSheetTheme.copyWith(
        backgroundColor: Colors.black,
      ),
      textTheme: base.textTheme.copyWith(
        bodyLarge: base.textTheme.bodyLarge?.copyWith(color: Colors.white),
        bodyMedium: base.textTheme.bodyMedium?.copyWith(color: Colors.white),
      ),
    );
  }

  static final ThemeData shuklaHighContrastTheme = withHighContrast(
    shuklaTheme,
  );
  static final ThemeData krishnaHighContrastTheme = withHighContrast(
    krishnaTheme,
  );
  static final ThemeData pureDarkHighContrastTheme = withHighContrast(
    pureDarkTheme,
  );

  /// Returns the cached HC variant for a known base theme.
  static ThemeData resolveHighContrast(ThemeData base) {
    if (identical(base, krishnaTheme)) return krishnaHighContrastTheme;
    if (identical(base, pureDarkTheme)) return pureDarkHighContrastTheme;
    if (identical(base, shuklaTheme)) return shuklaHighContrastTheme;
    return withHighContrast(base);
  }

  /// Glassmorphism decoration for cards and sheets
  static BoxDecoration glassmorphism({
    required BuildContext context,
    double opacity = 0.1,
    double blur = 20,
    double borderRadius = 24,
    Border? border,
    WidgetRef? ref, // Added ref parameter
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isPureDark =
        Theme.of(context).scaffoldBackgroundColor == Colors.black;

    final appHighContrast =
        ref?.read(glassmorphismConfigProvider).isHighContrast ?? false;
    final isHighContrast = appHighContrast || highContrastOf(context);

    // High Contrast: solid surfaces with strong borders (dark: black card
    // + white 0.7 border so it reads on a flattened black background).
    if (isHighContrast) {
      return BoxDecoration(
        color: isDark ? Colors.black : Colors.white,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.7)
              : Colors.black.withValues(alpha: 0.6),
          width: 1.5,
        ),
      );
    }

    // Pure Dark (non-HC): keep existing subtle solid style.
    if (isPureDark) {
      return BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
        ),
      );
    }

    return BoxDecoration(
      color: isDark
          ? Colors.white.withValues(alpha: opacity)
          : Colors.white.withValues(alpha: 0.6), // More visible glass in light
      borderRadius: BorderRadius.circular(borderRadius),
      border:
          border ??
          Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.1)
                : Colors.white.withValues(alpha: 0.4),
            width: 1.5,
          ),
      boxShadow: [
        BoxShadow(
          color: Theme.of(
            context,
          ).primaryColor.withValues(alpha: isDark ? 0.2 : 0.1),
          blurRadius: blur,
        ),
      ],
    );
  }

  /// Returns [normal] unless Reduce Motion / OS disableAnimations is on,
  /// in which case a 1ms duration so implicit animations jump to end state.
  /// NOTE: must NOT be [Duration.zero] — AnimatedSize with a zero duration
  /// completes synchronously inside its own performLayout and crashes with
  /// "A RenderAnimatedSize was mutated in its own performLayout"
  /// (RenderAnimatedSize._layoutStable → controller.forward during layout).
  static Duration animationDuration(BuildContext context, Duration normal) {
    final disableAnimations =
        MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    return disableAnimations ? const Duration(milliseconds: 1) : normal;
  }

  /// True when animations should be skipped (app Reduce Motion or OS setting).
  static bool reduceMotionOf(BuildContext context) {
    return MediaQuery.maybeDisableAnimationsOf(context) ?? false;
  }

  /// AnimationStyle for showModalBottomSheet: near-instant when Reduce Motion
  /// is on, else null (framework default slide/fade). The framework route
  /// transitions ignore MediaQuery.disableAnimations, so sheets need this
  /// explicit hook (a caller-passed AnimationController would NOT be disposed
  /// by the route — willDisposeAnimationController=false — hence a style).
  static AnimationStyle? sheetAnimationStyleOf(BuildContext context) {
    if (!reduceMotionOf(context)) return null;
    return const AnimationStyle(
      duration: Duration(milliseconds: 1),
      reverseDuration: Duration(milliseconds: 1),
    );
  }

  /// Applies the High Contrast and/or Reduced Motion theme variants to [base].
  /// Reduced Motion swaps the platform page transitions for instant ones —
  /// MaterialPageRoute ignores MediaQuery.disableAnimations, so without this
  /// every screen push still slides at full speed.
  static ThemeData resolveAccessible(
    ThemeData base, {
    required bool highContrast,
    required bool reduceMotion,
  }) {
    var theme = highContrast ? resolveHighContrast(base) : base;
    if (reduceMotion) theme = withReducedMotion(theme);
    return theme;
  }

  /// Returns [base] with instant page transitions (new page appears with no
  /// slide/fade). Applied when Reduce Motion is on.
  static ThemeData withReducedMotion(ThemeData base) {
    return base.copyWith(pageTransitionsTheme: instantPageTransitionsTheme);
  }

  /// PageTransitionsTheme that shows the incoming page immediately on every
  /// platform. Covers all MaterialPageRoute pushes app-wide from one place.
  static const PageTransitionsTheme instantPageTransitionsTheme =
      PageTransitionsTheme(
        builders: {
          TargetPlatform.android: _InstantPageTransitionsBuilder(),
          TargetPlatform.iOS: _InstantPageTransitionsBuilder(),
          TargetPlatform.linux: _InstantPageTransitionsBuilder(),
          TargetPlatform.macOS: _InstantPageTransitionsBuilder(),
          TargetPlatform.windows: _InstantPageTransitionsBuilder(),
          TargetPlatform.fuchsia: _InstantPageTransitionsBuilder(),
        },
      );

  /// Standard background decoration with gradient.
  /// Returns a flat scaffold-colored background when Reduce Motion or High
  /// Contrast is on, so all callers respect the setting without per-screen
  /// branching.
  static BoxDecoration backgroundDecoration(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isPureDark =
        Theme.of(context).scaffoldBackgroundColor == Colors.black;

    if (isPureDark) {
      return const BoxDecoration(color: Colors.black);
    }

    if (reduceMotionOf(context) || highContrastOf(context)) {
      return BoxDecoration(color: Theme.of(context).scaffoldBackgroundColor);
    }

    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: isDark
            ? [
                const Color(0xFF10002B),
                const Color(0xFF240046),
                const Color(0xFF10002B),
              ]
            : [
                const Color(0xFFFFFDF7),
                const Color(0xFFFFECB3).withValues(alpha: 0.3),
                const Color(0xFFFFFDF7),
              ],
      ),
    );
  }
}

/// PageTransitionsBuilder that shows the new page instantly (Reduce Motion).
/// The route still runs its 300ms controller invisibly, but with the child
/// returned directly there is no visible slide/fade on push or pop.
class _InstantPageTransitionsBuilder extends PageTransitionsBuilder {
  const _InstantPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return child;
  }
}

/// Extension for quick theme access
extension ThemeExtension on BuildContext {
  ThemeData get theme => Theme.of(this);
  ColorScheme get colors => Theme.of(this).colorScheme;
  TextTheme get textTheme => Theme.of(this).textTheme;
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
}

/// Cached glassmorphism decoration data to avoid recreating on every build.
/// This provider only rebuilds when accessibility settings change.
class GlassmorphismConfig {
  final bool isHighContrast;

  const GlassmorphismConfig({required this.isHighContrast});

  /// Get cached decoration for a specific theme context
  BoxDecoration getDecoration({
    required bool isDark,
    required bool isPureDark,
    required Color primaryColor,
    double opacity = 0.1,
    double blur = 20,
    double borderRadius = 24,
    Border? border,
  }) {
    // High Contrast: solid + strong border (dark HC uses black card so it
    // stays legible on the flattened black background).
    if (isHighContrast) {
      return BoxDecoration(
        color: isDark ? Colors.black : Colors.white,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.7)
              : Colors.black.withValues(alpha: 0.6),
          width: 1.5,
        ),
      );
    }
    // Pure Dark (non-HC) - return solid decoration
    if (isPureDark) {
      return BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.1)
              : Colors.black.withValues(alpha: 0.1),
        ),
      );
    }

    // Standard glassmorphism
    return BoxDecoration(
      color: isDark
          ? Colors.white.withValues(alpha: opacity)
          : Colors.white.withValues(alpha: 0.6),
      borderRadius: BorderRadius.circular(borderRadius),
      border:
          border ??
          Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.1)
                : Colors.white.withValues(alpha: 0.4),
            width: 1.5,
          ),
      boxShadow: [
        BoxShadow(
          color: primaryColor.withValues(alpha: isDark ? 0.2 : 0.1),
          blurRadius: blur,
        ),
      ],
    );
  }
}

/// Provider for glassmorphism configuration - only rebuilds on accessibility changes
final glassmorphismConfigProvider = Provider<GlassmorphismConfig>((ref) {
  final accessibility = ref.watch(accessibilityProvider);
  return GlassmorphismConfig(isHighContrast: accessibility.highContrast);
});
