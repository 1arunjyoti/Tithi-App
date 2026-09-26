/// Shared naming for downloaded update APKs, importable from both the
/// conditional-export stub/io implementations and their callers.
library;

/// File name used for a downloaded release APK in the app cache.
/// `0.6.0+3` becomes `tithi-update-0.6.0_3.apk` (`+` is not file-safe).
String updateApkFileName(String version) {
  final safe = version.replaceAll(RegExp(r'[^\w\-.]+'), '_');
  return 'tithi-update-$safe.apk';
}
