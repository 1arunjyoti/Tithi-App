import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

/// `true` when the platform can save files (everything except web).
Future<bool> get supportsApkFileOperations async => true;

/// Streams an HTTP response body to `tithi-update-<fileName>` in the app
/// cache directory. Overwrites partial files. Returns the saved path.
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
  } finally {
    await sink.flush();
    await sink.close();
  }
  return file.path;
}

Future<bool> apkFileExists(String path) async => File(path).exists();

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
Future<bool> queryCanRequestInstalls() async {
  try {
    final result =
        await _installerChannel.invokeMethod<bool>('canRequestInstalls');
    return result ?? true;
  } on MissingPluginException {
    return false;
  }
}

/// Opens the system "install unknown apps" settings for this app.
Future<void> openUnknownAppsSettings() async {
  await _installerChannel.invokeMethod<bool>('openInstallPermissionSettings');
}
