import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../l10n/app_localizations.dart';
import '../l10n/app_localizations_en.dart';
import '../models/panchang_data.dart';
import '../core/anim/press_scale.dart';
import '../core/format/date_only.dart';
import '../core/locale/app_locale.dart';
import '../core/navigation/app_routes.dart';
import '../providers/accessibility_provider.dart';
import '../providers/calendar_provider.dart';
import '../providers/locale_provider.dart';
import '../providers/location_provider.dart';
import '../providers/panchang_provider.dart';
import '../screens/location_picker_screen.dart';
import '../theme/app_theme.dart';
import '../features/hero/domain/hero_content.dart';
import '../features/hero/providers/hero_providers.dart';
import '../features/hero/widgets/artwork_window.dart';
import '../features/hero/widgets/hero_chip.dart';
import '../features/hero/widgets/hero_festival_image.dart';
import '../features/sheets/sheet_launcher.dart';
import 'moon_animation_widget.dart';

export '../features/hero/providers/hero_providers.dart'
    show bengaliDateForHeroProvider;

/// True-cold placeholder height: reserves most of the hero's space up front
/// (any remainder still glides via AnimatedSize) without leaving a cavernous
/// block while the month batch computes.
const double _trueColdSkeletonHeight = 220;

// Hero spacing, grouped so the card's rhythm can be tuned in one place. The
// eyebrow tag sits tight above its title; the moon block and the transition
// chip below it get equal, looser gaps, so the card reads as one title block
// over its content.

/// Eyebrow tag → title.
const double _heroGapHeaderTitle = 6;

/// Title → moon block.
const double _heroGapTitleMoon = 10;

/// Moon block → transition chips.
const double _heroGapMoonChips = 10;

/// Header row: status dot ↔ tag and tag ↔ location pill (symmetric, so the
/// eyebrow reads as one row whether or not the pill is present).
const double _heroHeaderRowGap = 8;

/// Header row: location pill ↔ sheet chevron.
const double _heroHeaderPillChevronGap = 2;

/// Moon row: icon tile ↔ paksha/tithi text block.
const double _heroMoonIconTextGap = 12;

/// Moon row: paksha/tithi title ↔ illumination sublabel.
const double _heroMoonTitleSubGap = 2;

/// Moon row: text column ↔ festival artwork slot.
const double _heroMoonArtworkGap = 12;

/// Transition chips: gap between adjacent chips.
const double _heroChipSpacing = 8;

/// Transition chips: gap between wrapped chip runs.
const double _heroChipRunSpacing = 6;

/// Hero card showing the selected day's paksha/tithi (redesign v3 faithful).
///
/// Gradient hero (orange / purple / flat dark per theme) placed above the
/// calendar on the home screen. Data comes from [panchangForDateProvider] —
/// the month-map entry plus the resolved daytime tithi transition, computed
/// with [resolvedCoordinatesProvider] (GPS with Delhi fallback) — with the
/// month batch and [cachedPanchangUiSync] as instant fallbacks so date taps
/// never flash. City chip comes from [cityNameProvider]. Tap opens
/// [showTithiDetailSheet] for the displayed day.
///
/// The header mirrors the calendar Settings: the day line follows
/// [primaryCalendarSystemProvider] (Bengali primary swaps in the Bengali
/// date, otherwise the Hindu-flavored line), the masa is converted with
/// [displayMasaName] so Purnimant Krishna days show the right month, and a
/// Bengali secondary system adds its own line (other secondaries are already
/// visible in the tag/day/moon rows). [bengaliDateForHeroProvider] resolves
/// lazily and the hero falls back while it loads.
///
/// When the day's primary festival ships artwork ([Visuals.image]), it
/// renders in a rounded slot on the right of the moon row; otherwise the
/// card keeps its current text-only layout.
class PakshaHeroCard extends ConsumerWidget {
  const PakshaHeroCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Normalized once so the provider-family key, month key and map lookups
    // all share one stable midnight value (no duplicate cache entries when
    // the selected date carries a time component).
    final selected = ref.watch(selectedDateProvider);
    final day = dateOnly(selected);
    final isToday = isSameDay(day, DateTime.now());

    // Live record: on today the displayed label advances intraday when a
    // tithi boundary passes (see livePanchangProvider); browsed dates and
    // the month-batch fallback below stay sunrise-pinned.
    final panchangAsync = ref.watch(livePanchangProvider(day));
    final cityAsync = ref.watch(cityNameProvider);
    final primarySystem = ref.watch(primaryCalendarSystemProvider);
    final adaptiveGridHasDay =
        (primarySystem == AppCalendarSystem.hindu ||
            primarySystem == AppCalendarSystem.bengali) &&
        cachedPanchangUiSync(day) != null;
    // The adaptive calendar has already resolved this date and its nearby
    // event-list window. Do not launch a duplicate Gregorian-month batch
    // merely to provide a fallback the shared cache can provide instantly.
    final monthAsync = adaptiveGridHasDay
        ? const AsyncValue<Map<DateTime, PanchangData>>.loading()
        : ref.watch(monthlyPanchangProvider(DateTime(day.year, day.month)));

    Widget fallback() {
      // Month data first, then last-visited stale. True-cold (fresh restart:
      // both caches empty) reserves roughly the hero's full height with a
      // gradient-tinted placeholder instead of a 76px stub — so the cards
      // below never move when the real hero resolves, and its arrival reads
      // as loading → content (fade + size glide) rather than appearing from
      // nowhere. Any residual height difference still glides via the
      // AnimatedSize below.
      final cached = monthAsync.valueOrNull?[day] ?? cachedPanchangUiSync(day);
      if (cached != null) {
        return _HeroBody(
          panchang: cached,
          cityName: cityAsync.valueOrNull,
          isToday: isToday,
          resolved: false,
        );
      }
      final highContrast = AppTheme.highContrastOf(context);
      // Neutral block with festival-row-style placeholder bars (same look as
      // the Festivals & Events loading skeleton) so a slow cold load reads
      // as loading content rather than a spinner or a black hole.
      Widget bar() => Container(
        height: 76,
        decoration: BoxDecoration(
          color: context.colors.onSurface.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(16),
        ),
      );
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: AppTheme.homeCardGutter),
        height: _trueColdSkeletonHeight,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.colors.onSurface.withValues(
            alpha: highContrast ? 0.14 : 0.08,
          ),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [bar(), const SizedBox(height: 10), bar()],
        ),
      );
    }

    // Resize behavior on date taps: the swapped day can add/drop the
    // artwork column and the chips row, so the card height changes. That
    // change glides from a pinned top edge (AnimatedSize, slow-start curve
    // so the bottom edge never kicks), while the incoming content fades in
    // (keyed switcher, no stacking so the size glide stays in charge).
    // Together this reads as one calm settle instead of a rapid expand
    // flash with sliced text at the bottom edge.
    return AnimatedSize(
      alignment: Alignment.topCenter,
      duration: AppTheme.animationDuration(
        context,
        const Duration(milliseconds: 250),
      ),
      curve: Curves.easeInOutCubic,
      child: AnimatedSwitcher(
        duration: AppTheme.animationDuration(
          context,
          const Duration(milliseconds: 180),
        ),
        transitionBuilder: (child, animation) =>
            FadeTransition(opacity: animation, child: child),
        layoutBuilder: (currentChild, _) => currentChild!,
        // No key here: the shell (_HeroBody, gradient + ripple) stays
        // mounted across date taps. Only the true-cold skeleton (a plain
        // Container) cross-fades by type. Day text animates in the content
        // switcher inside _HeroBody, so the background never flashes.
        child: panchangAsync.when(
          data: (panchang) => _HeroBody(
            panchang: panchang,
            cityName: cityAsync.valueOrNull,
            isToday: isToday,
            resolved: true,
          ),
          loading: fallback,
          error: (_, _) => fallback(),
        ),
      ),
    );
  }
}

/// Resolved hero content. Split from [PakshaHeroCard] so provider watches
/// above don't rebuild the formatting helpers, and the body itself only
/// rebuilds when its inputs change.
///
/// All formatting lives in [heroContentData] (features/hero/domain, unit
/// tested); this widget composes [_HeroHeader], [_HeroTitle], [_HeroMoonRow]
/// and [_HeroChips] inside the gradient shell + tap handler.
class _HeroBody extends ConsumerWidget {
  const _HeroBody({
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
    final heroAccent = AppTheme.heroAccent(context);
    final onHero = AppTheme.heroForeground(context);

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
    );

    // Display title: larger than the old 22/600, tighter tracking and a
    // tight line box — the editorial pairing that makes the card read
    // "designed" rather than "default Material text".
    final titleBaseStyle = TextStyle(
      fontSize: 24,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.4,
      height: 1.2,
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
            borderRadius: BorderRadius.circular(24),
            clipBehavior: Clip.antiAlias,
            child: Ink(
              decoration: highContrast
                  ? AppTheme.glassmorphism(context: context, ref: ref)
                  : AppTheme.heroDecoration(context),
              child: InkWell(
                borderRadius: BorderRadius.circular(24),
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
                  if (ref.read(accessibilityProvider).hapticFeedback) {
                    HapticFeedback.lightImpact();
                  }
                  showTithiDetailSheet(context, panchang: panchang);
                },
                child: ClipRRect(
                  // Material defaults to Clip.none, so nothing bounded the
                  // card's children to the rounded shape: the glow backdrop
                  // and any ripple could square off past the corners. Clips
                  // only the content subtree — the gradient + drop shadow
                  // live on Ink's decoration, above this, so they keep their
                  // soft outer edge.
                  borderRadius: BorderRadius.circular(24),
                  child: Stack(
                    children: [
                      if (!highContrast)
                        Positioned.fill(
                          child: Container(
                            decoration: AppTheme.heroGlowBackdrop(context),
                          ),
                        ),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            // Content-only fade: the gradient shell, ripple
                            // and glow above stay mounted while day text swaps.
                            return AnimatedSwitcher(
                              duration: AppTheme.animationDuration(
                                context,
                                const Duration(milliseconds: 180),
                              ),
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
                                    _HeroHeader(
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
                                    _HeroTitle(
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
                                    _HeroMoonRow(
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

/// Header: tag + day, full width with the location pill capped so a long
/// city name truncates instead of squeezing the tag into a RenderFlex
/// overflow. Text wraps instead of eclipsing at any width.
class _HeroHeader extends StatelessWidget {
  const _HeroHeader({
    required this.tagLabel,
    required this.cityName,
    required this.highContrast,
    required this.onHero,
    required this.maxWidth,
  });

  final String tagLabel;
  final String? cityName;
  final bool highContrast;
  final Color onHero;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    // Location pill lives in the header's top-right corner, not with the
    // chips below.
    final city = cityName;
    final locationChip = city == null
        ? null
        : HeroChip(
            icon: Icons.location_on_rounded,
            text: city,
            highContrast: highContrast,
            hint: (AppLocalizations.of(context) ?? AppLocalizationsEn())
                .setHomeLocation,
            // Direct drill from the home hero to the map picker — same
            // destination as Settings → Home Location, without the detour.
            onTap: () =>
                AppRoutes.pushSharedX(context, const LocationPickerScreen()),
          );
    // Tag: dot + Today · 14 September 2026
    return Row(
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: highContrast
                ? context.colors.primary
                : AppTheme.heroAccent(context),
            boxShadow: highContrast
                ? null
                : [
                    BoxShadow(
                      color: AppTheme.heroAccent(context),
                      blurRadius: 8,
                    ),
                  ],
          ),
        ),
        const SizedBox(width: _heroHeaderRowGap),
        Expanded(
          child: Text(
            tagLabel.toUpperCase(),
            style: TextStyle(
              // Eyebrow: quieter than the old 11/2.2/bold — tighter tracking
              // and 72% ink let the 24pt title own the hierarchy.
              fontSize: 10.5,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w600,
              color: highContrast
                  ? context.colors.onSurface.withValues(alpha: 0.7)
                  : onHero.withValues(alpha: 0.72),
            ),
          ),
        ),
        // Capped so a long city name truncates inside
        // the pill instead of squeezing the tag
        // into a RenderFlex overflow.
        if (locationChip != null) ...[
          const SizedBox(width: _heroHeaderRowGap),
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth * 0.38),
            child: locationChip,
          ),
        ],
        // Header tap affordance: the card opens the
        // detail sheet below.
        const SizedBox(width: _heroHeaderPillChevronGap),
        Icon(
          Icons.expand_more,
          size: 18,
          color: highContrast
              ? context.colors.onSurface.withValues(alpha: 0.7)
              : onHero,
        ),
      ],
    );
  }
}

/// Title = weekday + secondary calendar.
class _HeroTitle extends StatelessWidget {
  const _HeroTitle({
    required this.content,
    required this.baseStyle,
    required this.accentStyle,
  });

  final HeroContent content;
  final TextStyle baseStyle;
  final TextStyle accentStyle;

  @override
  Widget build(BuildContext context) {
    TextSpan? secondarySpan;
    switch (content.secondaryKind) {
      case HeroSecondaryKind.gregorian:
        secondarySpan = TextSpan(text: content.secondaryText, style: baseStyle);
      case HeroSecondaryKind.hindu:
        secondarySpan = TextSpan(
          text: content.secondaryText,
          style: accentStyle,
        );
      case HeroSecondaryKind.bengali:
        secondarySpan = content.secondaryText == null
            ? null
            : TextSpan(
                text: content.secondaryText,
                // Bengali typeface only with the Bengali app language;
                // transliterated text keeps the hero typeface.
                style: content.bengaliScript
                    ? GoogleFonts.notoSansBengali(textStyle: accentStyle)
                    : accentStyle,
              );
      case HeroSecondaryKind.none:
        // Deliberately no label: title is just the weekday.
        break;
    }
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: secondarySpan == null
                ? content.weekday
                : '${content.weekday}, ',
            style: baseStyle,
          ),
          // build_runner's analyzer predates null-aware elements
          // (hive_generator pins analyzer <7): keep the collection-if.
          // ignore: use_null_aware_elements
          if (secondarySpan != null) secondarySpan,
        ],
      ),
    );
  }
}

/// Moon row: icon + title/sublabel left, festival artwork right (absent
/// without a picture — text-only layout kept). The transition chips live in
/// the left column under the moon text, so the artwork is centered against
/// text + chips and the chip sits close to the sublabel instead of below the
/// artwork's full height.
///
/// Long-pressing the artwork opens the floating [ArtworkWindow]; taps keep
/// the card's own behaviour (detail sheet). When the day has several
/// pictures the deck rotates on a sideways swipe, and the gallery opens on
/// whichever picture is in front.
class _HeroMoonRow extends ConsumerWidget {
  const _HeroMoonRow({
    required this.content,
    required this.highContrast,
    required this.onHero,
    required this.maxWidth,
  });

  final HeroContent content;
  final bool highContrast;
  final Color onHero;
  final double maxWidth;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context) ?? AppLocalizationsEn();
    final chipBg = AppTheme.heroChipBackground(context);
    final chipBd = AppTheme.heroChipBorder(context);
    // Responsive artwork width: ~26% of the content width,
    // clamped so the text column always keeps room.
    final imageWidth = (maxWidth * 0.26).clamp(76.0, 110.0);
    final artworks = content.artworks;
    return Row(
      children: [
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(13),
                      color: highContrast
                          ? context.colors.primary.withValues(alpha: 0.1)
                          : chipBg,
                      border: Border.all(
                        color: highContrast
                            ? context.colors.primary.withValues(alpha: 0.2)
                            : chipBd,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: MoonAnimationWidget(
                      phase: content.illumination,
                      isWaxing: content.isShukla,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: _heroMoonIconTextGap),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          content.title,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: highContrast
                                ? context.colors.onSurface
                                : onHero,
                          ),
                        ),
                        const SizedBox(height: _heroMoonTitleSubGap),
                        Text(
                          content.subLabel,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500,
                            color: highContrast
                                ? context.colors.onSurface.withValues(
                                    alpha: 0.7,
                                  )
                                : onHero,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (content.chips.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: _heroGapMoonChips),
                  child: _HeroChips(
                    chips: content.chips,
                    highContrast: highContrast,
                  ),
                ),
            ],
          ),
        ),
        // Artwork column on the right of the moon text; absent without a
        // picture (text-only layout kept). Several festivals with art stack
        // into a deck, rotate on a sideways swipe, and open as a gallery.
        if (artworks.isNotEmpty) ...[
          const SizedBox(width: _heroMoonArtworkGap),
          _HeroArtworkStack(
            artworks: artworks,
            width: imageWidth,
            highContrast: highContrast,
            hint: l10n.enlargeArtworkHint,
            swipeHint: l10n.swipeArtworkHint,
            // The index keeps the gallery on the picture the user swiped to
            // instead of always starting at the day's headline festival.
            onLongPress: (index) {
              if (ref.read(accessibilityProvider).hapticFeedback) {
                HapticFeedback.mediumImpact();
              }
              showArtworkWindow(context, images: artworks, initialIndex: index);
            },
          ),
        ],
      ],
    );
  }
}

/// Right-side festival artwork slot.
///
/// One picture renders exactly as the single-image slot always has. Two or
/// more render as a deck: the headline festival sits in front, the next ones
/// peek diagonally above and to the right (dimmed), and a position pill marks
/// where the deck is. Swiping sideways rotates it — the front picture goes to
/// the back — so every festival on the day can be read without opening the
/// gallery. The outer footprint never changes with the count or the position,
/// so the moon text column keeps its width on every date.
///
/// A deck also turns by itself every 10 s until the user takes over, so a day
/// with several pictures reveals all of them without a gesture. The idle
/// motion stops for good on the first swipe or long press, pauses while the
/// page is scrolling, while the card is scrolled out of the viewport, while a
/// sheet or dialog covers the card and while the app is in the background,
/// and never starts under Reduce Motion or while a screen reader is running.
class _HeroArtworkStack extends StatefulWidget {
  const _HeroArtworkStack({
    required this.artworks,
    required this.width,
    required this.highContrast,
    required this.hint,
    required this.swipeHint,
    required this.onLongPress,
  });

  final List<HeroArtwork> artworks;
  final double width;
  final bool highContrast;

  /// Accessibility hint for the single-picture slot (long press only).
  final String hint;

  /// Accessibility hint for the deck (swipe to rotate + long press).
  final String swipeHint;

  /// Long press carrying the index of the picture currently in front.
  final ValueChanged<int> onLongPress;

  @override
  State<_HeroArtworkStack> createState() => _HeroArtworkStackState();
}

class _HeroArtworkStackState extends State<_HeroArtworkStack>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  /// Which artwork is in front; the others follow it (rotating deck).
  int _index = 0;

  /// Diagonal step between stacked cards, in logical pixels.
  static const double _peek = 5;

  /// Cards drawn behind the headline picture; the pill and the gallery carry
  /// the rest.
  static const int _maxBackCards = 2;

  /// Travel that still counts as a swipe when the release itself was slow.
  static const double _swipeDistance = 16;

  /// How long each picture stays in front while the deck turns by itself.
  static const Duration _autoRotateInterval = Duration(seconds: 10);

  /// Idle turns cross-dissolve slowly: nobody asked for the change, so it
  /// should settle in rather than snap.
  static const Duration _autoTurnDuration = Duration(milliseconds: 1200);

  /// A swipe the user just made is already decided; swapping quickly keeps it
  /// feeling direct.
  static const Duration _swipeTurnDuration = Duration(milliseconds: 220);

  /// Drives the idle rotation; null when it is off for any reason.
  Timer? _autoRotate;

  /// True when the last change came from the timer, so the next transition
  /// uses the slow curve instead of the swipe tempo.
  bool _autoTurn = false;

  /// Set once the user has moved the deck themselves. From then on it only
  /// moves on request, so a picture they picked never slides away underneath
  /// them — and it is the pause control WCAG 2.2.2 asks for.
  bool _userTookOver = false;

  /// A finger is on the deck (never rotate mid-drag).
  bool _dragging = false;

  /// Horizontal travel of the drag in progress.
  double _dragDx = 0;

  /// Crossfade between the deck in front and its replacement. Hand-driven
  /// rather than an AnimatedSwitcher because a switcher cannot change the
  /// duration of a transition already in flight: the outgoing deck would
  /// finish at the old speed while the new one was still fading in.
  late final AnimationController _fade;
  late final CurvedAnimation _fadeIn;
  late final Animation<double> _fadeOut;

  /// The deck fading out, captured when it was replaced; null once the fade
  /// is done.
  ({List<HeroArtwork> deck, int index})? _outgoing;

  /// False while the app is in the background: nothing to rotate for.
  bool _appActive = true;

  /// The enclosing page's scrolling flag. While it is true the deck must hold
  /// still: a 1.2s cross-dissolve started mid-fling repaints two image layers
  /// every frame right under the finger.
  ValueNotifier<bool>? _scrollNotifier;
  bool _pageScrolling = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _fade = AnimationController(
      vsync: this,
      value: 1,
      duration: _swipeTurnDuration,
    )..addStatusListener(_onFadeStatus);
    _fadeIn = CurvedAnimation(parent: _fade, curve: Curves.easeInOutCubic);
    _fadeOut = ReverseAnimation(_fadeIn);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final active = state == AppLifecycleState.resumed;
    if (active == _appActive) return;
    _appActive = active;
    // Nobody can see the card in the background, and the timer must not fire
    // there; it is re-armed on resume.
    _syncAutoRotation();
  }

  void _onFadeStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed || _outgoing == null) return;
    setState(() => _outgoing = null);
  }

  /// The pictures in display order: the one in front first.
  List<HeroArtwork> get _ordered => [
    for (var i = 0; i < widget.artworks.length; i++)
      widget.artworks[(_index + i) % widget.artworks.length],
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // MediaQuery only resolves dependencies after initState, and it can
    // change (Reduce Motion, screen reader, text scaling) at any time.
    _bindPageScroll();
    _syncAutoRotation();
  }

  /// Follows the enclosing [Scrollable]'s scrolling flag, so an idle turn
  /// never starts — and a running one stops — while the page is moving.
  void _bindPageScroll() {
    final notifier = Scrollable.maybeOf(context)?.position.isScrollingNotifier;
    if (identical(notifier, _scrollNotifier)) return;
    _scrollNotifier?.removeListener(_onPageScrollChanged);
    _scrollNotifier = notifier;
    _pageScrolling = notifier?.value ?? false;
    notifier?.addListener(_onPageScrollChanged);
  }

  void _onPageScrollChanged() {
    final scrolling = _scrollNotifier?.value ?? false;
    if (scrolling == _pageScrolling) return;
    _pageScrolling = scrolling;
    if (!scrolling && !_isOnScreen) {
      // The page settled with the card out of sight: keep the picture as it is
      // and stop the clock instead of turning for an empty viewport.
      _autoRotate?.cancel();
      _autoRotate = null;
      return;
    }
    // Stops the timer on the first drag frame and starts a fresh countdown
    // once the page settles again.
    _syncAutoRotation();
  }

  @override
  void didUpdateWidget(covariant _HeroArtworkStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A different day means a different deck: start from its headline again
    // instead of keeping a position that no longer applies.
    if (!listEquals(oldWidget.artworks, widget.artworks) ||
        _index >= widget.artworks.length) {
      _index = 0;
      _userTookOver = false;
      _autoTurn = false;
      _outgoing = null;
      // Jump any half-finished crossfade to its end: the decks it was blending
      // belong to the old day.
      _fade.value = 1;
      _autoRotate?.cancel();
      _autoRotate = null;
      _syncAutoRotation();
    }
  }

  @override
  void dispose() {
    _scrollNotifier?.removeListener(_onPageScrollChanged);
    _scrollNotifier = null;
    WidgetsBinding.instance.removeObserver(this);
    _autoRotate?.cancel();
    _fade.removeStatusListener(_onFadeStatus);
    _fadeIn.dispose();
    _fade.dispose();
    super.dispose();
  }

  /// Rotating artwork is motion the user did not ask for, so it stays off
  /// under Reduce Motion and while a screen reader is announcing the deck
  /// (a label that changes every few seconds is noise there).
  bool get _shouldAutoRotate {
    if (widget.artworks.length < 2 ||
        _userTookOver ||
        !_appActive ||
        _pageScrolling) {
      return false;
    }
    // Another screen on top mutes this route's tickers; rotating there would
    // only queue transitions that can never finish.
    if (!TickerMode.valuesOf(context).enabled) return false;
    // A sheet or dialog over the card hides it just as well, and popups do
    // not mute tickers.
    if (ModalRoute.of(context)?.isCurrent == false) return false;
    final media = MediaQuery.maybeOf(context);
    if (media == null) return false;
    return !media.disableAnimations && !media.accessibleNavigation;
  }

  void _syncAutoRotation() {
    if (!_shouldAutoRotate) {
      _autoRotate?.cancel();
      _autoRotate = null;
      return;
    }
    _autoRotate ??= Timer.periodic(_autoRotateInterval, (_) {
      if (!mounted || _dragging) return;
      // Belt and braces: the sliver keeps this card mounted far above or
      // below the viewport, and a turn there paints for nobody.
      if (!_isOnScreen) return;
      _stepBy(1);
    });
  }

  /// Whether any part of the deck overlaps the window.
  ///
  /// Only called from the idle tick and from a settled scroll, never during
  /// the first build (where the render box has no size yet), so the rect is
  /// always from a completed layout.
  bool get _isOnScreen {
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) return false;
    final window = MediaQuery.maybeSizeOf(context);
    if (window == null) return true;
    final rect = box.localToGlobal(Offset.zero) & box.size;
    return rect.overlaps(Offset.zero & window);
  }

  void _pauseAutoRotation() {
    _userTookOver = true;
    _autoRotate?.cancel();
    _autoRotate = null;
  }

  /// Rotates the deck by [delta] pictures (1 = left swipe, i.e. next).
  ///
  /// [userInitiated] marks a swipe or a screen-reader action: the deck stops
  /// turning by itself from then on.
  void _stepBy(int delta, {bool userInitiated = false}) {
    final count = widget.artworks.length;
    if (count < 2) return;
    if (userInitiated) _pauseAutoRotation();
    setState(() {
      // The deck on screen becomes the layer fading out, then it advances.
      _outgoing = (deck: _ordered, index: _index);
      _autoTurn = !userInitiated;
      _index = (_index + delta) % count;
    });
    _fade.duration = AppTheme.animationDuration(
      context,
      _autoTurn ? _autoTurnDuration : _swipeTurnDuration,
    );
    _fade.forward(from: 0);
  }

  void _onLongPress() {
    _pauseAutoRotation();
    widget.onLongPress(_index);
  }

  void _onDragEnd(DragEndDetails details) {
    if (widget.artworks.length < 2) return;
    // Distance decides a slow drag; velocity rescues a quick flick.
    final travelled = _dragDx.abs() >= _swipeDistance
        ? _dragDx
        : -(details.primaryVelocity ?? 0);
    _dragDx = 0;
    if (travelled.abs() < _swipeDistance) return;
    _stepBy(travelled < 0 ? 1 : -1, userInitiated: true);
  }

  @override
  Widget build(BuildContext context) {
    final artworks = widget.artworks;
    final count = artworks.length;
    // Defensive: the parent hides the slot on a day without artwork, but an
    // empty list must never reach `ordered.first` below.
    if (count == 0) return const SizedBox.shrink();
    if (count == 1) {
      final only = artworks.first;
      return HeroFestivalImage(
        source: only.source,
        semanticsLabel: only.label,
        highContrast: widget.highContrast,
        width: widget.width,
        hint: widget.hint,
        onLongPress: () => widget.onLongPress(0),
      );
    }

    // Rotated view: the front picture followed by the ones behind it.
    final ordered = _ordered;
    final backCount = count - 1 < _maxBackCards ? count - 1 : _maxBackCards;
    final inset = _peek * backCount;
    final radius = BorderRadius.circular(24);
    // Decode the thumbnail at the size it is drawn instead of the full asset:
    // the same cache entry then serves the front card, the peeking cards and
    // the single-picture slot, at a fraction of the memory.
    final pixelRatio = MediaQuery.maybeDevicePixelRatioOf(context) ?? 1.0;
    final cacheWidth = (widget.width * pixelRatio).round();

    // One node for the whole deck: the labels list every festival, so a
    // screen reader hears all of them instead of just the top picture.
    // Switch Access / TalkBack rotate it through the scroll actions.
    return Semantics(
      container: true,
      image: true,
      label: ordered.map((artwork) => artwork.label).join(', '),
      hint: widget.swipeHint,
      onLongPress: _onLongPress,
      onScrollLeft: () => _stepBy(1, userInitiated: true),
      onScrollRight: () => _stepBy(-1, userInitiated: true),
      excludeSemantics: true,
      child: GestureDetector(
        // Only gestures this deck actually consumes stop the idle rotation, so
        // a scroll that merely starts on the picture keeps it turning.
        behavior: HitTestBehavior.opaque,
        onLongPress: _onLongPress,
        onHorizontalDragStart: (_) {
          // Only a finished swipe counts as taking over: a drag that stops
          // short never turns the deck, so it must not silence it either.
          _dragging = true;
          _dragDx = 0;
        },
        onHorizontalDragUpdate: (details) => _dragDx += details.delta.dx,
        onHorizontalDragCancel: () => _dragging = false,
        onHorizontalDragEnd: (details) {
          _dragging = false;
          _onDragEnd(details);
        },
        child: SizedBox(
          width: widget.width,
          height: widget.width * 1.2,
          child: Stack(
            children: [
              if (_outgoing != null)
                FadeTransition(
                  // The replaced deck holds still while the new one fades
                  // over it; a page slide would not read in this slot.
                  opacity: _fadeOut,
                  child: _deck(
                    _outgoing!.deck,
                    index: _outgoing!.index,
                    backCount: backCount,
                    inset: inset,
                    radius: radius,
                    cacheWidth: cacheWidth,
                  ),
                ),
              FadeTransition(
                opacity: _fadeIn,
                child: ScaleTransition(
                  scale: Tween<double>(
                    // An idle turn settles up from slightly smaller; a swipe
                    // brings the new picture up from further back. Neither
                    // exceeds the slot, so the Stack never crops the rounded
                    // corners mid-fade.
                    begin: _autoTurn ? 0.98 : 0.92,
                    end: 1,
                  ).animate(_fadeIn),
                  child: _deck(
                    ordered,
                    index: _index,
                    backCount: backCount,
                    inset: inset,
                    radius: radius,
                    cacheWidth: cacheWidth,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// One whole deck — back cards, headline picture and position pill — for
  /// [deck], whose first entry is the picture in front.
  Widget _deck(
    List<HeroArtwork> deck, {
    required int index,
    required int backCount,
    required double inset,
    required BorderRadius radius,
    required int cacheWidth,
  }) {
    return Stack(
      children: [
        // Farthest card first so nearer cards paint over it.
        for (var i = backCount; i >= 1; i--)
          Positioned(
            left: _peek * i,
            top: inset - _peek * i,
            right: inset - _peek * i,
            bottom: _peek * i,
            child: _HeroArtworkCard(
              artwork: deck[i],
              radius: radius,
              highContrast: widget.highContrast,
              cacheWidth: cacheWidth,
              dim: i == 1 ? 0.32 : 0.5,
            ),
          ),
        // Headline picture: bottom-left of the deck, inset by the room the
        // back cards need.
        Positioned(
          left: 0,
          top: inset,
          right: inset,
          bottom: 0,
          child: Stack(
            fit: StackFit.expand,
            children: [
              _HeroArtworkCard(
                artwork: deck.first,
                radius: radius,
                highContrast: widget.highContrast,
                cacheWidth: cacheWidth,
              ),
              Positioned(
                right: 6,
                bottom: 6,
                child: _HeroArtworkPositionBadge(
                  index: index,
                  count: widget.artworks.length,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// One picture in the hero's artwork slot: cover-cropped, rounded, scrimmed
/// and hairline-edged like the single-image slot. [dim] darkens the cards
/// behind the headline so the deck recedes instead of competing.
class _HeroArtworkCard extends StatelessWidget {
  const _HeroArtworkCard({
    required this.artwork,
    required this.radius,
    required this.highContrast,
    required this.cacheWidth,
    this.dim = 0,
  });

  final HeroArtwork artwork;
  final BorderRadius radius;
  final bool highContrast;

  /// Decode width in device pixels: the picture is a ~76-110 pt thumbnail, so
  /// decoding the full 600x800 asset would waste memory for every card.
  final int cacheWidth;

  final double dim;

  @override
  Widget build(BuildContext context) {
    final placeholder = ColoredBox(
      color: highContrast
          ? context.colors.primary.withValues(alpha: 0.08)
          : Colors.white.withValues(alpha: 0.12),
    );
    final source = artwork.source;
    final Widget image = source.startsWith('http')
        ? Image.network(
            source,
            cacheWidth: cacheWidth,
            fit: BoxFit.cover,
            loadingBuilder: (context, child, progress) =>
                progress == null ? child : placeholder,
            errorBuilder: (context, _, _) => placeholder,
          )
        : Image.asset(
            source,
            cacheWidth: cacheWidth,
            fit: BoxFit.cover,
            errorBuilder: (context, _, _) => placeholder,
          );

    return ClipRRect(
      borderRadius: radius,
      child: Stack(
        fit: StackFit.expand,
        children: [
          image,
          // Bottom scrim: settles the picture into the card.
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: radius,
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: const [0.55, 1],
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: highContrast ? 0.18 : 0.3),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (dim > 0)
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: radius,
                    color: Colors.black.withValues(alpha: dim),
                  ),
                ),
              ),
            ),
          // Hairline inner light edge, as on the single-image slot.
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: radius,
                  border: Border.all(
                    color: highContrast
                        ? context.colors.primary.withValues(alpha: 0.25)
                        : Colors.white.withValues(alpha: 0.22),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Position pill on the headline picture ("1/2" = first of two pictures).
/// Compact by design: the slot is 76-110 pt wide, so the spaces the gallery
/// counter uses ("1 / 2") would crowd the artwork.
class _HeroArtworkPositionBadge extends StatelessWidget {
  const _HeroArtworkPositionBadge({required this.index, required this.count});

  final int index;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.24)),
      ),
      child: Text(
        '${index + 1}/$count',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// Transition chips row. Chips opt into multi-line labels ([HeroChip.wrap])
/// because they sit in the moon row's text column, sharing width with the
/// festival artwork.
class _HeroChips extends StatelessWidget {
  const _HeroChips({required this.chips, required this.highContrast});

  final List<HeroChipData> chips;
  final bool highContrast;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: _heroChipSpacing,
      runSpacing: _heroChipRunSpacing,
      children: [
        for (final chip in chips)
          HeroChip(
            icon: chip.icon,
            text: chip.text,
            highlight: chip.highlight,
            suffix: chip.suffix,
            inlineIcon: chip.inlineIcon,
            wrap: true,
            fontWeight: FontWeight.w800,
            fontSize: 13,
            highContrast: highContrast,
          ),
      ],
    );
  }
}

/// Procedural film grain: a deterministic sprinkle of 1pt specks over the
/// hero gradient, which breaks up the banding a 150-200pt gradient shows on
/// 8-bit panels.
///
/// The specks are baked once into a small tiling texture and drawn as a single
/// shaded rect. Spraying them directly — one `drawRect` per speck — recorded
/// ~5,000 ops for a phone-sized card, and that display list is replayed on
/// every frame the card is composited (Impeller re-renders the layer tree each
/// frame). That made every animation in the app pay for the hero while it was
/// on screen: sheets, the drawer and the page itself all felt heavy. One quad
/// costs the same whatever the card size.
class HeroGrainPainter extends CustomPainter {
  const HeroGrainPainter(this.color);

  /// Speck spacing, matching the old "1pt speck every 3pt".
  static const double _cell = 3;

  /// 40 cells square. Short enough to stay cheap, long enough that the repeat
  /// does not read as a pattern once it is stretched over a card.
  static const double _tileExtent = 120;

  /// Built on first paint, then shared by every hero card. The tint is baked
  /// in (a shader ignores [Paint.color]) and the cache is rebuilt only when
  /// the theme hands over a different colour, which is rare.
  static ({Color color, Shader shader})? _cached;

  final Color color;

  ({Color color, Shader shader})? _grain() {
    final cached = _cached;
    if (cached != null && cached.color == color) return cached;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final ink = Paint()..color = color;
    // xorshift32: deterministic and allocation-free, so the grain is stable
    // across builds (no shimmering) and identical on every card.
    var seed = 0x9E3779B1;
    const extent = _tileExtent;
    for (double y = 0; y < extent; y += _cell) {
      for (double x = 0; x < extent; x += _cell) {
        seed ^= (seed << 13) & 0xFFFFFFFF;
        seed ^= seed >> 17;
        seed ^= (seed << 5) & 0xFFFFFFFF;
        if ((seed & 0x7) < 2) continue;
        // Jittered inside its cell; wrapped so specks at the right/bottom
        // edge stay inside the tile and the repeat has no seam.
        canvas.drawRect(
          Rect.fromLTWH(
            (x + (seed & 0x3)) % extent,
            (y + ((seed >> 2) & 0x3)) % extent,
            1,
            1,
          ),
          ink,
        );
      }
    }
    final ui.Image image;
    try {
      image = recorder.endRecording().toImageSync(
        extent.round(),
        extent.round(),
      );
    } catch (_) {
      // Engine cannot rasterize pictures synchronously (headless tooling):
      // the grain is decorative, so leave it off rather than paint per speck.
      return null;
    }
    final grain = (
      color: color,
      shader: ImageShader(
        image,
        TileMode.repeated,
        TileMode.repeated,
        Matrix4.identity().storage,
        filterQuality: FilterQuality.none,
      ),
    );
    _cached = grain;
    return grain;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final grain = _grain();
    if (grain == null) return;
    canvas.drawRect(Offset.zero & size, Paint()..shader = grain.shader);
  }

  @override
  bool shouldRepaint(HeroGrainPainter oldDelegate) =>
      oldDelegate.color != color;
}
