import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// A user-friendly error display widget that replaces the default red error screen.
/// Used both as a global ErrorWidget.builder replacement and for local error states.
class ErrorDisplayWidget extends StatelessWidget {
  /// Optional error message to display
  final String? message;

  /// Optional retry callback
  final VoidCallback? onRetry;

  /// Whether to show a compact version (for inline errors)
  final bool compact;

  const ErrorDisplayWidget({
    super.key,
    this.message,
    this.onRetry,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (compact) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.warningBackground(isDark),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.warningBorderColor()),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.warning_amber_rounded,
              color: AppTheme.warningStrong,
              size: 20,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                message ?? 'Something went wrong',
                style: TextStyle(
                  color: AppTheme.warningTextColor(isDark),
                  fontSize: 13,
                ),
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(width: 8),
              TextButton(
                onPressed: onRetry,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('Retry'),
              ),
            ],
          ],
        ),
      );
    }

    return Material(
      color: theme.scaffoldBackgroundColor,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppTheme.warningSoftBackground(),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.error_outline_rounded,
                  size: 56,
                  color: AppTheme.warningIconColor(isDark),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Oops! Something went wrong',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                message ?? 'An unexpected error occurred. Please try again.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
                textAlign: TextAlign.center,
              ),
              if (onRetry != null) ...[
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Try Again'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
