import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../../models/festival_region.dart';
import '../../../providers/calendar_provider.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/settings_widgets.dart';

/// Localized label for a [FestivalRegion].
String festivalRegionLabel(AppLocalizations? l10n, FestivalRegion region) {
  switch (region) {
    case FestivalRegion.all:
      return l10n?.festivalRegionAll ?? 'All India';
    case FestivalRegion.north:
      return l10n?.festivalRegionNorth ?? 'North India';
    case FestivalRegion.south:
      return l10n?.festivalRegionSouth ?? 'South India';
    case FestivalRegion.east:
      return l10n?.festivalRegionEast ?? 'East India';
    case FestivalRegion.west:
      return l10n?.festivalRegionWest ?? 'West India';
    case FestivalRegion.central:
      return l10n?.festivalRegionCentral ?? 'Central India';
    case FestivalRegion.northeast:
      return l10n?.festivalRegionNortheast ?? 'North-East India';
  }
}

/// Localized one-line explanation for a [FestivalRegion] option.
String festivalRegionDescription(
  AppLocalizations? l10n,
  FestivalRegion region,
) {
  switch (region) {
    case FestivalRegion.all:
      return l10n?.festivalRegionAllDescription ??
          'No reordering — keep the default festival order';
    case FestivalRegion.north:
      return l10n?.festivalRegionNorthDescription ??
          'Show North Indian festivals first on shared dates';
    case FestivalRegion.south:
      return l10n?.festivalRegionSouthDescription ??
          'Show South Indian festivals first on shared dates';
    case FestivalRegion.east:
      return l10n?.festivalRegionEastDescription ??
          'Show East Indian festivals first on shared dates';
    case FestivalRegion.west:
      return l10n?.festivalRegionWestDescription ??
          'Show West Indian festivals first on shared dates';
    case FestivalRegion.central:
      return l10n?.festivalRegionCentralDescription ??
          'Show Central Indian festivals first on shared dates';
    case FestivalRegion.northeast:
      return l10n?.festivalRegionNortheastDescription ??
          'Show North-Eastern festivals first on shared dates';
  }
}

/// Calendar preference: which region's festivals lead when several festivals
/// fall on the same day.
class FestivalRegionSetting extends ConsumerWidget {
  const FestivalRegionSetting({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final region = ref.watch(festivalRegionProvider);
    final l10n = AppLocalizations.of(context);
    return SettingsActionTile(
      icon: Icons.public_rounded,
      title: l10n?.festivalRegion ?? 'Festival Region',
      trailing: Text(
        festivalRegionLabel(l10n, region),
        style: context.textTheme.bodyMedium?.copyWith(
          color: context.colors.primary,
          fontWeight: FontWeight.bold,
        ),
      ),
      onTap: () => _showRegionPicker(context, ref),
    );
  }

  Future<void> _showRegionPicker(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final currentRegion = ref.read(festivalRegionProvider);

    await SettingsBottomSheet.show(
      context: context,
      title: l10n?.festivalRegion ?? 'Festival Region',
      subtitle:
          l10n?.festivalRegionSubtitle ??
          'Choose which region\'s festivals appear first when several fall '
              'on the same day',
      children: FestivalRegion.values.map((region) {
        return SettingsPickerItem(
          title: festivalRegionLabel(l10n, region),
          subtitle: festivalRegionDescription(l10n, region),
          isSelected: region == currentRegion,
          onTap: () async {
            await ref
                .read(calendarPreferencesProvider.notifier)
                .setFestivalRegion(region);
            if (context.mounted) Navigator.pop(context);
          },
        );
      }).toList(),
    );
  }
}
