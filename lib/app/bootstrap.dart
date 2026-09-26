import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'tile_orphan.dart';

import '../core/storage/hive_adapters.dart';
import '../providers/version_provider.dart' as version_warmup;
import '../services/notification_service.dart';
import '../services/storage_service.dart';
import '../utils/tithi_localization.dart';
import 'package:timezone/data/latest.dart' as tz_data;

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
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
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

  /// Timezone DB (required before any `tz.TZDateTime` scheduling).
  void initTimezones() {
    tz_data.initializeTimeZones();
  }

  /// Version/package metadata warm-up before first drawer animation.
  Future<void> warmVersionInfo() => version_warmup.warmVersionInfo();

  /// Preloads the app's GoogleFonts families (Poppins, Martel, Noto Sans
  /// Bengali) so first paint doesn't flash fallback type or shift layout.
  /// Safe offline (failures swallowed); bounded by timeout so a stalled
  /// fetch can never hold up startup when awaited in [Future.wait].
  Future<void> warmFonts() async {
    try {
      GoogleFonts.poppins();
      GoogleFonts.poppinsTextTheme();
      GoogleFonts.martel();
      GoogleFonts.notoSansBengali();
      await GoogleFonts.pendingFonts().timeout(const Duration(seconds: 8));
    } catch (_) {
      // Offline or store unavailable: runtime fallback type applies.
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
    if (kIsWeb) return;
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
    if (kIsWeb) return;
    await NotificationService().initWorkManager();
  }
}


