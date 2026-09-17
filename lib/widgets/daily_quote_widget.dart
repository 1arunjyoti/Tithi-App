import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';

import '../l10n/app_localizations.dart';
import '../models/shloka.dart';
import '../providers/panchang_provider.dart';
import '../services/share_file/share_file.dart';
import '../services/shloka_service.dart';
import '../theme/app_theme.dart';
import 'shloka_share_card.dart';

// Verse shown on the Daily Wisdom card for one day, plus display metadata.
class DailyWisdom {
  final Shloka shloka;
  final DateTime date;
  final int dayOffset;
  final String? festivalName;

  const DailyWisdom({
    required this.shloka,
    required this.date,
    this.dayOffset = 0,
    this.festivalName,
  });
}

// Day offset from today for browsing past/future verses. 0 = today.
final quoteDayOffsetProvider = StateProvider.autoDispose<int>((ref) => 0);

/// Browsing bounds in days. Each new date resolves its panchang from the
/// Hive-cached month batches, so the range stays modest.
const int quoteMaxDayOffset = 30;

// Provider for the verse of the selected day.
final dailyShlokaProvider = FutureProvider.autoDispose<DailyWisdom?>((
  ref,
) async {
  final service = ShlokaService();
  await service.init();

  final offset = ref.watch(quoteDayOffsetProvider);
  final now = DateTime.now();
  final date = DateTime(now.year, now.month, now.day + offset);
  final panchang = await ref.watch(panchangForDateProvider(date).future);
  final festivals = panchang.festivals;
  final shloka = service.getShlokaForDate(
    date,
    festivalIds: festivals.map((festival) => festival.id).toList(),
  );
  if (shloka == null) return null;
  String? festivalName;
  for (final festival in festivals) {
    if (shloka.festivalIds.contains(festival.id)) {
      festivalName = festival.name;
      break;
    }
  }
  return DailyWisdom(
    shloka: shloka,
    date: date,
    dayOffset: offset,
    festivalName: festivalName,
  );
});

/// Short day label for the card header: Today / Yesterday / Tomorrow / Mar 5.
String quoteDayLabel(DateTime date, int dayOffset, [AppLocalizations? l10n]) {
  if (dayOffset == 0) return l10n?.today ?? 'Today';
  if (dayOffset == -1) return l10n?.yesterday ?? 'Yesterday';
  if (dayOffset == 1) return l10n?.tomorrow ?? 'Tomorrow';
  return DateFormat.MMMd().format(date);
}

/// Steps the browsed day into the past, keeping the offset within bounds and
/// hiding any revealed extra translations (they belong to the previous
/// verse). Future verses are intentionally unavailable — only today and
/// earlier days can be revisited.
void stepQuoteDay(WidgetRef ref, int offset, int delta) {
  final next = (offset + delta).clamp(-quoteMaxDayOffset, 0);
  if (next == offset) return;
  ref.read(quoteShowAllTranslationsProvider.notifier).state = false;
  ref.read(quoteDayOffsetProvider.notifier).state = next;
}

// UI State provider for collapse/expand
// Using autoDispose so it resets when leaving the screen/rebuilding
final quoteExpandedProvider = StateProvider.autoDispose<bool>((ref) => false);

// UI State for revealing every available translation in the expanded view.
// Also autoDispose; explicitly reset when the card is collapsed.
final quoteShowAllTranslationsProvider = StateProvider.autoDispose<bool>(
  (ref) => false,
);

/// Builds shareable text for a shloka.
///
/// Collapsed shares the always-visible fields (Sanskrit + transliteration +
/// source); expanded also includes translation(s): just the locale-appropriate
/// one, or every available translation when [showAll] is true. Pass [l10n] so
/// the attribution line is localized; it falls back to English when null
/// (e.g. in unit tests with no BuildContext).
String buildShlokaShareText(
  Shloka shloka, {
  required bool expanded,
  bool hindiFirst = false,
  bool showAll = false,
  AppLocalizations? l10n,
}) {
  final parts = <String>[shloka.text];
  if (shloka.transliteration.isNotEmpty) {
    parts.add(shloka.transliteration);
  }
  if (expanded) {
    if (showAll) {
      final primary = pickShlokaTranslation(shloka, hindiFirst: hindiFirst);
      if (primary != null) parts.add(primary);
      final secondary = otherShlokaTranslation(shloka, hindiFirst: hindiFirst);
      if (secondary != null && secondary != primary) parts.add(secondary);
    } else {
      final translation = pickShlokaTranslation(shloka, hindiFirst: hindiFirst);
      if (translation != null) {
        parts.add(translation);
      }
    }
  }
  parts.add('— ${shloka.source}');
  if (shloka.themes.isNotEmpty) {
    parts.add(shloka.themes.map((t) => '#$t').join(' '));
  }
  parts.add(l10n?.sharedViaTithiApp ?? 'Shared via Tithi App');
  return parts.join('\n\n');
}

/// Picks the translation matching the UI language.
///
/// Hindi UI gets the Hindi translation, everything else gets English. Each
/// falls back to the other language when the preferred one is missing (38
/// entries have no Hindi), so the expanded view is never empty when at least
/// one translation exists. Returns null only when both are missing.
String? pickShlokaTranslation(Shloka shloka, {required bool hindiFirst}) {
  final hindi = shloka.hindiTranslation;
  final hasHindi = hindi != null && hindi.isNotEmpty;
  final hasEnglish = shloka.translation.isNotEmpty;
  if (hindiFirst) {
    if (hasHindi) return hindi;
    if (hasEnglish) return shloka.translation;
    return null;
  }
  if (hasEnglish) return shloka.translation;
  if (hasHindi) return hindi;
  return null;
}

/// Returns the non-primary translation when both English and Hindi exist,
/// otherwise null (nothing extra to reveal).
String? otherShlokaTranslation(Shloka shloka, {required bool hindiFirst}) {
  final hindi = shloka.hindiTranslation;
  final hasHindi = hindi != null && hindi.isNotEmpty;
  final hasEnglish = shloka.translation.isNotEmpty;
  if (!hasHindi || !hasEnglish) return null;
  final other = hindiFirst ? shloka.translation : hindi;
  return other == pickShlokaTranslation(shloka, hindiFirst: hindiFirst)
      ? null
      : other;
}

/// Shares the verse as a branded image card, mirroring [ShareService].
///
/// Falls back to text sharing on web (no temp-file support) and when the
/// capture fails.
Future<void> shareWisdomAsImage(
  BuildContext context,
  Shloka shloka, {
  required bool hindiFirst,
  required bool showAll,
}) async {
  final l10n = AppLocalizations.of(context);
  Future<void> shareTextFallback() {
    return SharePlus.instance.share(
      ShareParams(
        text: buildShlokaShareText(
          shloka,
          expanded: true,
          hindiFirst: hindiFirst,
          showAll: showAll,
          l10n: l10n,
        ),
        subject: l10n?.dailyWisdom ?? 'Daily Wisdom',
      ),
    );
  }

  if (kIsWeb) {
    await shareTextFallback();
    return;
  }
  try {
    // Storage hygiene first: drop day-old share images so repeated
    // shares don't grow the temp directory without bound.
    await purgeOldShareImages();
    if (!context.mounted) return;
    final primary = pickShlokaTranslation(shloka, hindiFirst: hindiFirst);
    final secondary = showAll
        ? otherShlokaTranslation(shloka, hindiFirst: hindiFirst)
        : null;
    final translations = [
      if (primary != null)
        ShlokaShareTranslation(
          primary,
          isHindi: primary == shloka.hindiTranslation,
        ),
      if (secondary != null && secondary != primary)
        ShlokaShareTranslation(
          secondary,
          isHindi: secondary == shloka.hindiTranslation,
        ),
    ];
    final imageBytes = await ScreenshotController().captureFromWidget(
      Material(
        type: MaterialType.transparency,
        child: ShlokaShareCard(shloka: shloka, translations: translations),
      ),
      delay: const Duration(milliseconds: 100),
      context: context,
      pixelRatio: 3.0,
    );
    final imagePath = await saveImageToTemp(imageBytes, 'daily-wisdom');
    if (!context.mounted) return;
    if (imagePath == null) {
      await shareTextFallback();
      return;
    }
    await SharePlus.instance.share(
      ShareParams(
        text: l10n?.dailyWisdomShareMessage ?? 'Daily Wisdom — Tithi App',
        files: [XFile(imagePath, mimeType: 'image/png')],
      ),
    );
  } catch (_) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n?.couldNotCreateImage ?? 'Could not create image')));
  }
}

/// Bottom-sheet chooser for sharing the verse as an image card or as text,
/// following the app's sheet presentation (cf. WeatherSheet) with the
/// festival-gold row styling used across the home cards.
void _showShareOptions(
  BuildContext context, {
  required Shloka shloka,
  required bool expanded,
  required bool hindiFirst,
  required bool showAll,
}) {
  final l10n = AppLocalizations.of(context);
  final accent = AppTheme.festivalAccent(context);
  showModalBottomSheet(
    context: context,
    sheetAnimationStyle: AppTheme.sheetAnimationStyleOf(context),
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => Container(
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(
          top: BorderSide(color: accent.withValues(alpha: 0.3), width: 2),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle (weather-sheet style)
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: context.colors.onSurfaceVariant.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppTheme.festivalTileBackground(context),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  alignment: Alignment.center,
                  child: Icon(Icons.share_rounded, color: accent, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        l10n?.shareVerse ?? 'Share verse',
                        style: context.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: context.colors.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '— ${shloka.source}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.textTheme.bodySmall?.copyWith(
                          color: context.colors.onSurface.withValues(
                            alpha: AppTheme.contrastAlpha(context, 0.6),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _ShareOption(
              icon: Icons.image_outlined,
              title: l10n?.shareAsImage ?? 'Share as image',
              subtitle: l10n?.verseCardPicture ?? 'Verse card picture',
              onTap: () {
                Navigator.of(sheetContext).pop();
                shareWisdomAsImage(
                  context,
                  shloka,
                  hindiFirst: hindiFirst,
                  showAll: showAll,
                );
              },
            ),
            const SizedBox(height: 8),
            _ShareOption(
              icon: Icons.short_text_rounded,
              title: l10n?.shareAsText ?? 'Share as text',
              subtitle: l10n?.verseWithTranslation ?? 'Verse with translation',
              onTap: () {
                Navigator.of(sheetContext).pop();
                SharePlus.instance.share(
                  ShareParams(
                    text: buildShlokaShareText(
                      shloka,
                      expanded: expanded,
                      hindiFirst: hindiFirst,
                      showAll: showAll,
                      l10n: l10n,
                    ),
                    subject: l10n?.dailyWisdom ?? 'Daily Wisdom',
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
            _ShareOption(
              icon: Icons.copy_rounded,
              title: l10n?.copyText ?? 'Copy text',
              subtitle: l10n?.copyVerseToClipboard ?? 'Copy verse to clipboard',
              onTap: () async {
                Navigator.of(sheetContext).pop();
                String? copyError;
                try {
                  await Clipboard.setData(
                    ClipboardData(
                      text: buildShlokaShareText(
                        shloka,
                        expanded: expanded,
                        hindiFirst: hindiFirst,
                        showAll: showAll,
                        l10n: l10n,
                      ),
                    ),
                  );
                } catch (_) {
                  copyError = l10n?.couldNotCopyVerse ?? 'Could not copy verse';
                }
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(copyError ?? (l10n?.verseCopied ?? 'Verse copied')),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                }
              },
            ),
          ],
        ),
      ),
    ),
  );
}

/// One action row in the share sheet: gold glyph tile, title/subtitle and a
/// chevron, on the shared festival-row surface so the sheet matches the
/// home cards.
class _ShareOption extends StatelessWidget {
  const _ShareOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = AppTheme.festivalAccent(context);
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: Ink(
        decoration: AppTheme.festivalRowDecoration(context),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppTheme.festivalTileBackground(context),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  alignment: Alignment.center,
                  child: Icon(icon, color: accent, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: context.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: context.colors.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: context.textTheme.bodySmall?.copyWith(
                          color: context.colors.onSurface.withValues(
                            alpha: AppTheme.contrastAlpha(context, 0.6),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.chevron_right_rounded,
                  color: context.colors.onSurface.withValues(
                    alpha: AppTheme.contrastAlpha(context, 0.4),
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

class DailyQuoteWidget extends ConsumerWidget {
  const DailyQuoteWidget({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final shlokaAsync = ref.watch(dailyShlokaProvider);
    // Hindi UI shows the Hindi translation, all other locales (en/bn/sa)
    // show English — same convention as EclipseScreen.
    final hindiFirst = Localizations.localeOf(context).languageCode == 'hi';

    // Hero-card pattern: size glides from a pinned top edge (first launch,
    // day browse, expand/collapse) while verse swaps fade in with no
    // stacking, so rapid taps settle calmly instead of snapping.
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
        child: KeyedSubtree(
          key: ValueKey(
            shlokaAsync.valueOrNull == null
                ? 'empty'
                : 'wisdom-${shlokaAsync.valueOrNull!.shloka.id}-'
                      '${shlokaAsync.valueOrNull!.dayOffset}',
          ),
          child: shlokaAsync.when(
            data: (wisdom) {
              if (wisdom == null) return const SizedBox.shrink();
              return _buildCard(
                context,
                ref,
                wisdom,
                hindiFirst: hindiFirst,
                l10n: l10n,
              );
            },
            // Keep the previous verse mounted while another day loads (or
            // when a reload fails) so browsing days doesn't flash the card
            // away.
            loading: () {
              final previous = shlokaAsync.valueOrNull;
              if (previous == null) return const SizedBox.shrink();
              return _buildCard(
                context,
                ref,
                previous,
                hindiFirst: hindiFirst,
                l10n: l10n,
              );
            },
            error: (_, _) {
              final previous = shlokaAsync.valueOrNull;
              if (previous == null) return const SizedBox.shrink();
              return _buildCard(
                context,
                ref,
                previous,
                hindiFirst: hindiFirst,
                l10n: l10n,
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildCard(
    BuildContext context,
    WidgetRef ref,
    DailyWisdom wisdom, {
    required bool hindiFirst,
    required AppLocalizations? l10n,
  }) {
    final shloka = wisdom.shloka;
    final isExpanded = ref.watch(quoteExpandedProvider);
    final showAll = ref.watch(quoteShowAllTranslationsProvider);
    final offset = ref.watch(quoteDayOffsetProvider);
    final atPastBound = offset <= -quoteMaxDayOffset;
    // Today is the upper bound: users can step forward to the current
    // verse, but never into future days.
    final atToday = offset >= 0;

    final translation = pickShlokaTranslation(shloka, hindiFirst: hindiFirst);
    final showingHindi =
        translation != null && translation == shloka.hindiTranslation;
    final secondaryTranslation = otherShlokaTranslation(
      shloka,
      hindiFirst: hindiFirst,
    );
    final showingSecondaryHindi =
        secondaryTranslation != null &&
        secondaryTranslation == shloka.hindiTranslation;

    // Label comes from the loaded verse, not the live offset: during reload
    // the offset already points at the next day while this stale verse is
    // still shown, which would flash a wrong label.
    final dayLabel = quoteDayLabel(wisdom.date, wisdom.dayOffset, l10n);

    void jumpToToday() {
      ref.read(quoteShowAllTranslationsProvider.notifier).state = false;
      ref.read(quoteDayOffsetProvider.notifier).state = 0;
    }

    void toggleExpanded() {
      if (isExpanded) {
        // Collapsing hides the extra translations too.
        ref.read(quoteShowAllTranslationsProvider.notifier).state = false;
      }
      ref.read(quoteExpandedProvider.notifier).state = !isExpanded;
    }

    return Container(
      key: ValueKey('daily-quote-${shloka.id}-${wisdom.dayOffset}'),
      // Shared home gutter (matches CalendarWidget exactly).
      margin: const EdgeInsets.symmetric(horizontal: AppTheme.homeCardGutter),
      decoration: AppTheme.glassmorphism(context: context, ref: ref),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _WisdomHeader(
            dayLabel: dayLabel,
            showTodayReset: offset != 0,
            onJumpToToday: jumpToToday,
            onShare: () => _showShareOptions(
              context,
              shloka: shloka,
              expanded: isExpanded,
              hindiFirst: hindiFirst,
              showAll: showAll,
            ),
            l10n: l10n,
          ),

          // Festival caption, shown when the verse was picked for a festival.
          if (wisdom.festivalName != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
              child: Center(child: _FestivalChip(name: wisdom.festivalName!)),
            ),

          // Verse body: ornament, Sanskrit, transliteration, translation.
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: Column(
              children: [
                ExcludeSemantics(
                  child: Icon(
                    Icons.format_quote_rounded,
                    size: 40,
                    color: AppTheme.festivalAccent(
                      context,
                    ).withValues(alpha: 0.35),
                  ),
                ),
                // Sanskrit Text (Always visible)
                Text(
                  shloka.text,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.martel(
                    fontSize: 19,
                    height: 1.6,
                    fontWeight: FontWeight.w600,
                    color: context.colors.onSurface,
                  ),
                ),

                // Transliteration (Always visible, muted)
                if (shloka.transliteration.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    shloka.transliteration,
                    textAlign: TextAlign.center,
                    style: context.textTheme.bodySmall?.copyWith(
                      color: context.colors.onSurface.withValues(
                        alpha: AppTheme.contrastAlpha(context, 0.6),
                      ),
                      fontStyle: FontStyle.italic,
                      height: 1.4,
                    ),
                  ),
                ],

                // Collapsible Translation (locale-driven, with fallback)
                AnimatedCrossFade(
                  firstChild: const SizedBox(width: double.infinity),
                  secondChild: Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: _TranslationPanel(
                      translation: translation,
                      showingHindi: showingHindi,
                      secondaryTranslation: secondaryTranslation,
                      showingSecondaryHindi: showingSecondaryHindi,
                      showAll: showAll,
                      l10n: l10n,
                      themes: shloka.themes,
                      onToggleShowAll: () {
                        ref
                                .read(quoteShowAllTranslationsProvider.notifier)
                                .state =
                            !showAll;
                      },
                    ),
                  ),
                  crossFadeState: isExpanded
                      ? CrossFadeState.showSecond
                      : CrossFadeState.showFirst,
                  duration: AppTheme.animationDuration(
                    context,
                    const Duration(milliseconds: 300),
                  ),
                ),

                // Source attribution (always visible)
                const SizedBox(height: 12),
                _SourceLine(source: shloka.source),
              ],
            ),
          ),

          // Bottom control bar: browse days + expand toggle.
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: _ControlBar(
              atPastBound: atPastBound,
              atToday: atToday,
              isExpanded: isExpanded,
              onPrevious: () => stepQuoteDay(ref, offset, -1),
              onNext: () => stepQuoteDay(ref, offset, 1),
              onToggleExpanded: toggleExpanded,
            ),
          ),
        ],
      ),
    );
  }
}

/// Card header: gold-tinted glyph tile (same language as the festival rows),
/// bold title with the browsed-day pill underneath, a filled "Today" reset
/// while browsing, and a tinted circular share button.
class _WisdomHeader extends StatelessWidget {
  const _WisdomHeader({
    required this.dayLabel,
    required this.showTodayReset,
    required this.onJumpToToday,
    required this.onShare,
    required this.l10n,
  });

  final String dayLabel;
  final bool showTodayReset;
  final VoidCallback onJumpToToday;
  final VoidCallback onShare;
  final AppLocalizations? l10n;

  @override
  Widget build(BuildContext context) {
    // Festival-gold accent shared with the Festivals & Events rows and the
    // calendar's festival marks — NOT scheme primary (purple in the Krishna
    // theme) — so this card sits visually with its home-screen neighbours.
    final accent = AppTheme.festivalAccent(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 0),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppTheme.festivalTileBackground(context),
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.center,
            child: Icon(Icons.auto_stories_rounded, size: 22, color: accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l10n?.dailyWisdom ?? 'Daily Wisdom',
                  style: context.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: context.colors.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    dayLabel,
                    style: context.textTheme.labelSmall?.copyWith(
                      color: accent,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (showTodayReset) ...[
            FilledButton(
              onPressed: onJumpToToday,
              style: FilledButton.styleFrom(
                backgroundColor: accent,
                // Shared helper: white-on-deep-gold (light),
                // near-black-on-gold (dark), onPrimary in high contrast.
                foregroundColor: AppTheme.onFestivalAccent(context),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                minimumSize: const Size(0, 32),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
                textStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              child: Text(l10n?.today ?? 'Today'),
            ),
            const SizedBox(width: 8),
          ],
          IconButton(
            onPressed: onShare,
            tooltip: l10n?.share ?? 'Share',
            icon: const Icon(Icons.share_rounded, size: 18),
            color: context.colors.onSurface.withValues(
              alpha: AppTheme.contrastAlpha(context, 0.7),
            ),
            style: IconButton.styleFrom(
              backgroundColor: accent.withValues(alpha: 0.1),
              minimumSize: const Size(36, 36),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ],
      ),
    );
  }
}

/// Centered festival pill noting which observance the verse was chosen for.
class _FestivalChip extends StatelessWidget {
  const _FestivalChip({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final accent = AppTheme.festivalAccent(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.celebration_rounded, size: 14, color: accent),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              l10n?.chosenForFestival(name) ?? 'Chosen for $name',
              overflow: TextOverflow.ellipsis,
              style: context.textTheme.labelSmall?.copyWith(
                color: accent,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Soft tinted panel holding the translation(s), the show-more toggle and
/// the theme chips. Tint/border alphas step up in high contrast so the panel
/// keeps its edge on flattened solid backgrounds.
class _TranslationPanel extends StatelessWidget {
  const _TranslationPanel({
    required this.translation,
    required this.showingHindi,
    required this.secondaryTranslation,
    required this.showingSecondaryHindi,
    required this.showAll,
    required this.l10n,
    required this.themes,
    required this.onToggleShowAll,
  });

  final String? translation;
  final bool showingHindi;
  final String? secondaryTranslation;
  final bool showingSecondaryHindi;
  final bool showAll;
  final AppLocalizations? l10n;
  final List<String> themes;
  final VoidCallback onToggleShowAll;

  @override
  Widget build(BuildContext context) {
    final accent = AppTheme.festivalAccent(context);
    final highContrast = AppTheme.highContrastOf(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: highContrast ? 0.12 : 0.07),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: accent.withValues(alpha: highContrast ? 0.5 : 0.14),
        ),
      ),
      child: Column(
        children: [
          if (translation != null)
            _TranslationText(text: translation!, isHindi: showingHindi),
          // Reveal every available translation on demand.
          if (secondaryTranslation != null) ...[
            const SizedBox(height: 10),
            if (showAll) ...[
              _TranslationText(
                text: secondaryTranslation!,
                isHindi: showingSecondaryHindi,
              ),
              const SizedBox(height: 4),
            ],
            TextButton(
              onPressed: onToggleShowAll,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
              ),
              child: Text(
                showAll
                    ? (l10n?.showLess ?? 'Show less')
                    : (l10n?.showMoreTranslations ?? 'Show more translations'),
              ),
            ),
          ],
          // Theme chips (expanded only)
          if (themes.isNotEmpty) ...[
            const SizedBox(height: 10),
            _ThemeChips(themes: themes, accent: accent),
          ],
        ],
      ),
    );
  }
}

/// Centered source attribution flanked by hairlines (manuscript style).
class _SourceLine extends StatelessWidget {
  const _SourceLine({required this.source});

  final String source;

  @override
  Widget build(BuildContext context) {
    final accent = AppTheme.festivalAccent(context);
    Widget hairline() => Container(
      width: 28,
      height: 1.5,
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(1),
      ),
    );
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        hairline(),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            '— $source',
            textAlign: TextAlign.center,
            style: context.textTheme.labelMedium?.copyWith(
              color: accent,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: 8),
        hairline(),
      ],
    );
  }
}

/// Bottom pill bar: previous-day / expand-toggle / next-day. The toggle's
/// visible label names its state (also what screen readers announce),
/// localized the same way as the translations toggle.
class _ControlBar extends StatelessWidget {
  const _ControlBar({
    required this.atPastBound,
    required this.atToday,
    required this.isExpanded,
    required this.onPrevious,
    required this.onNext,
    required this.onToggleExpanded,
  });

  final bool atPastBound;
  final bool atToday;
  final bool isExpanded;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onToggleExpanded;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final accent = AppTheme.festivalAccent(context);
    final onSurface = context.colors.onSurface;
    final highContrast = AppTheme.highContrastOf(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: onSurface.withValues(alpha: highContrast ? 0.06 : 0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: onSurface.withValues(alpha: highContrast ? 0.3 : 0.08),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left_rounded),
            tooltip: l10n?.previousDaysVerse ?? "Previous day's verse",
            onPressed: atPastBound ? null : onPrevious,
            color: accent.withValues(alpha: atPastBound ? 0.25 : 0.75),
            style: IconButton.styleFrom(
              minimumSize: const Size(44, 40),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
          TextButton.icon(
            onPressed: onToggleExpanded,
            icon: Icon(
              isExpanded
                  ? Icons.keyboard_arrow_up_rounded
                  : Icons.keyboard_arrow_down_rounded,
              color: accent,
              size: 20,
            ),
            label: Text(
              isExpanded
                  ? (l10n?.hideTranslation ?? 'Hide translation')
                  : (l10n?.showTranslation ?? 'Show translation'),
              style: context.textTheme.labelLarge?.copyWith(
                color: accent,
                fontWeight: FontWeight.w700,
              ),
            ),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              minimumSize: const Size(0, 40),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right_rounded),
            tooltip: l10n?.nextDaysVerse ?? "Next day's verse",
            onPressed: atToday ? null : onNext,
            color: accent.withValues(alpha: atToday ? 0.25 : 0.75),
            style: IconButton.styleFrom(
              minimumSize: const Size(44, 40),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ],
      ),
    );
  }
}

/// A single translation paragraph. Hindi renders in Martel (Devanagari),
/// English in italic body text — matching the card's established styles.
class _TranslationText extends StatelessWidget {
  const _TranslationText({required this.text, required this.isHindi});

  final String text;
  final bool isHindi;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: TextAlign.center,
      style: isHindi
          ? GoogleFonts.martel(
              fontSize: 15,
              height: 1.5,
              fontWeight: FontWeight.w500,
              color: context.colors.onSurface.withValues(alpha: 0.9),
            )
          : context.textTheme.bodyMedium?.copyWith(
              color: context.colors.onSurface.withValues(alpha: 0.8),
              fontStyle: FontStyle.italic,
              height: 1.4,
            ),
    );
  }
}

/// Wraps theme tags as `#tag` stadium pills. Caps visible chips at 3 with a
/// `+n` overflow indicator so long tag lists don't stretch the card.
class _ThemeChips extends StatelessWidget {
  const _ThemeChips({required this.themes, required this.accent});

  final List<String> themes;
  final Color accent;

  static const int _maxVisible = 3;

  @override
  Widget build(BuildContext context) {
    final visible = themes.take(_maxVisible).toList();
    final overflow = themes.length - visible.length;
    Widget chip(String label, {bool muted = false}) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: muted ? 0.06 : 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withValues(alpha: 0.25)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: accent,
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final theme in visible) chip('#$theme'),
        if (overflow > 0) chip('+$overflow', muted: true),
      ],
    );
  }
}
