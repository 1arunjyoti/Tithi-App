import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/accessibility_provider.dart';
import 'app_metrics.dart';
import 'app_typography.dart';

/// Theme configuration for the Tithi app
/// Modern, vibrant design targeting younger generation
class AppTheme {
  // Common Shapes
  static final roundedShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(AppRadius.card),
  );

  // ---------------------------------------------------------------------------
  // Centralized semantic & illustration palette.
  //
  // Rule: no widget/screen/painter may hardcode these hex values or
  // `Colors.orange/amber/indigo/...` shades directly. Reference the constants
  // or the brightness-aware helpers below so light/dark/high-contrast stay
  // consistent from this single file.
  // ---------------------------------------------------------------------------

  // ---------------------------------------------------------------------------
  // Crisp Shukla (light) palette.
  //
  // A cool-neutral page, pure-white cards with 1px hairlines and no shadows,
  // deep-charcoal ink, and a single vermilion accent. Do not reintroduce
  // translucent card fills, cream backgrounds, tan icon tiles or soft card
  // shadows: the accent is meant to be the only saturated colour on screen.
  // ---------------------------------------------------------------------------
  static const Color shuklaAccent = Color(0xFFE84A1B); // vermilion
  static const Color shuklaAccentDeep = Color(0xFFC2410C); // darker stop
  static const Color shuklaBackground = Color(0xFFF5F5F7); // cool neutral
  static const Color shuklaSurface = Colors.white; // cards: fully opaque
  static const Color shuklaHairline = Color(0xFFE5E5EA); // 1px card edge
  static const Color shuklaInk = Color(0xFF111113); // deep charcoal
  static const Color shuklaInkSecondary = Color(0xFF3C3C43);
  static const Color shuklaInkTertiary = Color(0xFF6E6E76);
  static const Color shuklaTile = Color(0xFFF2F2F7); // neutral icon tile
  static const Color shuklaTodayFill = Color(0xFFEDEDF2); // calendar today

  // Native launch-window colours. The platform splash and `NormalTheme`'s
  // window background both paint these, so the window is already the colour of
  // the first Flutter frame and the hand-off has no visible flash. Keep in
  // sync with `flutter_native_splash.yaml` (guarded by
  // `test/animated_splash_test.dart`).
  static const Color splashBackgroundLight = shuklaBackground; // #F5F5F7
  static const Color splashBackgroundDark = Color(0xFF10002B); // gradient stop

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
  static const Color moonDiscDarkA = Color(0xFFE0E0E0); // grey.shade300
  static const Color moonDiscDarkB = Color(0xFF757575); // grey.shade600
  static const Color moonDiscLightA = Color(0xFFFFE082); // amber.shade200
  static const Color moonDiscLightB = Color(0xFFFFB74D); // orange.shade300
  static const Color moonGlowDark = Color(0xFF3F51B5); // indigo
  static const Color moonGlowLight = Color(0xFFFFC107); // amber
  // Layered moon bloom (the hero's halo, not a UI accent):
  // warm ivory core -> luminous amber rim -> faint cool sky scatter.
  // Keeping the warm centre preserves the familiar glow while the cool edge
  // gives it depth instead of a flat, washed-out silhouette.
  static const Color moonGlowCore = Color(0xFFFFF6DF);
  static const Color moonGlowRim = Color(0xFFFFD97A);
  static const Color moonGlowScatter = Color(0xFFB9CFFF);
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
      : [shuklaSurface, shuklaSurface];
  static Color moonCountdownBorder(bool isDark) =>
      isDark ? Colors.white.withValues(alpha: 0.1) : shuklaHairline;
  static Color moonCountdownShadow(bool isDark) =>
      isDark ? Colors.black.withValues(alpha: 0.3) : Colors.transparent;
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
  // Calendar card palette — faithful mirror of
  // assets/redesign assets/calendar-redesign.html theme vars.
  // ---------------------------------------------------------------------------
  static const Color calendarSelectedTopShukla = shuklaAccent;
  static const Color calendarSelectedBottomShukla = shuklaAccentDeep;
  static const Color calendarSelectedTopKrishna = Color(0xFF9D4EDD);
  static const Color calendarSelectedBottomKrishna = Color(0xFF7B2CBF);
  static const Color calendarSelectedTopDark = Color(0xFFFFA000);
  static const Color calendarSelectedBottomDark = Color(0xFFE65100);
  static const Color calendarSelectedInkDark = Color(0xFF1A1200);
  static const Color calendarTodayInkKrishna = Color(0xFFC9B5FF);
  static const Color calendarDotShukla = shuklaAccent;
  static const Color calendarDotKrishna = Color(0xFF4CC9F0);
  static const Color calendarDotDark = Color(0xFFFFA000);

  static bool _isKrishnaTheme(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark &&
      !isPureDarkTheme(context);

  /// Selected-day gradient (spec `--todayGrad`). High contrast uses the
  /// solid primary so the text-on-gradient pairing never degrades.
  /// Explicit stops keep the gradient faithful even if the ColorScheme
  /// drifts from the spec palette.
  static List<Color> calendarSelectedGradient(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (highContrastOf(context)) {
      final primary = Theme.of(context).colorScheme.primary;
      return [primary, primary];
    }
    if (!isDark) {
      return [calendarSelectedTopShukla, calendarSelectedBottomShukla];
    }
    if (isPureDarkTheme(context)) {
      return [calendarSelectedTopDark, calendarSelectedBottomDark];
    }
    return [calendarSelectedTopKrishna, calendarSelectedBottomKrishna];
  }

  /// Selected-day text color (spec `.d.sel`: white, except pure-dark which
  /// uses `--selInk` near-black on the gold gradient).
  static Color calendarSelectedForeground(BuildContext context) {
    if (highContrastOf(context)) {
      return Theme.of(context).colorScheme.onPrimary;
    }
    if (isPureDarkTheme(context)) return calendarSelectedInkDark;
    return Colors.white;
  }

  /// Today (unselected) tile background (spec `--selBg`).
  static Color calendarTodayBackground(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (highContrastOf(context)) {
      return scheme.primary.withValues(alpha: 0.25);
    }
    if (!isDark) return shuklaTodayFill;
    // Krishna tints with the bright secondary (#9D4EDD at 18%); pure-dark
    // uses the gold primary at 14% — both per the spec vars.
    if (isPureDarkTheme(context)) {
      return scheme.primary.withValues(alpha: 0.14);
    }
    return scheme.secondary.withValues(alpha: 0.18);
  }

  /// Today (unselected) tile text.
  static Color calendarTodayForeground(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (highContrastOf(context)) {
      return Theme.of(context).colorScheme.onSurface;
    }
    if (!isDark) return shuklaAccent;
    if (isPureDarkTheme(context)) return moonDiscLightB;
    return calendarTodayInkKrishna;
  }

  /// Today (unselected) tile ring.
  static Color calendarTodayRing(BuildContext context) {
    if (_isKrishnaTheme(context) && !highContrastOf(context)) {
      return Theme.of(context).colorScheme.primary;
    }
    if (highContrastOf(context)) {
      return Theme.of(context).colorScheme.primary;
    }
    if (Theme.of(context).brightness != Brightness.dark) return shuklaAccent;
    return warningDarkContainer;
  }

  /// Festival pill-bar color (minor festivals render at reduced alpha).
  static Color calendarFestivalBar(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (!isDark) return calendarDotShukla;
    if (isPureDarkTheme(context)) return calendarDotDark;
    return calendarDotKrishna;
  }

  // ---------------------------------------------------------------------------
  // Festivals & Events palette — vermilion accents on light, gold/purple on
  // dark (see [festivalAccent]).
  // ---------------------------------------------------------------------------

  /// Bright purple for festival accents on the Krishna theme (same value the
  /// high-contrast treatment uses to lift the deep-purple primary). Stays
  /// legible at small sizes on dark violet surfaces (~5.5:1).
  static const Color festivalAccentKrishna = Color(0xFFC77DFF);

  /// Accent for festival rows, wisdom and countdowns: vermilion in light,
  /// moon-gold in pure-dark — but the Krishna theme keeps its purple
  /// identity (brighter secondary for legibility on dark violet) instead of
  /// gold. Solid primary in high contrast.
  static Color festivalAccent(BuildContext context) {
    if (highContrastOf(context)) {
      return Theme.of(context).colorScheme.primary;
    }
    if (Theme.of(context).brightness != Brightness.dark) {
      return shuklaAccent;
    }
    if (isPureDarkTheme(context)) return moonDiscLightB;
    return festivalAccentKrishna;
  }

  /// Soft tile behind the festival glyph: a neutral grey chip on the crisp
  /// light card (the accent stays in the glyph), gold/purple wash on dark.
  static Color festivalTileBackground(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (!isDark) {
      return highContrastOf(context)
          ? shuklaAccent.withValues(alpha: 0.12)
          : shuklaTile;
    }
    return festivalAccent(
      context,
    ).withValues(alpha: highContrastOf(context) ? 0.12 : 0.14);
  }

  /// Surface for a festival row: none.
  ///
  /// Rows sit flush on the parent card (transparent, borderless) so the card
  /// never reads as boxes-inside-a-box; separation comes from a 1px inset
  /// divider between rows and from the row's own spacing.
  ///
  /// [isSelectedDay] is the exception: the rows of the day the user is viewing
  /// (today or any browsed date) get a borderless accent wash so that group
  /// reads first. High Contrast keeps a hairline accent edge because colour
  /// alone would not carry the selection there.
  static BoxDecoration festivalRowDecoration(
    BuildContext context, {
    bool isSelectedDay = false,
  }) {
    if (!isSelectedDay) return const BoxDecoration();
    final accent = festivalAccent(context);
    final highContrast = highContrastOf(context);
    return BoxDecoration(
      color: accent.withValues(alpha: highContrast ? 0.18 : 0.08),
      borderRadius: BorderRadius.circular(AppRadius.tile),
      border: highContrast
          ? Border.all(color: accent.withValues(alpha: 0.6))
          : null,
    );
  }

  /// Surface for a festival row that owns its own container: the
  /// all-festivals list has no card behind it, so the row supplies its own
  /// fill + hairline (opaque card white in light, a faint tint in dark).
  /// High contrast steps both up.
  static BoxDecoration festivalListRowDecoration(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final highContrast = highContrastOf(context);
    final radius = BorderRadius.circular(cardRadiusCompact);
    // Light: a crisp white card with the same hairline as the featured card
    // and the sheet cards. The old 5% onSurface wash composited to a muted
    // grey on the white/#F5F5F7 page, so a plain row read as disabled next
    // to the featured one.
    if (theme.brightness != Brightness.dark) {
      return BoxDecoration(
        color: theme.cardTheme.color ?? shuklaSurface,
        borderRadius: radius,
        border: highContrast
            ? Border.all(
                color: scheme.onSurface.withValues(alpha: 0.6),
                width: 1.5,
              )
            : Border.all(color: sheetHairline(context)),
      );
    }
    return BoxDecoration(
      color: scheme.onSurface.withValues(alpha: highContrast ? 0.08 : 0.05),
      borderRadius: radius,
      border: Border.all(
        color: scheme.onSurface.withValues(alpha: highContrast ? 0.25 : 0.1),
      ),
    );
  }

  /// Ink for filled festival-accent surfaces (status pills, reset buttons):
  /// white in light, near-black on dark (gold or purple alike, mirroring the
  /// calendar's selected-day foreground). In high contrast the accent IS
  /// scheme primary, so onPrimary pairs correctly there.
  static Color onFestivalAccent(BuildContext context) {
    if (highContrastOf(context)) {
      return Theme.of(context).colorScheme.onPrimary;
    }
    if (Theme.of(context).brightness == Brightness.dark) {
      return calendarSelectedInkDark;
    }
    return Colors.white;
  }

  /// Selected-state fill for controls that sit on a surface (the floating nav
  /// pill, segmented choices): the accent as a wash, so "selected" reads as a
  /// tint instead of a block of saturated colour competing with the content.
  ///
  /// High Contrast keeps the solid accent: there the tint is the thing that
  /// would fail, so the pairing falls back to accent + [onFestivalAccent].
  static Color accentTint(BuildContext context, {double alpha = 0.18}) {
    final accent = festivalAccent(context);
    return highContrastOf(context) ? accent : accent.withValues(alpha: alpha);
  }

  /// Ink for content drawn on [accentTint]: the accent itself, because the
  /// fill is only a wash. On the solid High Contrast fill it pairs like any
  /// other filled accent surface.
  static Color onAccentTint(BuildContext context) {
    return highContrastOf(context)
        ? onFestivalAccent(context)
        : festivalAccent(context);
  }

  /// Weekend column striping tint.
  static Color calendarWeekendStripe(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (!isDark) return shuklaTile;
    if (isPureDarkTheme(context)) {
      return calendarDotDark.withValues(alpha: 0.05);
    }
    return scheme.secondary.withValues(alpha: 0.08);
  }

  // ---------------------------------------------------------------------------
  // Hero palette.
  //
  // Two flavours, deliberately split:
  //  * [homeHero*] - the home-screen paksha card keeps its original warm peach
  //    treatment in light. It is the one intentionally warm surface left in
  //    the crisp Shukla theme.
  //  * [hero*] - the sheet/detail surfaces. Light is crisp white with charcoal
  //    ink, so sheet headers, tiles and chips match the rest of the page.
  //
  // Both resolve dark themes through the same code paths (Krishna purple /
  // PureDark flat), so only the light branch differs.
  // ---------------------------------------------------------------------------
  static const Color heroHomeShukla1 = Color(0xFFFFF3E0); // orange.shade50
  static const Color heroHomeShukla2 = Color(0xFFFFE0B2); // orange.shade100
  static const Color heroHomeInkShukla = Color(0xFF4E342E); // brown.shade800
  static const Color heroHomeAccentShukla = Color(0xFFBF360C); // burnt orange

  // Shukla hero is a crisp white card on the cool-neutral page: charcoal ink
  // and the vermilion accent are the only colour, so the hero no longer reads
  // as another cream-on-cream layer. Krishna and PureDark keep their gradients.
  static const Color heroShukla1 = shuklaSurface;
  static const Color heroShukla2 = shuklaSurface;
  static const Color heroKrishna1 = Color(0xFF2D1B4E); // muted dark plum
  static const Color heroKrishna2 = Color(0xFF1F123E); // deeper plum
  static const Color heroDark1 = Color(0xFF1E1E1E);
  static const Color heroDark2 = Color(0xFF050505);
  static const Color heroInk = Colors.white;
  static const Color heroInkShukla = shuklaInk;
  static const Color heroAccentShukla = shuklaAccent;
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

  /// Main copy color on the hero: deep charcoal on the white Shukla card,
  /// white on the dark Krishna / PureDark cards.
  static Color heroForeground(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (!isDark) return heroInkShukla;
    return heroInk;
  }

  /// Accent color on the hero (italic title span, dot, chip highlight,
  /// number badge): vermilion on the crisp white Shukla card, moon-fill
  /// neon/gold on the dark cards. Kept separate from [heroMoonFill] so the
  /// calendar's selected-day bars can stay light-on-saturated.
  static Color heroAccent(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (!isDark) return heroAccentShukla;
    return heroMoonFill(context);
  }

  static Color heroGlow(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // No ambient wash in light: a tinted radial is exactly the dusty layer
    // the crisp palette removes. It also makes the calendar's selected-tile
    // glow transparent, so light mode paints zero shadows.
    if (!isDark) return Colors.transparent;
    if (isPureDarkTheme(context)) {
      return const Color(0xFFFFA000).withValues(alpha: 0.25);
    }
    // Muted plum glow — softer than the old saturated 0.4 halo.
    return const Color(0xFF7B2CBF).withValues(alpha: 0.22);
  }

  static Color heroSubtle(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (!isDark) return heroInkShukla.withValues(alpha: 0.72);
    if (isPureDarkTheme(context)) {
      return Colors.white.withValues(alpha: 0.7);
    }
    return Colors.white.withValues(alpha: 0.82);
  }

  static Color heroChipBackground(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Light Shukla: an opaque neutral chip on the white hero. Dark cards keep
    // their translucent white glass.
    if (!isDark) return shuklaTile;
    if (isPureDarkTheme(context)) {
      return Colors.white.withValues(alpha: 0.08);
    }
    return Colors.white.withValues(alpha: 0.12);
  }

  static Color heroChipBorder(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (!isDark) return shuklaHairline;
    if (isPureDarkTheme(context)) {
      return const Color(0xFFFFB74D).withValues(alpha: 0.3);
    }
    return Colors.white.withValues(alpha: 0.16);
  }

  static Color heroMoonFill(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (!isDark) return heroMoonFillShukla;
    if (isPureDarkTheme(context)) return heroMoonFillDark;
    return heroMoonFillKrishna;
  }

  /// Hero card decoration: linear gradient plus a hairline border.
  /// Shukla is a pure-white card with the shared #E5E5EA hairline so it reads
  /// as a crisp surface on the cool-neutral page; Krishna gets a faint light
  /// hairline so the dark plum card stays defined on the dark void; PureDark
  /// keeps its flat bordered card. No boxShadow: the hero card sits flat (see
  /// [glassmorphism], which every other home card uses), and a shadow painted
  /// inside the card's clip would be sliced off at the edge anyway.
  static BoxDecoration heroDecoration(BuildContext context) {
    final gradient = heroGradient(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isPureDark = isPureDarkTheme(context);
    return BoxDecoration(
      borderRadius: BorderRadius.circular(AppRadius.card),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: gradient,
      ),
      border: isPureDark
          ? Border.all(color: Colors.white.withValues(alpha: 0.1))
          : !isDark
          ? Border.all(color: shuklaHairline)
          : Border.all(color: Colors.white.withValues(alpha: 0.08)),
    );
  }

  static BoxDecoration heroGlowBackdrop(BuildContext context) {
    // Radial highlight at top-right, mirroring `.hero` background layer.
    return BoxDecoration(
      borderRadius: BorderRadius.circular(AppRadius.card),
      gradient: RadialGradient(
        center: const Alignment(0.85, -0.4),
        radius: 1.4,
        colors: [heroGlow(context), Colors.transparent],
        stops: const [0.0, 0.55],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Home-screen hero (warm exception)
  //
  // The paksha card on the home screen keeps the pre-crisp peach gradient and
  // brown/burnt-orange ink in light. Everything else - sheet headers, sheet
  // tiles, chips, calendar glows - uses the crisp [hero*] helpers above. Keep
  // this block the only warm surface in the light theme; routing a sheet
  // through it would put brown ink back on white headers.
  // ---------------------------------------------------------------------------

  static List<Color> homeHeroGradient(BuildContext context) {
    if (Theme.of(context).brightness != Brightness.dark) {
      return const [heroHomeShukla1, heroHomeShukla2];
    }
    return heroGradient(context);
  }

  /// Copy color on the home hero: warm brown on the peach Shukla card, white
  /// on the dark Krishna / PureDark cards.
  static Color homeHeroForeground(BuildContext context) {
    if (Theme.of(context).brightness != Brightness.dark) {
      return heroHomeInkShukla;
    }
    return heroForeground(context);
  }

  /// Accent on the home hero (italic title span, dot, chip highlight): burnt
  /// orange on the peach Shukla card, moon-fill neon/gold on the dark cards.
  static Color homeHeroAccent(BuildContext context) {
    if (Theme.of(context).brightness != Brightness.dark) {
      return heroHomeAccentShukla;
    }
    return heroAccent(context);
  }

  static Color homeHeroGlow(BuildContext context) {
    if (Theme.of(context).brightness != Brightness.dark) {
      return heroHomeAccentShukla.withValues(alpha: 0.14);
    }
    return heroGlow(context);
  }

  static Color homeHeroChipBackground(BuildContext context) {
    if (Theme.of(context).brightness != Brightness.dark) {
      return Colors.white.withValues(alpha: 0.6);
    }
    return heroChipBackground(context);
  }

  static Color homeHeroChipBorder(BuildContext context) {
    if (Theme.of(context).brightness != Brightness.dark) {
      return heroHomeAccentShukla.withValues(alpha: 0.18);
    }
    return heroChipBorder(context);
  }

  /// Home hero card decoration: warm peach gradient with a burnt-orange
  /// hairline in light, the shared [heroDecoration] on dark cards.
  static BoxDecoration homeHeroDecoration(BuildContext context) {
    if (Theme.of(context).brightness == Brightness.dark) {
      return heroDecoration(context);
    }
    return BoxDecoration(
      borderRadius: BorderRadius.circular(AppRadius.card),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: homeHeroGradient(context),
      ),
      border: Border.all(color: heroHomeAccentShukla.withValues(alpha: 0.12)),
    );
  }

  /// Radial highlight at the top-right of the home hero, mirroring the old
  /// `.hero` background layer (dark cards keep [heroGlowBackdrop]).
  static BoxDecoration homeHeroGlowBackdrop(BuildContext context) {
    if (Theme.of(context).brightness == Brightness.dark) {
      return heroGlowBackdrop(context);
    }
    return BoxDecoration(
      borderRadius: BorderRadius.circular(AppRadius.card),
      gradient: RadialGradient(
        center: const Alignment(0.85, -0.4),
        radius: 1.4,
        colors: [homeHeroGlow(context), Colors.transparent],
        stops: const [0.0, 0.55],
      ),
    );
  }

  /// Sheet header block: the hero treatment, flush with the sheet — rounded
  /// top (32, matching the bottom-sheet shape), straight bottom edge into the
  /// body, no outer shadow (the modal supplies elevation). On the crisp white
  /// Shukla sheet the header is white with a single bottom hairline so it
  /// separates from the body without a tinted band. Dark themes keep the hero
  /// gradient. High contrast falls back to a solid surface.
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
        borderRadius: AppRadius.sheetTop,
        border: Border(
          bottom: BorderSide(
            color: (isDark ? Colors.white : Colors.black).withValues(
              alpha: 0.15,
            ),
          ),
        ),
      );
    }
    if (!isDark) {
      return const BoxDecoration(
        color: shuklaSurface,
        borderRadius: AppRadius.sheetTop,
        border: Border(bottom: BorderSide(color: shuklaHairline)),
      );
    }
    final isPureDark = isPureDarkTheme(context);
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: heroGradient(context),
      ),
      borderRadius: AppRadius.sheetTop,
      border: isPureDark
          ? Border.all(color: Colors.white.withValues(alpha: 0.1))
          : Border.all(color: Colors.white.withValues(alpha: 0.08)),
    );
  }

  /// Hairline used by sheet body cards and their chips. White cards on the
  /// cool-neutral Shukla scaffold are separated by an explicit cool-grey edge
  /// rather than a shadow; dark themes use a faint light hairline to lift
  /// cards off the void.
  static Color sheetHairline(
    BuildContext context, {
    bool highContrast = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (highContrast) {
      return Theme.of(
        context,
      ).colorScheme.onSurface.withValues(alpha: isDark ? 0.35 : 0.28);
    }
    if (!isDark) return shuklaHairline;
    return Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.12);
  }

  /// Sheet body card decoration (tithi detail + festival event sheets):
  /// the shared card fill, 16pt radius and the [sheetHairline] edge — all
  /// constant-cost paint (solid fill + 1px stroke), which matters because
  /// the sheets scroll in a non-lazy [SingleChildScrollView], so the cards
  /// repaint on every scroll frame. A blurred drop shadow was deliberately
  /// left out: it would add a per-card blur pass per frame for depth the
  /// hairline already provides.
  ///
  /// Set [withBorder] to false for cards that clip an edge-to-edge child
  /// (the Begins/Ends and Yoga/Karana two-cell cards): Container insets the
  /// child by the border width but clips it to the *outer* radius, so the
  /// child's fill shows through the corner notch and squares off the
  /// stroke. Those cards paint [sheetCardBorderOverlay] on top instead.
  static BoxDecoration sheetCardDecoration(
    BuildContext context, {
    bool highContrast = false,
    double radius = AppRadius.tile,
    Color? color,
    bool withBorder = true,
  }) {
    final theme = Theme.of(context);
    return BoxDecoration(
      color: color ?? theme.cardTheme.color ?? theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(radius),
      border: withBorder
          ? Border.all(
              color: sheetHairline(context, highContrast: highContrast),
            )
          : null,
    );
  }

  /// Foreground twin of [sheetCardDecoration]'s border: painted above a
  /// clipped child so the [sheetHairline] stroke rides the rounded edge
  /// instead of being covered by the child's fill at the corners.
  static BoxDecoration sheetCardBorderOverlay(
    BuildContext context, {
    bool highContrast = false,
    double radius = AppRadius.tile,
  }) {
    return BoxDecoration(
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: sheetHairline(context, highContrast: highContrast),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Shukla (light) base surface — see the crisp palette constants at the top
  // of this class. The page is a cool neutral (#F5F5F7) so opaque white cards
  // separate from it; warm cream/peach backgrounds are intentionally gone.
  // ---------------------------------------------------------------------------

  /// OPT-3: static final fields so ThemeData objects are constructed exactly
  /// once (on first class access) rather than on every widget rebuild that
  /// calls AppTheme.shuklaTheme / krishnaTheme / pureDarkTheme.
  static final ThemeData shuklaTheme = _buildShuklaTheme();
  static final ThemeData krishnaTheme = _buildKrishnaTheme();
  static final ThemeData pureDarkTheme = _buildPureDarkTheme();

  /// Shukla Paksha (Waxing Moon) - Crisp Daylight Theme
  static ThemeData _buildShuklaTheme() {
    // One accent family only: vermilion primary, darker/saffron siblings.
    const primaryColor = shuklaAccent; // #E84A1B vermilion
    const secondaryColor = shuklaAccentDeep; // #C2410C
    const tertiaryColor = Color(0xFFFF5A1F); // saffron highlight
    const backgroundColor = shuklaBackground; // cool neutral #F5F5F7
    const surfaceColor = shuklaSurface; // pure #FFFFFF
    const ink = shuklaInk; // deep charcoal #111113

    final baseTextTheme = AppTypography.uiTextTheme(
      ThemeData.light().textTheme,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      fontFamily: AppTypography.uiFamily,
      fontFamilyFallback: AppTypography.indicSansFallback,
      colorScheme: const ColorScheme.light(
        primary: primaryColor,
        secondary: secondaryColor,
        onSecondary: Colors.white,
        tertiary: tertiaryColor,
        onTertiary: Colors.white,
        onSurface: ink,
        onSurfaceVariant: shuklaInkTertiary,
        outline: shuklaHairline,
        outlineVariant: shuklaHairline,
      ),
      scaffoldBackgroundColor: backgroundColor,
      appBarTheme: AppBarTheme(
        backgroundColor: backgroundColor,
        foregroundColor: ink,
        elevation: 0,
        centerTitle: true,
        systemOverlayStyle: systemUiOverlayStyle(Brightness.light),
        titleTextStyle: _appBarTitle(ink),
      ),
      // Flat white cards: 1px cool-grey edge, no elevation, no tinted shadow.
      cardTheme: CardThemeData(
        color: surfaceColor,
        elevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
          side: const BorderSide(color: shuklaHairline),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: shuklaHairline,
        thickness: 1,
        space: 1,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: surfaceColor,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.sheetTop),
      ),
      textTheme: _appTextTheme(
        base: baseTextTheme,
        ink: ink,
        bodyInk: shuklaInkSecondary,
        secondaryInk: shuklaInkTertiary,
      ),
    );
  }

  /// App-bar title: 22 serif on a 1.3 line box, so a two-line title stays
  /// centred in the bar.
  static TextStyle _appBarTitle(Color ink) => AppTypography.display(
    fontSize: AppTypography.sizeHeadline,
    color: ink,
    height: 1.3,
  );

  /// The type map every theme shares: editorial serif headings, sans body.
  ///
  /// Only the ink changes per theme, so the roles and sizes live in one place -
  /// three hand-copied maps is how `titleLarge` ends up serif in one theme and
  /// sans in another. [base] is [AppTypography.uiTextTheme] for the matching
  /// brightness; roles the map does not override keep the Material 3 geometry,
  /// which `Theme` merges in when the app mounts.
  static TextTheme _appTextTheme({
    required TextTheme base,
    required Color ink,
    required Color bodyInk,
    required Color secondaryInk,
  }) {
    return base.copyWith(
      headlineLarge: AppTypography.display(
        fontWeight: AppTypography.bold,
        color: ink,
      ),
      headlineMedium: AppTypography.display(color: ink),
      headlineSmall: AppTypography.display(color: ink),
      titleLarge: AppTypography.display(color: ink, height: 1.3),
      bodyLarge: AppTypography.ui(
        color: bodyInk,
        fontSize: AppTypography.sizeSubtitle,
      ),
      bodyMedium: AppTypography.ui(color: secondaryInk),
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

    final baseTextTheme = AppTypography.uiTextTheme(ThemeData.dark().textTheme);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      fontFamily: AppTypography.uiFamily,
      fontFamilyFallback: AppTypography.indicSansFallback,
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
        systemOverlayStyle: systemUiOverlayStyle(Brightness.dark),
        titleTextStyle: _appBarTitle(Colors.white),
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
        shape: RoundedRectangleBorder(borderRadius: AppRadius.sheetTop),
      ),
      textTheme: _appTextTheme(
        base: baseTextTheme,
        ink: Colors.white,
        bodyInk: const Color(0xFFE0E0E0),
        secondaryInk: const Color(0xFFBDBDBD),
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

    final baseTextTheme = AppTypography.uiTextTheme(ThemeData.dark().textTheme);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      fontFamily: AppTypography.uiFamily,
      fontFamilyFallback: AppTypography.indicSansFallback,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: Colors.black,

      // Clean AppBar
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        systemOverlayStyle: systemUiOverlayStyle(Brightness.dark),
        titleTextStyle: _appBarTitle(Colors.white),
      ),

      // Standard Card Style (Not Glassmorphic by default, just clean dark cards)
      cardTheme: CardThemeData(
        color: const Color(0xFF1E1E1E),
        elevation: 0,
        shape: roundedShape,
        margin: const EdgeInsets.symmetric(
          vertical: AppSpacing.s8,
          horizontal: AppSpacing.s4,
        ),
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
        shape: RoundedRectangleBorder(borderRadius: AppRadius.sheetTop),
      ),

      textTheme: _appTextTheme(
        base: baseTextTheme,
        ink: Colors.white,
        bodyInk: const Color(0xFFEEEEEE),
        secondaryInk: const Color(0xFFCCCCCC),
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

  /// Alpha for a 1px rule - card row separators, settings panel rules.
  ///
  /// High Contrast lifts hairlines to 0.22 rather than [contrastAlpha]'s full
  /// ink: an opaque 1px line reads as a hard border, not a divider, and the
  /// rows it separates are already at full ink there.
  static double hairlineAlpha(BuildContext context, double normal) {
    return highContrastOf(context) ? 0.22 : normal;
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
        cardTheme: base.cardTheme.copyWith(
          color: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.card),
            side: BorderSide(
              color: Colors.black.withValues(alpha: 0.6),
              width: 1.5,
            ),
          ),
        ),
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
        ? festivalAccentKrishna
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

  /// Single source of truth for page card gutters: every page-level card
  /// (home hero, calendar, festivals, wisdom, countdowns, widget, and the
  /// cards on the pushed screens) insets itself by exactly this on both
  /// sides, so left and right gaps can never drift apart between widgets or
  /// screens. Pushed screens used to pick 16/24 per screen; [ScreenBody]
  /// now applies this for them.
  static const double pageGutter = AppSpacing.s12;

  /// Home-screen spelling of [pageGutter]: the home cards *are* page cards.
  static const double homeCardGutter = pageGutter;

  /// Corner radius of a page-level card. Every standalone card (home cards,
  /// eclipse cards, the featured festival card, about/privacy/settings
  /// groups) uses this; 16 was the source of the "some screens are boxier"
  /// drift.
  static const double cardRadius = AppRadius.card;

  /// Corner radius for compact tiles that live inside another surface or
  /// stack tightly in a list (festival rows, nested stat tiles).
  static const double cardRadiusCompact = AppRadius.tile;

  /// Vertical gap between two page-level cards. Cards own no margin; the
  /// parent list/column spaces them with this, so gaps cannot double up.
  static const double cardGap = AppSpacing.s16;

  /// Horizontal breathing room inside a home-card row's surface (the selected
  /// day's wash and the press highlight).
  ///
  /// The row's content stays on the card's 16dp gutter - the leading tile
  /// lines up with the card heading, as the flush-row design requires - while
  /// the wash/highlight reaches this far past it on both sides. Without it
  /// the icon tile and the trailing chevron sit exactly on the wash edge and
  /// the highlight reads as a clipped band instead of a surface.
  static const double homeCardRowInset = AppSpacing.s12;

  /// Side padding the home cards themselves take so [homeCardRowInset] rows
  /// still land their content on the 16dp heading gutter
  /// (16 - [homeCardRowInset]).
  static const double homeCardRowPadding = AppSpacing.s4;

  /// Standard page-card surface: the neutral `glassmorphism` fill/hairline at
  /// [radius], with an optional [accent] edge for a featured card.
  ///
  /// This is the one entry point cards should use, so fill, edge, radius and
  /// palette branch stay in lockstep. An accent edge is the *featured*
  /// treatment (the featured festival card, an alert card); ordinary cards
  /// keep the neutral hairline - colouring every card's edge makes the whole
  /// screen read as featured.
  static BoxDecoration cardDecoration(
    BuildContext context, {
    WidgetRef? ref,
    double radius = cardRadius,
    Color? accent,
  }) {
    return glassmorphism(
      context: context,
      ref: ref,
      borderRadius: radius,
      border: accent == null
          ? null
          : Border.all(color: accent.withValues(alpha: 0.45), width: 1.5),
    );
  }

  /// Glassmorphism decoration for cards and sheets
  static BoxDecoration glassmorphism({
    required BuildContext context,
    double opacity = 0.1,
    double blur = 20,
    double borderRadius = AppRadius.card,
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

    // Shukla: opaque white card, 1px cool-grey edge, no shadow. The backdrop
    // blur has nothing to reveal on the flat #F5F5F7 page, and a translucent
    // fill was what made the light UI read beige-on-beige.
    if (!isDark) {
      return BoxDecoration(
        color: shuklaSurface,
        borderRadius: BorderRadius.circular(borderRadius),
        border: border ?? Border.all(color: shuklaHairline),
      );
    }

    return BoxDecoration(
      color: Colors.white.withValues(alpha: opacity),
      borderRadius: BorderRadius.circular(borderRadius),
      border:
          border ??
          Border.all(
            // Dark themes keep a faint light hairline to lift glass cards off
            // the void.
            color: Colors.white.withValues(alpha: 0.14),
            width: 1.5,
          ),
      boxShadow: [
        BoxShadow(
          color: Theme.of(context).primaryColor.withValues(alpha: 0.2),
          blurRadius: blur,
        ),
      ],
    );
  }

  /// Detached overlay surface for a floating navigation capsule.
  ///
  /// [glassmorphism] is built for cards that sit *on* the page: its Pure Dark
  /// branch returns an opaque `#1E1E1E` fill. A bar painted *over* scrolling
  /// content must stay translucent in every palette, otherwise it reads as a
  /// docked footer with a background of its own. Here the edge comes from the
  /// backdrop blur the widget applies
  /// ([floatingOverlayBlurs]) instead of from an opaque fill.
  ///
  /// The fill carries a tonal lift, because "translucent" alone is not enough
  /// to read as *above* the page. In the dark palettes Pure Dark paints a
  /// black page behind `#1E1E1E` cards, so the bare `surface` at 62% came out
  /// darker than the cards it floats over: the capsule read as a hole cut in
  /// the screen. Mixing a little white into the surface first puts the film
  /// above both the page and the card fill while staying see-through. Light
  /// mode is already the brightest tone, so it takes a hint of the primary
  /// instead.
  ///
  /// High Contrast drops the film entirely: a solid surface with a strong
  /// border is legible over any content the user scrolls under it.
  static BoxDecoration floatingOverlayDecoration(
    BuildContext context, {
    double borderRadius = AppRadius.sheet,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;

    if (highContrastOf(context)) {
      return BoxDecoration(
        color: isDark ? Colors.black : Colors.white,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.7),
          width: 1.5,
        ),
      );
    }

    final fill = isDark
        ? Color.alphaBlend(Colors.white.withValues(alpha: 0.10), scheme.surface)
        : Colors.white;

    return BoxDecoration(
      // Never the opaque card fill: the content underneath must stay visible
      // through the film (blurred by the widget, not by this decoration).
      //
      // Alpha is the depth knob. At ~0.75 the backdrop was blurred but hardly
      // visible, so the capsule read as a flat frosted rectangle. Dark goes
      // lower because the lift already separates it from the page; light stops
      // at 0.68, where artwork scrolling underneath still cannot drag the
      // dark labels under a readable contrast. The light film is untinted
      // white (the old 4% primary wash muddied the capsule).
      color: fill.withValues(alpha: isDark ? 0.66 : 0.68),
      borderRadius: BorderRadius.circular(borderRadius),
      border: isDark ? null : Border.all(color: shuklaHairline),
    );
  }

  /// Whether an overlay using [floatingOverlayDecoration] should add a real
  /// backdrop blur. High Contrast gets the solid fill instead: legibility over
  /// arbitrary content beats the effect.
  static bool floatingOverlayBlurs(BuildContext context) {
    return !highContrastOf(context);
  }

  /// Shadow cast by a floating overlay onto the content beneath it.
  ///
  /// This is the cue that says "detached", which a backdrop blur alone cannot
  /// give: blur marks the film as *not* the page, a cast shadow marks it as
  /// *above* the page. It has to be painted outside the overlay's clip — a
  /// shadow in [floatingOverlayDecoration] would be sliced off by the
  /// `ClipRRect` the blur needs — so hosts wrap the clipped surface in a
  /// [DecoratedBox] carrying this.
  ///
  /// Static by design: it depends on the palette, not on what scrolls under
  /// the bar, so a frame of scrolling costs two pre-resolved blurred rects and
  /// no new save layer. High Contrast returns none: the solid fill and its
  /// strong border already separate the bar from the page, and a soft shadow
  /// would soften the edge that mode is built on.
  static List<BoxShadow> floatingOverlayShadows(BuildContext context) {
    if (highContrastOf(context)) return const [];
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return [
      // Wide, low-alpha layer: the lift.
      BoxShadow(
        color: Colors.black.withValues(alpha: isDark ? 0.30 : 0.10),
        blurRadius: 24,
        offset: const Offset(0, 8),
      ),
      // Tight contact edge, so the capsule is not hovered 8dp up with nothing
      // holding it down.
      BoxShadow(
        color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.06),
        blurRadius: 3,
        offset: const Offset(0, 1),
      ),
    ];
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

  /// System-bar styling for a light or dark app theme.
  ///
  /// Both bars are transparent and both contrast scrims are off, so the app's
  /// own background paints edge-to-edge behind the status bar and the gesture /
  /// 3-button navigation area instead of leaving a tinted strip at the bottom.
  /// Only the icon brightness follows the theme; everything else is fixed, so
  /// every caller gets the same bars.
  ///
  /// Must stay in sync with the Activity's edge-to-edge setup
  /// (`android/app/src/main/kotlin/app/tithi/pro/MainActivity.kt`): Android
  /// ignores the bar colours on 15+, the transparent bar + `ContrastEnforced`
  /// pair is what keeps the navigation area free of a background there.
  static SystemUiOverlayStyle systemUiOverlayStyle(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final iconBrightness = isDark ? Brightness.light : Brightness.dark;
    return SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: iconBrightness,
      statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
      systemStatusBarContrastEnforced: false,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
      systemNavigationBarIconBrightness: iconBrightness,
      systemNavigationBarContrastEnforced: false,
    );
  }

  /// Height of the system navigation area (gesture handle or 3-button bar).
  ///
  /// Edge-to-edge screens must let their background paint behind this strip and
  /// add it to the *scrollable's* own bottom padding, not inset the viewport
  /// with `SafeArea(bottom: true)`. Insetting the viewport makes the last row
  /// stop short of the handle, and the bare page background below it reads as
  /// a dedicated navigation-bar band even though the bar itself is transparent.
  static double navigationBarInset(BuildContext context) =>
      MediaQuery.viewPaddingOf(context).bottom;

  /// Standard background decoration for full-screen bodies.
  ///
  /// Shukla paints a flat [shuklaBackground] (#F5F5F7) surface. Every warm
  /// layer stacked on the old body (the #FFFDF7 base, then the amber gradient
  /// wash) composited the page back to cream, which read as a tinted,
  /// night-mode-ish background under the orange primary. The light branch
  /// therefore returns the scaffold color as-is; the ambient gradient is
  /// dark-theme only.
  ///
  /// Reduce Motion and High Contrast flatten to the scaffold color too, so no
  /// caller needs to branch on the setting.
  static BoxDecoration backgroundDecoration(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Light: flat body (HC resolves to pure white via the scaffold color).
    if (!isDark) {
      return BoxDecoration(color: Theme.of(context).scaffoldBackgroundColor);
    }

    final isPureDark =
        Theme.of(context).scaffoldBackgroundColor == Colors.black;

    if (isPureDark) {
      return const BoxDecoration(color: Colors.black);
    }

    if (reduceMotionOf(context) || highContrastOf(context)) {
      return BoxDecoration(color: Theme.of(context).scaffoldBackgroundColor);
    }

    return const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [splashBackgroundDark, Color(0xFF240046), splashBackgroundDark],
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

/// The three levels of de-emphasized ink.
///
/// Before this the level was picked per call site: `onSurface @ 0.6` for a
/// subtitle here, 0.65/0.7 for the same job one screen over, 0.4/0.5/0.55 for
/// captions, and 352 raw `withValues(alpha:)` against 18 `contrastAlpha`
/// calls - so High Contrast only lifted the 18. Pick by job, not by alpha:
///
/// - [secondaryInk] (0.7): information-bearing text - descriptions, subtitle
///   lines, values under a label.
/// - [hintInk] (0.55): metadata and quiet affordances - timestamps, chevrons,
///   "last updated", search-field placeholders, empty-state copy.
/// - [faintInk] (0.35): decorative glyphs only - empty-state illustration,
///   unselected marks, out-of-month calendar days. Never copy to read.
///
/// Every level folds to full ink under High Contrast ([faintInk] stops at 0.6
/// so it still reads as "not available"); go through these instead of
/// `withValues`, which ignores the accessibility setting.
extension MutedInk on BuildContext {
  Color get secondaryInk =>
      colors.onSurface.withValues(alpha: AppTheme.contrastAlpha(this, 0.7));

  Color get hintInk =>
      colors.onSurface.withValues(alpha: AppTheme.contrastAlpha(this, 0.55));

  Color get faintInk => colors.onSurface.withValues(
    alpha: AppTheme.highContrastOf(this) ? 0.6 : 0.35,
  );
}

/// Cached glassmorphism configuration for the high-contrast branch.
/// This provider only rebuilds when accessibility settings change.
class GlassmorphismConfig {
  final bool isHighContrast;

  const GlassmorphismConfig({required this.isHighContrast});
}

/// Provider for glassmorphism configuration - only rebuilds on accessibility changes
final glassmorphismConfigProvider = Provider<GlassmorphismConfig>((ref) {
  final accessibility = ref.watch(accessibilityProvider);
  return GlassmorphismConfig(isHighContrast: accessibility.highContrast);
});
