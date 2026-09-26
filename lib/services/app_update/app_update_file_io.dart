import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import 'update_apk_name.dart';

/// `true` when the platform can save files (everything except web).
Future<bool> get supportsApkFileOperations async => true;

/// Streams an HTTP response body to the cache directory under
/// [updateApkFileName]. Overwrites partial files. Returns the saved path.
///
/// A failed stream never leaves a partial APK behind: leftovers would
/// look like a complete download to the next update check.
Future<String> saveApkStream(Stream<List<int>> stream, String fileName) async {
  final directory = await getTemporaryDirectory();
  final safeName = fileName.replaceAll(RegExp(r'[^\w\-.]+'), '_');
  final file = File('${directory.path}/$safeName');
  if (await file.exists()) await file.delete();
  final sink = file.openWrite();
  try {
    await for (final chunk in stream) {
      sink.add(chunk);
    }
  } catch (_) {
    try {
      await sink.flush();
      await sink.close();
      await file.delete();
    } catch (_) {}
    rethrow;
  }
  await sink.flush();
  await sink.close();
  return file.path;
}

/// Path of an already-downloaded APK for [version], or `null` when it
/// is not (or no longer) in the cache.
Future<String?> findCachedApkPath(String version) async {
  try {
    final directory = await getTemporaryDirectory();
    final file = File('${directory.path}/${updateApkFileName(version)}');
    return await file.exists() ? file.path : null;
  } catch (_) {
    return null;
  }
}

Future<bool> apkFileExists(String path) async => File(path).exists();

/// Size of the cached APK in bytes, or `null` when it cannot be read.
Future<int?> apkFileSize(String path) async {
  try {
    return await File(path).length();
  } catch (_) {
    return null;
  }
}

/// SHA-256 of the cached APK as lowercase hex, or `null` on failure.
Future<String?> apkFileDigest(String path) async {
  try {
    final digest = await sha256.bind(File(path).openRead()).first;
    return digest.toString();
  } catch (_) {
    return null;
  }
}

/// Best-effort delete of a cached APK.
Future<void> deleteApkFile(String path) async {
  try {
    final file = File(path);
    if (await file.exists()) await file.delete();
  } catch (_) {
    // Nothing else to do: the caller only wants the file gone.
  }
}

/// Deletes downloaded update APKs other than [keepPath].
///
/// Update APKs are ~80MB each, so only the newest is retained; older
/// ones are removed whenever a fresh download completes. Never throws;
/// returns the removal count.
Future<int> purgeOldUpdateApks({String? keepPath}) async {
  // Compare by file name: directory listings may use different path
  // separators than the saved path (e.g. backslashes on Windows).
  String? keepName;
  if (keepPath != null) {
    final segments = keepPath.split(RegExp(r'[\\/]'));
    keepName = segments.isNotEmpty ? segments.last : null;
  }
  try {
    final directory = await getTemporaryDirectory();
    var removed = 0;
    await for (final entity in directory.list()) {
      if (entity is! File) continue;
      final name = entity.uri.pathSegments.isNotEmpty
          ? entity.uri.pathSegments.last
          : '';
      if (!name.startsWith('tithi-update-') || !name.endsWith('.apk')) {
        continue;
      }
      if (keepName != null && name == keepName) continue;
      try {
        await entity.delete();
        removed++;
      } catch (_) {
        continue;
      }
    }
    return removed;
  } catch (_) {
    return 0;
  }
}

const MethodChannel _installerChannel =
    MethodChannel('app.tithi.pro/app_update');

/// Hands a downloaded `.apk` to the Android package installer.
///
/// On Android 8+, when the "install unknown apps" permission is missing,
/// the system settings are opened and a [PlatformException] is thrown
/// explaining the next step.
Future<void> installDownloadedApk(String path) async {
  if (!await apkFileExists(path)) {
    throw MissingPluginException('Downloaded file is missing.');
  }
  await _installerChannel.invokeMethod<bool>('installApk', {'path': path});
}

/// `true` when the app may already request package installs (Android 8+).
///
/// A missing plugin reports `true` on purpose: sending the user to the
/// "install unknown apps" settings would be wrong when no installer
/// exists at all, and the install attempt then surfaces the accurate
/// "Installer is unavailable" error instead.
Future<bool> queryCanRequestInstalls() async {
  try {
    final result =
        await _installerChannel.invokeMethod<bool>('canRequestInstalls');
    return result ?? true;
  } on MissingPluginException {
    return true;
  }
}

/// Opens the system "install unknown apps" settings for this app.
Future<void> openUnknownAppsSettings() async {
  await _installerChannel.invokeMethod<bool>('openInstallPermissionSettings');
}
