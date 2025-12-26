/// Festival model matching festivals.json structure
class Festival {
  final String id;
  final String name;
  final String? nameHindi;
  final String description;
  final String masa;
  final String paksha;
  final int tithi;
  final String conditions;
  final String category;
  final bool recurring;
  final List<String> rituals;

  const Festival({
    required this.id,
    required this.name,
    this.nameHindi,
    required this.description,
    required this.masa,
    required this.paksha,
    required this.tithi,
    required this.conditions,
    this.category = '',
    this.recurring = false,
    this.rituals = const [],
  });

  factory Festival.fromJson(Map<String, dynamic> json) {
    return Festival(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      nameHindi: json['nameHindi'],
      description: json['description'] ?? '',
      masa: json['masa'] ?? '',
      paksha: json['paksha'] ?? '',
      tithi: json['tithi'] ?? 0,
      conditions: json['conditions'] ?? '',
      category: json['category'] ?? '',
      recurring: json['recurring'] ?? false,
      rituals:
          (json['rituals'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
    );
  }

  /// Check if this festival matches the given paksha and tithi
  bool matchesTithi(
    String currentPaksha,
    int currentTithi, [
    String currentMasa = '',
  ]) {
    // Skip solar festivals (like Makar Sankranti)
    if (conditions == 'Solar') return false;

    // Check paksha match (or wildcard '*')
    final pakshaMatch = paksha == '*' || paksha == currentPaksha;

    // Check tithi match
    final tithiMatch = tithi == currentTithi;

    // Check masa match (or wildcard '*')
    // If currentMasa is empty, we might choose to skip check or fail.
    // Assuming empty currentMasa implies we don't know the masa, so maybe strict checking is bad?
    // But usually we will have it.
    // If festival masa is '*', it matches any month.
    bool masaMatch = true;
    if (masa != '*' && currentMasa.isNotEmpty) {
      masaMatch = masa == currentMasa;
    }

    return pakshaMatch && tithiMatch && masaMatch;
  }

  @override
  String toString() => 'Festival($name, $paksha T$tithi)';
}
