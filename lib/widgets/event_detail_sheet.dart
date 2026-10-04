import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/locale/app_locale.dart';
import '../l10n/app_localizations.dart';
import '../models/festival.dart';
import '../models/panchang_data.dart';
import '../providers/calendar_provider.dart';
import '../providers/locale_provider.dart';
import '../providers/panchang_provider.dart';
import '../theme/app_theme.dart';
import '../services/moonrise_calculator.dart';
import '../services/share_service.dart';
import '../services/sunrise_calculator.dart';
import '../utils/tithi_localization.dart';
import '../features/event_detail/domain/event_content.dart';
import '../features/event_detail/domain/puja_samay.dart';
import '../features/event_detail/providers/event_detail_providers.dart';
import '../features/sheets/widgets/sheet_chip.dart';
import '../features/sheets/widgets/sheet_explainer_card.dart';
import '../features/sheets/widgets/sheet_hero_tile.dart';
import '../features/sheets/widgets/sheet_scaffold.dart';
import '../features/sheets/widgets/sheet_surface_card.dart';
import '../features/sheets/widgets/sheet_time_format.dart';
import '../features/sheets/widgets/info_row.dart';
import '../features/sheets/widgets/section_header.dart';
import '../features/tithi_sheet/widgets/timings_cards.dart';

export '../features/event_detail/providers/event_detail_providers.dart'
    show descExpandedProvider, heroChipsExpandedProvider;

/// Bottom sheet showing festival details in the tithi-sheet visual language.
///
/// Scaffold, hero header, chips, timings card and explainer are the shared
/// sheet kit ([SheetScaffold], [SheetHeroHeader] inside it, [SheetChip],
/// [TimingsCard], [SheetExplainerCard]); the body cards use the shared
/// [SheetSurfaceCard] (surface fill, 16pt radius) instead of glassmorphism
/// so both sheets share fill, radius and high-contrast behavior.
///
/// Same data as the tithi sheet reuses the same component: the observed
/// tithi Begins/Ends span renders in the shared [TimingsCard] with the
/// shared [sheetInstantValue] formatting (clock time + primary-calendar
/// date), not the old Gregorian-only info rows.
class EventDetailSheet extends ConsumerWidget {
  final Festival festival;
  final PanchangData? panchang;

  const EventDetailSheet({super.key, required this.festival, this.panchang});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeColor = context.colors.primary;
    // Month system for Masa labels: Purnimant Krishna days carry the next
    // month's name (e.g. Janmashtami = Bhadrapada, not Shravana).
    final monthSystem = ref.watch(hinduMonthSystemProvider);
    final l10n = AppLocalizations.of(context);
    final locale = l10n?.localeName ?? 'en';
    // Hero title follows the app language (Bengali/Hindi/Sanskrit names
    // under those locales, English otherwise), resolved from the language
    // setting like the tithi sheet — not the Material locale.
    final appLanguage =
        resolveAppLocale(ref.watch(localeProvider)).languageCode;
    final displayName = festivalDisplayName(
      festival: festival,
      locale: appLanguage,
    );
    // Settings tithi display mode: paksha-based shows T1-15, continuous
    // shows T1-30 — resolved once here instead of inside row builders.
    final continuous =
        ref.watch(tithiDisplayModeProvider) == TithiDisplayMode.continuous30;
    final flags = eventFlags(festival);
    // Normalized ritual-window fields (null when absent/unknown → the
    // corresponding card or line hides).
    final pujaKala = normalizedPujaKala(festival);
    final paranRule = normalizedParanRule(festival);
    // Local promotes null checks for the section widgets below (fields
    // don't promote).
    final dayPanchang = panchang;
    // All derived labels/rows (features/event_detail/domain, unit tested).
    // Null without panchang data: the rules-only fallback rows below apply.
    final content = dayPanchang != null
        ? eventSheetContent(
            festival: festival,
            panchang: dayPanchang,
            monthSystem: monthSystem,
            continuousTithi: continuous,
            l10n: l10n,
          )
        : null;

    // Same high-contrast resolution as the tithi sheet (OS + app setting).
    final highContrast =
        AppTheme.highContrastOf(context) ||
        ref.watch(glassmorphismConfigProvider).isHighContrast;

    // Hero date line: observance weekday + Gregorian date (tithi-sheet
    // date styling, 22pt semibold hero ink).
    final dateBaseStyle = TextStyle(
      fontSize: 22,
      fontWeight: FontWeight.w600,
      color: highContrast
          ? context.colors.onSurface
          : AppTheme.heroForeground(context),
    );
    final heroInk = highContrast
        ? context.colors.onSurface
        : AppTheme.heroForeground(context);
    final heroAccent = highContrast
        ? context.colors.primary
        : AppTheme.heroAccent(context);

    // Chip row: all language names minus the title language, plus English
    // up front when the title shows another language (shared helper,
    // unit tested).
    final heroChips = heroLanguageChips(festival: festival, locale: appLanguage);
    // Observance banner sentence ("Observed on the day …"), mapped from
    // timingOverride with an English fallback like the other sheet strings.
    final ruleLabel = observanceRuleLabel(observanceRuleKey(festival), l10n);
    final ruleSentence =
        l10n?.observedOnTheDay(ruleLabel) ?? 'Observed on the day $ruleLabel';
    final categoryLabel =
        content?.categoryLabel ??
        categoryLabelFor(festival: festival, l10n: l10n);

    return SheetScaffold(
      highContrast: highContrast,
      hero: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header date: observance weekday + Gregorian date.
          if (dayPanchang != null)
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text:
                        '${formatLocalizedDate(dayPanchang.date, 'EEEE', locale)}, ',
                    style: dateBaseStyle,
                  ),
                  TextSpan(
                    text: formatLocalizedDate(
                      dayPanchang.date,
                      'd MMMM y',
                      locale,
                    ),
                    style: dateBaseStyle,
                  ),
                ],
              ),
            ),
          if (dayPanchang != null) const SizedBox(height: 12),
          // Title row: icon tile + name/subtitle + tithi badge + share.
          // Center-aligned like the tithi sheet's moon row, so the badge
          // and share button sit mid-row instead of riding the top edge.
          Row(
            children: [
              SheetHeroTile(
                highContrast: highContrast,
                child: Icon(
                  Icons.celebration_outlined,
                  size: 24,
                  color: highContrast
                      ? context.colors.primary
                      : AppTheme.heroForeground(context),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: heroInk,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      // Sanskrit companion to the title.
                      festival.nameSanskrit ?? categoryLabel,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                        color: heroInk,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (content != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: highContrast
                          ? context.colors.primary.withValues(alpha: 0.4)
                          : heroAccent.withValues(alpha: 0.7),
                    ),
                  ),
                  child: Text(
                    '${content.displayTithiNum}',
                    style: TextStyle(
                      color: heroAccent,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
              IconButton(
                onPressed: () =>
                    ShareService().shareFestival(context, festival),
                icon: const Icon(Icons.share_outlined),
                color: heroInk,
                tooltip:
                    AppLocalizations.of(context)?.shareCard ?? 'Share Card',
              ),
            ],
          ),
          // Hero chips (shared pill style): regional names only, minus the
          // title language. Collapsed to the first row with a "show more"
          // toggle so festivals with many names don't push the hero tall.
          // The category stays in the Panchang Details rows below.
          if (heroChips.isNotEmpty)
            _HeroLanguageChips(
              chips: heroChips,
              highContrast: highContrast,
            ),
        ],
      ),
      body: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Observance banner: which tithi checkpoint fixes this date.
          // Lives below the header, above the description — not inside the
          // hero. Shown even for the default sunrise rule — the
          // transparency is what makes the date trustworthy when it differs
          // from another calendar. Hidden where no tithi checkpoint applies
          // (Solar fixed dates, nakshatra-observed, dateless rules).
          if (showsObservanceBanner(festival)) ...[
            // The observance date itself lives in the header date line
            // above — the banner carries only the rule sentence.
            _ObservanceBanner(
              highContrast: highContrast,
              rule: ruleSentence,
            ),
            const SizedBox(height: 12),
          ],
          _EventDescription(
            festival: festival,
            hasAdditionalDesc: flags.additionalDesc,
            themeColor: themeColor,
          ),
          const SizedBox(height: 12),

          // Panchang info (tithi-sheet section style).
          Row(
            children: [
              Expanded(
                child: SectionHeader(
                  text:
                      AppLocalizations.of(context)?.panchangDetails ??
                      'Panchang Details',
                ),
              ),
              if (content?.showTimings ?? false)
                _buildTimingInfoButton(context),
            ],
          ),
          const SizedBox(height: 10),
          if (dayPanchang != null && content != null) ...[
            _EventPanchang(
              festival: festival,
              panchang: dayPanchang,
              content: content,
              themeColor: themeColor,
            ),
          ] else ...[
            // Generic info from festival rules when no panchang available.
            SheetSurfaceCard(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  buildInfoRow(
                    context,
                    Icons.brightness_3,
                    AppLocalizations.of(context)?.paksha ?? 'Paksha',
                    festival.paksha,
                  ),
                  buildInfoRow(
                    context,
                    Icons.calendar_today,
                    AppLocalizations.of(context)?.tithi ?? 'Tithi',
                    // Respect the Settings tithi display mode here too:
                    // festival rules store paksha-based 1-15, so map
                    // Krishna tithis to 16-30 in continuous mode.
                    ruleTithiLabel(
                      festival: festival,
                      continuous: continuous,
                      l10n: l10n,
                    ),
                  ),
                  // Masa from festival rules (stored Amanta) — converted
                  // for Purnimant display using the rule's own paksha.
                  if (festival.masa.isNotEmpty && festival.masa != '*')
                    buildInfoRow(
                      context,
                      Icons.wb_sunny_outlined,
                      AppLocalizations.of(context)?.masa ?? 'Masa',
                      localizedMasaLabel(
                        masa: festival.masa,
                        paksha: festival.paksha,
                        monthSystem: monthSystem,
                        locale:
                            AppLocalizations.of(context)?.localeName ?? 'en',
                      ),
                    ),
                  // Nakshatra from festival rules when tithi is
                  // overridden by one (stored tithi is then ignored).
                  if (festival.nakshatraCondition != null)
                    buildInfoRow(
                      context,
                      Icons.star_outline,
                      AppLocalizations.of(context)?.nakshatra ?? 'Nakshatra',
                      festival.nakshatraCondition!,
                    ),
                  buildInfoRow(
                    context,
                    Icons.category,
                    AppLocalizations.of(context)?.category ?? 'Category',
                    categoryLabel,
                  ),
                ],
              ),
            ),
          ],

          // Puja Samay ritual window (below Panchang Details). Needs the
          // day's anchors, so it hides without panchang data.
          if (dayPanchang != null && content != null && pujaKala != null) ...[
            const SizedBox(height: 12),
            SectionHeader(
              text:
                  '${AppLocalizations.of(context)?.pujaSamay ?? 'Puja Samay'} · ${pujaKalaLabel(pujaKala, l10n)}',
            ),
            const SizedBox(height: 10),
            _EventPujaSamay(
              festival: festival,
              panchang: dayPanchang,
              content: content,
              kala: pujaKala,
            ),
          ],

          // Fasting / Vrat info (below Puja Samay), with the paran line
          // when the breaking time is critical. Paran needs a date, so it
          // only renders with panchang data.
          if (flags.fasting ||
              (paranRule != null &&
                  dayPanchang != null &&
                  content != null)) ...[
            const SizedBox(height: 12),
            SectionHeader(
              text:
                  AppLocalizations.of(context)?.fastingVrat ??
                  'Fasting / Vrat',
            ),
            const SizedBox(height: 10),
            _EventFasting(
              festival: festival,
              panchang: dayPanchang,
              content: content,
              paranRule: paranRule,
              themeColor: themeColor,
            ),
          ],

          // Rituals
          if (festival.rituals.steps.isNotEmpty) ...[
            const SizedBox(height: 12),
            SectionHeader(
              text:
                  AppLocalizations.of(context)?.ritualsAndPractices ??
                  'Rituals & Practices',
            ),
            const SizedBox(height: 10),
            _EventRituals(festival: festival, themeColor: themeColor),
          ],

          // Mantra section
          if (flags.mantra) ...[
            const SizedBox(height: 12),
            SectionHeader(
              text: AppLocalizations.of(context)?.mantra ?? 'Mantra',
            ),
            const SizedBox(height: 10),
            _EventMantra(festival: festival, themeColor: themeColor),
          ],

          // Timing note (shared explainer style) while timings resolve.
          if (content?.showTimings ?? false) ...[
            const SizedBox(height: 12),
            SheetExplainerCard(
              text:
                  AppLocalizations.of(context)?.timingNoteDescription ??
                  'Timings are calculated astronomically based on coordinates and may vary by a few minutes from local temple calendars due to atmospheric refraction, elevation, or calculation methods.',
            ),
          ],
        ],
      ),
    );
  }
}

Widget _buildTimingInfoButton(BuildContext context) {
  return InkWell(
    onTap: () => _showTimingDialog(context),
    borderRadius: BorderRadius.circular(12),
    child: Padding(
      padding: const EdgeInsets.all(4.0),
      child: Icon(
        Icons.info_outline_rounded,
        size: 16,
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
      ),
    ),
  );
}

void _showTimingDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (context) {
      return AlertDialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 40),
        titlePadding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
        contentPadding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
        actionsPadding: const EdgeInsets.fromLTRB(20, 0, 16, 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            Icon(
              Icons.info_outline_rounded,
              color: Theme.of(context).colorScheme.primary,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              AppLocalizations.of(context)?.timingNote ?? 'Timing Note',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Text(
          AppLocalizations.of(context)?.timingNoteDescription ??
              'Timings are calculated astronomically based on coordinates and may vary by a few minutes from local temple calendars due to atmospheric refraction, elevation, or calculation methods.',
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(height: 1.35, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(AppLocalizations.of(context)?.gotIt ?? 'Got it'),
          ),
        ],
      );
    },
  );
}

Widget _buildFormattedText(String text, TextStyle? baseStyle) {
  final parts = text.split('**');
  if (parts.length == 1) {
    return Text(text, style: baseStyle);
  }

  final spans = <TextSpan>[];
  for (int i = 0; i < parts.length; i++) {
    if (parts[i].isEmpty && i == 0) continue;

    final isBold = i.isOdd;
    spans.add(
      TextSpan(
        text: parts[i],
        style: baseStyle?.copyWith(
          fontWeight: isBold ? FontWeight.bold : baseStyle.fontWeight,
        ),
      ),
    );
  }

  return Text.rich(TextSpan(children: spans), style: baseStyle);
}

/// Tinted observance banner (TransitionCard fill): the bold primary rule
/// sentence ("Observed on the day …"). The date itself is not repeated
/// here — it already stands in the header date line.
class _ObservanceBanner extends StatelessWidget {
  const _ObservanceBanner({required this.highContrast, required this.rule});

  final bool highContrast;
  final String rule;

  @override
  Widget build(BuildContext context) {
    final primary = context.colors.primary;
    // Text ink: theme primary is unreadable on the tinted fill in light
    // mode (vibrant orange on peach), so the banner uses the hero accent —
    // burnt orange on the light card, neon/gold on the dark ones — the
    // same ink as the hero titles. High contrast keeps primary.
    final ink = highContrast
        ? context.colors.primary
        : AppTheme.heroAccent(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: primary.withValues(alpha: highContrast ? 0.15 : 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: primary.withValues(alpha: 0.35)),
      ),
      child: Text(
        rule,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.bold,
          color: ink,
        ),
      ),
    );
  }
}

/// Collapsible hero language chips (shared pill style): collapsed shows
/// only the first chip row with an expand chevron, expanded shows every
/// regional name with a collapse chevron. The chevron sits in its own
/// right-aligned row below the full-width chips. Single-row sets render
/// bare — no chevron when there is nothing to reveal.
///
/// The first row is measured, not guessed: each chip carries a key and a
/// post-frame pass groups them by vertical position, so the clipped height
/// matches the real chip height on any screen width, font scale or locale.
/// Before the first measurement the full row renders unclipped (safe
/// fallback — nothing is ever hidden without a toggle).
class _HeroLanguageChips extends ConsumerStatefulWidget {
  const _HeroLanguageChips({
    required this.chips,
    required this.highContrast,
  });

  final List<String> chips;
  final bool highContrast;

  @override
  ConsumerState<_HeroLanguageChips> createState() =>
      _HeroLanguageChipsState();
}

class _HeroLanguageChipsState extends ConsumerState<_HeroLanguageChips> {
  late List<GlobalKey> _chipKeys = [
    for (final _ in widget.chips) GlobalKey(),
  ];
  bool _measured = false;
  int _measureAttempts = 0;
  int _firstRowCount = 0;
  double? _firstRowHeight;

  bool get _multiRow =>
      _measured && _firstRowCount < widget.chips.length;

  @override
  void didUpdateWidget(covariant _HeroLanguageChips oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.chips.length != widget.chips.length) {
      _chipKeys = [for (final _ in widget.chips) GlobalKey()];
      _measured = false;
      _measureAttempts = 0;
      _firstRowCount = 0;
      _firstRowHeight = null;
    }
    _scheduleMeasure();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Re-runs on width/text-scale changes too, so rotation or a larger
    // accessibility font re-groups the rows instead of going stale.
    _scheduleMeasure();
  }

  void _scheduleMeasure() {
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
  }

  double? _globalDy(RenderBox box) {
    try {
      return box.localToGlobal(Offset.zero).dy;
    } catch (_) {
      return null;
    }
  }

  void _measure() {
    if (!mounted || widget.chips.isEmpty) return;
    if (_chipKeys.length != widget.chips.length) return;
    final firstBox =
        _chipKeys.first.currentContext?.findRenderObject() as RenderBox?;
    if (firstBox == null || !firstBox.hasSize) {
      _retryLater();
      return;
    }
    final firstDy = _globalDy(firstBox);
    if (firstDy == null) {
      _retryLater();
      return;
    }
    var count = 0;
    for (final key in _chipKeys) {
      final box = key.currentContext?.findRenderObject() as RenderBox?;
      if (box == null || !box.hasSize) {
        _retryLater();
        return;
      }
      final dy = _globalDy(box);
      if (dy == null) {
        _retryLater();
        return;
      }
      // Chips sharing the first row sit on the same baseline (1px
      // tolerance for rounding); the first chip on a lower row ends it.
      if ((dy - firstDy).abs() > 1.0) break;
      count++;
    }
    if (!_measured ||
        count != _firstRowCount ||
        firstBox.size.height != _firstRowHeight) {
      setState(() {
        _measured = true;
        _firstRowCount = count;
        _firstRowHeight = firstBox.size.height;
      });
    }
  }

  void _retryLater() {
    // Layout may lag a frame behind (sheet entry animation); retry a few
    // frames before giving up and leaving the full row visible.
    if (_measured || _measureAttempts >= 5 || !mounted) return;
    _measureAttempts++;
    _scheduleMeasure();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.chips.isEmpty) return const SizedBox.shrink();
    final expanded = ref.watch(heroChipsExpandedProvider);
    final l10n = AppLocalizations.of(context);
    // Toggle ink matches the hero titles (primary is unreadable on the
    // peach gradient in light mode — same call as _ObservanceBanner).
    final ink = widget.highContrast
        ? context.colors.primary
        : AppTheme.heroForeground(context);

    Wrap chipsWrap() {
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        // Clip the paint instead of overflowing: the SizedBox below caps
        // the height at exactly one row.
        clipBehavior: Clip.hardEdge,
        children: [
          for (var i = 0; i < widget.chips.length; i++)
            SheetChip(
              key: _chipKeys[i],
              icon: Icons.translate,
              text: widget.chips[i],
              highContrast: widget.highContrast,
            ),
        ],
      );
    }

    // Chevron pinned to the right side of the chips row (no text label).
    // The existing translations/less strings serve as the tooltip so the
    // icon-only button stays localized and screen-reader friendly.
    Widget arrowButton({required bool isExpanded}) {
      return IconButton(
        onPressed: () =>
            ref.read(heroChipsExpandedProvider.notifier).state = !isExpanded,
        icon: Icon(
          isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
          color: ink,
          size: 20,
        ),
        tooltip: isExpanded
            ? (l10n?.showLess ?? 'Show less')
            : (l10n?.showMoreTranslations ?? 'Show more translations'),
        style: IconButton.styleFrom(
          foregroundColor: ink,
          padding: EdgeInsets.zero,
          minimumSize: const Size(32, 32),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
        ),
      );
    }

    // Chips always take the full width; the chevron lives in its own
    // right-aligned row below. (Parking the arrow beside the Wrap would
    // reserve a strip on the right of every row and squeeze the chips
    // left.) Single-row sets render bare with no arrow.
    final showToggle = _multiRow;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 14),
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          alignment: Alignment.topCenter,
          child: showToggle && !expanded
              // Collapsed multi-row: first row only, clipped at the
              // measured chip height plus a 2px buffer so the bottom
              // border isn't cut by anti-aliasing (still well under the
              // 8px runSpacing, so the second row stays hidden). Clip is
              // paint-only, so the hidden chips still lay out and the row
              // grouping above stays valid.
              ? SizedBox(
                  height: (_firstRowHeight ?? 0) + 2,
                  child: chipsWrap(),
                )
              : chipsWrap(),
        ),
        if (showToggle)
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [arrowButton(isExpanded: expanded)],
          ),
      ],
    );
  }
}

/// Description surface card with read-more expansion for the additional
/// text (tithi-sheet surface style, 16pt radius).
class _EventDescription extends ConsumerWidget {
  const _EventDescription({
    required this.festival,
    required this.hasAdditionalDesc,
    required this.themeColor,
  });

  final Festival festival;
  final bool hasAdditionalDesc;
  final Color themeColor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SheetSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildFormattedText(
            festival.description,
            context.textTheme.bodyLarge?.copyWith(
              fontSize: 16,
              height: 1.5,
            ),
          ),
          if (hasAdditionalDesc) ...[
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                InkWell(
                  onTap: () {
                    ref
                        .read(descExpandedProvider.notifier)
                        .update((state) => !state);
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 4,
                      horizontal: 8,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          ref.watch(descExpandedProvider)
                              ? (AppLocalizations.of(
                                      context,
                                    )?.showLessTitleCase ??
                                    'Show Less')
                              : (AppLocalizations.of(
                                      context,
                                    )?.readMore ??
                                    'Read More'),
                          style: context.textTheme.labelLarge?.copyWith(
                            color: themeColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          ref.watch(descExpandedProvider)
                              ? Icons.keyboard_arrow_up
                              : Icons.keyboard_arrow_down,
                          color: themeColor,
                          size: 18,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              alignment: Alignment.topCenter,
              child: ref.watch(descExpandedProvider)
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 8),
                        Divider(
                          color: context.colors.onSurface.withValues(
                            alpha: 0.15,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _buildFormattedText(
                          festival.purpose.additionalDescription,
                          context.textTheme.bodyMedium?.copyWith(
                            fontSize: 14,
                            height: 1.5,
                            color: context.colors.onSurface.withValues(
                              alpha: 0.8,
                            ),
                          ),
                        ),
                      ],
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ],
      ),
    );
  }
}

/// Panchang details for a day with data: the observed tithi span in the
/// shared [TimingsCard] (same component + [sheetInstantValue] formatting as
/// the tithi sheet), with the observed paksha/tithi/masa rows in a shared
/// surface card below it. Rows follow the festival's observed tithi
/// ([EventSheetContent]), not the sunrise tithi.
class _EventPanchang extends ConsumerWidget {
  const _EventPanchang({
    required this.festival,
    required this.panchang,
    required this.content,
    required this.themeColor,
  });

  final Festival festival;
  final PanchangData panchang;
  final EventSheetContent content;
  final Color themeColor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final locale = l10n?.localeName ?? 'en';
    final highContrast =
        AppTheme.highContrastOf(context) ||
        ref.watch(glassmorphismConfigProvider).isHighContrast;
    final coords = ref.watch(resolvedCoordinatesProvider);
    final timingsAsync = ref.watch(
      tithiTimingsProvider((
        date: panchang.date,
        // Full 1-30 index of the OBSERVED
        // (festival) tithi, not the sunrise tithi.
        tithiIndex: content.observedIndex,
        latitude: coords.latitude,
        longitude: coords.longitude,
      )),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Tithi Timings using user's location — the shared side-by-side
        // card. Solar festivals (fixed Gregorian dates) have no tithi
        // span, so no timings are shown. Same for
        // nakshatra-observed festivals.
        if (content.isNakshatraObserved)
          SheetSurfaceCard(
            child: buildInfoRow(
              context,
              Icons.star_outline,
              l10n?.nakshatra ?? 'Nakshatra',
              panchang.nakshatra ?? festival.nakshatraCondition!,
            ),
          ),
        if (content.showTimings)
          timingsAsync.when(
            data: (timings) {
              // Kshaya (skipped) tithi: the nearest
              // occurrence belongs to another
              // lunation, so hide rather than show
              // a wrong-month span.
              if (timings == null) {
                return const SizedBox.shrink();
              }
              return TimingsCard(
                highContrast: highContrast,
                begins: sheetInstantValue(
                  ref,
                  timings.start,
                  content.observedIndex,
                  locale,
                ),
                ends: sheetInstantValue(
                  ref,
                  timings.end,
                  content.observedIndex,
                  locale,
                ),
              );
            },
            loading: () => TimingsCard(highContrast: highContrast),
            error: (err, stack) => const SizedBox.shrink(),
          ),
        if (content.showTimings || content.isNakshatraObserved)
          const SizedBox(height: 12),
        SheetSurfaceCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              buildInfoRow(
                context,
                Icons.brightness_3,
                AppLocalizations.of(context)?.paksha ?? 'Paksha',
                content.pakshaLabel,
              ),
              buildInfoRow(
                context,
                Icons.calendar_today,
                AppLocalizations.of(context)?.tithi ?? 'Tithi',
                content.tithiLabel,
              ),
              // Masa (Hindu month) — converted for Purnimant display.
              // panchang.masa is always Amanta; Krishna days take the
              // next month's name in Purnimant (Shukla unchanged).
              if (content.masaLabel != null)
                buildInfoRow(
                  context,
                  Icons.wb_sunny_outlined,
                  l10n?.masa ?? 'Masa',
                  content.masaLabel!,
                ),
              buildInfoRow(
                context,
                Icons.category,
                AppLocalizations.of(context)?.category ?? 'Category',
                content.categoryLabel,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Moonrise for a puja/paran instant, with the tithi sheet's
/// prevailing-event fallback: on no-rise days the previous evening's rise
/// (which the fast still waits for) instead of nothing. Never throws —
/// lunar-theory failures hide the card instead of breaking the sheet.
DateTime? _pujaMoonrise({
  required DateTime date,
  required double latitude,
  required double longitude,
}) {
  try {
    final times = MoonriseCalculator.calculateMoonriseSet(
      date: date,
      latitude: latitude,
      longitude: longitude,
    );
    return times.moonrise ??
        MoonriseCalculator.findPreviousMoonrise(
          date: date,
          latitude: latitude,
          longitude: longitude,
        );
  } catch (_) {
    return null;
  }
}

/// Thematic icon per puja kala, mirroring the tithi sheet's sun/moon chips.
IconData _pujaKalaIcon(String kala) {
  return switch (kala) {
    'sunrise' => Icons.wb_sunny_rounded,
    'sunset' => Icons.nightlight_round,
    'moonrise' => Icons.dark_mode_outlined,
    'sandhi_junction' => Icons.swap_horiz,
    'nishita' => Icons.dark_mode,
    'pradosha' => Icons.wb_twilight,
    _ => Icons.access_time,
  };
}

/// Two-cell span card in the YogaKarana idiom: kala instant (+ date) left,
/// "PUJA WINDOW" range (+ ghati duration note) right. Null strings render
/// a spinner in place (loading state).
Widget _pujaWindowCard({
  required BuildContext context,
  required bool highContrast,
  required String kalaName,
  required String windowLabel,
  String? instant,
  String? date,
  String? range,
  String? note,
}) {
  final border = context.colors.onSurface.withValues(
    alpha: highContrast ? 0.2 : 0.1,
  );
  final cardColor =
      Theme.of(context).cardTheme.color ?? context.colors.surface;
  final dim = context.colors.onSurface.withValues(alpha: 0.6);
  final faint = context.colors.onSurface.withValues(alpha: 0.7);
  Widget valueOrSpinner(String? value, TextStyle style) {
    if (value == null) {
      return const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }
    return Text(value, style: style);
  }

  Widget cell({
    required String label,
    required String? primary,
    String? secondary,
    String? tertiary,
  }) {
    return Expanded(
      child: Container(
        color: cardColor,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 10.5,
                letterSpacing: 1.0,
                fontWeight: FontWeight.w600,
                color: dim,
              ),
            ),
            const SizedBox(height: 6),
            valueOrSpinner(
              primary,
              TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: context.colors.onSurface,
              ),
            ),
            if (secondary != null) ...[
              const SizedBox(height: 2),
              Text(
                secondary,
                style: TextStyle(fontSize: 13, color: faint),
              ),
            ],
            if (tertiary != null) ...[
              const SizedBox(height: 2),
              Text(
                tertiary,
                style: TextStyle(fontSize: 13, color: faint),
              ),
            ],
          ],
        ),
      ),
    );
  }

  return Container(
    decoration: BoxDecoration(
      color: border,
      borderRadius: BorderRadius.circular(16),
    ),
    clipBehavior: Clip.antiAlias,
    child: IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          cell(label: kalaName, primary: instant, secondary: date),
          Container(width: 1, color: border),
          cell(
            label: windowLabel,
            primary: range,
            secondary: note,
          ),
        ],
      ),
    ),
  );
}

/// Puja Samay ritual card: the two-cell span card for window kalas
/// (madhyahna/nishita/pradosha/moonrise/sandhi_junction), a single "at"
/// row for exact instants (sunrise/sunset). Hides when its inputs are
/// missing (no anchors, no moonrise, sandhi without a span).
class _EventPujaSamay extends ConsumerWidget {
  const _EventPujaSamay({
    required this.festival,
    required this.panchang,
    required this.content,
    required this.kala,
  });

  final Festival festival;
  final PanchangData panchang;
  final EventSheetContent content;
  final String kala;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final locale = l10n?.localeName ?? 'en';
    final highContrast =
        AppTheme.highContrastOf(context) ||
        ref.watch(glassmorphismConfigProvider).isHighContrast;
    final coords = ref.watch(resolvedCoordinatesProvider);
    final timingsAsync = ref.watch(
      tithiTimingsProvider((
        date: panchang.date,
        tithiIndex: content.observedIndex,
        latitude: coords.latitude,
        longitude: coords.longitude,
      )),
    );

    if (!isPujaWindowKala(kala)) {
      // Exact instants (Chhath arghya at sunrise/sunset): single "at" row.
      final instant = resolvePujaInstant(
        kala: kala,
        sunrise: panchang.sunrise,
        sunset: panchang.sunset,
      );
      if (instant == null) return const SizedBox.shrink();
      return SheetSurfaceCard(
        child: buildInfoRow(
          context,
          _pujaKalaIcon(kala),
          pujaKalaLabel(kala, l10n),
          sheetInstantValue(ref, instant, content.observedIndex, locale),
        ),
      );
    }

    // Window kala: needs the day's anchors. The observed span only feeds
    // sandhi (and the clipToTithi cut), so a Kshaya null still leaves the
    // day-anchored windows standing.
    if (panchang.sunrise == null || panchang.sunset == null) {
      return const SizedBox.shrink();
    }
    return timingsAsync.when(
      data: (timings) {
        final span = resolvePujaKala(
          kala: kala,
          date: panchang.date,
          sunrise: panchang.sunrise,
          sunset: panchang.sunset,
          nextSunrise: SunriseCalculator.calculateSunriseIST(
            date: panchang.date.add(const Duration(days: 1)),
            latitude: coords.latitude,
            longitude: coords.longitude,
          ),
          moonrise: _pujaMoonrise(
            date: panchang.date,
            latitude: coords.latitude,
            longitude: coords.longitude,
          ),
          tithiEnd: timings?.end,
          clipToTithi: festival.panchangRules.clipToTithi,
        );
        if (span == null) return const SizedBox.shrink();
        final kalaName = pujaKalaLabel(kala, l10n);
        final ghatis = ghatikasBetween(span.start, span.end);
        return _pujaWindowCard(
          context: context,
          highContrast: highContrast,
          kalaName: kalaName.toUpperCase(),
          windowLabel: l10n?.pujaWindow ?? 'PUJA WINDOW',
          instant: formatLocalizedDate(span.instant, 'jm', locale),
          date: formatLocalizedDate(span.instant, 'MMM d', locale),
          range: sheetTimeRange(span.start, span.end, panchang.date, locale),
          note: localizeDigits(
            l10n?.pujaWindowDuration(ghatis, kalaName) ??
                '$ghatis ghatikas around $kalaName',
            locale,
          ),
        );
      },
      loading: () => _pujaWindowCard(
        context: context,
        highContrast: highContrast,
        kalaName: pujaKalaLabel(kala, l10n).toUpperCase(),
        windowLabel: l10n?.pujaWindow ?? 'PUJA WINDOW',
      ),
      error: (err, stack) => const SizedBox.shrink(),
    );
  }
}

/// Fasting / Vrat surface card (tithi-sheet surface style) with the paran
/// line when the breaking time is critical.
class _EventFasting extends ConsumerWidget {
  const _EventFasting({
    required this.festival,
    required this.panchang,
    required this.content,
    required this.paranRule,
    required this.themeColor,
  });

  final Festival festival;
  final PanchangData? panchang;
  final EventSheetContent? content;
  final String? paranRule;
  final Color themeColor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Locals promote null checks below (fields don't promote).
    final dayPanchang = panchang;
    final sheetContent = content;
    final rule = paranRule;
    final fasting = festival.rituals.fasting;
    final showFasting = fasting != null && fasting.isNotEmpty;
    return SheetSurfaceCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showFasting)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    fasting,
                    style: context.textTheme.bodyMedium?.copyWith(height: 1.5),
                  ),
                ),
              ],
            ),
          if (rule != null &&
              dayPanchang != null &&
              sheetContent != null) ...[
            if (showFasting) ...[
              const SizedBox(height: 8),
              Divider(
                color: context.colors.onSurface.withValues(alpha: 0.15),
              ),
              const SizedBox(height: 8),
            ],
            _EventParan(
              festival: festival,
              panchang: dayPanchang,
              content: sheetContent,
              paranRule: rule,
            ),
          ],
        ],
      ),
    );
  }
}

/// Paran (fast-breaking) block: red label plus reason and time. Ranges
/// render almanac-style ("8:07 – 8:55 PM"); the puja kala shows its end
/// approximately ("~12:46 AM"). Hides when the instant can't be resolved
/// (Kshaya span, no moonrise).
class _EventParan extends ConsumerWidget {
  const _EventParan({
    required this.festival,
    required this.panchang,
    required this.content,
    required this.paranRule,
  });

  final Festival festival;
  final PanchangData panchang;
  final EventSheetContent content;
  final String paranRule;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final locale = l10n?.localeName ?? 'en';
    final coords = ref.watch(resolvedCoordinatesProvider);
    final warnRed = AppTheme.warningTextColor(
      Theme.of(context).brightness == Brightness.dark,
    );

    Widget paranBlock({required String reason, required String detail}) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            l10n?.paranLabel ?? 'Paran (breaking the fast):',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: warnRed,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '$reason — $detail',
            style: context.textTheme.bodyMedium?.copyWith(
              fontSize: 15,
              height: 1.5,
              color: context.colors.onSurface.withValues(alpha: 0.9),
            ),
          ),
        ],
      );
    }

    // Almanac-style range anchored on its own start day, so next-morning
    // spans stay short ("5:29 – 7:29 AM") while midnight crossings keep
    // both periods (and the far date when off-day).
    String range(DateTime start, DateTime end) =>
        sheetTimeRange(start, end, start, locale);
    String jm(DateTime instant) =>
        formatLocalizedDate(instant, 'jm', locale);

    switch (paranRule) {
      case 'moonrise':
        // 48-minute grace window from the rise itself.
        final rise = _pujaMoonrise(
          date: panchang.date,
          latitude: coords.latitude,
          longitude: coords.longitude,
        );
        if (rise == null) return const SizedBox.shrink();
        return paranBlock(
          reason: l10n?.paranReasonMoonrise ?? 'after moonrise',
          detail: range(rise, rise.add(const Duration(minutes: 48))),
        );
      case 'next_sunrise':
        // Typical morning eat window: two hours from sunrise.
        final rise = SunriseCalculator.calculateSunriseIST(
          date: panchang.date.add(const Duration(days: 1)),
          latitude: coords.latitude,
          longitude: coords.longitude,
        );
        return paranBlock(
          reason: l10n?.paranReasonSunrise ?? 'after sunrise',
          detail: range(rise, rise.add(const Duration(hours: 2))),
        );
      case 'after_puja_kala':
        final kala = normalizedPujaKala(festival);
        if (kala == null) return const SizedBox.shrink();
        final kalaName = pujaKalaLabel(kala, l10n);
        final reason =
            l10n?.paranReasonPujaKala(kalaName) ?? 'after the $kalaName puja';
        if (!isPujaWindowKala(kala)) {
          final instant = resolvePujaInstant(
            kala: kala,
            sunrise: panchang.sunrise,
            sunset: panchang.sunset,
          );
          if (instant == null) return const SizedBox.shrink();
          return paranBlock(reason: reason, detail: '~${jm(instant)}');
        }
        // Window kala: synchronous unless the sandhi (or a flagged clip)
        // needs the observed tithi end.
        DateTime? moonrise;
        DateTime? nextSunrise;
        if (kala == 'moonrise') {
          moonrise = _pujaMoonrise(
            date: panchang.date,
            latitude: coords.latitude,
            longitude: coords.longitude,
          );
          if (moonrise == null) return const SizedBox.shrink();
        } else if (kala != 'sandhi_junction') {
          if (panchang.sunrise == null || panchang.sunset == null) {
            return const SizedBox.shrink();
          }
          nextSunrise = SunriseCalculator.calculateSunriseIST(
            date: panchang.date.add(const Duration(days: 1)),
            latitude: coords.latitude,
            longitude: coords.longitude,
          );
        }
        if (kala != 'sandhi_junction' &&
            !festival.panchangRules.clipToTithi) {
          final span = resolvePujaKala(
            kala: kala,
            date: panchang.date,
            sunrise: panchang.sunrise,
            sunset: panchang.sunset,
            nextSunrise: nextSunrise,
            moonrise: moonrise,
            tithiEnd: null,
            clipToTithi: false,
          );
          if (span == null) return const SizedBox.shrink();
          return paranBlock(reason: reason, detail: '~${jm(span.end)}');
        }
        final timingsAsync = ref.watch(
          tithiTimingsProvider((
            date: panchang.date,
            tithiIndex: content.observedIndex,
            latitude: coords.latitude,
            longitude: coords.longitude,
          )),
        );
        return timingsAsync.when(
          data: (timings) {
            if (timings == null) return const SizedBox.shrink();
            final span = resolvePujaKala(
              kala: kala,
              date: panchang.date,
              sunrise: panchang.sunrise,
              sunset: panchang.sunset,
              // Null unless the pre-pass computed it for m/n/p: moonrise
              // and sandhi spans ignore it, so no wasted calculation.
              nextSunrise: nextSunrise,
              moonrise: moonrise,
              tithiEnd: timings.end,
              clipToTithi: festival.panchangRules.clipToTithi,
            );
            if (span == null) return const SizedBox.shrink();
            return paranBlock(reason: reason, detail: '~${jm(span.end)}');
          },
          loading: () => const SizedBox.shrink(),
          error: (err, stack) => const SizedBox.shrink(),
        );
      case 'dwadashi_window':
        // Ekadashi fasts break the next morning inside Dwadashi: Hari
        // Vasara (the first quarter of the day) is avoided, so the window
        // runs from sunrise + D/4 until Dwadashi ends. The observed index
        // + 1 is the same-paksha Dwadashi (index 30 has no successor, so a
        // misconfigured rule hides instead of querying index 31); Kshaya
        // hides the line.
        if (content.observedIndex >= 30) return const SizedBox.shrink();
        final nextDay = panchang.date.add(const Duration(days: 1));
        final rise = SunriseCalculator.calculateSunriseIST(
          date: nextDay,
          latitude: coords.latitude,
          longitude: coords.longitude,
        );
        final set = SunriseCalculator.calculateSunsetIST(
          date: nextDay,
          latitude: coords.latitude,
          longitude: coords.longitude,
        );
        final start = rise.add(
          Duration(
            microseconds: set.difference(rise).inMicroseconds ~/ 4,
          ),
        );
        final dwadashiAsync = ref.watch(
          tithiTimingsProvider((
            date: nextDay,
            tithiIndex: content.observedIndex + 1,
            latitude: coords.latitude,
            longitude: coords.longitude,
          )),
        );
        return dwadashiAsync.when(
          data: (timings) {
            if (timings == null || !timings.end.isAfter(start)) {
              return const SizedBox.shrink();
            }
            return paranBlock(
              reason: l10n?.paranReasonDwadashi ?? 'in the Dwadashi window',
              detail: range(start, timings.end),
            );
          },
          loading: () => const SizedBox.shrink(),
          error: (err, stack) => const SizedBox.shrink(),
        );
      default:
        return const SizedBox.shrink();
    }
  }
}

/// Numbered ritual-steps timeline surface card.
class _EventRituals extends StatelessWidget {
  const _EventRituals({required this.festival, required this.themeColor});

  final Festival festival;
  final Color themeColor;

  @override
  Widget build(BuildContext context) {
    return SheetSurfaceCard(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Column(
        children: festival.rituals.steps.asMap().entries.map((entry) {
          final index = entry.key;
          final ritual = entry.value;
          final totalSteps = festival.rituals.steps.length;

          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Column(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: themeColor.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: themeColor.withValues(alpha: 0.8),
                          width: 1.5,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '${index + 1}',
                        style: context.textTheme.bodySmall?.copyWith(
                          color: themeColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    if (index < totalSteps - 1)
                      Expanded(
                        child: Container(
                          width: 1.5,
                          color: themeColor.withValues(alpha: 0.25),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      bottom: index < totalSteps - 1 ? 20.0 : 4.0,
                    ),
                    child: Text(
                      ritual,
                      style: context.textTheme.bodyMedium?.copyWith(
                        fontSize: 15,
                        height: 1.5,
                        color: context.colors.onSurface.withValues(alpha: 0.9),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

/// Centered serif mantra surface card with accent border.
class _EventMantra extends StatelessWidget {
  const _EventMantra({required this.festival, required this.themeColor});

  final Festival festival;
  final Color themeColor;

  @override
  Widget build(BuildContext context) {
    return SheetSurfaceCard(
      border: Border.all(color: themeColor.withValues(alpha: 0.25)),
      child: Text(
        festival.rituals.mantra,
        style: context.textTheme.bodyLarge?.copyWith(
          fontFamily: 'serif',
          fontSize: 15,
          height: 1.8,
          color: themeColor,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}
