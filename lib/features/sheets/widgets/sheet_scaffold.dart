import 'package:flutter/material.dart';

import 'edge_dismiss.dart';
import 'sheet_hero_header.dart';

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
  });

  final bool highContrast;
  final Widget hero;
  final Widget body;

  @override
  Widget build(BuildContext context) {
    // Cap the sheet at 85% of the screen height: below the cap the column
    // still shrink-wraps (min height is unconstrained).
    final maxHeight = MediaQuery.sizeOf(context).height * 0.85;
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: SafeArea(
          child: EdgeDismiss(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SheetHeroHeader(highContrast: highContrast, child: hero),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    child: body,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
