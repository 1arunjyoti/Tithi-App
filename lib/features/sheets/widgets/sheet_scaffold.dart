import 'package:material_ui/material_ui.dart';

import 'edge_dismiss.dart';
import 'sheet_hero_header.dart';
import '../../../theme/app_metrics.dart';

// Canonical bottom-sheet scaffold shared by the tithi detail sheet and
// the festival event sheet: capped at 85% of the screen height (the card
// stack keeps growing, so beyond the cap the SingleChildScrollView takes
// over), 32pt top radius matching the hero header, SafeArea + EdgeDismiss
// (sustained downward drag past the top edge pops the route) + scroll view.
//
// [hero] renders inside the gradient [SheetHeroHeader]; [body] renders in
// the 20/16 padded column below it (callers own their SectionHeaders and
// cards, in the same dotted-label + surface-card idiom).
class SheetScaffold extends StatelessWidget {
  const SheetScaffold({
    super.key,
    required this.highContrast,
    required this.hero,
    required this.body,
    this.expressive = false,
  });

  final bool highContrast;
  final Widget hero;
  final Widget body;

  /// When true, the M3E sheet owns the chrome: drop this widget's own surface,
  /// height cap, SafeArea and edge-dismiss, and attach the scroll view to the
  /// sheet's primary scroll controller.
  final bool expressive;

  @override
  Widget build(BuildContext context) {
    if (expressive) {
      return SingleChildScrollView(
        primary: true,
        padding: const EdgeInsets.only(bottom: AppSpacing.s28),
        child: _content(),
      );
    }
    // Cap the sheet at 85% of the screen height: below the cap the column
    // still shrink-wraps (min height is unconstrained).
    final maxHeight = MediaQuery.sizeOf(context).height * 0.85;
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: AppRadius.sheetTop,
        ),
        child: SafeArea(
          child: EdgeDismiss(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: AppSpacing.s28),
              child: _content(),
            ),
          ),
        ),
      ),
    );
  }

  /// Hero + body shared by the classic and expressive variants.
  Widget _content() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SheetHeroHeader(highContrast: highContrast, child: hero),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.s20,
            AppSpacing.s16,
            AppSpacing.s20,
            0,
          ),
          child: body,
        ),
      ],
    );
  }
}
