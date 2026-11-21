import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/festival.dart';
import '../../../providers/panchang_provider.dart';
import '../../../theme/app_metrics.dart';
import '../../../utils/tithi_localization.dart';
import '../../sheets/widgets/section_header.dart';
import '../../sheets/widgets/sheet_time_format.dart';
import '../domain/tithi_sheet_context.dart';
import 'nakshatra_card.dart';
import 'timings_cards.dart';
import 'yoga_karana_card.dart';

typedef TithiTimingsAsync = AsyncValue<({DateTime start, DateTime end})?>;
typedef NakshatraTimingAsync =
    AsyncValue<({int index, String nakshatra, DateTime start, DateTime end})?>;
typedef YogaKaranaTimingAsync =
    AsyncValue<
      ({
        int yogaIndex,
        String yoga,
        DateTime yogaEnd,
        int karanaIndex,
        String karana,
        DateTime karanaEnd,
      })?
    >;

/// Begins/Ends card for the displayed tithi. Prefers the precomputed
/// transition instant when it ENDS the label, so a short tithi that flips
/// before the next sunrise shows its real span instead of tomorrow's.
class TithiTimingsSection extends ConsumerWidget {
  const TithiTimingsSection({
    super.key,
    required this.ctx,
    required this.timingsAsync,
  });

  final TithiSheetContext ctx;
  final TithiTimingsAsync timingsAsync;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final panchang = ctx.panchang;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(text: ctx.l10n.tithiTimings),
        const SizedBox(height: AppSpacing.s10),
        timingsAsync.when(
          data: (timings) {
            // Kshaya edge (no nearby occurrence): hide rather
            // than show a wrong-lunation span.
            if (timings == null) return const SizedBox.shrink();
            // Prefer the precomputed transition instant when it ENDS
            // the displayed label (it exits into a later tithi
            // before the next sunrise); otherwise the searched
            // end (next boundary, usually tomorrow). After a
            // live flip the instant is the label's beginning —
            // using it as the end would collapse the span.
            // Date fragments follow the primary calendar.
            final end =
                (panchang.transitionExitsLabel
                    ? panchang.tithiTransitionTime
                    : null) ??
                timings.end;
            return TimingsCard(
              highContrast: ctx.highContrast,
              begins: sheetInstantValue(
                ref,
                timings.start,
                panchang.tithiIndex,
                ctx.locale,
              ),
              ends: sheetInstantValue(
                ref,
                end,
                panchang.tithiIndex,
                ctx.locale,
              ),
            );
          },
          loading: () => TimingsCard(highContrast: ctx.highContrast),
          error: (err, stack) => const SizedBox.shrink(),
        ),
      ],
    );
  }
}

/// Daytime-transition history (squeeze-case visibility). Shown whenever a
/// boundary falls inside the day — both before the flip and after it.
class TithiTransitionSection extends ConsumerWidget {
  const TithiTransitionSection({super.key, required this.ctx});

  final TithiSheetContext ctx;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final panchang = ctx.panchang;
    // Post-flip the subline keeps the morning's context so a user opening
    // the sheet at 3 PM still learns what the day started as; the incoming
    // tithi's own end already stands in the Begins/Ends card above.
    if (!panchang.hasTithiTransition) return const SizedBox.shrink();
    final coords = ctx.coords;
    final nextTimingsAsync = ref.watch(
      tithiTimingsProvider((
        date: panchang.date,
        tithiIndex: panchang.transitionTithiIndex!,
        latitude: coords.latitude,
        longitude: coords.longitude,
      )),
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: AppSpacing.s12),
        nextTimingsAsync.when(
          data: (nextTimings) {
            if (nextTimings == null) return const SizedBox.shrink();
            return TransitionCard(
              highContrast: ctx.highContrast,
              headline: ctx.l10n.tithiBeginsAt(
                localizedTithiName(
                  panchang.transitionTithiNumber,
                  panchang.transitionPaksha,
                  ctx.l10n,
                ),
                formatLocalizedDate(
                  panchang.tithiTransitionTime!,
                  'jm',
                  ctx.locale,
                ),
              ),
              subline: panchang.transitionExitsLabel
                  ? ctx.l10n.tithiEndsAtDateTime(
                      localizedTithiName(
                        panchang.transitionTithiNumber,
                        panchang.transitionPaksha,
                        ctx.l10n,
                      ),
                      sheetInstantValue(
                        ref,
                        nextTimings.end,
                        panchang.transitionTithiIndex!,
                        ctx.locale,
                      ),
                    )
                  : ctx.l10n.tithiEndsAtDateTime(
                      localizedTithiName(
                        panchang.sunriseTithiNumber,
                        panchang.sunrisePaksha,
                        ctx.l10n,
                      ),
                      sheetInstantValue(
                        ref,
                        panchang.tithiTransitionTime!,
                        panchang.sunriseTithiIndex,
                        ctx.locale,
                      ),
                    ),
            );
          },
          loading: () => TransitionCard(highContrast: ctx.highContrast),
          error: (err, stack) => const SizedBox.shrink(),
        ),
      ],
    );
  }
}

/// Nakshatra span card with the elapsed-progress bar. Hidden when the span
/// can't be resolved — the same hide-on-null contract as the timings card.
class NakshatraSection extends StatelessWidget {
  const NakshatraSection({
    super.key,
    required this.ctx,
    required this.nakshatraAsync,
  });

  final TithiSheetContext ctx;
  final NakshatraTimingAsync nakshatraAsync;

  @override
  Widget build(BuildContext context) {
    Widget section(Widget card) => Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: AppSpacing.s12),
        SectionHeader(text: ctx.l10n.nakshatraTimings),
        const SizedBox(height: AppSpacing.s10),
        card,
      ],
    );

    return nakshatraAsync.when(
      data: (nak) {
        if (nak == null) return const SizedBox.shrink();
        final endLabel = sheetInstantLabel(
          nak.end,
          ctx.panchang.date,
          ctx.locale,
        );
        final now = DateTime.now();
        final progress = now.isBefore(nak.start)
            ? 0.0
            : now.isAfter(nak.end)
            ? 1.0
            : (now.difference(nak.start).inSeconds /
                      nak.end.difference(nak.start).inSeconds)
                  .clamp(0.0, 1.0);
        return section(
          NakshatraCard(
            highContrast: ctx.highContrast,
            headline: ctx.l10n.nakshatraUntil(nak.nakshatra, endLabel),
            subline:
                '${ctx.l10n.nakshatraLord(localizedNakshatraLord(nak.index, ctx.l10n))} · '
                '${ctx.l10n.nakshatraElapsed((progress * 100).toStringAsFixed(0))}',
            progress: progress,
            // The Moon's longitude advances monotonically, so the upcoming
            // mansion is always the next Vedic-order index — no search needed.
            nextline: ctx.l10n.nakshatraNext(
              hinduNakshatras[(nak.index + 1) % 27],
              endLabel,
            ),
          ),
        );
      },
      loading: () => section(NakshatraCard(highContrast: ctx.highContrast)),
      error: (err, stack) => const SizedBox.shrink(),
    );
  }
}

/// Yoga & karana side-by-side card. Hidden when the spans can't be resolved.
class YogaKaranaSection extends StatelessWidget {
  const YogaKaranaSection({
    super.key,
    required this.ctx,
    required this.yogaKaranaAsync,
  });

  final TithiSheetContext ctx;
  final YogaKaranaTimingAsync yogaKaranaAsync;

  @override
  Widget build(BuildContext context) {
    Widget section(Widget card) => Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: AppSpacing.s12),
        SectionHeader(text: ctx.l10n.yogaKaranaTimings),
        const SizedBox(height: AppSpacing.s10),
        card,
      ],
    );

    return yogaKaranaAsync.when(
      data: (yk) {
        if (yk == null) return const SizedBox.shrink();
        // Both sequences advance by exactly one per boundary (elongation
        // and Sun+Moon sum grow monotonically), so the followers need no
        // search.
        final yogaEndLabel = sheetInstantLabel(
          yk.yogaEnd,
          ctx.panchang.date,
          ctx.locale,
        );
        final karanaEndLabel = sheetInstantLabel(
          yk.karanaEnd,
          ctx.panchang.date,
          ctx.locale,
        );
        return section(
          YogaKaranaCard(
            highContrast: ctx.highContrast,
            yogaLabel: ctx.l10n.yogaLabel,
            yogaValue: yk.yoga,
            yogaSubline: ctx.l10n.untilThen(
              yogaEndLabel,
              yogaNames[(yk.yogaIndex + 1) % 27],
            ),
            yogaTime: yogaEndLabel,
            karanaLabel: ctx.l10n.karanaLabel,
            karanaValue: yk.karana,
            karanaSubline: ctx.l10n.untilThen(
              karanaEndLabel,
              karanaNameForIndex(yk.karanaIndex + 1),
            ),
            karanaTime: karanaEndLabel,
          ),
        );
      },
      loading: () => section(
        YogaKaranaCard(
          highContrast: ctx.highContrast,
          yogaLabel: ctx.l10n.yogaLabel,
          karanaLabel: ctx.l10n.karanaLabel,
        ),
      ),
      error: (err, stack) => const SizedBox.shrink(),
    );
  }
}
