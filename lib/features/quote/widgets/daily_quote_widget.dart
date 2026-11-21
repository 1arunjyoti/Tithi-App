import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../l10n/app_localizations.dart';
import '../../../theme/app_metrics.dart';
import '../../../theme/app_motion.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/app_card.dart';
import '../domain/quote_day_navigation.dart';
import '../domain/shloka_translation.dart';
import '../providers/quote_providers.dart';
import 'quote_card_header.dart';
import 'quote_control_bar.dart';
import 'quote_share_sheet.dart';
import 'quote_verse_body.dart';

/// Home-screen "Daily Wisdom" card: one shloka per day with day browsing,
/// a collapsible translation and a share sheet.
///
/// Renderers live beside this file: [QuoteCardHeader], [QuoteVerseBody],
/// [QuoteTranslationPanel], [QuoteControlBar], [showQuoteShareOptions].
/// Pure rules live in `features/quote/domain/`.
class DailyQuoteWidget extends ConsumerWidget {
  const DailyQuoteWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final shlokaAsync = ref.watch(dailyShlokaProvider);
    // Hindi UI shows the Hindi translation, all other locales (en/bn/sa)
    // show English — same convention as EclipseScreen.
    final hindiFirst = Localizations.localeOf(context).languageCode == 'hi';

    Widget cardFor(DailyWisdom wisdom) =>
        _QuoteCard(wisdom: wisdom, hindiFirst: hindiFirst, l10n: l10n);

    // Hero-card pattern: size glides from a pinned top edge (first launch,
    // day browse, expand/collapse). The outer switcher only reacts to
    // empty ↔ verse transitions (first load): day browsing is handled by
    // the INNER content switcher in _QuoteCard, so the glass shell and the
    // control bar stay mounted and never blink.
    return AnimatedSize(
      alignment: Alignment.topCenter,
      duration: AppMotion.of(context, AppMotion.emphasized),
      curve: AppMotion.emphasizedCurve,
      child: AnimatedSwitcher(
        duration: AppMotion.of(context, AppMotion.subtle),
        transitionBuilder: (child, animation) =>
            FadeTransition(opacity: animation, child: child),
        layoutBuilder: (currentChild, _) => currentChild!,
        child: shlokaAsync.when(
          data: (wisdom) {
            if (wisdom == null) return const SizedBox.shrink();
            return cardFor(wisdom);
          },
          // Keep the previous verse mounted while another day loads (or
          // when a reload fails) so browsing days doesn't flash the card
          // away.
          loading: () {
            final previous = shlokaAsync.valueOrNull;
            if (previous == null) return const SizedBox.shrink();
            return cardFor(previous);
          },
          error: (_, _) {
            final previous = shlokaAsync.valueOrNull;
            if (previous == null) return const SizedBox.shrink();
            return cardFor(previous);
          },
        ),
      ),
    );
  }
}

/// The mounted card: glass shell + per-day content switcher + control bar.
///
/// A separate [ConsumerWidget] so expand/day toggles rebuild only the card
/// body, not the outer size/switcher shell.
class _QuoteCard extends ConsumerWidget {
  const _QuoteCard({
    required this.wisdom,
    required this.hindiFirst,
    required this.l10n,
  });

  final DailyWisdom wisdom;
  final bool hindiFirst;
  final AppLocalizations? l10n;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shloka = wisdom.shloka;
    final isExpanded = ref.watch(quoteExpandedProvider);
    final showAll = ref.watch(quoteShowAllTranslationsProvider);
    final offset = ref.watch(quoteDayOffsetProvider);
    final atPastBound = offset <= -quoteMaxDayOffset;
    // Today is the upper bound: users can step forward to the current
    // verse, but never into future days.
    final atToday = offset >= 0;

    final translation = QuoteTranslationView.resolve(
      shloka,
      hindiFirst: hindiFirst,
      showAll: showAll,
    );

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

    void toggleShowAll() {
      ref.read(quoteShowAllTranslationsProvider.notifier).state = !showAll;
    }

    return AppCard(
      // Shared page gutter (matches CalendarWidget exactly). No key: the
      // shell stays mounted across day browse; only the content below swaps.
      margin: const EdgeInsets.symmetric(horizontal: AppTheme.pageGutter),
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Verse content cross-dissolves per day while the glass shell and
          // the control bar below stay put — so prev/next never blinks the
          // chrome. Default stacking (both verses briefly co-exist) reads
          // as a dissolve; the outer AnimatedSize glides any height delta.
          // Top-aligned stack (not the default center): a shorter incoming
          // verse must grow from the pinned header downward, never float
          // mid-card and snap back when the transition ends.
          AnimatedSwitcher(
            duration: AppMotion.of(context, AppMotion.standard),
            transitionBuilder: (child, animation) =>
                FadeTransition(opacity: animation, child: child),
            layoutBuilder: (currentChild, previousChildren) => Stack(
              alignment: Alignment.topCenter,
              children: <Widget>[...previousChildren, ?currentChild],
            ),
            child: KeyedSubtree(
              key: ValueKey('wisdom-content-${shloka.id}-${wisdom.dayOffset}'),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  QuoteCardHeader(
                    dayLabel: dayLabel,
                    showTodayReset: offset != 0,
                    onJumpToToday: jumpToToday,
                    onShare: () => showQuoteShareOptions(
                      context,
                      shloka: shloka,
                      expanded: isExpanded,
                      hindiFirst: hindiFirst,
                      showAll: showAll,
                    ),
                    l10n: l10n,
                  ),
                  QuoteVerseBody(
                    shloka: shloka,
                    festivalName: wisdom.festivalName,
                    translation: translation,
                    isExpanded: isExpanded,
                    l10n: l10n,
                    onToggleShowAll: toggleShowAll,
                  ),
                ],
              ),
            ),
          ),

          // Bottom control bar: browse days + expand toggle.
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.s16,
              AppSpacing.s12,
              AppSpacing.s16,
              AppSpacing.s12,
            ),
            child: QuoteControlBar(
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
