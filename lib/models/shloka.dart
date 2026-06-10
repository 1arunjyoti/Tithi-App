class Shloka {
  final String text;
  final String translation;
  final String source;
  final List<String> festivalIds;

  const Shloka({
    required this.text,
    required this.translation,
    required this.source,
    this.festivalIds = const [],
  });

  factory Shloka.fromJson(Map<String, dynamic> json) {
    final rawFestivalIds = json['festivalIds'];
    final festivalIds = rawFestivalIds is List
        ? rawFestivalIds.whereType<String>().toList()
        : const <String>[];

    // SEC-3: Null-safe casts – avoid TypeError when JSON fields are null or
    // not the expected type.
    return Shloka(
      text: json['text'] as String? ?? '',
      translation: json['translation'] as String? ?? '',
      source: json['source'] as String? ?? '',
      festivalIds: festivalIds,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'text': text,
      'translation': translation,
      'source': source,
      'festivalIds': festivalIds,
    };
  }
}
