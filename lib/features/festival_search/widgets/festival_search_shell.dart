import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../l10n/app_localizations.dart';
import '../../../widgets/app_buttons.dart';
import '../../../theme/app_typography.dart';

/// Shared chrome for the app's festival search overlays.
///
/// Two screens open a [SearchDelegate] over the same catalog: the home app
/// bar's search and the countdown picker. Both used to spell out the same
/// themed search bar, the clear/back controls and the results plumbing; only
/// the result list differs, so subclasses implement [buildSearchResults] and
/// inherit everything else.
///
/// The overlay is built outside the widget tree that opened it, so a delegate
/// cannot `ref.watch` - it is handed the caller's [ref] and must `read` (see
/// each subclass for why that is enough).
abstract class FestivalSearchShell<T> extends SearchDelegate<T?> {
  FestivalSearchShell({required this.ref});

  /// The caller's container. Reads only: the overlay never rebuilds on
  /// provider changes, it is dismissed when the user picks a row.
  final WidgetRef ref;

  /// The list body for the current [query] - the one per-screen decision.
  Widget buildSearchResults(BuildContext context);

  @override
  ThemeData appBarTheme(BuildContext context) {
    final theme = Theme.of(context);
    return theme.copyWith(
      appBarTheme: theme.appBarTheme.copyWith(
        backgroundColor: theme.colorScheme.surface,
        elevation: 0,
      ),
      inputDecorationTheme: const InputDecorationTheme(
        border: InputBorder.none,
        hintStyle: TextStyle(fontSize: AppTypography.sizeHeading),
      ),
    );
  }

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        AppIconButton(
          icon: const Icon(Icons.clear_rounded),
          tooltip: AppLocalizations.of(context)?.clearSearch ?? 'Clear search',
          onPressed: () => query = '',
        ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return AppIconButton(
      icon: const Icon(Icons.arrow_back_rounded),
      tooltip: MaterialLocalizations.of(context).backButtonTooltip,
      onPressed: () => close(context, null),
    );
  }

  @override
  Widget buildResults(BuildContext context) => buildSearchResults(context);

  @override
  Widget buildSuggestions(BuildContext context) => buildSearchResults(context);
}
