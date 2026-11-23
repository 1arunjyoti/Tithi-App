import 'package:material_ui/material_ui.dart';

import '../l10n/app_localizations.dart';
import '../theme/app_theme.dart';
import '../theme/app_metrics.dart';
import '../theme/app_typography.dart';

/// The last-resort screen shown when a widget throws.
///
/// Installed as the global `ErrorWidget.builder` in `main.dart`, so a build
/// failure renders this instead of Flutter's red screen. Local, recoverable
/// data errors use [ErrorState] instead: they stay inside the page and keep
/// its content, while this replaces it.
class ErrorDisplayWidget extends StatelessWidget {
  /// Optional error message to display
  final String? message;

  /// Optional retry callback
  final VoidCallback? onRetry;

  const ErrorDisplayWidget({super.key, this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Material(
      color: theme.scaffoldBackgroundColor,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.s32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.s20),
                decoration: BoxDecoration(
                  color: AppTheme.warningSoftBackground(),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.error_outline_rounded,
                  size: AppIconSize.display,
                  color: AppTheme.warningIconColor(isDark),
                ),
              ),
              const SizedBox(height: AppSpacing.s24),
              Text(
                l10n?.oopsSomethingWentWrong ?? 'Oops! Something went wrong',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: AppTypography.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.s12),
              Text(
                message ??
                    l10n?.unexpectedErrorOccurred ??
                    'An unexpected error occurred. Please try again.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: context.secondaryInk,
                ),
                textAlign: TextAlign.center,
              ),
              if (onRetry != null) ...[
                const SizedBox(height: AppSpacing.s24),
                FilledButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded),
                  label: Text(l10n?.retry ?? 'Retry'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
