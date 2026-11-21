import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/anim/press_scale.dart';
import '../../../core/feedback/app_haptics.dart';
import '../../../core/locale/app_locale.dart';
import '../../../l10n/app_localizations.dart';
import '../../../l10n/app_localizations_en.dart';
import '../../../models/panchang_data.dart';
import '../../../providers/calendar_provider.dart';
import '../../../providers/locale_provider.dart';
import '../../../theme/app_metrics.dart';
import '../../../theme/app_motion.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/app_typography.dart';
import '../../sheets/sheet_launcher.dart';
import '../domain/hero_content.dart';
import '../providers/hero_providers.dart';
import 'hero_card_sections.dart';
import 'hero_grain_painter.dart';

/// Eyebrow tag → title.
const double _heroGapHeaderTitle = 6;

/// Title → moon block.
const double _heroGapTitleMoon = 10;

/// Resolved hero content. Split from `PakshaHeroCard` so provider watches
/// above don't rebuild the formatting helpers, and the body itself only
/// rebuilds when its inputs change.
///
/// All formatting lives in [heroContentData] (features/hero/domain, unit
/// tested); this widget composes [HeroHeader], [HeroTitle], [HeroMoonRow]
/// inside the gradient shell + tap handler.
class HeroBody extends ConsumerWidget {
  const HeroBody({
    super.key,
    required this.panchang,
    required this.cityName,
    required this.isToday,
    required this.resolved,
  });

  final PanchangData panchang;
  final String? cityName;
  final bool isToday;

  /// False while showing the cached fallback ahead of the fully resolved
  /// day (daytime tithi transition). Part of the content fade key so the
  /// second arrival animates instead of snapping text.
  final bool resolved;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context) ?? AppLocalizationsEn();

    // High-contrast falls back to solid theme surfaces so white-on-gradient
    // never becomes illegible.
    final highContrast =
        AppTheme.highContrastOf(context) ||
        ref.watch(glassmorphismConfigProvider).isHighContrast;
    // Home hero keeps its warm peach palette in light (the crisp sheet
    // surfaces use the plain heroAccent/heroForeground helpers instead).
    final heroAccent = AppTheme.homeHeroAccent(context);
    final onHero = AppTheme.homeHeroForeground(context);

    final content = heroContentData(
      panchang: panchang,
      l10n: l10n,
      primarySystem: ref.watch(primaryCalendarSystemProvider),
      secondarySystem: ref.watch(secondaryCalendarSystemProvider),
      monthSystem: ref.watch(hinduMonthSystemProvider),
      bengali: ref.watch(bengaliDateForHeroProvider(panchang.date)).valueOrNull,
      useBengaliScript:
          resolveAppLocale(ref.watch(localeProvider)).languageCode == 'bn',
      isToday: isToday,
      region: ref.watch(festivalRegionProvider),
    );

    // Display title: larger than the old 22/600, tighter tracking and a
    // tight line box — the editorial pairing that makes the card read
    // "designed" rather than "default Material text".
    final titleBaseStyle = AppTypography.display(
      fontSize: AppTypography.sizeDisplay,
      fontWeight: AppTypography.bold,
      letterSpacing: -0.4,
      height: 1.3,
      color: highContrast ? context.colors.onSurface : onHero,
    );
    final titleAccentStyle = titleBaseStyle.copyWith(
      fontStyle: FontStyle.italic,
      color: highContrast ? context.colors.primary : heroAccent,
    );

    // Tappable card done properly: button semantics for screen readers,
    // trailing chevron as the visual cue, and a Material ripple clipped to
    // the card shape (Ink paints the gradient so the splash shows above it).
    //
    // A transparent Material never clipped its children, which is how the
    // gradient used to paint square past the rounded corners. The Material
    // now clips (antiAlias) so the gradient, border, glow backdrop and
    // ripple all stay within the 24px radius. No drop shadow: the card sits
    // flat like the other home cards, and a shadow painted inside this clip
    // would be sliced off at the edge anyway.
    return Semantics(
      button: true,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: AppTheme.homeCardGutter),
        child: PressScale(
          // The card buzzes inside onTap; scale only, no second buzz.
          haptic: false,
          // Softer than the app's 0.94 button default: a card this large
          // visibly shrinks at 0.94, where 0.985 just reads as "gives".
          pressedScale: 0.985,
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.card),
            clipBehavior: Clip.antiAlias,
            child: Ink(
              decoration: highContrast
                  ? AppTheme.glassmorphism(context: context, ref: ref)
                  : AppTheme.homeHeroDecoration(context),
              child: InkWell(
                borderRadius: BorderRadius.circular(AppRadius.card),
                // Ink defaults to ThemeData.splashColor (onSurface @12%),
                // which lands as a grey wash on the peach hero. Use a white
                // veil instead — the light end of the card's own palette, so
                // the press reads as the surface lifting. (The card colour
                // itself can't be used: it's a gradient, so a splash in it
                // would be invisible.) Stronger on the light peach card,
                // restrained on plum so it doesn't bloom.
                splashColor: Colors.white.withValues(
                  alpha: highContrast
                      ? 0.08
                      : context.isDark
                      ? 0.14
                      : 0.26,
                ),
                highlightColor: Colors.white.withValues(
                  alpha: highContrast
                      ? 0.04
                      : context.isDark
                      ? 0.08
                      : 0.12,
                ),
                onTap: () {
                  AppHaptics.tap(ref);
                  showTithiDetailSheet(context, panchang: panchang);
                },
                child: ClipRRect(
                  // Material defaults to Clip.none, so nothing bounded the
                  // card's children to the rounded shape: the glow backdrop
                  // and any ripple could square off past the corners. Clips
                  // only the content subtree — the gradient + drop shadow
                  // live on Ink's decoration, above this, so they keep their
                  // soft outer edge.
                  borderRadius: BorderRadius.circular(AppRadius.card),
                  child: Stack(
                    children: [
                      // Ambient glow: burnt-orange wash on the peach Shukla
                      // card, plum/gold halo on dark. The calendar's selected
                      // tile glow stays off in light via [AppTheme.heroGlow].
                      if (!highContrast)
                        Positioned.fill(
                          child: Container(
                            decoration: AppTheme.homeHeroGlowBackdrop(context),
                          ),
                        ),
                      Padding(
                        padding: const EdgeInsets.all(AppSpacing.s16),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            // Content-only fade: the gradient shell, ripple
                            // and glow above stay mounted while day text swaps.
                            return AnimatedSwitcher(
                              duration: AppMotion.of(context, AppMotion.subtle),
                              transitionBuilder: (child, animation) =>
                                  FadeTransition(
                                    opacity: animation,
                                    child: child,
                                  ),
                              layoutBuilder: (currentChild, _) => currentChild!,
                              child: KeyedSubtree(
                                key: ValueKey((panchang.date, resolved)),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Header: tag + day, full width. Text wraps
                                    // instead of eclipsing at any width.
                                    HeroHeader(
                                      tagLabel: content.tagLabel,
                                      cityName: cityName,
                                      highContrast: highContrast,
                                      onHero: onHero,
                                      maxWidth: constraints.maxWidth,
                                    ),
                                    const SizedBox(height: _heroGapHeaderTitle),
                                    // Title = weekday + secondary calendar
                                    // (spec). Weekday stands alone while
                                    // Bengali resolves.
                                    HeroTitle(
                                      content: content,
                                      baseStyle: titleBaseStyle,
                                      accentStyle: titleAccentStyle,
                                    ),
                                    const SizedBox(height: _heroGapTitleMoon),
                                    // Two columns below the header: moon text
                                    // (plus the transition chip, when present)
                                    // left, artwork right. Keeping the chip in
                                    // the text column lets the artwork center
                                    // against the whole text block instead of
                                    // sitting above a full-width chip row.
                                    HeroMoonRow(
                                      content: content,
                                      highContrast: highContrast,
                                      onHero: onHero,
                                      maxWidth: constraints.maxWidth,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      // Surface finish, painted over the content: film grain
                      // breaks up the large gradient (banding on 8-bit
                      // panels) and the specular hairline catches light along
                      // the top edge. Decorative only — IgnorePointer keeps
                      // both out of the gesture arena.
                      if (!highContrast) ...[
                        Positioned.fill(
                          child: IgnorePointer(
                            child: RepaintBoundary(
                              child: CustomPaint(
                                painter: HeroGrainPainter(
                                  onHero.withValues(alpha: 0.035),
                                ),
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          top: 0,
                          left: 22,
                          right: 22,
                          child: IgnorePointer(
                            child: Container(
                              height: 1,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.transparent,
                                    Colors.white.withValues(alpha: 0.55),
                                    Colors.transparent,
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
