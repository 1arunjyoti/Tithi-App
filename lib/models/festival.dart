import 'package:hive/hive.dart';
import 'hindu_month_system.dart';

part 'festival.g.dart';

/// The 27 lunar mansions in Vedic order (index 0 = Ashwini).
/// Canonical source for nakshatra-name validation in festival rules and for
/// mapping a sidereal Moon longitude to a name (index = floor(lon / (360/27))).
/// Kept here (not in the jyotish package) so the model, the web fallback
/// service, and tests can use it without an FFI dependency.
const List<String> hinduNakshatras = [
  'Ashwini',
  'Bharani',
  'Krittika',
  'Rohini',
  'Mrigashira',
  'Ardra',
  'Punarvasu',
  'Pushya',
  'Ashlesha',
  'Magha',
  'Purva Phalguni',
  'Uttara Phalguni',
  'Hasta',
  'Chitra',
  'Swati',
  'Vishakha',
  'Anuradha',
  'Jyeshtha',
  'Mula',
  'Purva Ashadha',
  'Uttara Ashadha',
  'Shravana',
  'Dhanishta',
  'Shatabhisha',
  'Purva Bhadrapada',
  'Uttara Bhadrapada',
  'Revati',
];

/// Canonical nakshatra name for a sidereal Moon [longitude] in degrees.
String nakshatraForLongitude(double longitude) {
  var lon = longitude % 360;
  if (lon < 0) lon += 360;
  return hinduNakshatras[(lon / (360 / 27)).floor().clamp(0, 26)];
}

/// Vimshottari lords in nakshatra order: the 9-graha sequence
/// (Ketu, Venus, Sun, Moon, Mars, Rahu, Jupiter, Saturn, Mercury) repeats
/// three times across the 27 mansions.
const List<String> nakshatraLords = [
  'Ketu',
  'Venus',
  'Sun',
  'Moon',
  'Mars',
  'Rahu',
  'Jupiter',
  'Saturn',
  'Mercury',
];

/// Canonical Vimshottari lord for a Vedic-order nakshatra [index] (0-26).
String nakshatraLordFor(int index) => nakshatraLords[index % 9];

/// The 27 yogas in Vedic order (index 0 = Vishkambha).
/// Canonical source for yoga-name lookup; kept here (not in the jyotish
/// package) so the model and tests can use it without an FFI dependency.
const List<String> yogaNames = [
  'Vishkambha',
  'Priti',
  'Ayushman',
  'Saubhagya',
  'Shobhana',
  'Atiganda',
  'Sukarma',
  'Dhriti',
  'Shula',
  'Ganda',
  'Vriddhi',
  'Dhruva',
  'Vyaghata',
  'Harshana',
  'Vajra',
  'Siddhi',
  'Vyatipata',
  'Variyana',
  'Parigha',
  'Shiva',
  'Siddha',
  'Sadhya',
  'Shubha',
  'Shukla',
  'Brahma',
  'Indra',
  'Vaidhriti',
];

/// Normalizes an ecliptic angle into [0, 360).
double _normalizeAngle(double degrees) {
  var a = degrees % 360;
  if (a < 0) a += 360;
  return a;
}

/// Yoga index (0-26) for sidereal Sun/Moon longitudes in degrees.
///
/// Unlike tithi (a difference, where ayanamsa cancels), yoga uses the SUM,
/// so the ayanamsa enters twice — callers must pass sidereal longitudes
/// from a single consistent ayanamsa (Lahiri here).
int yogaIndexFor(double sunLongitude, double moonLongitude) {
  final s = _normalizeAngle(sunLongitude + moonLongitude);
  return (s / (360 / 27)).floor().clamp(0, 26);
}

/// The 7 movable (repeating) karanas in order.
const List<String> movableKaranas = [
  'Bava',
  'Balava',
  'Kaulava',
  'Taitila',
  'Gara',
  'Vanija',
  'Vishti',
];

/// Karana index (0-59) for sidereal Sun/Moon longitudes: the elongation
/// (Moon − Sun) divided into 60 segments of 6° (half a tithi).
int karanaIndexFor(double sunLongitude, double moonLongitude) {
  final elong = _normalizeAngle(moonLongitude - sunLongitude);
  return (elong / 6).floor().clamp(0, 59);
}

/// Canonical karana name for a karana [index] (0-59).
///
/// The mapping is the subtle part: only index 0 (Kimstughna) and 57-59
/// (Shakuni, Chatushpada, Naga — the fixed karanas) are special; indices
/// 1-56 run the 7 movable karanas through exactly 8 full cycles, so a
/// plain modulo applies. Sanity: 15 → Bava (Shukla Ashtami 2nd half),
/// 16 → Balava (Navami 1st half).
String karanaNameForIndex(int index) {
  final idx = index % 60;
  if (idx == 0) return 'Kimstughna';
  if (idx <= 56) return movableKaranas[(idx - 1) % 7];
  if (idx == 57) return 'Shakuni';
  if (idx == 58) return 'Chatushpada';
  return 'Naga';
}

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

  /// Optional same-day display rank (lower shows first).
  ///
  /// Null (default) means "no override" — the day list keeps its current
  /// order. When set on one or more same-day festivals, those sort before
  /// unranked ones, ordered by this value. Ties keep their existing relative
  /// order (stable sort), so missing == current behaviour.
  @HiveField(9)
  final int? displayPriority;

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
    this.displayPriority,
  });

  factory Festival.fromJson(Map<String, dynamic> json) {
    int? priority;
    final rawPriority = json['displayPriority'];
    if (rawPriority is int) {
      priority = rawPriority;
    } else if (rawPriority is num) {
      priority = rawPriority.toInt();
    }
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
      displayPriority: priority,
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

  /// Nakshatra override from [conditions], e.g. `"Mula Nakshatra"`.
  ///
  /// When set, matching is masa + paksha + prevailing nakshatra and the
  /// stored [tithi] is ignored (a static tithi cannot represent festivals
  /// like Saraswati Avahan, which falls on Shashthi some years and Saptami
  /// others depending on Mula). Null for tithi-based and Solar festivals.
  /// Case-insensitive; unknown names yield null (rule falls back to tithi).
  String? get nakshatraCondition {
    final raw = panchangRules.conditions.trim();
    if (!raw.toLowerCase().endsWith(' nakshatra')) return null;
    final name = raw.substring(0, raw.length - ' nakshatra'.length).trim();
    for (final n in hinduNakshatras) {
      if (n.toLowerCase() == name.toLowerCase()) return n;
    }
    return null;
  }
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

/// Single-day festival match aware of nakshatra overrides.
///
/// - Nakshatra festivals (`conditions: "<Name> Nakshatra"`, e.g. Saraswati
///   Avahan on Mula): matches [masa] (Amanta basis) + [paksha] + prevailing
///   [nakshatra]. The stored tithi is ignored — it cannot represent such
///   festivals across years. A null (unknown, e.g. web fallback) [nakshatra]
///   never matches.
/// - All other festivals: plain tithi delegation to [Festival.matchesTithi].
///
/// The one definition of a match shared by [PanchangData.fromRawTithi] (tithi
/// festivals branch on checkpoints first; nakshatra festivals match here on
/// the sunrise paksha/nakshatra) and by the forward-scan occurrence finders.
bool matchesFestivalOnDay({
  required Festival festival,
  required String paksha,
  required int tithiNumber,
  required String masa,
  required String? nakshatra,
  DateTime? date,
}) {
  final required = festival.nakshatraCondition;
  if (required != null) {
    if (nakshatra == null) return false;
    final pakshaMatch = festival.paksha == '*' || festival.paksha == paksha;
    var masaMatch = true;
    if (festival.masa != '*' && masa.isNotEmpty) {
      masaMatch = festival.masa == masa;
    }
    return pakshaMatch && masaMatch && nakshatra == required;
  }
  return festival.matchesTithi(
    paksha,
    tithiNumber,
    masa,
    HinduMonthSystem.amanta,
    date,
  );
}

/// Sort key for [Festival.displayPriority]: ranked festivals first (lower
/// value first), unranked (null) last.
///
/// Used only as a comparator input — callers must use a stable sort so that
/// ties (including all-null) keep their existing relative order, i.e. the
/// current behaviour is preserved when the field is unused.
int displayPrioritySortKey(Festival festival) =>
    festival.displayPriority ?? 1 << 30;

/// In-place stable sort of a same-day festival list by [displayPriority].
///
/// No-op when no festival carries a rank, so the hot path keeps its current
/// order untouched when the field is unused/missing. A single ranked entry
/// still sorts first; unranked entries keep their relative order at the end.
void sortFestivalsByDisplayPriority(List<Festival> festivals) {
  var ranked = 0;
  for (final f in festivals) {
    if (f.displayPriority != null) ranked++;
  }
  if (ranked == 0) return;
  // Dart's List.sort is stable: equal keys (including ties) keep their
  // existing relative order.
  festivals.sort(
    (a, b) => displayPrioritySortKey(a).compareTo(displayPrioritySortKey(b)),
  );
}

/// Primary festival for headlines/notifications.
///
/// - When at least one festival carries a [Festival.displayPriority], the
///   smallest rank wins (ties keep list order).
/// - Otherwise (all null — field unused/missing) falls back to the legacy
///   behaviour: first `major` festival, else the first festival.
Festival primaryFestival(List<Festival> festivals) {
  assert(festivals.isNotEmpty);
  var hasRank = false;
  for (final f in festivals) {
    if (f.displayPriority != null) {
      hasRank = true;
      break;
    }
  }
  if (hasRank) {
    var best = festivals.first;
    for (var i = 1; i < festivals.length; i++) {
      if (displayPrioritySortKey(festivals[i]) <
          displayPrioritySortKey(best)) {
        best = festivals[i];
      }
    }
    return best;
  }
  for (final f in festivals) {
    if (f.category == 'major') return f;
  }
  return festivals.first;
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
      // Accept both spellings: 10 entries use correct
      // 'additional_description', 91 use typo 'addtional_description'.
      additionalDescription:
          json['additional_description'] ??
          json['addtional_description'] ??
          '',
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

  /// Vriddhi (extended tithi spanning two sunrises) resolution.
  /// Valid values: 'first', 'second', 'both'.
  /// 'both' (default) = observed on every matching sunrise (legacy behavior).
  /// 'first' = only the first day of a consecutive matching run (e.g. Sharad
  /// Navratri sequence days); 'second' = only the last day.
  /// Used by the shared festival-matching pipeline to trim duplicate matches;
  /// see festival_matching_pipeline.dart.
  @HiveField(9)
  final String vriddhi;

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
    this.vriddhi = 'both',
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
      vriddhi: json['vriddhi'] ?? 'both',
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
