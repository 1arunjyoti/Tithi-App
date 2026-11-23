import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/festival.dart';
import '../../../providers/calendar_provider.dart';
import '../../../services/auspicious_timings.dart';
import '../../../services/inauspicious_timings.dart';
import '../../../theme/app_metrics.dart';
import '../../../widgets/festival_row_tile.dart';
import '../../ai/domain/ai_prompt.dart';
import '../../ai/widgets/ask_ai_sheet.dart';
import '../../sheets/sheet_launcher.dart';
import '../../sheets/widgets/section_header.dart';
import '../../sheets/widgets/sheet_link_tile.dart';
import '../domain/tithi_sheet_context.dart';

/// Festivals matched on the day, above the closing explainer so the
/// explainer stays the sheet's last word. Tapping one opens the festival
/// sheet on top of this one (pop returns here).
class TithiSheetFestivalsSection extends StatelessWidget {
  const TithiSheetFestivalsSection({
    super.key,
    required this.ctx,
    required this.festivals,
  });

  final TithiSheetContext ctx;
  final List<Festival> festivals;

  @override
  Widget build(BuildContext context) {
    // The leading gap is emitted even when the section is empty (the
    // original layout owns it outside the conditional), so the explainer
    // keeps the same breathing room.
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: AppSpacing.s12),
        if (festivals.isNotEmpty) ...[
          SectionHeader(text: ctx.l10n.festivalsOnThisDay),
          const SizedBox(height: AppSpacing.s10),
          for (var i = 0; i < festivals.length; i++) ...[
            if (i > 0) const SizedBox(height: AppSpacing.s8),
            FestivalRowTile(
              festival: festivals[i],
              date: ctx.panchang.date,
              panchang: ctx.panchang,
              // Flush with the section header above (no inner row box).
              flush: true,
              onTap: () => showEventDetailSheet(
                context,
                festival: festivals[i],
                panchang: ctx.panchang,
                fromTithiSheet: true,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.s12),
        ],
      ],
    );
  }
}

/// Opt-in AI hand-off. Sits above the closing explainer so the explainer
/// stays the sheet's last word.
class TithiSheetAiLink extends ConsumerWidget {
  const TithiSheetAiLink({
    super.key,
    required this.ctx,
    required this.enabled,
    required this.auspicious,
    required this.inauspicious,
  });

  final TithiSheetContext ctx;
  final bool enabled;
  final AuspiciousTimings? auspicious;
  final InauspiciousTimings? inauspicious;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!enabled) return const SizedBox.shrink();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: AppSpacing.s12),
        SheetLinkTile(
          icon: Icons.auto_awesome_outlined,
          // This sheet opens for any date the user selects, so "today" is
          // only right when it actually is.
          label:
              DateUtils.isSameDay(
                ctx.panchang.date,
                ref.watch(todayDateProvider),
              )
              ? ctx.l10n.aiAskAboutToday
              : ctx.l10n.aiAskAboutDay,
          supporting: ctx.l10n.aiOpensYourApp,
          onTap: () => showAskAiSheet(
            context,
            intent: AiIntent.todayPanchang,
            panchang: ctx.panchang,
            // Same windows the cards above show, so a muhurta question is
            // answered from Tithi's numbers.
            timings: auspicious,
            inauspicious: inauspicious,
          ),
        ),
        const SizedBox(height: AppSpacing.s12),
      ],
    );
  }
}
