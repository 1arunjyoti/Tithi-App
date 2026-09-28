import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../l10n/app_localizations.dart';
import '../l10n/app_localizations_en.dart';
import '../models/panchang_data.dart';
import '../core/format/date_only.dart';
import '../core/locale/app_locale.dart';
import '../providers/accessibility_provider.dart';
import '../providers/calendar_provider.dart';
import '../providers/locale_provider.dart';
import '../providers/location_provider.dart';
import '../providers/panchang_provider.dart';
import '../theme/app_theme.dart';
import '../features/hero/domain/hero_content.dart';
import '../features/hero/providers/hero_providers.dart';
import '../features/hero/widgets/hero_chip.dart';
import '../features/hero/widgets/hero_festival_image.dart';
import 'moon_animation_widget.dart';
import 'tithi_detail_sheet.dart';

export '../features/hero/providers/hero_providers.dart'
    show bengaliDateForHeroProvider;

/// True-cold placeholder height: reserves most of the hero's space up front
/// (any remainder still glides via AnimatedSize) without leaving a cavernous
/// block while the month batch computes.
const double _trueColdSkeletonHeight = 220;



/// Hero card showing the selected day's paksha/tithi (redesign v3 faithful).
///
/// Gradient hero (orange / purple / flat dark per theme) placed above the
/// calendar on the home screen. Data comes from [panchangForDateProvider] —
/// the month-map entry plus the resolved daytime tithi transition, computed
/// with [resolvedCoordinatesProvider] (GPS with Delhi fallback) — with the
/// month batch and [cachedPanchangUiSync] as instant fallbacks so date taps
/// never flash. City chip comes from [cityNameProvider]. Tap opens
/// [TithiDetailSheet] for the displayed day.
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

    final titleBaseStyle = TextStyle(
      fontSize: 22,
      fontWeight: FontWeight.w600,
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
    // Two-layer shape discipline, because a transparent Material never clipped
    // its children: the outer Container carries the drop shadow and stays
    // unclipped so the glow can bleed past the corners, while the Material
    // below clips (antiAlias) so the gradient, border, glow backdrop and
    // ripple can never square off outside the 24px radius.
    return Semantics(
      button: true,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: AppTheme.homeCardGutter),
        decoration: highContrast ? null : AppTheme.heroOuterGlow(context),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(24),
          clipBehavior: Clip.antiAlias,
          child: Ink(
            decoration: highContrast
                ? AppTheme.glassmorphism(context: context, ref: ref)
                : AppTheme.heroDecoration(context, includeShadow: false),
            child: InkWell(
              borderRadius: BorderRadius.circular(24),
              onTap: () {
                if (ref.read(accessibilityProvider).hapticFeedback) {
                  HapticFeedback.lightImpact();
                }
                showModalBottomSheet(
                  context: context,
                  sheetAnimationStyle: AppTheme.sheetAnimationStyleOf(context),
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (context) => TithiDetailSheet(panchang: panchang),
                );
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
                        // Content-only fade: the gradient shell, ripple and
                        // glow above stay mounted while day text swaps.
                        return AnimatedSwitcher(
                          duration: AppTheme.animationDuration(
                            context,
                            const Duration(milliseconds: 180),
                          ),
                          transitionBuilder: (child, animation) =>
                              FadeTransition(opacity: animation, child: child),
                          layoutBuilder: (currentChild, _) => currentChild!,
                          child: KeyedSubtree(
                            key: ValueKey((panchang.date, resolved)),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Header: tag + day, full width. Text wraps instead of
                                // eclipsing at any width.
                                _HeroHeader(
                                  tagLabel: content.tagLabel,
                                  cityName: cityName,
                                  highContrast: highContrast,
                                  onHero: onHero,
                                  maxWidth: constraints.maxWidth,
                                ),
                                const SizedBox(height: 6),
                                // Title = weekday + secondary calendar (spec).
                                // Weekday stands alone while Bengali resolves.
                                _HeroTitle(
                                  content: content,
                                  baseStyle: titleBaseStyle,
                                  accentStyle: titleAccentStyle,
                                ),
                                const SizedBox(height: 10),
                                // Two columns below the header: moon text left, artwork
                                // right. Row centers its children, so the shorter text
                                // block sits balanced against the taller portrait
                                // artwork instead of leaving all the slack below it.
                                _HeroMoonRow(
                                  content: content,
                                  highContrast: highContrast,
                                  onHero: onHero,
                                  maxWidth: constraints.maxWidth,
                                ),
                                if (content.chips.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 10),
                                    child: _HeroChips(
                                      chips: content.chips,
                                      highContrast: highContrast,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
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
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            tagLabel.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              letterSpacing: 2.2,
              fontWeight: FontWeight.bold,
              color: highContrast
                  ? context.colors.onSurface.withValues(alpha: 0.7)
                  : onHero,
            ),
          ),
        ),
        // Capped so a long city name truncates inside
        // the pill instead of squeezing the tag
        // into a RenderFlex overflow.
        if (locationChip != null) ...[
          const SizedBox(width: 8),
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth * 0.38),
            child: locationChip,
          ),
        ],
        // Header tap affordance: the card opens the
        // detail sheet below.
        const SizedBox(width: 2),
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
/// without a picture — text-only layout kept).
class _HeroMoonRow extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final chipBg = AppTheme.heroChipBackground(context);
    final chipBd = AppTheme.heroChipBorder(context);
    // Responsive artwork width: ~26% of the content width,
    // clamped so the text column always keeps room.
    final imageWidth = (maxWidth * 0.26).clamp(76.0, 110.0);
    return Row(
      children: [
        Expanded(
          child: Row(
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
              const SizedBox(width: 12),
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
                    const SizedBox(height: 2),
                    Text(
                      content.subLabel,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                        color: highContrast
                            ? context.colors.onSurface.withValues(alpha: 0.7)
                            : onHero,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        // Artwork column on the right of the moon text;
        // absent without a picture (text-only layout kept).
        if (content.artwork != null) ...[
          const SizedBox(width: 12),
          HeroFestivalImage(
            source: content.artwork!.source,
            semanticsLabel: content.artwork!.label,
            highContrast: highContrast,
            width: imageWidth,
          ),
        ],
      ],
    );
  }
}

/// Transition chips row.
class _HeroChips extends StatelessWidget {
  const _HeroChips({required this.chips, required this.highContrast});

  final List<HeroChipData> chips;
  final bool highContrast;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: [
        for (final chip in chips)
          HeroChip(
            icon: chip.icon,
            text: chip.text,
            highlight: chip.highlight,
            suffix: chip.suffix,
            inlineIcon: chip.inlineIcon,
            fontWeight: FontWeight.w800,
            fontSize: 13,
            highContrast: highContrast,
          ),
      ],
    );
  }
}
