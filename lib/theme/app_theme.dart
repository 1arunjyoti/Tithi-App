import 'package:flutter/material.dart';
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

  /// Shukla Paksha (Waxing Moon) - Vibrant Warm Theme
  static ThemeData get shuklaTheme {
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
        surface: surfaceColor,
        onPrimary: Colors.white,
        onSecondary: Colors.brown.shade900,
        onSurface: const Color(0xFF2D3436),
      ),
      scaffoldBackgroundColor: backgroundColor,
      appBarTheme: AppBarTheme(
        backgroundColor: backgroundColor,
        foregroundColor: const Color(0xFF2D3436),
        elevation: 0,
        centerTitle: true,
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
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surfaceColor,
        shape: const RoundedRectangleBorder(
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
  static ThemeData get krishnaTheme {
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
      colorScheme: ColorScheme.dark(
        primary: primaryColor,
        secondary: secondaryColor,
        tertiary: accentColor,
        surface: surfaceColor,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: Colors.white,
      ),
      scaffoldBackgroundColor: backgroundColor,
      appBarTheme: AppBarTheme(
        backgroundColor: backgroundColor,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
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
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: const Color(0xFF240046),
        shape: const RoundedRectangleBorder(
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
  static ThemeData get pureDarkTheme {
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

    // Check accessibility overrides
    bool isHighContrast = false;
    if (ref != null) {
      isHighContrast = ref.watch(accessibilityProvider).highContrast;
    }

    // High Contrast Mode / Pure Dark
    if (isPureDark || isHighContrast) {
      return BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.1)
              : Colors.black.withValues(alpha: 0.1),
          width: 1,
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
          spreadRadius: 0,
        ),
      ],
    );
  }
}

/// Extension for quick theme access
extension ThemeExtension on BuildContext {
  ThemeData get theme => Theme.of(this);
  ColorScheme get colors => Theme.of(this).colorScheme;
  TextTheme get textTheme => Theme.of(this).textTheme;
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
}
