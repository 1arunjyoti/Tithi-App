import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
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
String quoteDayLabel(DateTime date, int dayOffset) {
  if (dayOffset == 0) return 'Today';
  if (dayOffset == -1) return 'Yesterday';
  if (dayOffset == 1) return 'Tomorrow';
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
/// one, or every available translation when [showAll] is true.
String buildShlokaShareText(
  Shloka shloka, {
  required bool expanded,
  bool hindiFirst = false,
  bool showAll = false,
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
  parts.add('Shared via Tithi App');
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
  Future<void> shareTextFallback() {
    return SharePlus.instance.share(
      ShareParams(
        text: buildShlokaShareText(
          shloka,
          expanded: true,
          hindiFirst: hindiFirst,
          showAll: showAll,
        ),
        subject: 'Daily Wisdom',
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
        text: 'Daily Wisdom — Tithi App',
        files: [XFile(imagePath, mimeType: 'image/png')],
      ),
    );
  } catch (_) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Could not create image')));
  }
}

/// Bottom-sheet chooser for sharing the verse as an image card or as text,
/// following the app's sheet presentation (cf. WeatherSheet).
void _showShareOptions(
  BuildContext context, {
  required Shloka shloka,
  required bool expanded,
  required bool hindiFirst,
  required bool showAll,
}) {
  showModalBottomSheet(
    context: context,
    sheetAnimationStyle: AppTheme.sheetAnimationStyleOf(context),
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => Container(
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle (weather-sheet style)
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: context.colors.onSurfaceVariant.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Text(
              'Share verse',
              style: context.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: context.colors.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '— ${shloka.source}',
              style: context.textTheme.bodySmall?.copyWith(
                color: context.colors.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 16),
            _ShareOption(
              icon: Icons.image_outlined,
              title: 'Share as image',
              subtitle: 'Verse card picture',
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
            _ShareOption(
              icon: Icons.short_text_rounded,
              title: 'Share as text',
              subtitle: 'Verse with translation',
              onTap: () {
                Navigator.of(sheetContext).pop();
                SharePlus.instance.share(
                  ShareParams(
                    text: buildShlokaShareText(
                      shloka,
                      expanded: expanded,
                      hindiFirst: hindiFirst,
                      showAll: showAll,
                    ),
                    subject: 'Daily Wisdom',
                  ),
                );
              },
            ),
            _ShareOption(
              icon: Icons.copy_rounded,
              title: 'Copy text',
              subtitle: 'Copy verse to clipboard',
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
                      ),
                    ),
                  );
                } catch (_) {
                  copyError = 'Could not copy verse';
                }
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(copyError ?? 'Verse copied'),
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

/// One action row in the share sheet: tinted icon tile (theme-chip style)
/// plus title and subtitle, following the settings picker item pattern.
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
    return Material(
      color: Colors.transparent,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: context.colors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: context.colors.primary, size: 22),
        ),
        title: Text(
          title,
          style: context.textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.w600,
            color: context.colors.onSurface,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: context.textTheme.bodySmall?.copyWith(
            color: context.colors.onSurface.withValues(alpha: 0.6),
          ),
        ),
        onTap: onTap,
      ),
    );
  }
}

class DailyQuoteWidget extends ConsumerWidget {
  const DailyQuoteWidget({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shlokaAsync = ref.watch(dailyShlokaProvider);
    // Hindi UI shows the Hindi translation, all other locales (en/bn/sa)
    // show English — same convention as EclipseScreen.
    final hindiFirst = Localizations.localeOf(context).languageCode == 'hi';

    return shlokaAsync.when(
      data: (wisdom) {
        if (wisdom == null) return const SizedBox.shrink();
        return _buildCard(context, ref, wisdom, hindiFirst: hindiFirst);
      },
      // Keep the previous verse mounted while another day loads (or when a
      // reload fails) so browsing days doesn't flash the card away.
      loading: () {
        final previous = shlokaAsync.valueOrNull;
        if (previous == null) return const SizedBox.shrink();
        return _buildCard(context, ref, previous, hindiFirst: hindiFirst);
      },
      error: (_, _) {
        final previous = shlokaAsync.valueOrNull;
        if (previous == null) return const SizedBox.shrink();
        return _buildCard(context, ref, previous, hindiFirst: hindiFirst);
      },
    );
  }

  Widget _buildCard(
    BuildContext context,
    WidgetRef ref,
    DailyWisdom wisdom, {
    required bool hindiFirst,
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

    return Container(
      key: ValueKey('daily-quote-${shloka.id}-${wisdom.dayOffset}'),
      // Match CalendarWidget margin exactly (horizontal 12)
      margin: const EdgeInsets.symmetric(horizontal: 12),
      decoration: AppTheme.glassmorphism(context: context, ref: ref),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header & Share
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 2, 16, 0),
            child: Row(
              children: [
                Icon(
                  Icons.auto_stories_rounded,
                  size: 18,
                  color: context.colors.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Daily Wisdom',
                  style: context.textTheme.labelMedium?.copyWith(
                    color: context.colors.primary,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
                const Spacer(),

                // Jump back to today after browsing other days.
                if (offset != 0)
                  TextButton(
                    onPressed: () {
                      ref
                              .read(quoteShowAllTranslationsProvider.notifier)
                              .state =
                          false;
                      ref.read(quoteDayOffsetProvider.notifier).state = 0;
                    },
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                    ),
                    child: const Text('Today'),
                  ),

                // Share Button (image / text / copy chooser)
                IconButton(
                  icon: Icon(
                    Icons.share_rounded,
                    size: 18,
                    color: context.colors.onSurface.withValues(alpha: 0.6),
                  ),
                  onPressed: () {
                    _showShareOptions(
                      context,
                      shloka: shloka,
                      expanded: isExpanded,
                      hindiFirst: hindiFirst,
                      showAll: showAll,
                    );
                  },
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  tooltip: 'Share',
                ),
              ],
            ),
          ),

          // Festival caption, shown when the verse was picked for a festival.
          if (wisdom.festivalName != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.celebration_rounded,
                    size: 14,
                    color: context.colors.primary,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      'Chosen for ${wisdom.festivalName}',
                      overflow: TextOverflow.ellipsis,
                      style: context.textTheme.labelSmall?.copyWith(
                        color: context.colors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          //const Divider(height: 2),

          // Content Area
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 2, 20, 2),
            child: Column(
              children: [
                // Sanskrit Text (Always visible)
                Text(
                  shloka.text,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.martel(
                    fontSize: 18,
                    height: 1.6,
                    fontWeight: FontWeight.w600,
                    color: context.colors.onSurface,
                  ),
                ),

                // Transliteration (Always visible, muted)
                if (shloka.transliteration.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    shloka.transliteration,
                    textAlign: TextAlign.center,
                    style: context.textTheme.bodySmall?.copyWith(
                      color: context.colors.onSurface.withValues(alpha: 0.6),
                      fontStyle: FontStyle.italic,
                      height: 1.4,
                    ),
                  ),
                ],

                const SizedBox(height: 2),

                // Collapsible Translation (locale-driven, with fallback)
                AnimatedCrossFade(
                  firstChild: const SizedBox(width: double.infinity),
                  secondChild: Padding(
                    padding: const EdgeInsets.only(top: 8, bottom: 8),
                    child: Column(
                      children: [
                        if (translation != null)
                          _TranslationText(
                            text: translation,
                            isHindi: showingHindi,
                          ),
                        // Reveal every available translation on demand.
                        if (secondaryTranslation != null) ...[
                          const SizedBox(height: 8),
                          if (showAll) ...[
                            _TranslationText(
                              text: secondaryTranslation,
                              isHindi: showingSecondaryHindi,
                            ),
                            const SizedBox(height: 4),
                          ],
                          TextButton(
                            onPressed: () {
                              ref
                                      .read(
                                        quoteShowAllTranslationsProvider
                                            .notifier,
                                      )
                                      .state =
                                  !showAll;
                            },
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                              ),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              visualDensity: VisualDensity.compact,
                            ),
                            child: Text(
                              showAll
                                  ? (hindiFirst ? 'कम देखें' : 'Show less')
                                  : (hindiFirst
                                        ? 'और अनुवाद देखें'
                                        : 'Show more translations'),
                            ),
                          ),
                        ],
                        const SizedBox(height: 8),
                        // Theme chips (expanded only)
                        if (shloka.themes.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          _ThemeChips(
                            themes: shloka.themes,
                            primary: context.colors.primary,
                          ),
                        ],
                      ],
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
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    "— ${shloka.source}",
                    style: context.textTheme.labelSmall?.copyWith(
                      color: context.colors.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

                // Bottom navigation: browse days + expand toggle
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left_rounded),
                      tooltip: "Previous day's verse",
                      onPressed: atPastBound
                          ? null
                          : () => stepQuoteDay(ref, offset, -1),
                      color: context.colors.primary.withValues(
                        alpha: atPastBound ? 0.25 : 0.6,
                      ),
                      style: IconButton.styleFrom(
                        minimumSize: const Size(40, 36),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          // Label comes from the loaded verse, not the
                          // live offset: during reload the offset already
                          // points at the next day while this stale verse
                          // is still shown, which flashed a wrong label.
                          quoteDayLabel(wisdom.date, wisdom.dayOffset),
                          style: context.textTheme.labelSmall?.copyWith(
                            color: context.colors.onSurface.withValues(
                              alpha: 0.5,
                            ),
                            letterSpacing: 0.5,
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            if (isExpanded) {
                              // Collapsing hides the extra translations too.
                              ref
                                      .read(
                                        quoteShowAllTranslationsProvider
                                            .notifier,
                                      )
                                      .state =
                                  false;
                            }
                            // Toggle state via provider
                            ref.read(quoteExpandedProvider.notifier).state =
                                !isExpanded;
                          },
                          behavior: HitTestBehavior.opaque,
                          child: Padding(
                            padding: const EdgeInsets.all(2),
                            child: Icon(
                              isExpanded
                                  ? Icons.keyboard_arrow_up_rounded
                                  : Icons.keyboard_arrow_down_rounded,
                              color: context.colors.primary.withValues(
                                alpha: 0.6,
                              ),
                              size: 28,
                              semanticLabel: isExpanded
                                  ? 'Hide translation'
                                  : 'Show translation',
                            ),
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right_rounded),
                      tooltip: "Next day's verse",
                      onPressed: atToday
                          ? null
                          : () => stepQuoteDay(ref, offset, 1),
                      color: context.colors.primary.withValues(
                        alpha: atToday ? 0.25 : 0.6,
                      ),
                      style: IconButton.styleFrom(
                        minimumSize: const Size(40, 36),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ],
                ),
              ],
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

/// Wraps theme tags as `#tag` pills. Caps visible chips at 3 with a `+n`
/// overflow indicator so long tag lists don't stretch the card.
class _ThemeChips extends StatelessWidget {
  const _ThemeChips({required this.themes, required this.primary});

  final List<String> themes;
  final Color primary;

  static const int _maxVisible = 3;

  @override
  Widget build(BuildContext context) {
    final visible = themes.take(_maxVisible).toList();
    final overflow = themes.length - visible.length;
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final theme in visible)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '#$theme',
              style: TextStyle(
                color: primary,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        if (overflow > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: primary.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '+$overflow',
              style: TextStyle(
                color: primary,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }
}
