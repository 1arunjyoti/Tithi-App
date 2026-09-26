// Web stub: APK files cannot be saved and there is no package
// installer, so every operation reports as unsupported. Callers fall
// back to opening the GitHub releases page in the browser.

Future<bool> get supportsApkFileOperations async => false;

Future<String> saveApkStream(Stream<List<int>> stream, String fileName) {
  throw UnsupportedError('APK download is not supported on web.');
}

Future<bool> apkFileExists(String path) async => false;

/// Web stub: nothing is ever downloaded, so nothing is ever cached.
Future<String?> findCachedApkPath(String version) async => null;

/// Web stub: no file is ever cached, so there is nothing to inspect.
Future<int?> apkFileSize(String path) async => null;

Future<String?> apkFileDigest(String path) async => null;

Future<void> deleteApkFile(String path) async {}

/// Web stub: nothing is ever downloaded, so nothing to purge.
Future<int> purgeOldUpdateApks({String? keepPath}) => Future.value(0);

Future<void> installDownloadedApk(String path) {
  throw UnsupportedError('APK install is not supported on web.');
}

Future<bool> queryCanRequestInstalls() async => false;

Future<void> openUnknownAppsSettings() {
  throw UnsupportedError('Install settings are not available on web.');
}
