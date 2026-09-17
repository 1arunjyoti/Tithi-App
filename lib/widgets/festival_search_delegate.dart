import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../models/festival.dart';
import '../models/panchang_data.dart';
import '../providers/accessibility_provider.dart';
import '../providers/festival_provider.dart';
import '../providers/calendar_provider.dart';
import '../providers/panchang_provider.dart';
import '../theme/app_theme.dart';

import 'event_detail_sheet.dart';

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
        hintStyle: TextStyle(fontSize: 18),
      ),
    );
  }

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        IconButton(
          icon: const Icon(Icons.clear),
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
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_rounded,
              size: 64,
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.2),
            ),
            const SizedBox(height: 16),
            Text(
              'Search for festivals, vrats, and events',
              style: TextStyle(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      );
    }

    if (results.isEmpty) {
      return Center(
        child: Text(
          'No festivals found',
          style: TextStyle(
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
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
        if (ref.read(accessibilityProvider).hapticFeedback) {
          await HapticFeedback.lightImpact();
        }
        // Try to find the next occurrence date so we can pass panchang context
        final panchangService = ref.read(panchangServiceProvider);
        final nextDate = await panchangService.findNextFestivalOccurrence(
          festival,
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
        await showModalBottomSheet(
          context: context,
          sheetAnimationStyle: AppTheme.sheetAnimationStyleOf(context),
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (context) =>
              EventDetailSheet(festival: festival, panchang: panchang),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(
            context,
          ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.1),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withValues(
                  alpha: isMajor ? 0.2 : 0.1,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                isMajor ? Icons.celebration : Icons.event,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    festival.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  if (festival.nameHindi != null)
                    Text(
                      festival.nameHindi!,
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, size: 20),

            // Go to Date Button
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.calendar_month_outlined),
              tooltip: AppLocalizations.of(context)?.goToNextOccurrence ?? 'Go to next occurrence',
              onPressed: () async {
                // Show loading or feedback
                final l10n = AppLocalizations.of(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(l10n?.findingNextOccurrence ?? 'Finding next occurrence...'),
                    duration: const Duration(seconds: 1),
                  ),
                );

                // Find next date
                final panchangService = ref.read(panchangServiceProvider);
                final nextDate = await panchangService
                    .findNextFestivalOccurrence(festival);

                if (nextDate != null && context.mounted) {
                  // Navigate
                  setCalendarMonth(ref, nextDate);
                  ref.read(selectedDateProvider.notifier).setDate(nextDate);

                  // Close search
                  close(context, null);
                } else if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(l10n?.couldNotFindUpcomingOccurrence ?? 'Could not find upcoming occurrence within a year.'),
                    ),
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
