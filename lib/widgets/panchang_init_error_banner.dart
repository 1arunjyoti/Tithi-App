import 'package:material_ui/material_ui.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../providers/panchang_provider.dart';
import '../services/panchang_init/panchang_init.dart';
import '../theme/app_theme.dart';
import '../theme/app_metrics.dart';
import '../theme/app_typography.dart';
import 'app_buttons.dart';

/// Shows why the panchang engine could not start, with a retry.
///
/// [panchangInitProvider] is the only place the ephemeris copy + native setup
/// runs. When it fails, every downstream provider fails too, but the calendar
/// turns those failures into an empty map (a deliberate offline behaviour), so
/// without this banner the user sees a blank month and no reason for it.
class PanchangInitErrorBanner extends ConsumerWidget {
  const PanchangInitErrorBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final init = ref.watch(panchangInitProvider);
    if (!init.hasError) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context);
    final error = init.error;
    // Panchang init failures carry a message written for the user; anything
    // else is unexpected, so keep the generic copy rather than leaking
    // internals.
    final detail = error is PanchangInitException
        ? error.message
        : (l10n?.unexpectedErrorOccurred ??
              'An unexpected error occurred. Please try again.');
    final colors = Theme.of(context).colorScheme;

    return Semantics(
      liveRegion: true,
      container: true,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppTheme.homeCardGutter,
          0,
          AppTheme.homeCardGutter,
          AppSpacing.s12,
        ),
        child: Material(
          color: colors.errorContainer,
          borderRadius: BorderRadius.circular(AppRadius.tile),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.s16,
              AppSpacing.s12,
              AppSpacing.s8,
              AppSpacing.s12,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.error_outline_rounded,
                  color: colors.onErrorContainer,
                ),
                const SizedBox(width: AppSpacing.s12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n?.errorLoadingData ?? 'Error loading data',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: colors.onErrorContainer,
                          fontWeight: AppTypography.semibold,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.s4),
                      Text(
                        detail,
                        style: Theme.of(context).textTheme.bodySmall
                            ?.copyWith(color: colors.onErrorContainer),
                      ),
                    ],
                  ),
                ),
                AppButton(
                  style: M3EButtonStyle.text,
                  onPressed: () => ref.invalidate(panchangInitProvider),
                  label: Text(l10n?.retry ?? 'Retry'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
