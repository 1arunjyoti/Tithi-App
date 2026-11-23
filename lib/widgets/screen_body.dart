import 'package:material_ui/material_ui.dart';

import '../theme/app_theme.dart';

/// Outer frame for a page's scrollable body.
///
/// Two numbers used to be re-decided per screen - the side gutter (12 on home,
/// 16 on most pushed screens, 24 in settings) and the reading width (800
/// almost everywhere, 900 on eclipses) - which is why cards sat at different
/// distances from the edge depending on where you were. Both now come from
/// here: [AppTheme.pageGutter] on every breakpoint and an 800 max width.
///
/// Vertical rhythm stays with the scroll view ([AppTheme.cardGap] above the
/// first card, [AppTheme.cardGap] plus any system inset below the last), so
/// this widget never adds top/bottom padding of its own.
class ScreenBody extends StatelessWidget {
  const ScreenBody({
    super.key,
    required this.child,
    this.maxWidth = 800,
    this.gutter = AppTheme.pageGutter,
  });

  final Widget child;

  /// Reading width. 800 is the app-wide value; keep it unless a surface
  /// genuinely needs more (and change it here, not per screen).
  final double maxWidth;

  final double gutter;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: gutter),
          child: child,
        ),
      ),
    );
  }
}
