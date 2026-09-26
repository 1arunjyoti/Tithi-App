import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../l10n/app_localizations_en.dart';
import '../../../theme/app_theme.dart';

/// Side-by-side Begins/Ends card with a center divider. Null values render
/// a spinner (loading state).
class TimingsCard extends StatelessWidget {
  const TimingsCard({super.key, this.begins, this.ends, required this.highContrast});

  final String? begins;
  final String? ends;
  final bool highContrast;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context) ?? AppLocalizationsEn();
    final border = context.colors.onSurface.withValues(
      alpha: highContrast ? 0.2 : 0.1,
    );
    Widget cell({
      required IconData icon,
      required String label,
      String? value,
    }) {
      return Expanded(
        child: Container(
          color: Theme.of(context).cardTheme.color ?? context.colors.surface,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(icon, size: 16, color: context.colors.primary),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 10.5,
                      letterSpacing: 1.0,
                      fontWeight: FontWeight.w600,
                      color: context.colors.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              if (value == null)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: context.colors.onSurface,
                  ),
                ),
            ],
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: border,
        borderRadius: BorderRadius.circular(16),
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            cell(
              icon: Icons.access_time,
              label: l10n.beginsUppercase,
              value: begins,
            ),
            Container(width: 1, color: border),
            cell(
              icon: Icons.access_time_filled,
              label: l10n.endsUppercase,
              value: ends,
            ),
          ],
        ),
      ),
    );
  }
}

/// Tinted transition card: orange label row, bold primary headline, dim
/// subline. Null strings render a spinner (loading state).
class TransitionCard extends StatelessWidget {
  const TransitionCard({super.key, 
    this.headline,
    this.subline,
    required this.highContrast,
  });

  final String? headline;
  final String? subline;
  final bool highContrast;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context) ?? AppLocalizationsEn();
    final primary = context.colors.primary;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: primary.withValues(alpha: highContrast ? 0.15 : 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: primary.withValues(alpha: 0.35)),
      ),
      child: (headline == null)
          ? const Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.swap_horiz, size: 16, color: primary),
                    const SizedBox(width: 6),
                    Text(
                      l10n.transition,
                      style: TextStyle(
                        fontSize: 11,
                        letterSpacing: 1.5,
                        fontWeight: FontWeight.w600,
                        color: primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  headline!,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: primary,
                  ),
                ),
                if (subline != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subline!,
                    style: TextStyle(
                      fontSize: 13,
                      color: context.colors.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ],
            ),
    );
  }
}
