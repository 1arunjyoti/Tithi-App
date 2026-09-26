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

  Future<String> _currentVersion() async {
    if (state.currentVersion != null) return state.currentVersion!;
    final info = await PackageInfo.fromPlatform();
    state = state.copyWith(currentVersion: info.version);
    return info.version;
  }

  /// Contacts GitHub releases and reports whether a newer build exists.
  Future<void> checkForUpdates() async {
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
        state = state.copyWith(
          status: AppUpdateStatus.available,
          release: release,
        );
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
    }
  }

  /// Downloads the pending release `.apk`, reporting progress.
  Future<void> downloadUpdate() async {
    final release = state.release;
    if (release == null || !release.hasApk) {
      state = state.copyWith(
        status: AppUpdateStatus.error,
        errorMessage: 'No installable update found.',
      );
      return;
    }
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
      );
      state = state.copyWith(
        status: AppUpdateStatus.readyToInstall,
        progress: 1,
        downloadedFilePath: path,
      );
    } on AppUpdateException catch (e) {
      state = state.copyWith(
        status: AppUpdateStatus.error,
        errorMessage: e.message,
      );
    }
  }

  /// Hands the downloaded `.apk` to the Android package installer.
  Future<void> installUpdate() async {
    final path = state.downloadedFilePath;
    if (path == null) {
      state = state.copyWith(
        status: AppUpdateStatus.error,
        errorMessage: 'Nothing downloaded yet.',
      );
      return;
    }
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
