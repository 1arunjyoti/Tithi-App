import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../l10n/app_localizations.dart';
import '../providers/quote_providers.dart';

// Day-browsing rules for the Daily Wisdom card, extracted from the former
// widgets/daily_quote_widget.dart monolith.

/// Short day label for the card header: Today / Yesterday / Tomorrow / Mar 5.
String quoteDayLabel(DateTime date, int dayOffset, [AppLocalizations? l10n]) {
  if (dayOffset == 0) return l10n?.today ?? 'Today';
  if (dayOffset == -1) return l10n?.yesterday ?? 'Yesterday';
  if (dayOffset == 1) return l10n?.tomorrow ?? 'Tomorrow';
  return DateFormat.MMMd().format(date);
}

/// Steps the browsed day by [delta], clamped to `[-quoteMaxDayOffset, 0]`.
///
/// Hides any revealed extra translations first (they belong to the previous
/// verse). Future verses are intentionally unavailable — only today and
/// earlier days can be revisited — so today is the upper bound.
void stepQuoteDay(WidgetRef ref, int offset, int delta) {
  final next = (offset + delta).clamp(-quoteMaxDayOffset, 0);
  if (next == offset) return;
  ref.read(quoteShowAllTranslationsProvider.notifier).state = false;
  ref.read(quoteDayOffsetProvider.notifier).state = next;
}
