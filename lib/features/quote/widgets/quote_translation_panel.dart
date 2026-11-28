import 'package:material_ui/material_ui.dart';
import 'package:material_3_expressive/material_3_expressive.dart';

import '../../../l10n/app_localizations.dart';
import '../../../widgets/app_buttons.dart';
import '../../../theme/app_metrics.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/app_typography.dart';
import '../domain/shloka_translation.dart';

/// Soft tinted panel holding the translation(s), the show-more toggle and
/// the theme chips. Tint/border alphas step up in high contrast so the panel
/// keeps its edge on flattened solid backgrounds.
class QuoteTranslationPanel extends StatelessWidget {
  const QuoteTranslationPanel({
    super.key,
    required this.view,
    required this.l10n,
    required this.onToggleShowAll,
  });

  final QuoteTranslationView view;
  final AppLocalizations? l10n;
  final VoidCallback onToggleShowAll;

  @override
  Widget build(BuildContext context) {
    final accent = AppTheme.festivalAccent(context);
    final highContrast = AppTheme.highContrastOf(context);
    final primary = view.primary;
    final secondary = view.secondary;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s14,
        vertical: AppSpacing.s12,
      ),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: highContrast ? 0.12 : 0.07),
        borderRadius: BorderRadius.circular(AppRadius.tile),
        border: Border.all(
          color: accent.withValues(alpha: highContrast ? 0.5 : 0.14),
        ),
      ),
      child: Column(
        children: [
          if (primary != null)
            _TranslationText(text: primary, isHindi: view.primaryIsHindi),
          // Reveal every available translation on demand.
          if (secondary != null) ...[
            const SizedBox(height: AppSpacing.s10),
            if (view.showAll) ...[
              _TranslationText(text: secondary, isHindi: view.secondaryIsHindi),
              const SizedBox(height: AppSpacing.s4),
            ],
            AppButton(
              style: M3EButtonStyle.text,
              onPressed: onToggleShowAll,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              label: Text(
                view.showAll
                    ? (l10n?.showLess ?? 'Show less')
                    : (l10n?.showMoreTranslations ?? 'Show more translations'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// A single translation paragraph. Hindi renders in Martel (Devanagari),
/// English in italic body text — matching the card's established styles.
class _TranslationText extends StatelessWidget {
  const _TranslationText({required this.text, required this.isHindi});

  final String text;
  final bool isHindi;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: TextAlign.center,
      style: isHindi
          ? AppTypography.shloka(
              fontSize: AppTypography.sizeProse,
              height: 1.5,
              fontWeight: AppTypography.medium,
              color: context.colors.onSurface.withValues(alpha: 0.9),
            )
          : context.textTheme.bodyMedium?.copyWith(
              color: context.colors.onSurface.withValues(alpha: 0.8),
              fontStyle: FontStyle.italic,
              height: 1.4,
            ),
    );
  }
}
