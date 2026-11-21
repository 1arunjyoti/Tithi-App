import '../../../l10n/app_localizations.dart';
import '../../../models/shloka.dart';
import 'shloka_translation.dart';

// Share-text composition for the Daily Wisdom card, extracted from the former
// widgets/daily_quote_widget.dart monolith.

/// Builds shareable text for a shloka.
///
/// Collapsed shares the always-visible fields (Sanskrit + transliteration +
/// source); expanded also includes translation(s): just the locale-appropriate
/// one, or every available translation when [showAll] is true. Theme hashtags
/// are always appended. Pass [l10n] so the attribution line is localized; it
/// falls back to English when null (e.g. in unit tests with no BuildContext).
String buildShlokaShareText(
  Shloka shloka, {
  required bool expanded,
  bool hindiFirst = false,
  bool showAll = false,
  AppLocalizations? l10n,
}) {
  final parts = <String>[shloka.text];
  if (shloka.transliteration.isNotEmpty) {
    parts.add(shloka.transliteration);
  }
  if (expanded) {
    if (showAll) {
      final primary = pickShlokaTranslation(shloka, hindiFirst: hindiFirst);
      if (primary != null) parts.add(primary);
      final secondary = otherShlokaTranslation(shloka, hindiFirst: hindiFirst);
      if (secondary != null && secondary != primary) parts.add(secondary);
    } else {
      final translation = pickShlokaTranslation(shloka, hindiFirst: hindiFirst);
      if (translation != null) {
        parts.add(translation);
      }
    }
  }
  parts.add('— ${shloka.source}');
  if (shloka.themes.isNotEmpty) {
    parts.add(shloka.themes.map((t) => '#$t').join(' '));
  }
  parts.add(l10n?.sharedViaTithiApp ?? 'Shared via Tithi App');
  return parts.join('\n\n');
}
