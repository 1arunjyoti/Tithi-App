import 'package:material_ui/material_ui.dart';

import '../../../l10n/app_localizations.dart';
import '../../../models/shloka.dart';
import '../../../theme/app_metrics.dart';
import '../../../theme/app_motion.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/app_typography.dart';
import '../domain/shloka_translation.dart';
import 'quote_translation_panel.dart';

/// The per-day content below the card header: optional festival caption,
/// ornament, Sanskrit, transliteration, the collapsible translation panel and
/// the source attribution.
///
/// Everything here swaps when the browsed day changes; the glass shell and
/// the control bar above/below stay mounted.
class QuoteVerseBody extends StatelessWidget {
  const QuoteVerseBody({
    super.key,
    required this.shloka,
    required this.translation,
    required this.isExpanded,
    required this.l10n,
    required this.onToggleShowAll,
    this.festivalName,
  });

  final Shloka shloka;
  final QuoteTranslationView translation;
  final bool isExpanded;
  final AppLocalizations? l10n;
  final VoidCallback onToggleShowAll;

  /// Set when the verse was picked for a festival.
  final String? festivalName;

  @override
  Widget build(BuildContext context) {
    final name = festivalName;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Festival caption, shown when the verse was picked for a festival.
        if (name != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.s20,
              AppSpacing.s10,
              AppSpacing.s20,
              0,
            ),
            child: Center(child: _FestivalChip(name: name)),
          ),

        // Verse body: ornament, Sanskrit, transliteration, translation.
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.s20,
            AppSpacing.s12,
            AppSpacing.s20,
            0,
          ),
          child: Column(
            children: [
              ExcludeSemantics(
                child: Icon(
                  Icons.format_quote_rounded,
                  size: AppIconSize.feature,
                  color: AppTheme.festivalAccent(
                    context,
                  ).withValues(alpha: 0.35),
                ),
              ),
              // Sanskrit Text (Always visible)
              Text(
                shloka.text,
                textAlign: TextAlign.center,
                style: AppTypography.shloka(
                  fontSize: AppTypography.sizeHeading,
                  color: context.colors.onSurface,
                ),
              ),

              // Transliteration (Always visible, muted)
              if (shloka.transliteration.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.s8),
                Text(
                  shloka.transliteration,
                  textAlign: TextAlign.center,
                  style: context.textTheme.bodySmall?.copyWith(
                    color: context.colors.onSurface.withValues(
                      alpha: AppTheme.contrastAlpha(context, 0.6),
                    ),
                    fontStyle: FontStyle.italic,
                    height: 1.4,
                  ),
                ),
              ],

              // Collapsible Translation (locale-driven, with fallback)
              AnimatedCrossFade(
                firstChild: const SizedBox(width: double.infinity),
                secondChild: Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.s12),
                  child: QuoteTranslationPanel(
                    view: translation,
                    l10n: l10n,
                    onToggleShowAll: onToggleShowAll,
                  ),
                ),
                crossFadeState: isExpanded
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
                duration: AppMotion.of(context, AppMotion.page),
              ),

              // Source attribution (always visible)
              const SizedBox(height: AppSpacing.s12),
              _SourceLine(source: shloka.source),
            ],
          ),
        ),
      ],
    );
  }
}

/// Centered festival pill noting which observance the verse was chosen for.
class _FestivalChip extends StatelessWidget {
  const _FestivalChip({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final accent = AppTheme.festivalAccent(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s12,
        vertical: AppSpacing.s6,
      ),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadius.round),
        border: Border.all(color: accent.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.celebration_rounded,
            size: AppIconSize.inline,
            color: accent,
          ),
          const SizedBox(width: AppSpacing.s6),
          Flexible(
            child: Text(
              l10n?.chosenForFestival(name) ?? 'Chosen for $name',
              overflow: TextOverflow.ellipsis,
              style: context.textTheme.labelSmall?.copyWith(
                color: accent,
                fontWeight: AppTypography.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Centered source attribution flanked by hairlines (manuscript style).
class _SourceLine extends StatelessWidget {
  const _SourceLine({required this.source});

  final String source;

  @override
  Widget build(BuildContext context) {
    final accent = AppTheme.festivalAccent(context);
    Widget hairline() => Container(
      width: 28,
      height: 1.5,
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(AppRadius.micro),
      ),
    );
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        hairline(),
        const SizedBox(width: AppSpacing.s8),
        Flexible(
          child: Text(
            '— $source',
            textAlign: TextAlign.center,
            style: context.textTheme.labelMedium?.copyWith(
              color: accent,
              fontWeight: AppTypography.bold,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.s8),
        hairline(),
      ],
    );
  }
}
