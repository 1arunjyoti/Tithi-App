import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/anim/press_scale.dart';
import '../core/feedback/app_messages.dart';
import '../features/home_widget/providers/home_widget_promo_providers.dart';
import '../l10n/app_localizations.dart';
import '../providers/accessibility_provider.dart';
import '../providers/home_widget_provider.dart';
import '../services/home_widget.dart';
import '../theme/app_theme.dart';

export '../features/home_widget/providers/home_widget_promo_providers.dart'
    show homeWidgetPromoDismissedProvider, HomeWidgetPromoDismissNotifier;

/// One row in the home-widget gallery.
typedef _WidgetEntry = ({
  HomeWidgetKind kind,
  IconData icon,
  String label,
  String description,
});

/// Card that lets the user add any of the app's home screen widgets.
/// Collapsed to a single header row by default; tap the header to reveal the
/// five-row gallery. Shown on the home screen and the festival countdown
/// screen. On unsupported platforms the widget renders nothing.
class HomeWidgetCard extends ConsumerStatefulWidget {
  const HomeWidgetCard({super.key, this.showDismiss = false});

  /// Shows a close button that hides the card (persisted). Enabled on home;
  /// the countdown screen keeps the card permanently.
  final bool showDismiss;

  @override
  ConsumerState<HomeWidgetCard> createState() => _HomeWidgetCardState();
}

class _HomeWidgetCardState extends ConsumerState<HomeWidgetCard> {
  /// The gallery starts collapsed so the card stays a compact header on both
  /// screens. This is local state: a rebuilt card keeps it, but a newly
  /// mounted card starts collapsed again.
  bool _expanded = false;

  void _toggleExpanded() {
    if (ref.read(accessibilityProvider).hapticFeedback) {
      HapticFeedback.lightImpact();
    }
    setState(() => _expanded = !_expanded);
  }

  @override
  Widget build(BuildContext context) {
    // Keep widgets in sync
    ref.watch(homeWidgetSyncProvider);

    if (widget.showDismiss && ref.watch(homeWidgetPromoDismissedProvider)) {
      return const SizedBox.shrink();
    }
    // Dismissal and support-state swaps glide closed/open instead of popping
    // the column below. Expansion rides the same size animation.
    return AnimatedSize(
      alignment: Alignment.topCenter,
      duration: AppTheme.animationDuration(
        context,
        const Duration(milliseconds: 250),
      ),
      curve: Curves.easeInOutCubic,
      child: _supportedBody(context),
    );
  }

  Widget _supportedBody(BuildContext context) {
    final supported = ref.watch(homeWidgetSupportedProvider);
    return supported.when(
      data: (isSupported) {
        if (!isSupported) return const SizedBox.shrink();
        final pinSupported = ref.watch(homeWidgetPinSupportProvider);
        return pinSupported.when(
          data: (canPin) => _buildCard(context, canPin),
          loading: () => _buildCard(context, false, isLoading: true),
          error: (_, _) => _buildCard(context, false),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }

  Widget _buildCard(
    BuildContext context,
    bool canPin, {
    bool isLoading = false,
  }) {
    final l10n = AppLocalizations.of(context);
    final colors = context.colors;
    final accent = AppTheme.festivalAccent(context);
    final entries = <_WidgetEntry>[
      (
        kind: HomeWidgetKind.countdowns,
        icon: Icons.event_available_rounded,
        label: l10n?.widgetCountdownsLabel ?? 'Festival Countdowns',
        description:
            l10n?.homeWidgetCountdownDescription ??
            'Add festival countdowns to your home screen',
      ),
      (
        kind: HomeWidgetKind.hero,
        icon: Icons.auto_awesome_rounded,
        label: l10n?.widgetHeroLabel ?? 'Hero Card',
        description:
            l10n?.widgetHeroDescription ?? "Today's tithi, paksha and festival",
      ),
      (
        kind: HomeWidgetKind.auspicious,
        icon: Icons.wb_twilight_rounded,
        label: l10n?.widgetAuspiciousLabel ?? 'Auspicious Timings',
        description:
            l10n?.widgetAuspiciousDescription ??
            'Abhijit, Brahma Muhurta, Godhuli',
      ),
      (
        kind: HomeWidgetKind.inauspicious,
        icon: Icons.nightlight_round,
        label: l10n?.widgetInauspiciousLabel ?? 'Inauspicious Timings',
        description:
            l10n?.widgetInauspiciousDescription ??
            'Rahu Kalam, Yamaganda, Gulika',
      ),
      (
        kind: HomeWidgetKind.combined,
        icon: Icons.view_agenda_rounded,
        label: l10n?.widgetCombinedLabel ?? 'Auspicious & Inauspicious',
        description:
            l10n?.widgetCombinedDescription ?? 'Both timing sets in one widget',
      ),
    ];

    return Container(
      decoration: AppTheme.glassmorphism(context: context, ref: ref),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            // Tighter bottom gap while the rows are open; the collapsed card
            // keeps the standard 16dp edge.
            padding: EdgeInsets.fromLTRB(16, 16, 16, _expanded ? 8 : 16),
            child: Row(
              children: [
                Expanded(
                  child: Semantics(
                    button: true,
                    expanded: _expanded,
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: _toggleExpanded,
                        borderRadius: BorderRadius.circular(12),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: AppTheme.festivalTileBackground(context),
                                borderRadius: BorderRadius.circular(13),
                              ),
                              child: Icon(
                                Icons.widgets_rounded,
                                color: accent,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    l10n?.homeScreenWidget ??
                                        'Home Screen Widgets',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: context.textTheme.titleSmall
                                        ?.copyWith(fontWeight: FontWeight.w700),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    canPin
                                        ? l10n?.homeWidgetGallerySubtitle ??
                                              'Add panchang widgets to your home screen'
                                        : l10n?.homeWidgetManualHint ??
                                              'Long-press home screen → Widgets → Tithi',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: context.textTheme.bodySmall
                                        ?.copyWith(
                                          color: colors.onSurface.withValues(
                                            alpha: AppTheme.contrastAlpha(
                                              context,
                                              0.64,
                                            ),
                                          ),
                                        ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 4),
                            AnimatedRotation(
                              turns: _expanded ? 0.5 : 0.0,
                              duration: AppTheme.animationDuration(
                                context,
                                const Duration(milliseconds: 200),
                              ),
                              curve: Curves.easeInOutCubic,
                              child: Icon(
                                Icons.keyboard_arrow_down_rounded,
                                size: 22,
                                color: colors.onSurface.withValues(
                                  alpha: AppTheme.contrastAlpha(context, 0.55),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                if (widget.showDismiss) ...[
                  const SizedBox(width: 4),
                  PressScale(
                    child: IconButton(
                      tooltip: l10n?.dismissTooltip ?? 'Dismiss',
                      onPressed: () => ref
                          .read(homeWidgetPromoDismissedProvider.notifier)
                          .dismiss(),
                      icon: const Icon(Icons.close_rounded, size: 18),
                      color: colors.onSurface.withValues(
                        alpha: AppTheme.contrastAlpha(context, 0.5),
                      ),
                      style: IconButton.styleFrom(
                        minimumSize: const Size(32, 32),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (_expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final entry in entries)
                    _WidgetTile(
                      icon: entry.icon,
                      label: entry.label,
                      description: entry.description,
                      canPin: canPin,
                      isLoading: isLoading,
                      onAdd: () => _requestPin(context, entry),
                      onInfo: () =>
                          _showManualInstructions(context, entry.label),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _requestPin(BuildContext context, _WidgetEntry entry) async {
    final l10n = AppLocalizations.of(context);
    final service = ref.read(homeWidgetServiceProvider);
    final success = await service.requestPinWidget(entry.kind);
    if (!context.mounted) return;
    if (success) {
      showAppMessage(
        context,
        l10n?.widgetPinRequested ??
            'Widget pin requested — confirm on home screen',
        kind: AppMessageKind.success,
      );
    } else {
      showAppMessage(
        context,
        l10n?.couldNotPinWidget ??
            'Could not pin widget. Try adding manually: long-press → Widgets → Tithi',
        kind: AppMessageKind.error,
      );
    }
  }

  void _showManualInstructions(BuildContext context, String label) {
    final l10n = AppLocalizations.of(context);
    unawaited(
      showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(l10n?.addWidgetManually ?? 'Add Widget Manually'),
          content: Text(
            '${l10n?.homeWidgetManualInstructions ?? '1. Long-press on your home screen\n2. Tap "Widgets"\n3. Find "Tithi" and drag the widget to your home screen'}\n\n'
            '$label',
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

/// Compact, tappable gallery row: icon, name + description, add affordance.
class _WidgetTile extends StatelessWidget {
  const _WidgetTile({
    required this.icon,
    required this.label,
    required this.description,
    required this.canPin,
    required this.isLoading,
    required this.onAdd,
    required this.onInfo,
  });

  final IconData icon;
  final String label;
  final String description;
  final bool canPin;
  final bool isLoading;
  final VoidCallback onAdd;
  final VoidCallback onInfo;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final accent = AppTheme.festivalAccent(context);
    final muted = context.colors.onSurface.withValues(
      alpha: AppTheme.contrastAlpha(context, 0.6),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 20, color: accent),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: context.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: context.textTheme.bodySmall?.copyWith(color: muted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (isLoading)
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: accent),
            )
          else if (canPin)
            Tooltip(
              message: l10n?.widgetAddTooltip ?? 'Add to home screen',
              child: PressScale(
                child: FilledButton.tonal(
                  onPressed: onAdd,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.festivalTileBackground(context),
                    foregroundColor: accent,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    minimumSize: const Size(0, 34),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(l10n?.add ?? 'Add'),
                ),
              ),
            )
          else
            PressScale(
              child: IconButton(
                tooltip: l10n?.infoTooltip ?? 'Info',
                onPressed: onInfo,
                icon: const Icon(Icons.info_outline_rounded, size: 20),
                style: IconButton.styleFrom(
                  minimumSize: const Size(34, 34),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
