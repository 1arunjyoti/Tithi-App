import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/home_widget.dart';
import 'festival_countdown_provider.dart';

/// Exposes the [HomeWidgetService] as a shared const instance.
/// Const constructor — no per-read allocation, no state to leak.
final homeWidgetServiceProvider = Provider<HomeWidgetService>((ref) {
  return const HomeWidgetService();
});

/// Whether the device supports pinning widgets (Android 8+ with launcher support).
/// keepAlive caches the platform-channel result across navigation so rebuilds
/// don't re-hit the MethodChannel on every card mount.
final homeWidgetPinSupportProvider = FutureProvider<bool>((ref) async {
  ref.keepAlive();
  final service = ref.watch(homeWidgetServiceProvider);
  return service.isRequestPinSupported();
});

/// Whether widgets are supported on this platform at all.
/// Purely synchronous platform check, but kept async for API symmetry.
/// keepAlive avoids re-evaluation on every rebuild.
final homeWidgetSupportedProvider = FutureProvider<bool>((ref) async {
  ref.keepAlive();
  final service = ref.watch(homeWidgetServiceProvider);
  return service.isWidgetSupported();
});

/// Side-effect provider: keeps the home screen widget in sync with ALL
/// festivals on the countdown page.
///
/// Note: this intentionally watches [allFestivalCountdownTargetsProvider],
/// not [homeFestivalCountdownTargetsProvider]. The home-pin (house icon)
/// only controls the in-app home section; the Android widget always shows
/// every countdown.
///
/// The widget theme is NOT synced here — it belongs to the widget itself
/// (configure screen on add, long-press → Reconfigure on API 31+).
///
/// Single-fire design: exactly ONE watch path (no parallel listen+watch),
/// so each data change triggers at most one sync. The service itself
/// dedups identical payloads, making rebuild-driven re-evaluation free
/// (early return before any platform-channel IPC).
///
/// Memory: no Stream/Timer/Controller held; Riverpod disposes the
/// subscription automatically when the last listener unsubscribes. No leak.
final homeWidgetSyncProvider = Provider<void>((ref) {
  final asyncTargets = ref.watch(allFestivalCountdownTargetsProvider);

  final targets = asyncTargets.valueOrNull;
  if (targets != null) {
    // Fire-and-forget: never block the build phase on IPC. unawaited
    // documents the intentional no-await and satisfies the lint.
    unawaited(
      ref
          .read(homeWidgetServiceProvider)
          .updateFestivalCountdownWidget(targets),
    );
  }
});
