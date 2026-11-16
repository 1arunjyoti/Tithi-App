import 'dart:async';

import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:hive_flutter/hive_flutter.dart';
// `latest_all` (not `latest`) because place lookups can return any of the
// 419 zone identifiers in the timezone boundary data; 106 of them are absent
// from the reduced `latest` set and `getLocation` would throw on a hit.
import 'package:timezone/data/latest_all.dart' as tz_data;

import 'tile_orphan.dart';

import '../core/location/timezone_resolver.dart';
import '../core/storage/hive_adapters.dart';
import '../providers/version_provider.dart' as version_warmup;
import '../services/notification_service.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import '../utils/tithi_localization.dart';

/// Phase-1 app startup pipeline extracted from `main.dart`.
///
/// Each step is independently testable and ordered by critical-path:
/// critical UI deps first, heavy/deferrable work (tile cache, Workmanager)
/// last so the first frame is not blocked.
class AppBootstrap {
  const AppBootstrap();

  /// Chronological system UI + localization setup. Must run inside
  /// `WidgetsFlutterBinding.ensureInitialized`.
  Future<void> initSystem() async {
    await initializeLocalizedDateFormatting();
    // Android 15+ enforces edge-to-edge, but below that the Flutter engine only
    // lays the view out behind the system bars once Dart opts in. Ask for it
    // explicitly so the page background reaches the gesture / 3-button area on
    // every supported version (`MainActivity` handles API < 29, where the
    // engine ignores this mode).
    if (defaultTargetPlatform == TargetPlatform.android) {
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
    // Transparent bars with no contrast scrim; the launch window uses the
    // platform brightness, then `MaterialApp` re-applies the theme-aware style.
    SystemChrome.setSystemUIOverlayStyle(
      AppTheme.systemUiOverlayStyle(
        WidgetsBinding.instance.platformDispatcher.platformBrightness,
      ),
    );
  }

  /// Hive + adapters + core boxes. Replaces the inline block in `main()`.
  Future<StorageService> initStorage() async {
    await Hive.initFlutter();
    registerHiveAdapters();
    final storageService = StorageService();
    await storageService.init();
    return storageService;
  }

  /// Timezone DB (required before any `tz.TZDateTime` scheduling) and the
  /// place-boundary index (required before the first coordinate lookup).
  ///
  /// Decoding the boundary index here keeps the first place resolution
  /// (location init or a pick) off the UI thread's critical path.
  Future<void> initTimezones() async {
    tz_data.initializeTimeZones();
    await warmPlaceTimezoneIndex();
  }

  /// Version/package metadata warm-up before first drawer animation.
  ///
  /// Best-effort: when the platform channel is unavailable the drawer falls
  /// back to its placeholder version, which must not cost the user the app.
  /// Self-swallowing (like [warmFonts]) so awaiting it in a `Future.wait`
  /// during startup can never prevent `runApp`.
  Future<void> warmVersionInfo() async {
    try {
      await version_warmup.warmVersionInfo();
    } catch (error) {
      debugPrint('Version warm-up failed (non-fatal): $error');
    }
  }

  /// Shared tile cache: flutter_map's built-in file cache (replaces
  /// FMTC/ObjectBox, removed for its AGP-9-blocking native module and
  /// GPL-3.0 license). `getOrCreateInstance` honors the FIRST call's
  /// config, so every call site passes identical args — creation order
  /// between the warm-up below and the map screens doesn't matter.
  ///
  /// No freshness override: the OSM tile usage policy requires honouring
  /// server caching headers (with conditional revalidation), so the cache
  /// follows them instead of forcing 30 days. The byte cap (~old
  /// 8000-tile FMTC cap) keeps repeat views from re-downloading.
  static MapCachingProvider appTileCaching() =>
      BuiltInMapCachingProvider.getOrCreateInstance(
        maxCacheSize: 250 * 1024 * 1024,
      );

  static Future<void>? _tileCacheInit;

  /// Map tile cache readiness (memoized). Kick off post-first-frame via
  /// [initTileCache]; consumers that need tiles (temple map) await this.
  static Future<void> get tileCacheReady =>
      _tileCacheInit ??= _initTileCacheStatic();

  static Future<void> _initTileCacheStatic() async {
    // Warm the singleton with the app's config (no-op if a map screen won
    // the race — args are identical everywhere) and drop FMTC's orphaned
    // ObjectBox database once. Both best-effort; tiles work regardless.
    appTileCaching();
    await deleteFmtcOrphan();
  }

  /// Starts tile-cache init without awaiting (post-first-frame entry).
  Future<void> initTileCache() => tileCacheReady;

  /// Background notification worker. Deferred: must not block first frame.
  Future<void> initBackgroundWork() async {
    await NotificationService().initWorkManager();
  }
}
