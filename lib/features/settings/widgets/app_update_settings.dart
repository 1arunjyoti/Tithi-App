import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../../providers/app_update_provider.dart';
import '../../../providers/version_provider.dart';
import '../../../services/app_update_service.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/settings_widgets.dart';

String _formatApkSize(int? bytes) {
  if (bytes == null || bytes <= 0) return '';
  return '${(bytes / 1048576).toStringAsFixed(1)} MB';
}

/// Compact entry point for the Settings screen.
class CheckForUpdatesTile extends ConsumerWidget {
  const CheckForUpdatesTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(appUpdateProvider);
    final installed =
        ref.watch(packageInfoProvider).valueOrNull?.version ??
        state.currentVersion;

    final busy = state.status == AppUpdateStatus.checking ||
        state.status == AppUpdateStatus.downloading ||
        state.status == AppUpdateStatus.installing;

    return SettingsActionTile(
      icon: Icons.system_update_rounded,
      title: l10n?.checkForUpdates ?? 'Check for updates',
      subtitle: _subtitle(l10n, state, installed),
      trailing: busy
          ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : state.status == AppUpdateStatus.available
              ? Icon(
                  Icons.fiber_new_rounded,
                  color: context.colors.primary,
                )
              : null,
      onTap: busy ? null : () async => _handleTap(context, ref),
    );
  }

  Future<void> _handleTap(BuildContext context, WidgetRef ref) async {
    final notifier = ref.read(appUpdateProvider.notifier);
    switch (ref.read(appUpdateProvider).status) {
      case AppUpdateStatus.available:
        await UpdateAvailableDialog.show(context);
      case AppUpdateStatus.readyToInstall:
        await notifier.installUpdate();
        if (context.mounted) await _reportError(context, ref);
      case AppUpdateStatus.idle:
      case AppUpdateStatus.upToDate:
      case AppUpdateStatus.error:
        await notifier.checkForUpdates();
        if (!context.mounted) return;
        final next = ref.read(appUpdateProvider);
        if (next.status == AppUpdateStatus.available) {
          await UpdateAvailableDialog.show(context);
        } else if (next.status == AppUpdateStatus.error) {
          await _reportError(context, ref);
        } else if (next.status == AppUpdateStatus.upToDate) {
          await _reportUpToDate(context, ref);
        }
      case AppUpdateStatus.checking:
      case AppUpdateStatus.downloading:
      case AppUpdateStatus.installing:
        break;
    }
  }
}

/// Full update card for the About screen: status, release notes,
/// download progress and install actions in one place.
class AppUpdateCard extends ConsumerWidget {
  const AppUpdateCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(appUpdateProvider);
    final installed =
        ref.watch(packageInfoProvider).valueOrNull?.version ??
        state.currentVersion;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppTheme.glassmorphism(context: context, ref: ref),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: context.colors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.system_update_rounded,
                  color: context.colors.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      state.status == AppUpdateStatus.available
                          ? l10n?.updateAvailable ?? 'Update available'
                          : l10n?.checkForUpdates ?? 'Check for updates',
                      style: context.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: context.colors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _subtitle(l10n, state, installed),
                      style: context.textTheme.bodySmall?.copyWith(
                        color: context.colors.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (state.release != null && _showsReleaseDetails(state.status)) ...[
            const SizedBox(height: 12),
            _ReleaseNotesPreview(release: state.release!),
          ],
          if (state.status == AppUpdateStatus.downloading) ...[
            const SizedBox(height: 12),
            _DownloadProgress(state: state),
          ],
          if (state.status == AppUpdateStatus.error &&
              state.errorMessage != null) ...[
            const SizedBox(height: 8),
            Text(
              state.errorMessage!,
              style: context.textTheme.bodySmall?.copyWith(
                color: context.colors.error,
              ),
            ),
          ],
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _PrimaryActionButton(state: state),
              TextButton.icon(
                onPressed: () async {
                  await ref.read(appUpdateProvider.notifier).openReleasesPage();
                },
                icon: const Icon(Icons.open_in_new_rounded, size: 18),
                label: Text(
                  l10n?.viewReleasesOnGitHub ?? 'View releases on GitHub',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PrimaryActionButton extends ConsumerWidget {
  const _PrimaryActionButton({required this.state});

  final AppUpdateState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final notifier = ref.read(appUpdateProvider.notifier);

    Future<void> check() async {
      await notifier.checkForUpdates();
      if (context.mounted) await _reportError(context, ref);
    }

    switch (state.status) {
      case AppUpdateStatus.checking:
        return FilledButton.tonal(
          onPressed: null,
          child: Text(l10n?.checkingForUpdates ?? 'Checking for updates…'),
        );
      case AppUpdateStatus.downloading:
        return FilledButton.tonal(
          onPressed: null,
          child: Text(l10n?.downloadingUpdate ?? 'Downloading update…'),
        );
      case AppUpdateStatus.installing:
        return FilledButton.tonal(
          onPressed: null,
          child: Text(l10n?.installingUpdate ?? 'Opening installer…'),
        );
      case AppUpdateStatus.available:
        if (!AppUpdateService.supportsInAppInstall) {
          return FilledButton(
            onPressed: () async => notifier.openReleasesPage(),
            child: Text(
              l10n?.viewReleasesOnGitHub ?? 'View releases on GitHub',
            ),
          );
        }
        return FilledButton.icon(
          onPressed: () async {
            await notifier.downloadUpdate();
            if (context.mounted) await _reportError(context, ref);
          },
          icon: const Icon(Icons.download_rounded),
          label: Text(l10n?.downloadUpdate ?? 'Download update'),
        );
      case AppUpdateStatus.readyToInstall:
        return FilledButton.icon(
          onPressed: () async {
            await notifier.installUpdate();
            if (context.mounted) await _reportError(context, ref);
          },
          icon: const Icon(Icons.install_mobile_rounded),
          label: Text(l10n?.installUpdate ?? 'Install update'),
        );
      case AppUpdateStatus.idle:
      case AppUpdateStatus.upToDate:
      case AppUpdateStatus.error:
        return FilledButton.icon(
          onPressed: check,
          icon: const Icon(Icons.refresh_rounded),
          label: Text(l10n?.checkForUpdates ?? 'Check for updates'),
        );
    }
  }
}

class _ReleaseNotesPreview extends StatelessWidget {
  const _ReleaseNotesPreview({required this.release});

  final AppReleaseInfo release;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final size = _formatApkSize(release.apkSizeBytes);
    final header = size.isEmpty
        ? release.version
        : '${release.version} • $size';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          header,
          style: context.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: context.colors.primary,
          ),
        ),
        if (release.body.trim().isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            l10n?.releaseNotes ?? "What's new",
            style: context.textTheme.labelSmall?.copyWith(
              color: context.colors.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            release.body.trim(),
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            style: context.textTheme.bodySmall?.copyWith(
              color: context.colors.onSurface.withValues(alpha: 0.78),
              height: 1.5,
            ),
          ),
        ],
      ],
    );
  }
}

class _DownloadProgress extends StatelessWidget {
  const _DownloadProgress({required this.state});

  final AppUpdateState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final determinate = state.progress >= 0;
    final percent = (state.progress.clamp(0, 1) * 100).round().toString();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LinearProgressIndicator(
          value: determinate ? state.progress.clamp(0, 1) : null,
        ),
        const SizedBox(height: 6),
        Text(
          determinate
              ? l10n?.downloadProgressPercent(percent) ?? '$percent% downloaded'
              : l10n?.downloadingUpdate ?? 'Downloading update…',
          style: context.textTheme.labelSmall?.copyWith(
            color: context.colors.onSurface.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }
}

/// Dialog that walks through check → download → install without
/// leaving the Settings screen.
class UpdateAvailableDialog extends ConsumerWidget {
  const UpdateAvailableDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (context) => const UpdateAvailableDialog(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(appUpdateProvider);
    final notifier = ref.read(appUpdateProvider.notifier);
    final release = state.release;

    return AlertDialog(
      title: Text(
        state.status == AppUpdateStatus.available
            ? l10n?.updateAvailable ?? 'Update available'
            : l10n?.checkForUpdates ?? 'Check for updates',
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (release != null) ...[
                Text(
                  release.name.isNotEmpty ? release.name : release.version,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                if (release.body.trim().isNotEmpty) ...[
                  Text(
                    l10n?.releaseNotes ?? "What's new",
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                  const SizedBox(height: 4),
                  Text(release.body.trim()),
                  const SizedBox(height: 8),
                ],
              ],
              switch (state.status) {
                AppUpdateStatus.downloading => _DownloadProgress(state: state),
                AppUpdateStatus.readyToInstall => Text(
                  l10n?.updateDownloaded ?? 'Update downloaded',
                ),
                AppUpdateStatus.installing => Text(
                  l10n?.installingUpdate ?? 'Opening installer…',
                ),
                AppUpdateStatus.error => Text(
                  state.errorMessage ??
                      l10n?.updateCheckFailed ??
                      "Couldn't check for updates",
                ),
                _ => const SizedBox.shrink(),
              },
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n?.cancel ?? 'Cancel'),
        ),
        if (state.status == AppUpdateStatus.available &&
            AppUpdateService.supportsInAppInstall)
          FilledButton.icon(
            onPressed: () async {
              await notifier.downloadUpdate();
              if (context.mounted) await _reportError(context, ref);
            },
            icon: const Icon(Icons.download_rounded),
            label: Text(l10n?.downloadUpdate ?? 'Download update'),
          ),
        if (state.status == AppUpdateStatus.available &&
            !AppUpdateService.supportsInAppInstall)
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              await notifier.openReleasesPage();
            },
            child: Text(
              l10n?.viewReleasesOnGitHub ?? 'View releases on GitHub',
            ),
          ),
        if (state.status == AppUpdateStatus.readyToInstall)
          FilledButton.icon(
            onPressed: () async {
              await notifier.installUpdate();
              if (context.mounted) {
                final next = ref.read(appUpdateProvider);
                if (next.status == AppUpdateStatus.error) {
                  Navigator.pop(context);
                  await _reportError(context, ref);
                }
              }
            },
            icon: const Icon(Icons.install_mobile_rounded),
            label: Text(l10n?.installUpdate ?? 'Install update'),
          ),
      ],
    );
  }
}

/// Release notes are only relevant while an update is pending or in
/// progress. Showing them for `upToDate`/`error` would present an older
/// (or stale) release as if it were available.
bool _showsReleaseDetails(AppUpdateStatus status) {
  switch (status) {
    case AppUpdateStatus.available:
    case AppUpdateStatus.downloading:
    case AppUpdateStatus.readyToInstall:
    case AppUpdateStatus.installing:
      return true;
    case AppUpdateStatus.idle:
    case AppUpdateStatus.checking:
    case AppUpdateStatus.upToDate:
    case AppUpdateStatus.error:
      return false;
  }
}

String _subtitle(
  AppLocalizations? l10n,
  AppUpdateState state,
  String? installed,
) {
  final versionLabel = installed == null
      ? ''
      : l10n?.versionText(installed) ?? 'Version $installed';
  switch (state.status) {
    case AppUpdateStatus.checking:
      return l10n?.checkingForUpdates ?? 'Checking for updates…';
    case AppUpdateStatus.downloading:
      if (state.progress >= 0) {
        final percent = (state.progress.clamp(0, 1) * 100).round().toString();
        return l10n?.downloadProgressPercent(percent) ?? '$percent% downloaded';
      }
      return l10n?.downloadingUpdate ?? 'Downloading update…';
    case AppUpdateStatus.installing:
      return l10n?.installingUpdate ?? 'Opening installer…';
    case AppUpdateStatus.available:
      final release = state.release;
      if (release == null) return l10n?.updateAvailable ?? 'Update available';
      return l10n?.updateAvailableVersion(release.version) ??
          'Version ${release.version} is available';
    case AppUpdateStatus.upToDate:
      return versionLabel.isEmpty
          ? l10n?.appUpToDate ?? "You're up to date"
          : '$versionLabel • ${l10n?.appUpToDate ?? "You're up to date"}';
    case AppUpdateStatus.readyToInstall:
      return l10n?.updateDownloaded ?? 'Update downloaded';
    case AppUpdateStatus.error:
      return state.errorMessage ??
          l10n?.updateCheckFailed ??
          "Couldn't check for updates";
    case AppUpdateStatus.idle:
      return versionLabel.isEmpty
          ? l10n?.checkForUpdates ?? 'Check for updates'
          : versionLabel;
  }
}

Future<void> _reportError(BuildContext context, WidgetRef ref) async {
  final state = ref.read(appUpdateProvider);
  if (state.status == AppUpdateStatus.error &&
      state.errorMessage != null &&
      context.mounted) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(state.errorMessage!)));
  }
}

Future<void> _reportUpToDate(BuildContext context, WidgetRef ref) async {
  if (!context.mounted) return;
  final l10n = AppLocalizations.of(context);
  final state = ref.read(appUpdateProvider);
  if (state.status == AppUpdateStatus.upToDate) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          l10n?.youHaveLatestVersion ?? 'You have the latest version',
        ),
      ),
    );
  }
}
