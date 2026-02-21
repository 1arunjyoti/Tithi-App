import 'package:hive/hive.dart';
import 'hindu_month_system.dart';

part 'festival.g.dart';

/// Festival model matching festivals.json structure
@HiveType(typeId: 0)
class Festival {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final String category;

  @HiveField(3)
  final NameRegional nameRegional;

  @HiveField(4)
  final Visuals visuals;

  @HiveField(5)
  final Purpose purpose;

  @HiveField(6)
  final PanchangRules panchangRules;

  @HiveField(7)
  final Rituals rituals;

  @HiveField(8)
  final Media media;

  const Festival({
    required this.id,
    required this.name,
    this.category = '',
    required this.nameRegional,
    required this.visuals,
    required this.purpose,
    required this.panchangRules,
    required this.rituals,
    required this.media,
  });

  factory Festival.fromJson(Map<String, dynamic> json) {
    return Festival(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      category: json['category'] ?? '',
      nameRegional: NameRegional.fromJson(json['nameRegional'] ?? {}),
      visuals: Visuals.fromJson(json['visuals'] ?? {}),
      purpose: Purpose.fromJson(json['purpose'] ?? {}),
      panchangRules: PanchangRules.fromJson(json['panchang_rules'] ?? {}),
      rituals: Rituals.fromJson(json['rituals'] ?? {}),
      media: Media.fromJson(json['media'] ?? {}),
    );
  }

  // Backward compatibility getters
  String? get nameHindi => nameRegional.nameHindi;
  String get description => purpose.description;
  String get masa => panchangRules.masa;
  String get paksha => panchangRules.paksha;
  int get tithi => panchangRules.tithi;
  String get conditions => panchangRules.conditions;
  bool get recurring => panchangRules.recurring;
  List<String> get ritualSteps => rituals.steps;

  /// Check if this festival matches the given paksha and tithi
  ///
  /// [monthSystem] - The calendar system being used (Amanta or Purnimant).
  /// Festivals are stored in Amanta format, so when Purnimant is selected,
  /// the currentMasa is converted to Amanta for accurate matching.
  bool matchesTithi(
    String currentPaksha,
    int currentTithi, [
    String currentMasa = '',
    HinduMonthSystem monthSystem = HinduMonthSystem.amanta,
  ]) {
    // Skip solar festivals (like Makar Sankranti)
    if (conditions == 'Solar') return false;

    // Check paksha match (or wildcard '*')
    final pakshaMatch = paksha == '*' || paksha == currentPaksha;

    // Check tithi match (or range if endTithi is set)
    bool tithiMatch = tithi == currentTithi;
    if (!tithiMatch && panchangRules.endTithi != null) {
      tithiMatch =
          currentTithi >= tithi && currentTithi <= panchangRules.endTithi!;
    }

    // Check masa match (or wildcard '*')
    bool masaMatch = true;
    if (masa != '*' && currentMasa.isNotEmpty) {
      // If using Purnimant system, convert the current masa to Amanta for comparison
      // since festivals are stored in Amanta format
      String compareMasa = currentMasa;
      if (monthSystem == HinduMonthSystem.purnimant) {
        compareMasa = convertPurnimantToAmanta(currentMasa, currentPaksha);
      }
      masaMatch = masa == compareMasa;
    }

    return pakshaMatch && tithiMatch && masaMatch;
  }

  @override
  String toString() => 'Festival($name, $paksha T$tithi)';
}

@HiveType(typeId: 1)
class NameRegional {
  @HiveField(0)
  final String? nameSanskrith;

  @HiveField(1)
  final String nameEnglish;

  @HiveField(2)
  final String? nameHindi;

  @HiveField(3)
  final String? nameBengali;

  @HiveField(4)
  final String? nameTelugu;

  @HiveField(5)
  final String? nameKannada;

  @HiveField(6)
  final String? nameTamil;

  @HiveField(7)
  final String? nameMalayalam;

  const NameRegional({
    this.nameSanskrith,
    required this.nameEnglish,
    this.nameHindi,
    this.nameBengali,
    this.nameTelugu,
    this.nameKannada,
    this.nameTamil,
    this.nameMalayalam,
  });

  factory NameRegional.fromJson(Map<String, dynamic> json) {
    return NameRegional(
      nameSanskrith: json['nameSanskrith'],
      nameEnglish: json['nameEnglish'] ?? '',
      nameHindi: json['nameHindi'],
      nameBengali: json['nameBengali'],
      nameTelugu: json['nameTelugu'],
      nameKannada: json['nameKannada'],
      nameTamil: json['nameTamil'],
      nameMalayalam: json['nameMalayalam'],
    );
  }
}

@HiveType(typeId: 2)
class Visuals {
  @HiveField(0)
  final String image;

  @HiveField(1)
  final String themeColor;

  const Visuals({this.image = '', this.themeColor = ''});

  factory Visuals.fromJson(Map<String, dynamic> json) {
    return Visuals(
      image: json['image'] ?? '',
      themeColor: json['theme_color'] ?? '',
    );
  }
}

@HiveType(typeId: 3)
class Purpose {
  @HiveField(0)
  final String description;

  @HiveField(1)
  final String additionalDescription;

  const Purpose({required this.description, this.additionalDescription = ''});

  factory Purpose.fromJson(Map<String, dynamic> json) {
    return Purpose(
      description: json['description'] ?? '',
      additionalDescription: json['addtional_description'] ?? '',
    );
  }
}

@HiveType(typeId: 4)
class PanchangRules {
  @HiveField(0)
  final String masa;

  @HiveField(1)
  final String paksha;

  @HiveField(2)
  final int tithi;

  @HiveField(3)
  final String conditions;

  @HiveField(4)
  final bool recurring;

  @HiveField(5)
  final String? solarDate;

  @HiveField(6)
  final String? weekday;

  @HiveField(7)
  final int? endTithi;

  const PanchangRules({
    required this.masa,
    required this.paksha,
    required this.tithi,
    required this.conditions,
    this.recurring = false,
    this.solarDate,
    this.weekday,
    this.endTithi,
  });

  factory PanchangRules.fromJson(Map<String, dynamic> json) {
    return PanchangRules(
      masa: json['masa'] ?? '',
      paksha: json['paksha'] ?? '',
      tithi: json['tithi'] ?? 0,
      conditions: json['conditions'] ?? '',
      recurring: json['recurring'] ?? false,
      solarDate: json['solarDate'],
      weekday: json['weekday'],
      endTithi: json['endTithi'],
    );
  }
}

@HiveType(typeId: 5)
class Rituals {
  @HiveField(0)
  final List<String> steps;

  @HiveField(1)
  final String mantra;

  @HiveField(2)
  final String? fasting;

  const Rituals({required this.steps, this.mantra = '', this.fasting});

  factory Rituals.fromJson(Map<String, dynamic> json) {
    return Rituals(
      steps:
          (json['steps'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      mantra: json['mantra'] ?? '',
      fasting: json['fasting'],
    );
  }
}

@HiveType(typeId: 6)
class Media {
  @HiveField(0)
  final String audioStotra;

  const Media({this.audioStotra = ''});

  factory Media.fromJson(Map<String, dynamic> json) {
    return Media(audioStotra: json['audio_stotra'] ?? '');
  }
}
