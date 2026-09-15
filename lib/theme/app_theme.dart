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

  // ---------------------------------------------------------------------------
  // Centralized semantic & illustration palette.
  //
  // Rule: no widget/screen/painter may hardcode these hex values or
  // `Colors.orange/amber/indigo/...` shades directly. Reference the constants
  // or the brightness-aware helpers below so light/dark/high-contrast stay
  // consistent from this single file.
  // ---------------------------------------------------------------------------

  // Warning / error-display palette (replaces hardcoded Colors.orange shades).
  static const Color warning = Color(0xFFFF9800);
  static const Color warningLightContainer = Color(
    0xFFFFF3E0,
  ); // orange.shade50
  static const Color warningDarkContainer = Color(
    0xFFE65100,
  ); // orange.shade900
  static const Color warningIconLight = Color(0xFFFB8C00); // orange.shade600
  static const Color warningIconDark = Color(0xFFFFCC80); // orange.shade200
  static const Color warningTextLight = Color(0xFFEF6C00); // orange.shade800
  static const Color warningTextDark = Color(0xFFFFCC80); // orange.shade200
  static const Color warningStrong = Color(0xFFF57C00); // orange.shade700

  static Color warningBackground(bool isDark) => isDark
      ? warningDarkContainer.withValues(alpha: 0.3)
      : warningLightContainer;
  static Color warningBorderColor() => warning.withValues(alpha: 0.3);
  static Color warningSoftBackground() => warning.withValues(alpha: 0.1);
  static Color warningIconColor(bool isDark) =>
      isDark ? warningIconDark : warningIconLight;
  static Color warningTextColor(bool isDark) =>
      isDark ? warningTextDark : warningTextLight;

  // Moon countdown / moon animation palette (replaces hardcoded
  // indigo/deepPurple/amber/orange/grey shades).
  static const Color moonLit = Color(0xFFFFE082); // amber.shade200
  static const Color moonShadow = Color(0xFF1A1A2E); // deep dark blue/black
  static const Color moonGradientDarkA = Color(0xFF1A237E); // indigo.shade900
  static const Color moonGradientDarkB = Color(
    0xFF311B92,
  ); // deepPurple.shade900
  static const Color moonGradientLightA = Color(0xFFFFECB3); // amber.shade100
  static const Color moonGradientLightB = Color(0xFFFFF3E0); // orange.shade50
  static const Color moonDiscDarkA = Color(0xFFE0E0E0); // grey.shade300
  static const Color moonDiscDarkB = Color(0xFF757575); // grey.shade600
  static const Color moonDiscLightA = Color(0xFFFFE082); // amber.shade200
  static const Color moonDiscLightB = Color(0xFFFFB74D); // orange.shade300
  static const Color moonGlowDark = Color(0xFF3F51B5); // indigo
  static const Color moonGlowLight = Color(0xFFFFC107); // amber
  static const Color moonIconDark = Color(0xFF1A237E); // indigo.shade900
  static const Color moonIconLight = Color(0xFFEF6C00); // orange.shade800
  static const Color purnimaIconDark = Color(0xFFFFC107); // amber
  static const Color purnimaIconLight = Color(0xFFFB8C00); // orange.shade600
  static const Color amavasyaIconDark = Color(0xFFBDBDBD); // grey.shade400
  static const Color amavasyaIconLight = Color(0xFF616161); // grey.shade700

  static List<Color> moonCountdownGradient(bool isDark) => isDark
      ? [
          moonGradientDarkA.withValues(alpha: 0.6),
          moonGradientDarkB.withValues(alpha: 0.4),
        ]
      : [
          moonGradientLightA.withValues(alpha: 0.8),
          moonGradientLightB.withValues(alpha: 0.6),
        ];
  static Color moonCountdownBorder(bool isDark) => isDark
      ? Colors.white.withValues(alpha: 0.1)
      : moonLit.withValues(alpha: 0.5);
  static Color moonCountdownShadow(bool isDark) => isDark
      ? Colors.black.withValues(alpha: 0.3)
      : moonGlowLight.withValues(alpha: 0.2);
  static List<Color> moonDiscGradient(bool isDark) => isDark
      ? [moonDiscDarkA, moonDiscDarkB]
      : [moonDiscLightA, moonDiscLightB];
  static Color moonGlowColor(bool isDark) =>
      (isDark ? moonGlowDark : moonGlowLight).withValues(alpha: 0.5);
  static Color moonIconColor(bool isDark) =>
      isDark ? moonIconDark : moonIconLight;
  static Color purnimaIconColor(bool isDark) =>
      isDark ? purnimaIconDark : purnimaIconLight;
  static Color amavasyaIconColor(bool isDark) =>
      isDark ? amavasyaIconDark : amavasyaIconLight;

  // Space / solar-system illustration palette (fixed illustration colors that
  // must not shift with the app theme, but still centralized here).
  static const Color spaceDarkTop = Color(0xFF0F0F1A);
  static const Color spaceDarkBottom = Color(0xFF050508);
  static const Color spaceLightTop = Color(0xFF1A1A2E);
  static const Color spaceLightBottom = Color(0xFF0F0F1A);
  static const Color sunInner = Color(0xFFFFFFE0);
  static const Color sunMid = Color(0xFFFFD700);
  static const Color sunOuter = Color(0xFFFF8C00);
  static const Color earthLight = Color(0xFF87CEEB);
  static const Color earthMid = Color(0xFF4A90D9);
  static const Color earthDeep = Color(0xFF2E5090);
  static const Color earthGlowGreen = Color(0xFF2E8B57);
  static const Color spaceStar = Colors.white;
  static const Color spaceLabel = Colors.white;
  static const Color retrogradeIndicator = Color(0xFFE53935);

  static List<Color> spaceBackgroundGradient(bool isDark) => isDark
      ? [spaceDarkTop, spaceDarkBottom]
      : [spaceLightTop, spaceLightBottom];

  // Planet visualization palette (single source; PlanetaryViewService delegates).
  static const int planetSun = 0xFFFFD700; // Gold
  static const int planetMoon = 0xFFC0C0C0; // Silver
  static const int planetMercury = 0xFF00BFFF; // Deep sky blue
  static const int planetVenus = 0xFFFF69B4; // Hot pink
  static const int planetMars = 0xFFFF4500; // Red-orange
  static const int planetJupiter = 0xFFFFB347; // Light orange
  static const int planetSaturn = 0xFFFFFACD; // Lemon chiffon
  static const int planetUranus = 0xFF40E0D0; // Turquoise
  static const int planetNeptune = 0xFF4169E1; // Royal blue

  // Sunrise / sunset icon accents (replaces orange.shade300 / indigo.shade300).
  static const Color sunrise = Color(0xFFFFB74D); // orange.shade300
  static const Color sunset = Color(0xFF7986CB); // indigo.shade300

  // Success / visibility accent (replaces hardcoded Colors.green).
  static const Color successLight = Color(0xFF2E7D32); // green.shade800
  static const Color successDark = Color(0xFF81C784); // green.shade300
  static Color success(bool isDark) => isDark ? successDark : successLight;

  // Map boundary stroke (replaces hardcoded Colors.orange on map layers).
  // Fixed illustration color so maps look identical in light/dark.
  static const Color mapBoundary = Color(0xFFFF9800);

  // Location prompt accent (replaces hardcoded Colors.amber pin).
  static const Color locationAccent = Color(0xFFFFC107); // amber

  // ---------------------------------------------------------------------------
  // Hero (paksha indicator) palette — faithful mirror of
  // assets/redesign assets/tithi-redesign-v3-faithful.html theme vars.
  // Shukla: orange gradient / Krishna: purple gradient / PureDark: flat dark.
  // Resolve via isDark + isPureDark (scaffold == black) so all three
  // ThemeData variants + high-contrast stay correct from one place.
  // ---------------------------------------------------------------------------
  // Shukla stops are deepened (bright #FF9F1C left white text at ~2:1
  // contrast) so white copy stays legible while keeping the warm identity.
  static const Color heroShukla1 = Color(0xFFE65100);
  static const Color heroShukla2 = Color(0xFFBF3600);
  static const Color heroKrishna1 = Color(0xFF9D4EDD);
  static const Color heroKrishna2 = Color(0xFF7B2CBF);
  static const Color heroDark1 = Color(0xFF1E1E1E);
  static const Color heroDark2 = Color(0xFF050505);
  static const Color heroInk = Colors.white;
  static const Color heroMoonFillShukla = Color(0xFFFFE082); // moonLit
  static const Color heroMoonFillKrishna = Color(0xFF4CC9F0); // tertiary neon
  static const Color heroMoonFillDark = Color(0xFFFFE082); // moonLit

  static bool isPureDarkTheme(BuildContext context) =>
      Theme.of(context).scaffoldBackgroundColor == Colors.black;

  static List<Color> heroGradient(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (!isDark) return [heroShukla1, heroShukla2];
    if (isPureDarkTheme(context)) return [heroDark1, heroDark2];
    return [heroKrishna1, heroKrishna2];
  }

  static Color heroGlow(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (!isDark) return heroShukla1.withValues(alpha: 0.32);
    if (isPureDarkTheme(context)) {
      return const Color(0xFFFFA000).withValues(alpha: 0.25);
    }
    return heroKrishna1.withValues(alpha: 0.4);
  }

  static Color heroSubtle(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (!isDark) return Colors.white.withValues(alpha: 0.88);
    if (isPureDarkTheme(context)) {
      return Colors.white.withValues(alpha: 0.7);
    }
    return Colors.white.withValues(alpha: 0.82);
  }

  static Color heroChipBackground(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Shukla uses a dark glass so white-bold chip text stays legible on the
    // orange gradient (a white veil would wash it out).
    if (!isDark) return Colors.black.withValues(alpha: 0.22);
    if (isPureDarkTheme(context)) {
      return Colors.white.withValues(alpha: 0.08);
    }
    return Colors.white.withValues(alpha: 0.12);
  }

  static Color heroChipBorder(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (!isDark) return Colors.white.withValues(alpha: 0.3);
    if (isPureDarkTheme(context)) {
      return const Color(0xFFFFB74D).withValues(alpha: 0.3);
    }
    return heroKrishna1.withValues(alpha: 0.4);
  }

  static Color heroMoonFill(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (!isDark) return heroMoonFillShukla;
    if (isPureDarkTheme(context)) return heroMoonFillDark;
    return heroMoonFillKrishna;
  }

  /// Hero card decoration: radial glow + linear gradient, white ink.
  /// Pure Dark gets a flat bordered card per the redesign.
  static BoxDecoration heroDecoration(BuildContext context) {
    final glow = heroGlow(context);
    final gradient = heroGradient(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isPureDark = isPureDarkTheme(context);
    return BoxDecoration(
      borderRadius: BorderRadius.circular(24),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: gradient,
      ),
      border: isPureDark
          ? Border.all(color: Colors.white.withValues(alpha: 0.1))
          : null,
      boxShadow: [
        // Softened so less color flows outside the card's bottom edge.
        BoxShadow(
          color: glow,
          blurRadius: isDark && !isPureDark ? 16 : 20,
          offset: const Offset(0, 6),
        ),
      ],
    );
  }

  static BoxDecoration heroGlowBackdrop(BuildContext context) {
    // Radial highlight at top-right, mirroring `.hero` background layer.
    return BoxDecoration(
      borderRadius: BorderRadius.circular(24),
      gradient: RadialGradient(
        center: const Alignment(0.85, -0.4),
        radius: 1.4,
        colors: [heroGlow(context), Colors.transparent],
        stops: const [0.0, 0.55],
      ),
    );
  }

  /// Sheet header block: same hero gradient/ink treatment as [heroDecoration]
  /// but flush with the sheet — rounded top (32, matching the bottom-sheet
  /// shape), straight bottom edge into the body, no outer shadow (the modal
  /// supplies elevation). High contrast falls back to a solid surface.
  /// Pass the resolved flag (OS MediaQuery and/or app accessibility setting,
  /// same as the hero card) — a static cannot read providers itself.
  static BoxDecoration heroSheetHeaderDecoration(
    BuildContext context, {
    required bool highContrast,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (highContrast) {
      return BoxDecoration(
        color: isDark ? Colors.black : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        border: Border(
          bottom: BorderSide(
            color: (isDark ? Colors.white : Colors.black).withValues(
              alpha: 0.15,
            ),
          ),
        ),
      );
    }
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: heroGradient(context),
      ),
      borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      border: isPureDarkTheme(context)
          ? Border.all(color: Colors.white.withValues(alpha: 0.1))
          : null,
    );
  }

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
      colorScheme: const ColorScheme.light(
        primary: primaryColor,
        secondary: secondaryColor,
        tertiary: accentColor,
        onSecondary: Color(0xFF3E2723), // brown.shade900
        onSurface: Color(0xFF2D3436),
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
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
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
