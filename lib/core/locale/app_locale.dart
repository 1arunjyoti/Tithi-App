import 'package:flutter/widgets.dart';

// P0-1: single app-locale resolution (user override, else system).
// Replaces 6 copies of `ref.watch/read(localeProvider) ??
// WidgetsBinding.instance.platformDispatcher.locale` across sheets,
// heroes, and calendar header builders.
//
// Takes the already-watched/read override instead of a Ref so it works
// with both Ref (providers) and WidgetRef (widgets), which share no
// common watch/read interface in Riverpod 2:
//   resolveAppLocale(ref.watch(localeProvider))
Locale resolveAppLocale(Locale? override) =>
    override ?? WidgetsBinding.instance.platformDispatcher.locale;
