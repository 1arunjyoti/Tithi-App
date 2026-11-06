import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/panchang_provider.dart';
import 'panchang_init_error_banner.dart';

/// Pins [PanchangInitErrorBanner] above every route in the app.
///
/// Mounted from `MaterialApp.builder`, so it sits above the navigator: a
/// failed ephemeris install stays visible on pushed screens and dialogs, not
/// just on the home screen. That matters because about two dozen call sites
/// await [panchangInitProvider] and most of them degrade quietly (the calendar
/// maps provider errors to `{}`), so without a shared surface the failure looks
/// like empty data instead of a broken install.
///
/// When init succeeds this returns [child] untouched, so the common path pays
/// no layout change. On failure the app is shifted down by the banner and the
/// consumed status-bar inset is removed from the child, so its own `AppBar`
/// does not pad for the status bar a second time.
class PanchangInitFailureOverlay extends ConsumerWidget {
  const PanchangInitFailureOverlay({super.key, required this.child});

  /// The app's navigator, as provided by `MaterialApp.builder`.
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final init = ref.watch(panchangInitProvider);
    if (!init.hasError) return child;

    return Column(
      children: [
        const SafeArea(
          bottom: false,
          child: Padding(
            padding: EdgeInsets.only(top: 8),
            child: PanchangInitErrorBanner(),
          ),
        ),
        Expanded(
          child: MediaQuery.removePadding(
            context: context,
            removeTop: true,
            child: child,
          ),
        ),
      ],
    );
  }
}
