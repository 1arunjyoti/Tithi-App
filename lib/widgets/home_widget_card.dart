import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/home_widget_provider.dart';
import '../theme/app_theme.dart';

/// Card that lets the user add the festival countdown widget to the Android
/// home screen. Shown on the home screen below countdowns and in settings.
/// On unsupported platforms the widget renders nothing.
class HomeWidgetCard extends ConsumerWidget {
  const HomeWidgetCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Keep widget in sync
    ref.watch(homeWidgetSyncProvider);

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
    return Container(
      decoration: AppTheme.glassmorphism(context: context, ref: ref),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: colors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.widgets_rounded, color: colors.primary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Home Screen Widget',
                  style: context.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  canPin
                      ? 'Add festival countdowns to your home screen'
                      : 'Long-press home screen → Widgets → Tithi',
                  style: context.textTheme.bodySmall?.copyWith(
                    color: colors.onSurface.withValues(alpha: 0.64),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (isLoading)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else if (canPin)
            FilledButton(
              onPressed: () => _requestPin(context, ref),
              child: const Text('Add'),
            )
          else
            IconButton(
              tooltip: 'Info',
              onPressed: () => _showManualInstructions(context),
              icon: const Icon(Icons.info_outline_rounded),
            ),
        ],
      ),
    );
  }

  Future<void> _requestPin(BuildContext context, WidgetRef ref) async {
    final service = ref.read(homeWidgetServiceProvider);
    final success = await service.requestPinWidget();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? 'Widget pin requested — confirm on home screen'
              : 'Could not pin widget. Try adding manually: long-press → Widgets → Tithi',
        ),
      ),
    );
  }

  void _showManualInstructions(BuildContext context) {
    unawaited(
      showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Add Widget Manually'),
          content: const Text(
            '1. Long-press on your home screen\n'
            '2. Tap "Widgets"\n'
            '3. Find "Tithi" and drag "Festival Countdowns" to your home screen\n\n'
            'The widget shows all festivals from your Countdowns page.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Got it'),
            ),
          ],
        ),
      ),
    );
  }
}
