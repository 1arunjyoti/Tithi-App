import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../../models/festival.dart';
import '../../../models/panchang_data.dart';
import '../../../providers/panchang_provider.dart';
import '../../../theme/app_metrics.dart';
import '../../../theme/app_theme.dart';
import '../../sheets/widgets/info_row.dart';
import '../../sheets/widgets/sheet_surface_card.dart';
import '../../sheets/widgets/sheet_time_format.dart';
import '../../tithi_sheet/widgets/timings_cards.dart';
import '../domain/event_content.dart';

/// Panchang details for a day with data: the observed tithi span in the
/// shared [TimingsCard] (same component + [sheetInstantValue] formatting as
/// the tithi sheet), with the observed paksha/tithi/masa rows in a shared
/// surface card below it. Rows follow the festival's observed tithi
/// ([EventSheetContent]), not the sunrise tithi.
class EventPanchangSection extends ConsumerWidget {
  const EventPanchangSection({
    super.key,
    required this.festival,
    required this.panchang,
    required this.content,
  });

  final Festival festival;
  final PanchangData panchang;
  final EventSheetContent content;

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
        // Full 1-30 index of the OBSERVED (festival) tithi, not the sunrise
        // tithi.
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
        // span, so no timings are shown. Same for nakshatra-observed
        // festivals.
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
              // Kshaya (skipped) tithi: the nearest occurrence belongs to
              // another lunation, so hide rather than show a wrong-month span.
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
          const SizedBox(height: AppSpacing.s12),
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
