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

  /// Paksha this festival is observed in, falling back to the day's paksha
  /// for wildcard ('*'/empty) rules.
  String resolvePaksha(String dayPaksha) =>
      (paksha == '*' || paksha.isEmpty) ? dayPaksha : paksha;

  /// Full 1-30 tithi index this festival is observed on.
  ///
  /// Rules store the paksha-relative number (1-15), so Krishna observances
  /// map to 16-30. [dayPaksha] disambiguates wildcard rules. Use this (not
  /// the day's sunrise tithi) when querying exact Begins/Ends times:
  /// festivals with a timingOverride (e.g. Ganesh Chaturthi at madhyahna)
  /// are observed on a tithi that may differ from the sunrise tithi.
  int resolveTithiIndex(String dayPaksha) {
    final observed = resolvePaksha(dayPaksha) == 'Krishna'
        ? tithi + 15
        : tithi;
    return observed.clamp(1, 30);
  }

  /// Check if this festival matches the given paksha, tithi, masa, and
  /// optionally the weekday of [date] when [panchangRules.weekday] is set.
  ///
  /// [monthSystem] declares the system [currentMasa] is expressed in.
  /// Festivals are stored in Amanta format, so a Purnimant [currentMasa] is
  /// converted back to Amanta before comparison. Callers computing masa via
  /// the panchang service already hold Amanta values and must pass
  /// [HinduMonthSystem.amanta] — passing the *display* system with an
  /// Amanta masa double-shifts Krishna paksha and drops those festivals.
  bool matchesTithi(
    String currentPaksha,
    int currentTithi, [
    String currentMasa = '',
    HinduMonthSystem monthSystem = HinduMonthSystem.amanta,
    DateTime? date,
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
      // If using Purnimant system, convert the current masa to Amanta for
      // comparison since festivals are stored in Amanta format.
      String compareMasa = currentMasa;
      if (monthSystem == HinduMonthSystem.purnimant) {
        compareMasa = convertPurnimantToAmanta(currentMasa, currentPaksha);
      }
      masaMatch = masa == compareMasa;
    }

    // BUG-04: Check weekday constraint when set and a reference date is provided.
    bool weekdayMatch = true;
    if (panchangRules.weekday != null &&
        panchangRules.weekday!.isNotEmpty &&
        date != null) {
      const weekdayMap = {
        'Monday': DateTime.monday,
        'Tuesday': DateTime.tuesday,
        'Wednesday': DateTime.wednesday,
        'Thursday': DateTime.thursday,
        'Friday': DateTime.friday,
        'Saturday': DateTime.saturday,
        'Sunday': DateTime.sunday,
      };
      final requiredWeekday = weekdayMap[panchangRules.weekday!];
      if (requiredWeekday != null) {
        weekdayMatch = date.weekday == requiredWeekday;
      }
    }

    return pakshaMatch && tithiMatch && masaMatch && weekdayMatch;
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

  /// SMELL-05: Which timing checkpoint to use when evaluating this festival.
  /// Replaces the hardcoded switch on festival ID in PanchangData.fromRawTithi.
  /// Valid values: 'madhyahna', 'aparahna', 'nishita'.
  /// Null (default) = use sunrise tithi.
  @HiveField(8)
  final String? timingOverride;

  const PanchangRules({
    required this.masa,
    required this.paksha,
    required this.tithi,
    required this.conditions,
    this.recurring = false,
    this.solarDate,
    this.weekday,
    this.endTithi,
    this.timingOverride,
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
      timingOverride: json['timingOverride'],
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
