import 'package:material_ui/material_ui.dart';

import '../../../core/anim/press_scale.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/festival.dart';
import '../../../providers/festival_provider.dart';
import '../../../theme/app_metrics.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/app_typography.dart';
import '../../../widgets/state_views.dart';
import '../../countdown/providers/countdown_providers.dart';
import 'festival_search_shell.dart';

/// The countdown screen's "add a festival" search.
///
/// Unlike the home search it returns the picked festival to the caller instead
/// of opening a sheet, hides entries already on the countdown list, and matches
/// regional (Bengali) names as well as English/Hindi.
class CountdownFestivalSearchDelegate extends FestivalSearchShell<Festival?> {
  CountdownFestivalSearchDelegate({required super.ref});

  @override
  String? get searchFieldLabel =>
      AppLocalizations.of(ref.context)?.searchFestivalName ??
      'Search festival name';

  @override
  Widget buildSearchResults(BuildContext context) {
    final festivals = ref.read(festivalProvider);
    final existingIds = ref
        .read(festivalCountdownPreferencesProvider)
        .countdownIds;
    final results = _searchFestivals(festivals, query, existingIds);

    if (query.trim().isEmpty) {
      return const _SearchPrompt();
    }

    if (results.isEmpty) {
      final l10n = AppLocalizations.of(context);
      return EmptyState(
        icon: Icons.search_off_rounded,
        title: l10n?.noFestivalsFound ?? 'No festivals found',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(AppSpacing.s16),
      itemCount: results.length,
      itemBuilder: (context, index) {
        final festival = results[index];
        return _FestivalSearchTile(
          festival: festival,
          onTap: () => close(context, festival),
        );
      },
    );
  }

  List<Festival> _searchFestivals(
    List<Festival> festivals,
    String query,
    List<String> existingIds,
  ) {
    final normalizedQuery = query.trim().toLowerCase();
    if (normalizedQuery.isEmpty) return const [];

    final existing = existingIds.toSet();
    final matches = festivals.where((festival) {
      if (existing.contains(festival.id)) return false;

      return festival.name.toLowerCase().contains(normalizedQuery) ||
          (festival.nameHindi?.toLowerCase().contains(normalizedQuery) ??
              false) ||
          (festival.nameRegional.nameBengali?.toLowerCase().contains(
                normalizedQuery,
              ) ??
              false) ||
          festival.category.toLowerCase().contains(normalizedQuery);
    }).toList();

    matches.sort((a, b) {
      final majorCompare = _isMajor(b).compareTo(_isMajor(a));
      if (majorCompare != 0) return majorCompare;
      return a.name.compareTo(b.name);
    });
    return matches;
  }

  int _isMajor(Festival festival) => festival.category == 'major' ? 1 : 0;
}

class _FestivalSearchTile extends StatelessWidget {
  const _FestivalSearchTile({required this.festival, required this.onTap});

  final Festival festival;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isMajor = festival.category == 'major';

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.s12),
      child: Material(
        color: Colors.transparent,
        // Stateless-safe gated haptic + scale.
        child: PressScale(
          child: ListTile(
            onTap: onTap,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.tile),
            ),
            tileColor: colors.surfaceContainerHighest.withValues(alpha: 0.3),
            leading: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: colors.primary.withValues(alpha: isMajor ? 0.18 : 0.1),
                borderRadius: BorderRadius.circular(AppRadius.dense),
              ),
              child: Icon(
                isMajor ? Icons.celebration_rounded : Icons.event_rounded,
                color: colors.primary,
              ),
            ),
            title: Text(
              festival.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: AppTypography.semibold),
            ),
            subtitle: festival.nameHindi == null
                ? null
                : Text(
                    festival.nameHindi!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
            trailing: const Icon(Icons.add_circle_outline_rounded),
          ),
        ),
      ),
    );
  }
}

class _SearchPrompt extends StatelessWidget {
  const _SearchPrompt();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Icon(
        Icons.search_rounded,
        size: AppIconSize.splash,
        color: context.colors.onSurface.withValues(alpha: 0.2),
      ),
    );
  }
}
