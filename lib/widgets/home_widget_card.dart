import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../providers/home_widget_provider.dart';
import '../features/home_widget/providers/home_widget_promo_providers.dart';
import '../theme/app_theme.dart';

export '../features/home_widget/providers/home_widget_promo_providers.dart'
    show homeWidgetPromoDismissedProvider, HomeWidgetPromoDismissNotifier;

/// Card that lets the user add the festival countdown widget to the Android
/// home screen. Shown on the home screen below countdowns and in settings.
/// On unsupported platforms the widget renders nothing.
class HomeWidgetCard extends ConsumerWidget {
  const HomeWidgetCard({super.key, this.showDismiss = false});

  /// Shows a close button that hides the card (persisted). Enabled on home;
  /// the countdown screen keeps the card permanently.
  final bool showDismiss;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Keep widget in sync
    ref.watch(homeWidgetSyncProvider);

    if (showDismiss && ref.watch(homeWidgetPromoDismissedProvider)) {
      return const SizedBox.shrink();
    }
    // Dismissal and support-state swaps glide closed/open instead of popping
    // the column below.
    return AnimatedSize(
      alignment: Alignment.topCenter,
      duration: AppTheme.animationDuration(
        context,
        const Duration(milliseconds: 250),
      ),
      curve: Curves.easeInOutCubic,
      child: _supportedBody(context, ref),
    );
  }

  Widget _supportedBody(BuildContext context, WidgetRef ref) {
    final supported = ref.watch(homeWidgetSupportedProvider);
    return supported.when(
      data: (isSupported) {
        if (!isSupported) return const SizedBox.shrink();
        final pinSupported = ref.watch(homeWidgetPinSupportProvider);
        return pinSupported.when(
          data: (canPin) => _buildCard(context, ref, canPin),
          loading: () => _buildCard(context, ref, false, isLoading: true),
          error: (_, _) => _buildCard(context, ref, false),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }

  Widget _buildCard(
    BuildContext context,
    WidgetRef ref,
    bool canPin, {
    bool isLoading = false,
  }) {
    final colors = context.colors;
    final accent = AppTheme.festivalAccent(context);
    final l10n = AppLocalizations.of(context);
    return Container(
      decoration: AppTheme.glassmorphism(context: context, ref: ref),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppTheme.festivalTileBackground(context),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(Icons.widgets_rounded, color: accent),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n?.homeScreenWidget ?? 'Home Screen Widget',
                  style: context.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  canPin
                      ? l10n?.homeWidgetCountdownDescription ??
                            'Add festival countdowns to your home screen'
                      : l10n?.homeWidgetManualHint ??
                            'Long-press home screen → Widgets → Tithi',
                  style: context.textTheme.bodySmall?.copyWith(
                    color: colors.onSurface.withValues(
                      alpha: AppTheme.contrastAlpha(context, 0.64),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (isLoading)
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: accent),
            )
          else if (canPin)
            FilledButton(
              onPressed: () => _requestPin(context, ref),
              style: FilledButton.styleFrom(
                backgroundColor: accent,
                foregroundColor: AppTheme.onFestivalAccent(context),
              ),
              child: Text(AppLocalizations.of(context)?.add ?? 'Add'),
            )
          else
            IconButton(
              tooltip: AppLocalizations.of(context)?.infoTooltip ?? 'Info',
              onPressed: () => _showManualInstructions(context),
              icon: const Icon(Icons.info_outline_rounded),
            ),
          if (showDismiss) ...[
            const SizedBox(width: 4),
            IconButton(
              tooltip:
                  AppLocalizations.of(context)?.dismissTooltip ?? 'Dismiss',
              onPressed: () =>
                  ref.read(homeWidgetPromoDismissedProvider.notifier).dismiss(),
              icon: const Icon(Icons.close_rounded, size: 18),
              color: colors.onSurface.withValues(
                alpha: AppTheme.contrastAlpha(context, 0.5),
              ),
              style: IconButton.styleFrom(
                minimumSize: const Size(32, 32),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _requestPin(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final service = ref.read(homeWidgetServiceProvider);
    final success = await service.requestPinWidget();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? l10n?.widgetPinRequested ??
                    'Widget pin requested — confirm on home screen'
              : l10n?.couldNotPinWidget ??
                    'Could not pin widget. Try adding manually: long-press → Widgets → Tithi',
        ),
      ),
    );
  }

  void _showManualInstructions(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    unawaited(
      showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(l10n?.addWidgetManually ?? 'Add Widget Manually'),
          content: Text(
            l10n?.homeWidgetManualInstructions ??
                '1. Long-press on your home screen\n'
                    '2. Tap "Widgets"\n'
                    '3. Find "Tithi" and drag "Festival Countdowns" to your home screen\n\n'
                    'The widget shows all festivals from your Countdowns page.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l10n?.gotIt ?? 'Got it'),
            ),
          ],
        ),
      ),
    );
  }
}
