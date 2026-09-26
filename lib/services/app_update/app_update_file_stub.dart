// Web stub: APK files cannot be saved and there is no package
// installer, so every operation reports as unsupported. Callers fall
// back to opening the GitHub releases page in the browser.

Future<bool> get supportsApkFileOperations async => false;

Future<String> saveApkStream(Stream<List<int>> stream, String fileName) {
  throw UnsupportedError('APK download is not supported on web.');
}

Future<bool> apkFileExists(String path) async => false;

Future<void> installDownloadedApk(String path) {
  throw UnsupportedError('APK install is not supported on web.');
}

Future<bool> queryCanRequestInstalls() async => false;

Future<void> openUnknownAppsSettings() {
  throw UnsupportedError('Install settings are not available on web.');
}
