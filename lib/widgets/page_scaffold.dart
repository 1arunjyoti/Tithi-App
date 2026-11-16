import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// The one page shell for a full-screen route or tab.
///
/// Eleven screens used to spell out the same four things by hand - a
/// transparent `AppBar` with `automaticallyImplyLeading: false`, the
/// `extendBodyBehindAppBar` flag, a `RepaintBoundary` around the ambient
/// background, and a `SafeArea(bottom: false)` so the gradient paints behind
/// the gesture handle - and each was free to get one of them slightly wrong.
/// They now come from here:
///
/// - [title], [leading], [actions], [bottom]: the app bar. Pass
///   `leading: const HapticBackButton()` for a pushed page and
///   `const AppDrawerButton()` for a tab that owns a drawer; the shell never
///   guesses, because the home tab has no leading at all on wide screens.
/// - [body]: the page content, already wrapped in a `ScreenBody` when the
///   page is a reading surface.
/// - [background] paints [AppTheme.backgroundDecoration] behind [body] and
///   isolates it in a `RepaintBoundary` (the gradient must not repaint on
///   every scroll frame).
/// - [safeArea] adds the `bottom: false` `SafeArea`. Leave it on for pages
///   whose scroll view adds the system inset to its own bottom padding, and
///   turn it off for pages that paint edge to edge themselves (map, canvas).
///
/// [extendBodyBehindAppBar] is false for the two form-style screens that keep
/// the default Scaffold body (they never wanted content behind the bar); in
/// that mode the background is a plain wrapper and [safeArea] is ignored,
/// matching what those screens did before.
class PageScaffold extends StatelessWidget {
  const PageScaffold({
    super.key,
    required this.body,
    this.title,
    this.leading,
    this.actions,
    this.bottom,
    this.drawer,
    this.onDrawerChanged,
    this.floatingActionButton,
    this.extendBodyBehindAppBar = true,
    this.safeArea = true,
    this.background = true,
  });

  final Widget body;
  final Widget? title;
  final Widget? leading;
  final List<Widget>? actions;
  final PreferredSizeWidget? bottom;
  final Widget? drawer;
  final DrawerCallback? onDrawerChanged;
  final Widget? floatingActionButton;
  final bool extendBodyBehindAppBar;
  final bool safeArea;
  final bool background;

  @override
  Widget build(BuildContext context) {
    Widget content = body;

    if (safeArea && extendBodyBehindAppBar) {
      content = SafeArea(bottom: false, child: content);
    }

    if (background) {
      if (extendBodyBehindAppBar) {
        content = Stack(
          children: [
            Positioned.fill(
              child: RepaintBoundary(
                child: Container(
                  decoration: AppTheme.backgroundDecoration(context),
                ),
              ),
            ),
            Positioned.fill(child: content),
          ],
        );
      } else {
        content = Container(
          decoration: AppTheme.backgroundDecoration(context),
          child: content,
        );
      }
    }

    return Scaffold(
      extendBodyBehindAppBar: extendBodyBehindAppBar,
      drawer: drawer,
      onDrawerChanged: onDrawerChanged,
      floatingActionButton: floatingActionButton,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: leading,
        title: title,
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: actions,
        bottom: bottom,
      ),
      body: content,
    );
  }
}
