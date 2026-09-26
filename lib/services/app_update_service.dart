import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import 'app_update/app_update_file.dart';

/// Raised when the user cancels an in-flight download.
class AppUpdateCancelled implements Exception {
  const AppUpdateCancelled();
}

/// GitHub repository used as the update source.
///
/// Publish Android release builds as `.apk` assets on GitHub releases
/// (e.g. `tithi-0.6.0+3-release.apk`, which is exactly what
/// `android/app/build.gradle.kts` names the release output) and this
/// service will discover, download and install them.
///
/// [owner]/[repo] can be overridden at build time with
/// `--dart-define=UPDATE_REPO=owner/repo` so a renamed or moved
/// repository does not require a code change.
class AppUpdateConfig {
  const AppUpdateConfig({this.owner = '1arunjyoti', this.repo = 'Tithi-App'});

  /// Reads `owner/repo` from `--dart-define=UPDATE_REPO=owner/repo`,
  /// falling back to the compiled-in defaults.
  factory AppUpdateConfig.fromEnvironment() {
    const override = String.fromEnvironment('UPDATE_REPO');
    final parts = override.split('/');
    if (parts.length != 2 || parts.first.isEmpty || parts.last.isEmpty) {
      return const AppUpdateConfig();
    }
    return AppUpdateConfig(owner: parts.first, repo: parts.last);
  }

  final String owner;
  final String repo;

  Uri get latestReleaseApiUrl =>
      Uri.https('api.github.com', '/repos/$owner/$repo/releases/latest');

  Uri get repoApiUrl => Uri.https('api.github.com', '/repos/$owner/$repo');

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
    required this.apkDigest,
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

  /// Expected SHA-256 of the APK asset as published by GitHub, in the
  /// `sha256:<hex>` form. Verified after download when present.
  final String? apkDigest;

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
    final digestRaw = apk?['digest']?.toString();

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
      apkDigest: digestRaw == null || digestRaw.isEmpty ? null : digestRaw,
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
  AppUpdateService({AppUpdateConfig? config, http.Client? httpClient})
    : config = config ?? AppUpdateConfig.fromEnvironment(),
      _httpClient = httpClient;

  final AppUpdateConfig config;
  final http.Client? _httpClient;

  static const Duration _checkTimeout = Duration(seconds: 15);

  /// Longest a download may make no progress before it is treated as
  /// stalled. Guards against a dropped Wi-Fi or captive portal that
  /// never closes the socket, which would otherwise hang forever.
  ///
  /// 60s rather than something tighter: a large APK on a weak link can
  /// legitimately pause this long between chunks (CDN throttling, a
  /// tunnel renegotiating), and aborting a working download is worse
  /// than waiting.
  static const Duration _downloadStallTimeout = Duration(seconds: 60);

  /// Minimum gap between two checks. Unauthenticated GitHub API calls
  /// are limited to 60/hour per IP, and carrier NAT makes many users
  /// share one, so accidental double taps must not burn the quota.
  static const Duration _minCheckInterval = Duration(minutes: 2);

  DateTime? _lastCheckAt;

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

  /// Joins `PackageInfo`'s separate `version` (e.g. `0.5.0`) and
  /// `buildNumber` (e.g. `5`) into the `major.minor.patch+build` form
  /// used for comparison.
  ///
  /// Comparing with only `version` would treat an identical sideloaded
  /// build as an update: installed `0.5.0` reads as build `0` while the
  /// published `0.5.0+5` reads as build `5`.
  static String fullVersion(String version, String buildNumber) {
    final v = normalizeVersion(version);
    final b = buildNumber.trim();
    return b.isEmpty ? v : '$v+$b';
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
  static int buildNumberOf(String version) {
    final parts = normalizeVersion(version).split('+');
    if (parts.length < 2) return 0;
    return int.tryParse(parts.last.trim()) ?? 0;
  }

  /// Display form of `major.minor.patch+build`: `0.5.0+5` -> `0.5.0 (5)`.
  /// Keeps the build visible so a same-name rebuild (`0.5.0` -> `0.5.0+3`)
  /// is not announced as "0.5.0 is already installed".
  static String displayVersion(String version) {
    final v = normalizeVersion(version);
    final name = v.split('+').first;
    final build = buildNumberOf(v);
    return build == 0 ? name : '$name ($build)';
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
    return buildNumberOf(a).compareTo(buildNumberOf(b));
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
    return buildNumberOf(latest) > buildNumberOf(current);
  }

  Map<String, String> get _apiHeaders => const {
    'Accept': 'application/vnd.github+json',
    'X-Github-Api-Version': '2022-11-28',
    'User-Agent': 'Tithi-App',
  };

  /// `true` when a check ran within [_minCheckInterval], so a repeated
  /// tap is ignored instead of spending another API call.
  bool isCheckThrottled() {
    final last = _lastCheckAt;
    if (last == null) return false;
    return DateTime.now().difference(last) < _minCheckInterval;
  }

  /// Fetches the latest GitHub release.
  ///
  /// Returns `null` when the repository exists but has no releases.
  /// A 404 that is *not* "no releases yet" (renamed, moved or private
  /// repository) is reported as an [AppUpdateException] instead, so the
  /// user is not sent chasing a release that will never appear.
  /// Throws [AppUpdateException] on rate limiting, network or parsing
  /// failures.
  Future<AppReleaseInfo?> fetchLatestRelease() async {
    final client = _httpClient ?? http.Client();
    final shouldClose = _httpClient == null;
    try {
      final response = await client
          .get(config.latestReleaseApiUrl, headers: _apiHeaders)
          .timeout(_checkTimeout);
      _lastCheckAt = DateTime.now();

      if (response.statusCode == 404) {
        if (await _repositoryExists(client)) return null;
        throw const AppUpdateException(
          'The update repository could not be found. It may have been '
          'renamed, moved, or made private.',
        );
      }
      if (_isRateLimited(response)) {
        throw const AppUpdateException(
          'GitHub is temporarily rate limiting update checks. Please try '
          'again in a few minutes.',
        );
      }
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
      // A failed check must stay immediately retryable (e.g. the user
      // just came back online); only a completed check starts the
      // throttle window.
      _lastCheckAt = null;
      rethrow;
    } on TimeoutException {
      _lastCheckAt = null;
      throw const AppUpdateException(
        'Update check timed out. Check your connection and try again.',
      );
    } catch (e) {
      // SocketException (no connectivity) lands here along with any
      // other transport failure; keep the message actionable.
      debugPrint('Update check failed: $e');
      _lastCheckAt = null;
      throw const AppUpdateException(
        'No internet connection. Connect and try again.',
      );
    } finally {
      if (shouldClose) client.close();
    }
  }

  /// Secondary lookup used only on the 404 path: tells "no releases yet"
  /// apart from "no such repository". Only reached when the release
  /// endpoint 404s, so it costs nothing in the normal case.
  Future<bool> _repositoryExists(http.Client client) async {
    try {
      final response = await client
          .get(config.repoApiUrl, headers: _apiHeaders)
          .timeout(_checkTimeout);
      return response.statusCode == 200;
    } catch (e) {
      // Unreachable or rate limited: assume the repository is fine so
      // the user sees "no releases yet" rather than a scary 404.
      debugPrint('Repository probe failed: $e');
      return true;
    }
  }

  /// GitHub answers 403 (or 429) with `x-ratelimit-remaining: 0` when
  /// the unauthenticated hourly quota is spent.
  static bool _isRateLimited(http.Response response) {
    if (response.statusCode != 403 && response.statusCode != 429) {
      return false;
    }
    return response.headers['x-ratelimit-remaining'] == '0';
  }

  /// Downloads the release `.apk` to the app cache directory.
  ///
  /// Reports download progress as `0.0`–`1.0`, or `-1` when the total
  /// size is unknown. Returns the saved file path. Throws
  /// [AppUpdateException] on failure and [AppUpdateCancelled] when
  /// [isCancelled] reports true. A stalled connection aborts after
  /// [_downloadStallTimeout] rather than hanging, and the completed file
  /// is checked against GitHub's published digest when one exists.
  Future<String> downloadApk({
    required AppReleaseInfo release,
    void Function(double progress)? onProgress,
    bool Function()? isCancelled,
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
      // `.timeout` restarts on every chunk, so it only fires when the
      // connection stalls (dropped Wi-Fi, captive portal) instead of
      // hanging forever at a fixed percentage.
      final progressStream = streamed.stream.timeout(_downloadStallTimeout).map(
        (chunk) {
          if (isCancelled?.call() ?? false) {
            throw const AppUpdateCancelled();
          }
          received += chunk.length;
          if (total > 0) {
            onProgress?.call(received / total);
          } else {
            onProgress?.call(-1);
          }
          return chunk;
        },
      );
      final path = await saveApkStream(
        progressStream,
        updateApkFileName(release.version),
      );

      // GitHub publishes a size and a SHA-256 for each asset; verify both
      // before handing the file to the installer. Android verifies the
      // signing cert, so this guards against a truncated or corrupted
      // download rather than a tampered build.
      final intact = await isApkIntact(
        path,
        expectedSize: release.apkSizeBytes,
        expectedDigest: release.apkDigest,
      );
      if (!intact) {
        await deleteApkFile(path);
        throw const AppUpdateException(
          'The downloaded file failed its integrity check. Please try again.',
        );
      }

      // Best-effort: keep only the newest APK (~80MB each). The latest
      // is kept even after installing so a retry (e.g. after granting
      // the install permission) doesn't need a fresh download.
      await purgeOldUpdateApks(keepPath: path);
      onProgress?.call(1);
      return path;
    } on AppUpdateCancelled {
      rethrow;
    } on AppUpdateException {
      rethrow;
    } on TimeoutException {
      throw const AppUpdateException(
        'The download stalled. Check your connection and try again.',
      );
    } catch (e) {
      debugPrint('APK download failed: $e');
      throw const AppUpdateException(
        'Connection lost during download. Please retry.',
      );
    } finally {
      if (shouldClose) client.close();
    }
  }

  /// Lowercase hex SHA-256 from GitHub's `sha256:<hex>` digest field,
  /// or `null` when absent or malformed.
  static String? _expectedDigestHex(String? digest) {
    final raw = digest?.trim();
    if (raw == null || raw.isEmpty) return null;
    final hex = (raw.contains(':') ? raw.split(':').last : raw)
        .trim()
        .toLowerCase();
    return hex.length == 64 ? hex : null;
  }

  /// `true` when the cached file is a complete, untampered copy of the
  /// release asset.
  ///
  /// A download killed with the process (rather than failing with an
  /// exception) leaves a truncated file behind, and the resume path
  /// would otherwise hand it to the installer, which fails with an
  /// unexplained parse error. Size is checked first because it is
  /// cheap, then the digest when GitHub published one.
  static Future<bool> isApkIntact(
    String path, {
    int? expectedSize,
    String? expectedDigest,
  }) async {
    final size = await apkFileSize(path);
    if (size == null || size <= 0) return false;
    if (expectedSize != null && expectedSize > 0 && size != expectedSize) {
      debugPrint('Cached APK size mismatch: expected $expectedSize, got $size');
      return false;
    }
    final wanted = _expectedDigestHex(expectedDigest);
    if (wanted == null) return true;
    final actual = await apkFileDigest(path);
    if (actual == null || actual.toLowerCase() != wanted) {
      debugPrint('Cached APK digest mismatch: expected $wanted, got $actual');
      return false;
    }
    return true;
  }

  /// Path of a previously downloaded APK for [release], if it is still
  /// in the cache and still intact. Lets the app resume at "ready to
  /// install" instead of downloading the same build again (e.g. after a
  /// restart). A corrupt or truncated leftover is deleted so the next
  /// check offers a clean download.
  Future<String?> findDownloadedApk(AppReleaseInfo release) async {
    final path = await findCachedApkPath(release.version);
    if (path == null) return null;
    try {
      final intact = await isApkIntact(
        path,
        expectedSize: release.apkSizeBytes,
        expectedDigest: release.apkDigest,
      );
      if (intact) return path;
      await deleteApkFile(path);
      return null;
    } catch (e) {
      debugPrint('Cached APK inspection failed: $e');
      return null;
    }
  }

  /// Launches the Android package installer for a downloaded `.apk`.
  ///
  /// On Android 8+, the "install unknown apps" permission is checked
  /// *before* handing off: when it is missing the system settings are
  /// opened and an [AppUpdateException] explains the next step, instead
  /// of letting the user hit an unexplained system error. The Kotlin
  /// side keeps the same guard as a backstop.
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
    if (!await queryCanRequestInstalls()) {
      await _tryOpenInstallSettings();
      throw const AppUpdateException(
        'Allow installs from Tithi in system settings, then tap Install again.',
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

  /// Opens the "install unknown apps" settings. Never throws: failing to
  /// open settings must not mask the actionable permission message.
  Future<void> _tryOpenInstallSettings() async {
    try {
      await openUnknownAppsSettings();
    } catch (e) {
      debugPrint('Could not open install settings: $e');
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
