import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../l10n/app_localizations.dart';
import '../models/festival.dart';
import '../models/panchang_data.dart';
import '../providers/calendar_provider.dart';
import '../providers/panchang_provider.dart';
import '../theme/app_theme.dart';
import '../services/share_service.dart';
import '../utils/tithi_localization.dart';
import '../features/event_detail/domain/event_content.dart';
import '../features/event_detail/providers/event_detail_providers.dart';
import '../features/sheets/widgets/edge_dismiss.dart';
import '../features/sheets/widgets/info_row.dart';
import '../features/sheets/widgets/section_header.dart';
import '../features/sheets/widgets/sheet_drag_handle.dart';

export '../features/event_detail/providers/event_detail_providers.dart'
    show descExpandedProvider;

/// Bottom sheet showing festival details with glassmorphism
class EventDetailSheet extends ConsumerWidget {
  final Festival festival;
  final PanchangData? panchang;

  const EventDetailSheet({super.key, required this.festival, this.panchang});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Intentionally ignore festival.visuals.themeColor: per-festival colors
    // made text/background inconsistent across sheets (e.g. near-black
    // #1a0500). Always use the app primary color.
    final themeColor = context.colors.primary;
    // Month system for Masa labels: Purnimant Krishna days carry the next
    // month's name (e.g. Janmashtami = Bhadrapada, not Shravana).
    final monthSystem = ref.watch(hinduMonthSystemProvider);
    final l10n = AppLocalizations.of(context);
    // Settings tithi display mode: paksha-based shows T1-15, continuous
    // shows T1-30 — resolved once here instead of inside row builders.
    final continuous =
        ref.watch(tithiDisplayModeProvider) == TithiDisplayMode.continuous30;
    final flags = eventFlags(festival);
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

    // Fixed-fraction sheet instead of DraggableScrollableSheet: the
    // draggable variant fills the whole screen and swallows scrim taps, so
    // outside-tap dismissal silently broke (drag-down still worked). Same
    // look, with working scrim-tap + drag dismissal like other sheets.
    final highContrast = AppTheme.highContrastOf(context);
    final sheetHeight = MediaQuery.of(context).size.height * 0.75;
    return SizedBox(
      height: sheetHeight,
      child: Container(
        decoration: BoxDecoration(
          color: context.theme.scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // Shared drag handle (finalized tithi design).
            SheetDragHandle(highContrast: highContrast),

            // Content. A sustained downward drag past the top edge
            // dismisses the sheet (OverscrollNotification fires only for
            // touch drags via dragDetails, so ballistic flings can't
            // mis-dismiss). Pixels accumulate until a ~120px drag.
            Expanded(
              child: EdgeDismiss(
                child: ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    _EventHeader(festival: festival, themeColor: themeColor),
                    const SizedBox(height: 16),

                    _EventDescription(
                      festival: festival,
                      hasAdditionalDesc: flags.additionalDesc,
                      themeColor: themeColor,
                    ),
                    const SizedBox(height: 24),

                    // Panchang info (finalized section style).
                    SectionHeader(
                      text:
                          AppLocalizations.of(context)?.panchangDetails ??
                          'Panchang Details',
                    ),
                    const SizedBox(height: 12),
                    if (dayPanchang != null && content != null) ...[
                      _EventPanchang(
                        festival: festival,
                        panchang: dayPanchang,
                        content: content,
                        themeColor: themeColor,
                      ),
                    ] else ...[
                      // Generic info from festival object when no panchang available
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
                                AppLocalizations.of(context)?.localeName ??
                                'en',
                          ),
                        ),
                      // Nakshatra from festival rules when tithi is
                      // overridden by one (stored tithi is then ignored).
                      if (festival.nakshatraCondition != null)
                        buildInfoRow(
                          context,
                          Icons.star_outline,
                          AppLocalizations.of(context)?.nakshatra ??
                              'Nakshatra',
                          festival.nakshatraCondition!,
                        ),
                    ],
                    buildInfoRow(
                      context,
                      Icons.category,
                      AppLocalizations.of(context)?.category ?? 'Category',
                      content?.categoryLabel ??
                          categoryLabelFor(festival: festival, l10n: l10n),
                    ),

                    // Fasting / Vrat info (below Panchang Details)
                    if (flags.fasting) ...[
                      const SizedBox(height: 24),
                      SectionHeader(
                        text:
                            AppLocalizations.of(context)?.fastingVrat ??
                            'Fasting / Vrat',
                      ),
                      const SizedBox(height: 12),
                      _EventFasting(festival: festival, themeColor: themeColor),
                    ],

                    // Rituals
                    if (festival.rituals.steps.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      SectionHeader(
                        text:
                            AppLocalizations.of(context)?.ritualsAndPractices ??
                            'Rituals & Practices',
                      ),
                      const SizedBox(height: 12),
                      _EventRituals(
                        festival: festival,
                        themeColor: themeColor,
                      ),
                    ],

                    // Mantra section
                    if (flags.mantra) ...[
                      const SizedBox(height: 24),
                      SectionHeader(
                        text: AppLocalizations.of(context)?.mantra ?? 'Mantra',
                      ),
                      const SizedBox(height: 12),
                      _EventMantra(festival: festival, themeColor: themeColor),
                    ],

                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ],
        ),
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

/// Festival name + share row, Hindi name, and regional-name chips.
class _EventHeader extends StatelessWidget {
  const _EventHeader({required this.festival, required this.themeColor});

  final Festival festival;
  final Color themeColor;

  @override
  Widget build(BuildContext context) {
    final regionalNames = regionalNamesOf(festival);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Festival name and Share button
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                festival.name,
                style: context.textTheme.headlineLarge?.copyWith(
                  fontSize: 28,
                  color: themeColor,
                ),
              ),
            ),
            IconButton(
              onPressed: () =>
                  ShareService().shareFestival(context, festival),
              icon: const Icon(Icons.share_outlined),
              color: themeColor,
              tooltip:
                  AppLocalizations.of(context)?.shareCard ?? 'Share Card',
            ),
          ],
        ),

        // Hindi name
        if (festival.nameHindi != null) ...[
          const SizedBox(height: 4),
          Text(
            festival.nameHindi!,
            style: context.textTheme.headlineMedium?.copyWith(
              fontSize: 20,
              color: context.colors.onSurface.withValues(alpha: 0.7),
            ),
          ),
        ],

        // Regional names as chips
        if (regionalNames.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: regionalNames
                .map(
                  (name) => Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: themeColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: themeColor.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      name,
                      style: context.textTheme.bodySmall?.copyWith(
                        color: themeColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ],
    );
  }
}

/// Description card with read-more expansion for the additional text.
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.glassmorphism(context: context, ref: ref),
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
              duration: AppTheme.animationDuration(
                context,
                const Duration(milliseconds: 200),
              ),
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

/// Panchang rows for a day with data: observed paksha/tithi/masa rows plus
/// the async tithi-span timings. Rows follow the festival's observed tithi
/// ([EventSheetContent]), not the sunrise tithi.
class _EventPanchang extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
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

        // Tithi Timings using user's location.
        // Solar festivals (fixed Gregorian dates) have
        // no tithi span, so no timings are shown. Same
        // for nakshatra-observed festivals.
        if (content.isNakshatraObserved)
          buildInfoRow(
            context,
            Icons.star_outline,
            l10n?.nakshatra ?? 'Nakshatra',
            panchang.nakshatra ?? festival.nakshatraCondition!,
          ),
        if (content.showTimings)
          Consumer(
            builder: (context, ref, child) {
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

              return timingsAsync.when(
                data: (timings) {
                  // Kshaya (skipped) tithi: the nearest
                  // occurrence belongs to another
                  // lunation, so hide rather than show
                  // a wrong-month span.
                  if (timings == null) {
                    return const SizedBox.shrink();
                  }
                  final startStr = formatLocalizedDate(
                    timings.start,
                    'h:mm a, MMM d',
                    Localizations.localeOf(context).languageCode,
                  );
                  final endStr = formatLocalizedDate(
                    timings.end,
                    'h:mm a, MMM d',
                    Localizations.localeOf(context).languageCode,
                  );

                  return Column(
                    children: [
                      buildInfoRow(
                        context,
                        Icons.access_time,
                        AppLocalizations.of(context)?.begins ?? 'Begins',
                        startStr,
                        trailing: _buildTimingInfoButton(context),
                      ),
                      buildInfoRow(
                        context,
                        Icons.access_time_filled,
                        AppLocalizations.of(context)?.ends ?? 'Ends',
                        endStr,
                        trailing: _buildTimingInfoButton(context),
                      ),
                    ],
                  );
                },
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                ),
                error: (err, stack) => const SizedBox.shrink(),
              );
            },
          ),
      ],
    );
  }
}

/// Fasting / Vrat glass card.
class _EventFasting extends ConsumerWidget {
  const _EventFasting({required this.festival, required this.themeColor});

  final Festival festival;
  final Color themeColor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.glassmorphism(context: context, ref: ref),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              festival.rituals.fasting!,
              style: context.textTheme.bodyMedium?.copyWith(height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}

/// Numbered ritual-steps timeline card.
class _EventRituals extends ConsumerWidget {
  const _EventRituals({required this.festival, required this.themeColor});

  final Festival festival;
  final Color themeColor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      decoration: AppTheme.glassmorphism(context: context, ref: ref),
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

/// Centered serif mantra card with accent border.
class _EventMantra extends ConsumerWidget {
  const _EventMantra({required this.festival, required this.themeColor});

  final Festival festival;
  final Color themeColor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.glassmorphism(
        context: context,
        ref: ref,
      ).copyWith(
        border: Border.all(color: themeColor.withValues(alpha: 0.25)),
      ),
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
