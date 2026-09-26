import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import 'app_update/app_update_file.dart';

/// GitHub repository used as the update source.
///
/// Publish Android release builds as `.apk` assets on GitHub releases
/// (e.g. `tithi-0.6.0+3-release.apk`, which is exactly what
/// `android/app/build.gradle.kts` names the release output) and this
/// service will discover, download and install them.
class AppUpdateConfig {
  const AppUpdateConfig({
    this.owner = '1arunjyoti',
    this.repo = 'Tithi-App',
  });

  final String owner;
  final String repo;

  Uri get latestReleaseApiUrl =>
      Uri.https('api.github.com', '/repos/$owner/$repo/releases/latest');

  Uri get releasesPageUrl =>
      Uri.https('github.com', '/$owner/$repo/releases/latest');
}

/// Thrown when the update check, download or install cannot proceed.
class AppUpdateException implements Exception {
  const AppUpdateException(this.message);

  final String message;

  @override
  String toString() => 'AppUpdateException: $message';
}

/// Release metadata parsed from the GitHub releases API.
class AppReleaseInfo {
  const AppReleaseInfo({
    required this.tagName,
    required this.version,
    required this.name,
    required this.body,
    required this.htmlUrl,
    required this.publishedAt,
    required this.apkUrl,
    required this.apkSizeBytes,
  });

  final String tagName;

  /// Normalized version without a leading `v` (e.g. `0.6.0` or `0.6.0+3`).
  final String version;
  final String name;
  final String body;
  final Uri htmlUrl;
  final DateTime? publishedAt;

  /// Direct download URL of the release `.apk` asset, if any.
  final Uri? apkUrl;
  final int? apkSizeBytes;

  /// `true` when the release carries an installable `.apk` asset.
  bool get hasApk => apkUrl != null;

  /// Parses `GET /repos/{owner}/{repo}/releases/latest` JSON.
  ///
  /// Prefers the `-release.apk` asset (the name this project's Gradle
  /// build produces) and falls back to any other `.apk` asset.
  factory AppReleaseInfo.fromJson(Map<String, dynamic> json) {
    final assets = json['assets'];
    final List<Map<String, dynamic>> assetList = assets is List
        ? assets.whereType<Map<String, dynamic>>().toList()
        : <Map<String, dynamic>>[];

    Map<String, dynamic>? pickApk() {
      final apks = assetList.where((a) {
        final name = a['name']?.toString().toLowerCase() ?? '';
        return name.endsWith('.apk');
      }).toList();
      if (apks.isEmpty) return null;
      for (final apk in apks) {
        if ((apk['name']?.toString() ?? '').contains('-release.apk')) {
          return apk;
        }
      }
      return apks.first;
    }

    final apk = pickApk();
    final apkUrlRaw = apk?['browser_download_url']?.toString();
    final sizeRaw = apk?['size'];

    final tag = json['tag_name']?.toString() ?? '';
    final publishedRaw = json['published_at']?.toString();

    return AppReleaseInfo(
      tagName: tag,
      version: AppUpdateService.normalizeVersion(tag),
      name: json['name']?.toString() ?? tag,
      body: json['body']?.toString() ?? '',
      htmlUrl: Uri.tryParse(json['html_url']?.toString() ?? '') ??
          Uri.https('github.com', '/'),
      publishedAt:
          publishedRaw == null ? null : DateTime.tryParse(publishedRaw),
      apkUrl: apkUrlRaw == null ? null : Uri.tryParse(apkUrlRaw),
      apkSizeBytes: sizeRaw is int ? sizeRaw : int.tryParse('$sizeRaw'),
    );
  }
}

/// Checks GitHub releases for a newer build, downloads the `.apk`
/// and hands it to the Android installer.
///
/// No new dependencies: `http`, `path_provider` and `url_launcher`
/// are already used by the app. File + installer operations live
/// behind a `dart.library.io` conditional export so web builds keep
/// compiling; there the service falls back to the releases page.
class AppUpdateService {
  AppUpdateService({
    this.config = const AppUpdateConfig(),
    http.Client? httpClient,
  }) : _httpClient = httpClient;

  final AppUpdateConfig config;
  final http.Client? _httpClient;

  static const Duration _checkTimeout = Duration(seconds: 15);

  /// `true` on Android, where the package installer exists.
  static bool get supportsInAppInstall {
    return !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  }

  /// Strips a leading `v` and surrounding whitespace: `v0.6.0+3` -> `0.6.0+3`.
  static String normalizeVersion(String tag) {
    var version = tag.trim();
    if (version.startsWith('v') || version.startsWith('V')) {
      version = version.substring(1);
    }
    return version.trim();
  }

  /// Splits `major.minor.patch` into ints, ignoring any `+build` suffix.
  static List<int> _coreParts(String version) {
    return normalizeVersion(version)
        .split('+')
        .first
        .split('.')
        .map((part) => int.tryParse(part.trim()) ?? 0)
        .toList();
  }

  /// The `+build` number, or `0` when absent. Maps to Android's
  /// `versionCode`, which is what the package installer enforces.
  static int _buildNumber(String version) {
    final parts = normalizeVersion(version).split('+');
    if (parts.length < 2) return 0;
    return int.tryParse(parts.last.trim()) ?? 0;
  }

  /// Compares two version strings (`-1` if [a] < [b], `0` if equal,
  /// `1` if [a] > [b]). Understands `major.minor.patch+buildCode`.
  static int compareVersions(String a, String b) {
    final aCore = _coreParts(a);
    final bCore = _coreParts(b);
    final length = aCore.length > bCore.length ? aCore.length : bCore.length;
    for (var i = 0; i < length; i++) {
      final aPart = i < aCore.length ? aCore[i] : 0;
      final bPart = i < bCore.length ? bCore[i] : 0;
      if (aPart != bPart) return aPart.compareTo(bPart);
    }
    return _buildNumber(a).compareTo(_buildNumber(b));
  }

  /// `true` only when [latest] is an installable update over [current]:
  /// its build number (`+N`, i.e. Android's `versionCode`) must be
  /// strictly higher, and its `major.minor.patch` must not be older.
  ///
  /// The build-number gate matters because Android refuses to install
  /// an APK whose `versionCode` is not higher than the installed one,
  /// so offering anything else would only end in an install failure.
  /// Same-name rebuilds (e.g. installed `0.5.0+2`, released `0.5.0+3`)
  /// therefore count as updates, while a higher version name with a
  /// lower-or-equal build number does not.
  static bool isNewerThan(String current, String latest) {
    if (normalizeVersion(current).isEmpty ||
        normalizeVersion(latest).isEmpty) {
      return false;
    }
    if (compareVersions(current, latest) >= 0) return false;
    return _buildNumber(latest) > _buildNumber(current);
  }

  /// Fetches the latest GitHub release.
  ///
  /// Returns `null` when no release is published yet (HTTP 404).
  /// Throws [AppUpdateException] on network or parsing failures.
  Future<AppReleaseInfo?> fetchLatestRelease() async {
    final client = _httpClient ?? http.Client();
    final shouldClose = _httpClient == null;
    try {
      final response = await client
          .get(
            config.latestReleaseApiUrl,
            headers: const {
              'Accept': 'application/vnd.github+json',
              'X-Github-Api-Version': '2022-11-28',
              'User-Agent': 'Tithi-App',
            },
          )
          .timeout(_checkTimeout);
      if (response.statusCode == 404) return null;
      if (response.statusCode != 200) {
        throw AppUpdateException(
          'GitHub returned HTTP ${response.statusCode}. Please try again later.',
        );
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw const AppUpdateException('Unexpected response from GitHub.');
      }
      return AppReleaseInfo.fromJson(decoded);
    } on AppUpdateException {
      rethrow;
    } on TimeoutException {
      throw const AppUpdateException(
        'Update check timed out. Check your connection and try again.',
      );
    } catch (e) {
      // SocketException (no connectivity) lands here along with any
      // other transport failure; keep the message actionable.
      debugPrint('Update check failed: $e');
      throw const AppUpdateException(
        'No internet connection. Connect and try again.',
      );
    } finally {
      if (shouldClose) client.close();
    }
  }

  /// Downloads the release `.apk` to the app cache directory.
  ///
  /// Reports download progress as `0.0`–`1.0`, or `-1` when the total
  /// size is unknown. Returns the saved file path. Throws
  /// [AppUpdateException] on failure.
  Future<String> downloadApk({
    required AppReleaseInfo release,
    void Function(double progress)? onProgress,
  }) async {
    final url = release.apkUrl;
    if (url == null) {
      throw const AppUpdateException(
        'This release has no APK attached. Open the releases page instead.',
      );
    }
    if (!await supportsApkFileOperations) {
      await openReleasesPage();
      throw const AppUpdateException(
        'Downloads work on Android. The releases page was opened instead.',
      );
    }
    final client = _httpClient ?? http.Client();
    final shouldClose = _httpClient == null;
    try {
      final request = http.Request('GET', url)
        ..headers['Accept'] = 'application/octet-stream'
        ..headers['User-Agent'] = 'Tithi-App';
      final streamed =
          await client.send(request).timeout(const Duration(minutes: 10));
      if (streamed.statusCode != 200) {
        throw AppUpdateException(
          'Download failed with HTTP ${streamed.statusCode}.',
        );
      }
      final total = streamed.contentLength ?? release.apkSizeBytes ?? -1;
      var received = 0;
      final progressStream = streamed.stream.map((chunk) {
        received += chunk.length;
        if (total > 0) {
          onProgress?.call(received / total);
        } else {
          onProgress?.call(-1);
        }
        return chunk;
      });
      final path = await saveApkStream(
        progressStream,
        'tithi-update-${release.version}.apk',
      );
      onProgress?.call(1);
      return path;
    } on AppUpdateException {
      rethrow;
    } on TimeoutException {
      throw const AppUpdateException('Download timed out. Please retry.');
    } catch (e) {
      debugPrint('APK download failed: $e');
      throw const AppUpdateException(
        'Connection lost during download. Please retry.',
      );
    } finally {
      if (shouldClose) client.close();
    }
  }

  /// Launches the Android package installer for a downloaded `.apk`.
  ///
  /// On Android 8+, when the "install unknown apps" permission is not
  /// yet granted, the system settings are opened and an
  /// [AppUpdateException] is thrown explaining the next step.
  /// On other platforms the releases page is opened in the browser.
  Future<void> installApk(String filePath) async {
    if (!supportsInAppInstall) {
      await openReleasesPage();
      throw const AppUpdateException(
        'In-app install works on Android. The releases page was opened instead.',
      );
    }
    if (!await apkFileExists(filePath)) {
      throw const AppUpdateException(
        'Downloaded file is missing. Please download again.',
      );
    }
    try {
      await installDownloadedApk(filePath);
    } on MissingPluginException catch (e) {
      debugPrint('Installer channel missing: $e');
      throw const AppUpdateException('Installer is unavailable in this build.');
    } on PlatformException catch (e) {
      throw AppUpdateException(e.message ?? 'Could not start the installer.');
    } on UnsupportedError catch (e) {
      throw AppUpdateException(e.message ?? 'Install is not supported here.');
    }
  }

  /// Opens the GitHub releases page in the external browser.
  Future<void> openReleasesPage() async {
    final url = config.releasesPageUrl;
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      throw AppUpdateException('Could not open $url');
    }
  }
}
