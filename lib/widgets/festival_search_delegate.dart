import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../models/festival.dart';
import '../models/panchang_data.dart';
import '../core/format/date_only.dart';
import '../core/feedback/app_haptics.dart';
import '../providers/festival_provider.dart';
import '../providers/calendar_provider.dart';
import '../providers/panchang_provider.dart';
import '../theme/app_theme.dart';
import '../theme/app_metrics.dart';
import '../theme/app_typography.dart';
import '../core/feedback/app_messages.dart';
import '../features/countdown/domain/target_resolution.dart';
import '../features/sheets/sheet_launcher.dart';
import 'festival_thumbnail.dart';
import 'state_views.dart';

class FestivalSearchDelegate extends SearchDelegate {
  final WidgetRef ref;
  final BuildContext parentContext;

  FestivalSearchDelegate({required this.ref, required this.parentContext});

  @override
  ThemeData appBarTheme(BuildContext context) {
    final theme = Theme.of(context);
    return theme.copyWith(
      appBarTheme: theme.appBarTheme.copyWith(
        backgroundColor: theme.colorScheme.surface,
        elevation: 0,
      ),
      inputDecorationTheme: const InputDecorationTheme(
        border: InputBorder.none,
        hintStyle: TextStyle(fontSize: AppTypography.sizeHeading),
      ),
    );
  }

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        IconButton(
          icon: const Icon(Icons.clear),
          tooltip: AppLocalizations.of(context)?.clearSearch ?? 'Clear search',
          onPressed: () {
            query = '';
          },
        ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      tooltip: MaterialLocalizations.of(context).backButtonTooltip,
      onPressed: () {
        close(context, null);
      },
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return _buildList(context);
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return _buildList(context);
  }

  Widget _buildList(BuildContext context) {
    final allFestivals = ref.read(festivalProvider);
    final results = query.isEmpty
        ? <Festival>[] // Start empty or show recent?
        : allFestivals.where((f) {
            final q = query.toLowerCase();
            return f.name.toLowerCase().contains(q) ||
                (f.nameHindi?.toLowerCase().contains(q) ?? false) ||
                f.category.toLowerCase().contains(q);
          }).toList();

    if (query.isEmpty) {
      return const EmptyState(
        icon: Icons.search_rounded,
        title: 'Search for festivals, vrats, and events',
      );
    }

    if (results.isEmpty) {
      return const EmptyState(
        icon: Icons.search_off_rounded,
        title: 'No festivals found',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(AppSpacing.s16),
      itemCount: results.length,
      itemBuilder: (context, index) {
        final festival = results[index];
        return _buildFestivalTile(context, festival);
      },
    );
  }

  Widget _buildFestivalTile(BuildContext context, Festival festival) {
    final isMajor = festival.category == 'major';

    // We can reuse the glassmorphism style or keep it simpler for search results
    // Let's use a Card-like look that fits the theme

    return GestureDetector(
      onTap: () async {
        // Immediate feedback while the occurrence lookup runs.
        AppHaptics.tap(ref);
        // Try to find the next occurrence date so we can pass panchang context.
        // Await the shared init: a Panjika switch replaces the service, and
        // this scan would otherwise run on an uninitialized instance.
        await ref.read(panchangInitProvider.future);
        final panchangService = ref.read(panchangServiceProvider);
        final coords = ref.read(resolvedCoordinatesProvider);
        // Same "today" as the countdowns (not wall-clock now): avoids a
        // 1-day disagreement around midnight when todayDateProvider hasn't
        // rolled yet. Resolution is Amanta-fixed (display system never
        // affects dates).
        final nextDate = await resolveOccurrenceDate(
          service: panchangService,
          festival: festival,
          baseDate: dateOnly(ref.read(todayDateProvider)),
          latitude: coords.latitude,
          longitude: coords.longitude,
        );

        // Fetch panchang for that date if found
        PanchangData? panchang;
        if (nextDate != null) {
          try {
            panchang = await ref.read(panchangForDateProvider(nextDate).future);
          } catch (_) {
            // Fall through – sheet works without panchang too
          }
        }

        if (!context.mounted) return;
        await showEventDetailSheet(
          context,
          festival: festival,
          panchang: panchang,
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.s12),
        padding: const EdgeInsets.all(AppSpacing.s16),
        decoration: BoxDecoration(
          color: Theme.of(
            context,
          ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(AppRadius.tile),
          border: Border.all(
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.1),
          ),
        ),
        child: Row(
          children: [
            FestivalThumbnail(
              festival: festival,
              size: 44,
              borderRadius: AppRadius.dense,
              backgroundColor: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: isMajor ? 0.2 : 0.1),
              glyphColor: Theme.of(context).colorScheme.primary,
              // Search results keep their own category glyphs (celebration /
              // event) rather than the row's sun/temple set.
              glyphIcon: isMajor ? Icons.celebration : Icons.event,
            ),
            const SizedBox(width: AppSpacing.s16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    festival.name,
                    style: const TextStyle(
                      fontWeight: AppTypography.semibold,
                      fontSize: AppTypography.sizeSubtitle,
                    ),
                  ),
                  if (festival.nameHindi != null)
                    Text(
                      festival.nameHindi!,
                      style: TextStyle(
                        fontSize: AppTypography.sizeCaption,
                        color: context.secondaryInk,
                      ),
                    ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, size: AppIconSize.medium),

            // Go to Date Button
            const SizedBox(width: AppSpacing.s8),
            IconButton(
              icon: const Icon(Icons.calendar_month_outlined),
              tooltip:
                  AppLocalizations.of(context)?.goToNextOccurrence ??
                  'Go to next occurrence',
              onPressed: () async {
                // Show loading or feedback
                final l10n = AppLocalizations.of(context);
                showAppMessage(
                  context,
                  l10n?.findingNextOccurrence ?? 'Finding next occurrence...',
                  duration: const Duration(seconds: 1),
                );

                // Find next date (cached; resolved location, not Delhi).
                // Resolution is Amanta-fixed; the sheet resolves its own
                // display system when fetching panchang.
                await ref.read(panchangInitProvider.future);
                final panchangService = ref.read(panchangServiceProvider);
                final coords = ref.read(resolvedCoordinatesProvider);
                final nextDate = await resolveOccurrenceDate(
                  service: panchangService,
                  festival: festival,
                  baseDate: dateOnly(ref.read(todayDateProvider)),
                  latitude: coords.latitude,
                  longitude: coords.longitude,
                );

                if (nextDate != null && context.mounted) {
                  // Navigate
                  setCalendarMonth(ref, nextDate);
                  ref.read(selectedDateProvider.notifier).setDate(nextDate);

                  // Close search
                  close(context, null);
                } else if (context.mounted) {
                  showAppMessage(
                    context,
                    l10n?.couldNotFindUpcomingOccurrence ??
                        'Could not find upcoming occurrence within a year.',
                    kind: AppMessageKind.error,
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
