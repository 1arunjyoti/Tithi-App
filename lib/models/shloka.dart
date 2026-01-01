class Shloka {
  final String text;
  final String translation;
  final String source;

  const Shloka({
    required this.text,
    required this.translation,
    required this.source,
  });

  factory Shloka.fromJson(Map<String, dynamic> json) {
    return Shloka(
      text: json['text'] as String,
      translation: json['translation'] as String,
      source: json['source'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {'text': text, 'translation': translation, 'source': source};
  }
}
