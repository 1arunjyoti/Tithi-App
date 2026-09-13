import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../l10n/app_localizations.dart';
import '../models/festival.dart';
import '../models/hindu_month_system.dart';
import '../models/panchang_data.dart';
import '../providers/calendar_provider.dart';
import '../providers/panchang_provider.dart';
import '../theme/app_theme.dart';
import '../services/share_service.dart';

final _descExpandedProvider = StateProvider.autoDispose<bool>((ref) => false);

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

    // Gather non-null, non-empty regional names
    final regionalNames = <String>[];
    if (festival.nameRegional.nameBengali?.isNotEmpty == true) {
      regionalNames.add(festival.nameRegional.nameBengali!);
    }
    if (festival.nameRegional.nameTelugu?.isNotEmpty == true) {
      regionalNames.add(festival.nameRegional.nameTelugu!);
    }
    if (festival.nameRegional.nameKannada?.isNotEmpty == true) {
      regionalNames.add(festival.nameRegional.nameKannada!);
    }
    if (festival.nameRegional.nameTamil?.isNotEmpty == true) {
      regionalNames.add(festival.nameRegional.nameTamil!);
    }
    if (festival.nameRegional.nameMalayalam?.isNotEmpty == true) {
      regionalNames.add(festival.nameRegional.nameMalayalam!);
    }

    final hasAdditionalDesc = festival.purpose.additionalDescription.isNotEmpty;
    final hasFasting =
        festival.rituals.fasting != null &&
        festival.rituals.fasting!.isNotEmpty;
    final hasMantra = festival.rituals.mantra.isNotEmpty;

    // Fixed-fraction sheet instead of DraggableScrollableSheet: the
    // draggable variant fills the whole screen and swallows scrim taps, so
    // outside-tap dismissal silently broke (drag-down still worked). Same
    // look, with working scrim-tap + drag dismissal like other sheets.
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
            // Drag handle with theme color tint. The taller transparent
            // zone makes the framework drag-to-dismiss target easier to
            // grab; visuals unchanged (handle stays centered).
            Container(
              height: 32,
              alignment: Alignment.center,
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: themeColor.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Content. A sustained downward drag past the top edge
            // dismisses the sheet (OverscrollNotification fires only for
            // touch drags via dragDetails, so ballistic flings can't
            // mis-dismiss). Pixels accumulate until a ~120px drag.
            Expanded(
              child: NotificationListener<ScrollNotification>(
                onNotification: (() {
                  var edgeDrag = 0.0;
                  return (ScrollNotification notification) {
                    if (notification is ScrollStartNotification) {
                      edgeDrag = 0;
                    } else if (notification is OverscrollNotification &&
                        notification.dragDetails != null &&
                        notification.overscroll < 0) {
                      edgeDrag += -notification.overscroll;
                      if (edgeDrag >= 120 && Navigator.of(context).canPop()) {
                        Navigator.of(context).pop();
                        return true;
                      }
                    } else if (notification is ScrollUpdateNotification &&
                        notification.metrics.pixels > 0) {
                      // Left the edge: finger moved back into content.
                      edgeDrag = 0;
                    }
                    return false;
                  };
                })(),
                child: ListView(
                  padding: const EdgeInsets.all(24),
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
                          tooltip: 'Share Card',
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
                          color: context.colors.onSurface.withValues(
                            alpha: 0.7,
                          ),
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
                    const SizedBox(height: 16),

                    // Description
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: AppTheme.glassmorphism(
                        context: context,
                        ref: ref,
                      ),
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
                                        .read(_descExpandedProvider.notifier)
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
                                          ref.watch(_descExpandedProvider)
                                              ? 'Show Less'
                                              : 'Read More',
                                          style: context.textTheme.labelLarge
                                              ?.copyWith(
                                                color: themeColor,
                                                fontWeight: FontWeight.bold,
                                              ),
                                        ),
                                        const SizedBox(width: 4),
                                        Icon(
                                          ref.watch(_descExpandedProvider)
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
                              child: ref.watch(_descExpandedProvider)
                                  ? Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const SizedBox(height: 8),
                                        Divider(
                                          color: context.colors.onSurface
                                              .withValues(alpha: 0.15),
                                        ),
                                        const SizedBox(height: 8),
                                        _buildFormattedText(
                                          festival
                                              .purpose
                                              .additionalDescription,
                                          context.textTheme.bodyMedium
                                              ?.copyWith(
                                                fontSize: 14,
                                                height: 1.5,
                                                color: context.colors.onSurface
                                                    .withValues(alpha: 0.8),
                                              ),
                                        ),
                                      ],
                                    )
                                  : const SizedBox.shrink(),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Panchang info
                    _buildSectionHeader(
                      context,
                      icon: Icons.auto_awesome,
                      label:
                          AppLocalizations.of(context)?.panchangDetails ??
                          'Panchang Details',
                      color: themeColor,
                    ),
                    const SizedBox(height: 12),
                    if (panchang != null) ...[
                      // Festival-observed paksha/tithi: festivals with a
                      // timingOverride (e.g. Ganesh Chaturthi at madhyahna)
                      // are observed on a tithi that can differ from the
                      // sunrise tithi, so rows and timings below follow the
                      // festival's tithi, not the day's sunrise tithi.
                      // Solar festivals (and rules without a tithi) have no
                      // lunar observance: their rows stay day-based and no
                      // timings are shown.
                      Builder(
                        builder: (context) {
                          // Nakshatra-observed festivals (e.g. Saraswati
                          // Avahan on Mula): the stored tithi is
                          // documentation only. Paksha/Tithi/Masa rows stay
                          // day-based, a Nakshatra row is added, and no
                          // tithi span is shown (it would mislead).
                          final isNakshatraObserved =
                              festival.nakshatraCondition != null;
                          final useObserved =
                              !isNakshatraObserved &&
                              festival.conditions != 'Solar' &&
                              festival.tithi >= 1;
                          final observedPaksha = useObserved
                              ? festival.resolvePaksha(panchang!.paksha)
                              : panchang!.paksha;
                          final observedIndex = useObserved
                              ? festival.resolveTithiIndex(panchang!.paksha)
                              : panchang!.tithiIndex;
                          final observedNum = observedIndex <= 15
                              ? observedIndex
                              : observedIndex - 15;
                          final showTimings =
                              useObserved && !isNakshatraObserved;
                          final displayTithiNum =
                              ref.watch(tithiDisplayModeProvider) ==
                                  TithiDisplayMode.continuous30
                              ? observedIndex
                              : observedNum;
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _buildInfoRow(
                                context,
                                Icons.brightness_3,
                                AppLocalizations.of(context)?.paksha ??
                                    'Paksha',
                                '$observedPaksha (${observedPaksha == 'Shukla' ? (AppLocalizations.of(context)?.waxing ?? "Waxing") : (AppLocalizations.of(context)?.waning ?? "Waning")})',
                              ),
                              _buildInfoRow(
                                context,
                                Icons.calendar_today,
                                AppLocalizations.of(context)?.tithi ?? 'Tithi',
                                // Respect the Settings tithi display mode:
                                // paksha-based shows T1-15, continuous shows
                                // T1-30 — of the observed (festival) tithi.
                                '${PanchangData.tithiNameFor(observedNum, observedPaksha)} (T$displayTithiNum)',
                              ),
                              // Masa (Hindu month) — converted for Purnimant display.
                              // panchang.masa is always Amanta; Krishna days take the
                              // next month's name in Purnimant (Shukla unchanged).
                              if (panchang!.masa.isNotEmpty)
                                _buildInfoRow(
                                  context,
                                  Icons.wb_sunny_outlined,
                                  'Masa',
                                  displayMasaName(
                                        panchang!.masa,
                                        panchang!.paksha,
                                        monthSystem,
                                      )
                                      .replaceAll('_', ' ')
                                      .split(' ')
                                      .map(
                                        (w) => w.isEmpty
                                            ? w
                                            : '${w[0].toUpperCase()}${w.substring(1)}',
                                      )
                                      .join(' '),
                                ),

                              // Tithi Timings using user's location.
                              // Solar festivals (fixed Gregorian dates) have
                              // no tithi span, so no timings are shown. Same
                              // for nakshatra-observed festivals.
                              if (isNakshatraObserved)
                                _buildInfoRow(
                                  context,
                                  Icons.star_outline,
                                  'Nakshatra',
                                  panchang!.nakshatra ??
                                      festival.nakshatraCondition!,
                                ),
                              if (showTimings)
                                Consumer(
                                  builder: (context, ref, child) {
                                    final coords = ref.watch(
                                      resolvedCoordinatesProvider,
                                    );
                                    final timingsAsync = ref.watch(
                                      tithiTimingsProvider((
                                        date: panchang!.date,
                                        // Full 1-30 index of the OBSERVED
                                        // (festival) tithi, not the sunrise
                                        // tithi (see above).
                                        tithiIndex: observedIndex,
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
                                        final dateFormat = DateFormat(
                                          'h:mm a, MMM d',
                                        );
                                        final startStr = dateFormat.format(
                                          timings.start,
                                        );
                                        final endStr = dateFormat.format(
                                          timings.end,
                                        );

                                        return Column(
                                          children: [
                                            _buildInfoRow(
                                              context,
                                              Icons.access_time,
                                              'Begins',
                                              startStr,
                                              trailing: _buildTimingInfoButton(
                                                context,
                                              ),
                                            ),
                                            _buildInfoRow(
                                              context,
                                              Icons.access_time_filled,
                                              'Ends',
                                              endStr,
                                              trailing: _buildTimingInfoButton(
                                                context,
                                              ),
                                            ),
                                          ],
                                        );
                                      },
                                      loading: () => const Padding(
                                        padding: EdgeInsets.symmetric(
                                          vertical: 8,
                                        ),
                                        child: Center(
                                          child: SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          ),
                                        ),
                                      ),
                                      error: (err, stack) =>
                                          const SizedBox.shrink(),
                                    );
                                  },
                                ),
                            ],
                          );
                        },
                      ),
                    ] else ...[
                      // Generic info from festival object when no panchang available
                      _buildInfoRow(
                        context,
                        Icons.brightness_3,
                        AppLocalizations.of(context)?.paksha ?? 'Paksha',
                        festival.paksha,
                      ),
                      _buildInfoRow(
                        context,
                        Icons.calendar_today,
                        AppLocalizations.of(context)?.tithi ?? 'Tithi',
                        // Respect the Settings tithi display mode here too:
                        // festival rules store paksha-based 1-15, so map
                        // Krishna tithis to 16-30 in continuous mode.
                        'Tithi ${ref.watch(tithiDisplayModeProvider) == TithiDisplayMode.continuous30 && festival.paksha == 'Krishna' ? festival.tithi + 15 : festival.tithi}',
                      ),
                      // Masa from festival rules (stored Amanta) — converted
                      // for Purnimant display using the rule's own paksha.
                      if (festival.masa.isNotEmpty && festival.masa != '*')
                        _buildInfoRow(
                          context,
                          Icons.wb_sunny_outlined,
                          'Masa',
                          displayMasaName(
                                festival.masa,
                                festival.paksha,
                                monthSystem,
                              )
                              .replaceAll('_', ' ')
                              .split(' ')
                              .map(
                                (w) => w.isEmpty
                                    ? w
                                    : '${w[0].toUpperCase()}${w.substring(1)}',
                              )
                              .join(' '),
                        ),
                      // Nakshatra from festival rules when tithi is
                      // overridden by one (stored tithi is then ignored).
                      if (festival.nakshatraCondition != null)
                        _buildInfoRow(
                          context,
                          Icons.star_outline,
                          'Nakshatra',
                          festival.nakshatraCondition!,
                        ),
                    ],
                    _buildInfoRow(
                      context,
                      Icons.category,
                      AppLocalizations.of(context)?.category ?? 'Category',
                      festival.category.isEmpty
                          ? (AppLocalizations.of(context)?.general ?? 'General')
                          : festival.category.toUpperCase(),
                    ),

                    // Fasting / Vrat info (below Panchang Details)
                    if (hasFasting) ...[
                      const SizedBox(height: 24),
                      _buildSectionHeader(
                        context,
                        icon: Icons.self_improvement,
                        label: 'Fasting / Vrat',
                        color: themeColor,
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: AppTheme.glassmorphism(
                          context: context,
                          ref: ref,
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                festival.rituals.fasting!,
                                style: context.textTheme.bodyMedium?.copyWith(
                                  height: 1.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // Rituals
                    if (festival.rituals.steps.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      _buildSectionHeader(
                        context,
                        icon: Icons.spa_outlined,
                        label:
                            AppLocalizations.of(context)?.ritualsAndPractices ??
                            'Rituals & Practices',
                        color: themeColor,
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 20,
                        ),
                        decoration: AppTheme.glassmorphism(
                          context: context,
                          ref: ref,
                        ),
                        child: Column(
                          children: festival.rituals.steps.asMap().entries.map((
                            entry,
                          ) {
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
                                          color: themeColor.withValues(
                                            alpha: 0.1,
                                          ),
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: themeColor.withValues(
                                              alpha: 0.8,
                                            ),
                                            width: 1.5,
                                          ),
                                        ),
                                        alignment: Alignment.center,
                                        child: Text(
                                          '${index + 1}',
                                          style: context.textTheme.bodySmall
                                              ?.copyWith(
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
                                            color: themeColor.withValues(
                                              alpha: 0.25,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Padding(
                                      padding: EdgeInsets.only(
                                        bottom: index < totalSteps - 1
                                            ? 20.0
                                            : 4.0,
                                      ),
                                      child: Text(
                                        ritual,
                                        style: context.textTheme.bodyMedium
                                            ?.copyWith(
                                              fontSize: 15,
                                              height: 1.5,
                                              color: context.colors.onSurface
                                                  .withValues(alpha: 0.9),
                                            ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],

                    // Mantra section
                    if (hasMantra) ...[
                      const SizedBox(height: 24),
                      _buildSectionHeader(
                        context,
                        icon: Icons.record_voice_over_outlined,
                        label: 'Mantra',
                        color: themeColor,
                      ),
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration:
                            AppTheme.glassmorphism(
                              context: context,
                              ref: ref,
                            ).copyWith(
                              border: Border.all(
                                color: themeColor.withValues(alpha: 0.25),
                              ),
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
                      ),
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

  /// Builds a section header row with an icon, label, and a subtle divider line
  Widget _buildSectionHeader(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Row(
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 8),
        Text(
          label,
          style: context.textTheme.headlineMedium?.copyWith(
            fontSize: 18,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(
    BuildContext context,
    IconData icon,
    String label,
    String value, {
    Widget? trailing,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: context.colors.primary, size: 22),
          const SizedBox(width: 12),
          Text(
            '$label:',
            style: context.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: context.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 8), trailing],
        ],
      ),
    );
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
                'Timing Note',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: Text(
            'Timings are calculated astronomically based on coordinates and may vary by a few minutes from local temple calendars due to atmospheric refraction, elevation, or calculation methods.',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(height: 1.35, fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Got it'),
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
}
