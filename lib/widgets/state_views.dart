import 'package:material_ui/material_ui.dart';

import '../l10n/app_localizations.dart';
import '../theme/app_metrics.dart';
import '../theme/app_typography.dart';
import '../theme/app_theme.dart';

/// Where a state view sits, which decides its alignment and scale.
enum StateViewVariant {
  /// A whole screen or tab with nothing to show: centred, 48dp icon.
  page,

  /// A card body with nothing to show: centred inside the card.
  card,

  /// One row inside an otherwise populated card: icon + a single line.
  inline,
}

/// The "nothing to show" view, in one shape for every screen.
///
/// Empty states used to be hand-rolled per screen, so the same idea shipped
/// with a 20, 48, 56 or 64dp icon, five different inks, and sometimes no icon
/// at all. This is the only place that decision is made now:
///
///  * [StateViewVariant.page] - a tab or pushed screen: 48dp icon, title,
///    optional body, centred.
///  * [StateViewVariant.card] - a card body: same but with card padding.
///  * [StateViewVariant.inline] - a line inside a populated card; the caller
///    owns the outer padding, because that padding is part of the card's row
///    rhythm (home cards inset by [AppTheme.homeCardRowInset]).
///
/// The view is display-only on purpose: every empty state in the app already
/// has its action in a toolbar, a FAB or an adjacent control, and adding a
/// second copy here would duplicate it.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.variant = StateViewVariant.page,
  });

  /// The glyph that names the absence (a crossed-out search, a sleeping
  /// calendar). Keep it semantic, not decorative.
  final IconData icon;

  /// The one line a user reads when the list is empty.
  final String title;

  /// Optional second line explaining how to get content (or why it is empty).
  final String? message;

  final StateViewVariant variant;

  @override
  Widget build(BuildContext context) {
    if (variant == StateViewVariant.inline) {
      return Row(
        children: [
          ExcludeSemantics(
            child: Icon(icon, size: AppIconSize.medium, color: context.hintInk),
          ),
          const SizedBox(width: AppSpacing.s10),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: AppTypography.sizeDetail,
                color: context.secondaryInk,
              ),
            ),
          ),
        ],
      );
    }

    final card = variant == StateViewVariant.card;
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: card ? AppSpacing.s16 : AppSpacing.s24,
          vertical: card ? AppSpacing.s24 : AppSpacing.s32,
        ),
        child: _StateBody(
          icon: icon,
          iconColor: context.faintInk,
          title: title,
          message: message,
        ),
      ),
    );
  }
}

/// The "could not load this" view, in one shape for every screen.
///
/// Data errors are a calmer surface than a crash ([ErrorDisplayWidget]): the
/// page is still usable, so the icon is faint and the retry is the only
/// emphasis. [message] must be friendly, already-localised copy - never an
/// exception string; log the real error where it is caught and show the user
/// [AppLocalizations.couldNotLoadFestivals] or an equally plain sentence.
class ErrorState extends StatelessWidget {
  const ErrorState({
    super.key,
    this.title,
    required this.message,
    this.onRetry,
    this.variant = StateViewVariant.page,
  });

  /// Headline; defaults to "Something went wrong".
  final String? title;

  /// Friendly, user-facing explanation. Never `error.toString()`.
  final String message;

  final VoidCallback? onRetry;

  final StateViewVariant variant;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final heading = title ?? l10n?.somethingWentWrong ?? 'Something went wrong';
    final retry = l10n?.retry ?? 'Retry';

    if (variant == StateViewVariant.inline) {
      return Row(
        children: [
          ExcludeSemantics(
            child: Icon(
              Icons.warning_amber_rounded,
              size: AppIconSize.medium,
              color: context.colors.error,
            ),
          ),
          const SizedBox(width: AppSpacing.s8),
          Flexible(
            child: Text(
              message,
              style: TextStyle(
                fontSize: AppTypography.sizeDetail,
                color: context.secondaryInk,
              ),
            ),
          ),
          if (onRetry != null) ...[
            const SizedBox(width: AppSpacing.s8),
            TextButton(
              onPressed: onRetry,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.s12,
                  vertical: AppSpacing.s4,
                ),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(retry),
            ),
          ],
        ],
      );
    }

    final card = variant == StateViewVariant.card;
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: card ? AppSpacing.s16 : AppSpacing.s24,
          vertical: card ? AppSpacing.s24 : AppSpacing.s32,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _StateBody(
              icon: Icons.error_outline_rounded,
              iconColor: context.faintInk,
              title: heading,
              message: message,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: AppSpacing.s20),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: Text(retry),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The icon + title + body block shared by both states.
class _StateBody extends StatelessWidget {
  const _StateBody({
    required this.icon,
    required this.iconColor,
    required this.title,
    this.message,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String? message;

  @override
  Widget build(BuildContext context) {
    final semantics = <String>[title, ?message];
    return Semantics(
      container: true,
      label: semantics.join('. '),
      child: ExcludeSemantics(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: AppIconSize.empty, color: iconColor),
            const SizedBox(height: AppSpacing.s12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: context.secondaryInk,
                fontWeight: AppTypography.semibold,
              ),
            ),
            if (message != null) ...[
              const SizedBox(height: AppSpacing.s6),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: AppTypography.sizeDetail,
                  color: context.hintInk,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
