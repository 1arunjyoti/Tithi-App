import 'package:material_ui/material_ui.dart';

import '../../../core/anim/stagger_entrance.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/eclipse.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/screen_body.dart';
import '../../../widgets/state_views.dart';
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

    // Shared page frame: 12dp gutter and the 800 reading width every other
    // screen uses, so eclipse cards sit exactly as far from the edge as the
    // home cards do.
    return ScreenBody(
      child: eclipses.isEmpty
          ? EmptyState(
              icon: Icons.nights_stay_outlined,
              title: l10n.noUpcomingDates,
            )
          : ListView.separated(
              addRepaintBoundaries: false,
              // 16dp above the first card and below the last (plus the system
              // gesture inset); [AppTheme.cardGap] is the same gap the home
              // column uses.
              padding: EdgeInsets.only(
                top: AppTheme.cardGap,
                bottom:
                    AppTheme.cardGap + MediaQuery.viewPaddingOf(context).bottom,
              ),
              itemCount: eclipses.length,
              separatorBuilder: (_, _) =>
                  const SizedBox(height: AppTheme.cardGap),
              itemBuilder: (context, i) => StaggerEntrance(
                // Few items per tab (eclipses are rare), so all animate.
                index: i,
                child: EclipseCard(eclipse: eclipses[i]),
              ),
            ),
    );
  }
}
