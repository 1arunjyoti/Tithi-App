import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../services/storage_service.dart';

/// One-time removal of the pre-migration FMTC tile database
/// (`<app documents>/fmtc`). Guarded by a prefs flag and fully best-effort:
/// a leftover tile cache harms nothing, so any failure just records the
/// attempt and moves on instead of retrying every launch.
Future<void> deleteFmtcOrphan() async {
  try {
    final settings = await StorageService().openSettingsBox();
    const flag = 'fmtc_orphan_removed_v1';
    if (settings.get(flag) == true) return;
    try {
      final docs = await getApplicationDocumentsDirectory();
      final orphan = Directory(p.join(docs.path, 'fmtc'));
      if (await orphan.exists()) {
        await orphan.delete(recursive: true);
      }
    } catch (_) {
      // Missing directory or locked files: not worth retrying.
    }
    await settings.put(flag, true);
  } catch (_) {
    // Storage unavailable: retry on a later launch (flag stays unset).
  }
}
