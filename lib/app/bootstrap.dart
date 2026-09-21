import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';

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

  static Future<void>? _tileCacheInit;

  /// Map tile cache readiness (memoized). Kick off post-first-frame via
  /// [initTileCache]; consumers that need tiles (temple map) await this.
  static Future<void> get tileCacheReady =>
      _tileCacheInit ??= _initTileCacheStatic();

  static Future<void> _initTileCacheStatic() async {
    if (kIsWeb) return;
    await FMTCObjectBoxBackend().initialise(
      maxDatabaseSize: 256 * 1024 * 1024,
    );
    const tileStore = FMTCStore('osm_tiles');
    if (!await tileStore.manage.ready) {
      await tileStore.manage.create(maxLength: 8000);
    }
  }

  /// Starts tile-cache init without awaiting (post-first-frame entry).
  Future<void> initTileCache() => tileCacheReady;

  /// Background notification worker. Deferred: must not block first frame.
  Future<void> initBackgroundWork() async {
    if (kIsWeb) return;
    await NotificationService().initWorkManager();
  }
}


