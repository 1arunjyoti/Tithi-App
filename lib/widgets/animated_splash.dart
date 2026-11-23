import 'package:material_ui/material_ui.dart';

import '../l10n/app_localizations.dart';
import '../theme/app_metrics.dart';
import '../theme/app_motion.dart';
import '../theme/app_theme.dart';
import '../theme/app_typography.dart';

/// How long the caller should keep the branded splash up so its motion is
/// actually perceivable. Returns zero under Reduce Motion (the widget itself
/// also skips its loops) or when [minimum] has already elapsed.
///
/// Keeping this as a pure function lets the startup gate be tested without
/// booting Riverpod, Hive or the location service.
Duration splashHoldDuration({
  required DateTime startedAt,
  required DateTime now,
  required Duration minimum,
  required bool reduceMotion,
}) {
  if (reduceMotion) return Duration.zero;
  final remaining = minimum - now.difference(startedAt);
  return remaining.isNegative ? Duration.zero : remaining;
}

/// Size of the mark in the one and only logo moment. The native splash is
/// deliberately image-free, so there is no platform logo to match here: the
/// mark can be large enough to read as the app's hero on first launch.
const double kSplashLogoSize = 168;

/// Dark background the native splash can actually paint on MIUI. Saturated
/// brand purple is force-inverted into magenta there, so the platform window
/// is a neutral #121212. Flutter must match it or the cold start reads as a
/// blank screen followed by a different screen; the brand colour stays in the
/// rest of the app.
const _kNativeSplashDark = Color(0xFF121212);

/// The branded startup screen.
///
/// This is the *only* place the logo appears during startup: the platform
/// splash is colour-only (see `flutter_native_splash.yaml`), so there is no
/// static native mandala followed by a second, animated one. The mark has a
/// fade/scale entrance, then rotates slowly, breathes and sits in a pulsing
/// halo while the name and tagline fade in underneath.
///
/// Every loop is gated on Reduce Motion (app setting *or* OS flag): the
/// repeating controllers are never started, and the entrance snaps to its end
/// state. [AppTheme.reduceMotionOf] reads `MediaQuery.disableAnimations`,
/// which `TithiApp.builder` already folds the user's setting into.
///
/// No gradients here, deliberately. The native splash is a flat colour, so a
/// flat Flutter background makes the hand-off predictable. (An earlier theory
/// blamed an Impeller gradient bug for the dark-mode magenta startup screen;
/// the real cause was MIUI force-inverting a saturated colour in the native
/// background bitmap. Keep native splash resources neutral.)
class AnimatedSplash extends StatefulWidget {
  const AnimatedSplash({super.key});

  @override
  State<AnimatedSplash> createState() => _AnimatedSplashState();
}

class _AnimatedSplashState extends State<AnimatedSplash>
    with TickerProviderStateMixin {
  late final AnimationController _entrance;
  late final AnimationController _spin;
  late final AnimationController _breathe;
  late final AnimationController _halo;

  late final Animation<double> _fade;
  late final Animation<double> _entranceScale;
  late final Animation<double> _breatheScale;
  late final Animation<double> _haloOpacity;

  bool _started = false;

  @override
  void dispose() {
    _entrance.dispose();
    _spin.dispose();
    _breathe.dispose();
    _halo.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;

    // Inherited widgets (MediaQuery) are only safe here, not in initState.
    final reduceMotion = AppTheme.reduceMotionOf(context);
    _entrance = AnimationController(
      vsync: this,
      duration: AppMotion.of(context, AppMotion.entrance),
    );
    // Ambient loops, not UI transitions: long enough to feel meditative, and
    // deliberately outside the AppMotion vocabulary.
    _spin = AnimationController(vsync: this, duration: const Duration(seconds: 16));
    _breathe = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );
    _halo = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    _fade = CurvedAnimation(parent: _entrance, curve: Curves.easeOut);
    _entranceScale = Tween<double>(begin: 0.86, end: 1).animate(
      CurvedAnimation(parent: _entrance, curve: AppMotion.standardCurve),
    );
    _breatheScale = Tween<double>(begin: 1, end: 1.03).animate(
      CurvedAnimation(parent: _breathe, curve: Curves.easeInOut),
    );
    _haloOpacity = Tween<double>(begin: 0.12, end: 0.32).animate(
      CurvedAnimation(parent: _halo, curve: Curves.easeInOut),
    );

    if (reduceMotion) {
      _entrance.value = 1;
      return;
    }
    _entrance.forward();
    _spin.repeat();
    _breathe.repeat(reverse: true);
    _halo.repeat(reverse: true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final reduceMotion = AppTheme.reduceMotionOf(context);
    final primary = context.colors.primary;
    // Match what the platform splash painted: it follows *system* brightness,
    // not the app's theme override (which native cannot read). Dark is the
    // MIUI-safe neutral, not the brand colour, so the hand-off is invisible.
    final background = MediaQuery.platformBrightnessOf(context) == Brightness.dark
        ? _kNativeSplashDark
        : AppTheme.splashBackgroundLight;

    final mandala = Image.asset(
      'assets/icons/logo_transparent.png',
      width: kSplashLogoSize,
      height: kSplashLogoSize,
      fit: BoxFit.contain,
      excludeFromSemantics: true,
    );

    return Scaffold(
      body: Container(
        color: background,
        alignment: Alignment.center,
        child: FadeTransition(
          key: const ValueKey('splash-entrance'),
          opacity: _fade,
          child: ScaleTransition(
            scale: _entranceScale,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    FadeTransition(
                      opacity: _haloOpacity,
                      child: Container(
                        width: kSplashLogoSize * 1.45,
                        height: kSplashLogoSize * 1.45,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          // Flat disc, not a RadialGradient: see the class doc
                          // on Adreno/Impeller. The pulse carries the motion.
                          color: primary.withValues(alpha: 0.5),
                        ),
                      ),
                    ),
                    ScaleTransition(
                      key: const ValueKey('splash-breathe'),
                      scale: _breatheScale,
                      child: reduceMotion
                          ? mandala
                          : RotationTransition(
                              key: const ValueKey('splash-rotation'),
                              turns: _spin,
                              child: mandala,
                            ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.s24),
                Text(
                  l10n?.tithi ?? 'Tithi',
                  style: AppTypography.display(
                    fontSize: AppTypography.sizeHero,
                    color: context.colors.onSurface,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: AppSpacing.s6),
                Text(
                  l10n?.aboutTagline ?? 'Vedic calendar for modern life',
                  style: context.textTheme.bodyMedium?.copyWith(
                    color: context.secondaryInk,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
