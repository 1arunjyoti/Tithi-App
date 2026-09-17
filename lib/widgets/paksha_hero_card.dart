import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../l10n/app_localizations.dart';
import '../l10n/app_localizations_en.dart';
import '../models/festival.dart';
import '../models/hindu_month_system.dart';
import '../models/panchang_data.dart';
import '../providers/accessibility_provider.dart';
import '../providers/calendar_provider.dart';
import '../providers/locale_provider.dart';
import '../providers/location_provider.dart';
import '../providers/panchang_provider.dart';
import '../services/bengali_calendar/bengali_calendar_data.dart';
import '../services/bengali_calendar_service.dart';
import '../services/moon_phase_service.dart';
import '../theme/app_theme.dart';
import '../utils/tithi_localization.dart';
import 'moon_animation_widget.dart';
import 'tithi_detail_sheet.dart';

/// True-cold placeholder height: reserves most of the hero's space up front
/// (any remainder still glides via AnimatedSize) without leaving a cavernous
/// block while the month batch computes.
const double _trueColdSkeletonHeight = 220;

/// Bengali date for the hero header. Only resolves when Bengali is the
/// primary or secondary calendar system; null otherwise (and on failure),
/// in which case the hero falls back to its Hindu/Gregorian rendering —
/// same guarded pattern as the schedule view.
final bengaliDateForHeroProvider = FutureProvider.autoDispose
    .family<({int day, String month, int year})?, DateTime>((ref, date) async {
      final primary = ref.watch(primaryCalendarSystemProvider);
      final secondary = ref.watch(secondaryCalendarSystemProvider);
      if (primary != AppCalendarSystem.bengali &&
          secondary != AppCalendarSystem.bengali) {
        return null;
      }
      try {
        return await ref
            .read(bengaliCalendarServiceProvider)
            .calculateDate(date);
      } catch (_) {
        return null;
      }
    });

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
    final day = DateTime(selected.year, selected.month, selected.day);
    final now = DateTime.now();
    final isToday = day == DateTime(now.year, now.month, now.day);

    final panchangAsync = ref.watch(panchangForDateProvider(day));
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
    final isShukla = panchang.isShukla;

    final illumination = MoonPhaseService.illuminationFractionForDay(
      tithiNumber: panchang.tithiNumber,
      isShukla: isShukla,
      rawTithi: panchang.rawTithi,
    );
    // One decimal, matching the Moon Phases screen's
    // 'Illumination: x.x%' exactly (same inputs, same formatting).
    final illuminationPct = (illumination * 100).toStringAsFixed(1);

    // High-contrast falls back to solid theme surfaces so white-on-gradient
    // never becomes illegible.
    final highContrast =
        AppTheme.highContrastOf(context) ||
        ref.watch(glassmorphismConfigProvider).isHighContrast;
    final chipBg = AppTheme.heroChipBackground(context);
    final chipBd = AppTheme.heroChipBorder(context);
    final heroAccent = AppTheme.heroAccent(context);
    final onHero = AppTheme.heroForeground(context);

    // Calendar header combos (assets/redesign assets/calendar-header-combos):
    // tag row = primary compact, title = weekday + secondary full. Masa is
    // Purnimant-correct. Bengali shows Bengali script + digits only when the
    // app language is Bengali; otherwise transliterated names + Latin digits.
    final selectedLocale = ref.watch(localeProvider);
    final useBengaliScript =
        (selectedLocale ?? WidgetsBinding.instance.platformDispatcher.locale)
            .languageCode ==
        'bn';
    final primarySystem = ref.watch(primaryCalendarSystemProvider);
    final secondarySystem = ref.watch(secondaryCalendarSystemProvider);
    final displayMasa = displayMasaName(
      panchang.masa,
      panchang.paksha,
      ref.watch(hinduMonthSystemProvider),
    ).replaceAll('_', ' ');
    final localizedMasa = localizedHinduMonthName(displayMasa, l10n);
    final bengali = ref
        .watch(bengaliDateForHeroProvider(panchang.date))
        .valueOrNull;

    // Bengali month + digits: script form under the Bengali app language,
    // transliterated form otherwise (month lookup falls back as-is).
    String? bnCompact;
    String? bnTitle;
    final bDate = bengali;
    if (bDate != null) {
      if (useBengaliScript) {
        final idx = bengaliMonthIndexOf(bDate.month);
        final monthBn = idx >= 0 ? kBengaliMonthsBn[idx] : bDate.month;
        bnCompact =
            '${toBengaliDigits(bDate.day)} $monthBn ${toBengaliDigits(bDate.year)}';
        bnTitle = '${toBengaliDigits(bDate.day)} $monthBn';
      } else {
        bnCompact = '${bDate.day} ${bDate.month} ${bDate.year}';
        bnTitle = '${bDate.day} ${bDate.month}';
      }
    }

    final displayTithiName = localizedTithiName(
      panchang.tithiNumber,
      panchang.paksha,
      l10n,
    );
    final masaTithi = '$localizedMasa $displayTithiName'.trim();
    final gregFull = formatLocalizedDate(
      panchang.date,
      'd MMMM y',
      l10n.localeName,
    );
    final gregCompact = formatLocalizedDate(
      panchang.date,
      'd MMM y',
      l10n.localeName,
    ).toUpperCase();

    // Same system in both slots: title takes the full format, tag drops the
    // date to just Today/Selected (no duplication).
    final bool sameSystem =
        primarySystem == secondarySystem &&
        primarySystem != AppCalendarSystem.none;
    final String? tagDate = sameSystem
        ? null
        : switch (primarySystem) {
            AppCalendarSystem.gregorian => gregCompact,
            AppCalendarSystem.hindu => masaTithi.toUpperCase(),
            AppCalendarSystem.bengali => bnCompact,
            AppCalendarSystem.none => null,
          };
    final tagPrefix = isToday ? l10n.today : l10n.selected;
    final tagLabel = tagDate == null ? tagPrefix : '$tagPrefix · $tagDate';

    // Title = weekday + secondary full. Bengali secondary waits for its
    // async date (weekday alone meanwhile); other slots are sync.
    final weekday = formatLocalizedDate(panchang.date, 'EEEE', l10n.localeName);
    final titleBaseStyle = TextStyle(
      fontSize: 22,
      fontWeight: FontWeight.w600,
      color: highContrast ? context.colors.onSurface : onHero,
    );
    final titleAccentStyle = titleBaseStyle.copyWith(
      fontStyle: FontStyle.italic,
      color: highContrast ? context.colors.primary : heroAccent,
    );
    final bool isNoneSecondary = secondarySystem == AppCalendarSystem.none;
    TextSpan? secondarySpan;
    switch (secondarySystem) {
      case AppCalendarSystem.gregorian:
        secondarySpan = TextSpan(text: gregFull, style: titleBaseStyle);
      case AppCalendarSystem.hindu:
        secondarySpan = TextSpan(text: masaTithi, style: titleAccentStyle);
      case AppCalendarSystem.bengali:
        secondarySpan = bnTitle == null
            ? null
            : TextSpan(
                text: bnTitle,
                // Bengali typeface only with the Bengali app language;
                // transliterated text keeps the hero typeface.
                style: useBengaliScript
                    ? GoogleFonts.notoSansBengali(textStyle: titleAccentStyle)
                    : titleAccentStyle,
              );
      case AppCalendarSystem.none:
        // Deliberately no label: title is just the weekday.
        break;
    }
    final pakshaName = panchang.isShukla ? l10n.themeShukla : l10n.themeKrishna;
    final title = '${l10n.pakshaWithName(pakshaName)} · $displayTithiName';
    final phaseWord = isShukla ? l10n.waxing : l10n.waning;
    final subLabel = '$phaseWord · ${l10n.illuminatedPercent(illuminationPct)}';
    // Right-side artwork slot. Null until festival artwork lands, in which
    // case the moon row keeps its current text-only layout.
    final artwork = _heroArtwork(panchang);

    final chips = <Widget>[
      if (panchang.hasTithiTransition && panchang.tithiTransitionTime != null)
        _HeroChip(
          icon: Icons.arrow_forward_rounded,
          text: l10n.nextTithi,
          inlineIcon: true,
          fontWeight: FontWeight.w800,
          fontSize: 13,
          highlight: localizedTithiName(
            panchang.transitionTithiNumber,
            panchang.transitionPaksha,
            l10n,
          ),
          suffix:
              ' ${l10n.atTime(formatLocalizedDate(panchang.tithiTransitionTime!, 'jm', l10n.localeName))}',
          highContrast: highContrast,
        ),
    ];

    // Location pill lives in the header's top-right corner, not with the
    // chips below.
    final city = cityName;
    final locationChip = city == null
        ? null
        : _HeroChip(
            icon: Icons.location_on_rounded,
            text: city,
            highContrast: highContrast,
          );

    // Tappable card done properly: button semantics for screen readers,
    // trailing chevron as the visual cue, and a Material ripple clipped to
    // the card shape (Ink paints the gradient so the splash shows above it).
    return Semantics(
      button: true,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: AppTheme.homeCardGutter),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(24),
          child: Ink(
            decoration: highContrast
                ? AppTheme.glassmorphism(context: context, ref: ref)
                : AppTheme.heroDecoration(context),
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
                        // Responsive artwork width: ~26% of the content width,
                        // clamped so the text column always keeps room.
                        final imageWidth = (constraints.maxWidth * 0.26).clamp(
                          76.0,
                          110.0,
                        );
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
                                // Tag: dot + Today · 14 September 2026
                                Row(
                                  children: [
                                    Container(
                                      width: 6,
                                      height: 6,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: highContrast
                                            ? context.colors.primary
                                            : heroAccent,
                                        boxShadow: highContrast
                                            ? null
                                            : [
                                                BoxShadow(
                                                  color: heroAccent,
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
                                              ? context.colors.onSurface
                                                    .withValues(alpha: 0.7)
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
                                        constraints: BoxConstraints(
                                          maxWidth: constraints.maxWidth * 0.38,
                                        ),
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
                                          ? context.colors.onSurface.withValues(
                                              alpha: 0.7,
                                            )
                                          : onHero,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                // Title = weekday + secondary calendar (spec).
                                // Weekday stands alone while Bengali resolves.
                                Text.rich(
                                  TextSpan(
                                    children: [
                                      TextSpan(
                                        text:
                                            secondarySpan == null ||
                                                isNoneSecondary
                                            ? weekday
                                            : '$weekday, ',
                                        style: titleBaseStyle,
                                      ),
                                      ?secondarySpan,
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 10),
                                // Two columns below the header: moon text left, artwork
                                // right. Row centers its children, so the shorter text
                                // block sits balanced against the taller portrait
                                // artwork instead of leaving all the slack below it.
                                Row(
                                  children: [
                                    Expanded(
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 44,
                                            height: 44,
                                            decoration: BoxDecoration(
                                              borderRadius:
                                                  BorderRadius.circular(13),
                                              color: highContrast
                                                  ? context.colors.primary
                                                        .withValues(alpha: 0.1)
                                                  : chipBg,
                                              border: Border.all(
                                                color: highContrast
                                                    ? context.colors.primary
                                                          .withValues(
                                                            alpha: 0.2,
                                                          )
                                                    : chipBd,
                                              ),
                                            ),
                                            alignment: Alignment.center,
                                            child: MoonAnimationWidget(
                                              phase: illumination,
                                              isWaxing: isShukla,
                                              size: 28,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  title,
                                                  style: TextStyle(
                                                    fontSize: 18,
                                                    fontWeight: FontWeight.w600,
                                                    color: highContrast
                                                        ? context
                                                              .colors
                                                              .onSurface
                                                        : onHero,
                                                  ),
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  subLabel,
                                                  style: TextStyle(
                                                    fontSize: 12.5,
                                                    fontWeight: FontWeight.w500,
                                                    color: highContrast
                                                        ? context
                                                              .colors
                                                              .onSurface
                                                              .withValues(
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
                                    ),
                                    // Artwork column on the right of the moon text;
                                    // absent without a picture (text-only layout kept).
                                    if (artwork != null) ...[
                                      const SizedBox(width: 12),
                                      _HeroFestivalImage(
                                        source: artwork.source,
                                        semanticsLabel: artwork.label,
                                        highContrast: highContrast,
                                        width: imageWidth,
                                      ),
                                    ],
                                  ],
                                ),
                                if (chips.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 10),
                                    child: Wrap(
                                      spacing: 8,
                                      runSpacing: 6,
                                      children: chips,
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
    );
  }
}

/// Festival artwork for the hero's right-side slot.
///
/// Resolves the day's primary festival ([primaryFestival]) image
/// ([Visuals.image], asset path or http(s) URL). Returns null when the day
/// has no festival or the festival ships no image — the hero then keeps its
/// current text-only layout.
({String source, String label})? _heroArtwork(PanchangData panchang) {
  if (panchang.festivals.isEmpty) return null;
  final festival = primaryFestival(panchang.festivals);
  final source = festival.visuals.image.trim();
  if (source.isEmpty) return null;
  return (source: source, label: festival.name);
}

/// Right-side festival artwork for the hero moon row.
///
/// Handles asset paths and network URLs. Shows a translucent placeholder
/// while a network image loads, and collapses to nothing if the image fails
/// to resolve — so a missing/broken picture degrades to the current
/// text-only layout instead of an empty box or error icon.
class _HeroFestivalImage extends StatefulWidget {
  const _HeroFestivalImage({
    required this.source,
    required this.semanticsLabel,
    required this.highContrast,
    this.width = 96,
  });

  final String source;
  final String semanticsLabel;
  final bool highContrast;

  /// Responsive slot width; height follows a ~1:1.2 ratio that suits
  /// deity artwork without stretching the card (other ratios center-crop
  /// via [BoxFit.cover]).
  final double width;

  @override
  State<_HeroFestivalImage> createState() => _HeroFestivalImageState();
}

class _HeroFestivalImageState extends State<_HeroFestivalImage> {
  bool _failed = false;

  @override
  void didUpdateWidget(covariant _HeroFestivalImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Selected date changed (calendar tap): retry the new source instead of
    // staying collapsed from a previous failure.
    if (oldWidget.source != widget.source) _failed = false;
  }

  void _markFailed() {
    // Image callbacks fire during build; defer so setState runs after.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _failed = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) return const SizedBox.shrink();

    final placeholder = Container(
      color: widget.highContrast
          ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.08)
          : Colors.white.withValues(alpha: 0.12),
    );

    final Widget image;
    if (widget.source.startsWith('http')) {
      image = Image.network(
        widget.source,
        fit: BoxFit.cover,
        semanticLabel: widget.semanticsLabel,
        loadingBuilder: (context, child, progress) =>
            progress == null ? child : placeholder,
        errorBuilder: (context, _, _) {
          _markFailed();
          return const SizedBox.shrink();
        },
      );
    } else {
      image = Image.asset(
        widget.source,
        fit: BoxFit.cover,
        errorBuilder: (context, _, _) {
          _markFailed();
          return const SizedBox.shrink();
        },
      );
    }

    return Semantics(
      label: widget.semanticsLabel,
      image: true,
      child: Container(
        width: widget.width,
        height: widget.width * 1.2,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: widget.highContrast
                ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.2)
                : AppTheme.heroChipBorder(context),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: image,
      ),
    );
  }
}

/// Pill chip shared by the hero's transition / sunrise / sunset / city rows.
///
/// Bold hero-foreground ink on the gradient (brown on light Shukla, white
/// on dark); theme primary on surface in high-contrast mode. [highlight]
/// renders a middle segment (e.g. the next tithi name) in the themed accent
/// color: hero accent on the gradient, primary in high-contrast mode.
class _HeroChip extends StatelessWidget {
  const _HeroChip({
    required this.icon,
    required this.text,
    this.highlight,
    this.suffix,
    this.inlineIcon = false,
    this.fontWeight,
    this.fontSize,
    required this.highContrast,
  });

  final IconData icon;
  final String text;
  final String? highlight;
  final String? suffix;

  /// When true the icon renders inline after [text] (e.g. between the label
  /// and the highlighted tithi) instead of leading the chip.
  final bool inlineIcon;

  /// Overrides the label weight (base and highlight alike). Defaults to bold
  /// on the gradient, medium in high-contrast mode.
  final FontWeight? fontWeight;

  /// Overrides the label size. Defaults to 12.
  final double? fontSize;
  final bool highContrast;

  @override
  Widget build(BuildContext context) {
    final accent = highContrast
        ? context.colors.primary
        : AppTheme.heroAccent(context);
    final baseColor = highContrast
        ? context.colors.onSurface
        : AppTheme.heroForeground(context);
    final iconColor = highContrast ? accent : AppTheme.heroForeground(context);
    final weight =
        fontWeight ?? (highContrast ? FontWeight.w500 : FontWeight.bold);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: highContrast
            ? context.colors.primary.withValues(alpha: 0.1)
            : AppTheme.heroChipBackground(context),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: highContrast
              ? context.colors.primary.withValues(alpha: 0.2)
              : AppTheme.heroChipBorder(context),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!inlineIcon) Icon(icon, size: 14, color: iconColor),
          if (!inlineIcon) const SizedBox(width: 6),
          Flexible(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: text),
                  if (inlineIcon)
                    WidgetSpan(
                      alignment: PlaceholderAlignment.middle,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Icon(icon, size: 14, color: iconColor),
                      ),
                    ),
                  if (highlight != null)
                    TextSpan(
                      text: highlight,
                      style: TextStyle(color: accent, fontWeight: weight),
                    ),
                  if (suffix != null) TextSpan(text: suffix),
                ],
              ),
              style: TextStyle(
                fontSize: fontSize ?? 12,
                color: baseColor,
                fontWeight: weight,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
