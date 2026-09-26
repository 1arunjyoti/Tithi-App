import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../services/app_update_service.dart';

/// Lifecycle of an in-app update check.
enum AppUpdateStatus {
  idle,
  checking,
  upToDate,
  available,
  downloading,
  cancelling,
  readyToInstall,
  installing,
  error,
}

class AppUpdateState {
  const AppUpdateState({
    this.status = AppUpdateStatus.idle,
    this.currentVersion,
    this.release,
    this.progress = 0,
    this.downloadedFilePath,
    this.errorMessage,
  });

  final AppUpdateStatus status;
  final String? currentVersion;
  final AppReleaseInfo? release;

  /// `0.0`–`1.0`, or `-1` when the total download size is unknown.
  final double progress;
  final String? downloadedFilePath;
  final String? errorMessage;

  AppUpdateState copyWith({
    AppUpdateStatus? status,
    String? currentVersion,
    AppReleaseInfo? release,
    double? progress,
    String? downloadedFilePath,
    String? errorMessage,
    bool clearError = false,
  }) {
    return AppUpdateState(
      status: status ?? this.status,
      currentVersion: currentVersion ?? this.currentVersion,
      release: release ?? this.release,
      progress: progress ?? this.progress,
      downloadedFilePath: downloadedFilePath ?? this.downloadedFilePath,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

final appUpdateServiceProvider = Provider<AppUpdateService>((ref) {
  return AppUpdateService();
});

final appUpdateProvider =
    StateNotifierProvider<AppUpdateNotifier, AppUpdateState>((ref) {
  return AppUpdateNotifier(ref.read(appUpdateServiceProvider));
});

class AppUpdateNotifier extends StateNotifier<AppUpdateState> {
  AppUpdateNotifier(this._service) : super(const AppUpdateState());

  final AppUpdateService _service;

  /// Set while a download runs so the user can abandon it.
  bool _cancelRequested = false;

  /// True while a check, download or install is in flight.
  ///
  /// The 2-minute throttle only kicks in *after* a check completes, so
  /// without this guard rapid taps would start several overlapping
  /// requests whose responses could land out of order and leave the
  /// state showing a stale release.
  bool _inFlight = false;

  /// `true` when an operation is running; the UI uses this to disable
  /// actions that would otherwise queue up behind themselves.
  bool get isBusy => _inFlight;

  Future<String> _currentVersion() async {
    if (state.currentVersion != null) return state.currentVersion!;
    final info = await PackageInfo.fromPlatform();
    // PackageInfo splits versionName ("0.5.0") from versionCode ("5");
    // join them so an identical sideloaded build is not seen as older.
    final full = AppUpdateService.fullVersion(info.version, info.buildNumber);
    state = state.copyWith(currentVersion: full);
    return full;
  }

  /// Contacts GitHub releases and reports whether a newer build exists.
  ///
  /// Re-entrant calls are ignored while a check is already running, so
  /// repeated taps cannot race. Pass [force] to bypass the minimum
  /// interval that protects GitHub's unauthenticated hourly quota.
  Future<void> checkForUpdates({bool force = false}) async {
    if (_inFlight) return;
    if (!force &&
        _service.isCheckThrottled() &&
        state.status != AppUpdateStatus.idle) {
      return;
    }
    _inFlight = true;
    state = state.copyWith(
      status: AppUpdateStatus.checking,
      clearError: true,
      progress: 0,
    );
    try {
      final current = await _currentVersion();
      final release = await _service.fetchLatestRelease();
      if (release == null) {
        state = state.copyWith(
          status: AppUpdateStatus.error,
          errorMessage: 'No releases published yet.',
        );
        return;
      }
      if (AppUpdateService.isNewerThan(current, release.version)) {
        // Resume: the APK may already be cached from an earlier download
        // (e.g. the user downloaded but installed later / restarted).
        final cached = await _service.findDownloadedApk(release);
        if (cached != null) {
          state = state.copyWith(
            status: AppUpdateStatus.readyToInstall,
            release: release,
            downloadedFilePath: cached,
            progress: 1,
          );
        } else {
          state = state.copyWith(
            status: AppUpdateStatus.available,
            release: release,
          );
        }
      } else {
        state = state.copyWith(
          status: AppUpdateStatus.upToDate,
          release: release,
        );
      }
    } on AppUpdateException catch (e) {
      state = state.copyWith(
        status: AppUpdateStatus.error,
        errorMessage: e.message,
      );
    } finally {
      _inFlight = false;
    }
  }

  /// Downloads the pending release `.apk`, reporting progress.
  ///
  /// Ignored while another operation is in flight, so a double tap
  /// cannot start two downloads writing the same file.
  Future<void> downloadUpdate() async {
    if (_inFlight) return;
    final release = state.release;
    if (release == null || !release.hasApk) {
      state = state.copyWith(
        status: AppUpdateStatus.error,
        errorMessage: 'No installable update found.',
      );
      return;
    }
    _cancelRequested = false;
    _inFlight = true;
    state = state.copyWith(
      status: AppUpdateStatus.downloading,
      progress: 0,
      clearError: true,
    );
    try {
      final path = await _service.downloadApk(
        release: release,
        onProgress: (progress) {
          state = state.copyWith(
            status: AppUpdateStatus.downloading,
            progress: progress,
          );
        },
        isCancelled: () => _cancelRequested,
      );
      state = state.copyWith(
        status: AppUpdateStatus.readyToInstall,
        progress: 1,
        downloadedFilePath: path,
      );
    } on AppUpdateCancelled {
      // Back to the offer so the download can be started again.
      state = state.copyWith(
        status: AppUpdateStatus.available,
        progress: 0,
      );
    } on AppUpdateException catch (e) {
      state = state.copyWith(
        status: AppUpdateStatus.error,
        errorMessage: e.message,
      );
    } finally {
      _inFlight = false;
    }
  }

  /// Abandons an in-flight download; the partial file is discarded.
  ///
  /// The stream only notices on its next chunk, so the status moves to
  /// `cancelling` immediately. Without that intermediate state the
  /// Download button stays disabled and looks unresponsive until the
  /// stall timeout fires.
  void cancelDownload() {
    if (!_inFlight) return;
    _cancelRequested = true;
    state = state.copyWith(status: AppUpdateStatus.cancelling);
  }

  /// Hands the downloaded `.apk` to the Android package installer.
  Future<void> installUpdate() async {
    if (_inFlight) return;
    final path = state.downloadedFilePath;
    if (path == null) {
      state = state.copyWith(
        status: AppUpdateStatus.error,
        errorMessage: 'Nothing downloaded yet.',
      );
      return;
    }
    _inFlight = true;
    state = state.copyWith(
      status: AppUpdateStatus.installing,
      clearError: true,
    );
    try {
      await _service.installApk(path);
      state = state.copyWith(status: AppUpdateStatus.readyToInstall);
    } on AppUpdateException catch (e) {
      state = state.copyWith(
        status: AppUpdateStatus.error,
        errorMessage: e.message,
      );
    } finally {
      _inFlight = false;
    }
  }

  Future<void> openReleasesPage() async {
    try {
      await _service.openReleasesPage();
    } on AppUpdateException catch (e) {
      state = state.copyWith(
        status: AppUpdateStatus.error,
        errorMessage: e.message,
      );
    }
  }

  void reset() {
    state = AppUpdateState(currentVersion: state.currentVersion);
  }
}
