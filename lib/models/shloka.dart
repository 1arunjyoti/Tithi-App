class Shloka {
  /// Stable unique identifier, e.g. "gita-2-47", "orig-01".
  /// Encodes the source (gita/chanakya/up-/ram-/orig-) so callers can
  /// filter by prefix (e.g. a "Gita only" mode) and use it as a key for
  /// favorites, dismissal tracking, or share analytics.
  final String id;
  final String text;
  final String transliteration;
  final String translation;
  final String? hindiTranslation;
  final String source;
  final List<String> themes;
  final List<String> festivalIds;

  const Shloka({
    this.id = '',
    required this.text,
    this.transliteration = '',
    required this.translation,
    this.hindiTranslation,
    required this.source,
    this.themes = const [],
    this.festivalIds = const [],
  });

  factory Shloka.fromJson(Map<String, dynamic> json) {
    final rawFestivalIds = json['festivalIds'];
    final festivalIds = rawFestivalIds is List
        ? rawFestivalIds.whereType<String>().toList()
        : const <String>[];

    final rawThemes = json['themes'];
    final themes = rawThemes is List
        ? rawThemes
              .whereType<String>()
              .map((t) => t.trim())
              .where((t) => t.isNotEmpty)
              .toSet()
              .toList()
        : const <String>[];

    // SEC-3: Null-safe casts – avoid TypeError when JSON fields are null or
    // not the expected type. Old JSON (4 keys) still parses: missing fields
    // fall back to empty defaults.
    final hindiRaw = json['hindiTranslation'] as String?;
    return Shloka(
      id: json['id'] as String? ?? '',
      text: json['text'] as String? ?? '',
      transliteration: json['transliteration'] as String? ?? '',
      translation: json['translation'] as String? ?? '',
      hindiTranslation: hindiRaw?.isNotEmpty == true ? hindiRaw : null,
      source: json['source'] as String? ?? '',
      themes: themes,
      festivalIds: festivalIds,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'text': text,
      'transliteration': transliteration,
      'translation': translation,
      'hindiTranslation': hindiTranslation,
      'source': source,
      'themes': themes,
      'festivalIds': festivalIds,
    };
  }
}
