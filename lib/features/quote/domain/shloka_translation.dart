import '../../../models/shloka.dart';

// Translation-selection logic for the Daily Wisdom card, extracted from the
// former widgets/daily_quote_widget.dart monolith.
//
// Pure: model in, strings out — unit-testable without widgets or a
// BuildContext (see test/shloka_test.dart).

/// Picks the translation matching the UI language.
///
/// Hindi UI gets the Hindi translation, everything else gets English. Each
/// falls back to the other language when the preferred one is missing (38
/// entries have no Hindi), so the expanded view is never empty when at least
/// one translation exists. Returns null only when both are missing.
String? pickShlokaTranslation(Shloka shloka, {required bool hindiFirst}) {
  final hindi = shloka.hindiTranslation;
  final hasHindi = hindi != null && hindi.isNotEmpty;
  final hasEnglish = shloka.translation.isNotEmpty;
  if (hindiFirst) {
    if (hasHindi) return hindi;
    if (hasEnglish) return shloka.translation;
    return null;
  }
  if (hasEnglish) return shloka.translation;
  if (hasHindi) return hindi;
  return null;
}

/// Returns the non-primary translation when both English and Hindi exist,
/// otherwise null (nothing extra to reveal).
String? otherShlokaTranslation(Shloka shloka, {required bool hindiFirst}) {
  final hindi = shloka.hindiTranslation;
  final hasHindi = hindi != null && hindi.isNotEmpty;
  final hasEnglish = shloka.translation.isNotEmpty;
  if (!hasHindi || !hasEnglish) return null;
  final other = hindiFirst ? shloka.translation : hindi;
  return other == pickShlokaTranslation(shloka, hindiFirst: hindiFirst)
      ? null
      : other;
}

/// Everything the card needs to render one verse's translations.
///
/// The `*IsHindi` flags select the Devanagari typeface; they are derived here
/// (not in the widget) so the identity check lives next to the picker that
/// chose the string.
class QuoteTranslationView {
  const QuoteTranslationView({
    this.primary,
    this.primaryIsHindi = false,
    this.secondary,
    this.secondaryIsHindi = false,
    this.showAll = false,
  });

  /// Resolves the visible translations for [shloka] in the UI language.
  factory QuoteTranslationView.resolve(
    Shloka shloka, {
    required bool hindiFirst,
    bool showAll = false,
  }) {
    final primary = pickShlokaTranslation(shloka, hindiFirst: hindiFirst);
    final secondary = otherShlokaTranslation(shloka, hindiFirst: hindiFirst);
    return QuoteTranslationView(
      primary: primary,
      primaryIsHindi: primary != null && primary == shloka.hindiTranslation,
      secondary: secondary,
      secondaryIsHindi:
          secondary != null && secondary == shloka.hindiTranslation,
      showAll: showAll,
    );
  }

  /// Locale-preferred translation, or null when the verse has none.
  final String? primary;
  final bool primaryIsHindi;

  /// The other language, when both exist; null otherwise.
  final String? secondary;
  final bool secondaryIsHindi;

  /// Whether the secondary translation is revealed behind "show more".
  final bool showAll;
}
