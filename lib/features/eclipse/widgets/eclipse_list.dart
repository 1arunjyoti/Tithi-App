import 'package:flutter/material.dart';

import '../../../core/anim/stagger_entrance.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/eclipse.dart';
import '../../../widgets/responsive_layout.dart';
import 'eclipse_card.dart';

/// Upcoming eclipses for one tab of [EclipseScreen].
///
/// The screen splits the provider's list by type and shows solar and lunar as
/// two peer tabs (the same split pattern as the moon phases screen's
/// Purnima/Amavasya tabs), so a list never buries the other one below a long
/// scroll. Each tab owns its own empty state.
class EclipseList extends StatelessWidget {
  const EclipseList({super.key, required this.eclipses});

  /// Already filtered to the tab's eclipse type.
  final List<Eclipse> eclipses;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    if (eclipses.isEmpty) {
      return Center(child: Text(l10n.noUpcomingDates));
    }

    return CenteredContent(
      maxWidth: 900,
      child: ListView(
        addRepaintBoundaries: false,
        padding: ResponsiveLayout.responsivePadding(context).add(
          EdgeInsets.only(bottom: MediaQuery.viewPaddingOf(context).bottom),
        ),
        children: [
          // Few items per tab (eclipses are rare), so all animate; the index
          // restarts per tab and only runs when that tab first builds.
          for (var i = 0; i < eclipses.length; i++)
            StaggerEntrance(
              index: i,
              child: EclipseCard(eclipse: eclipses[i]),
            ),
        ],
      ),
    );
  }
}
