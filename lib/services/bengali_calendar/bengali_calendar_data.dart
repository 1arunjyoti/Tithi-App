/// Shared Bisuddha Siddhanta Bengali calendar metadata.
///
/// Pure constants + helpers (no Riverpod/FFI) so the native service, the web
/// fallback, and the notification isolate (no FFI/Ref) can all share one
/// source of truth. Spellings follow
/// `docs/Bisuddha_Siddhanta_Bengali_Calendar_Implementation_Guide.md`
/// Sec 3.1 (months), Sec 6 (seasons/ritu), Sec 7 (weekdays), Appendix A
/// (sankranti mapping).
///
/// Month index convention (0-based): 0 = Boishakh .. 11 = Choitro.
library;

/// Transliterated Bengali solar month names (guide Sec 3.1).
const List<String> kBengaliMonths = [
  'Boishakh',
  'Joishtho',
  'Asharh',
  'Shrabon',
  'Bhadro',
  'Ashshin',
  'Kartik',
  'Ogrohayon',
  'Poush',
  'Magh',
  'Falgun',
  'Choitro',
];

/// Bengali-script month names (guide Sec 3.1).
const List<String> kBengaliMonthsBn = [
  'বৈশাখ',
  'জ্যৈষ্ঠ',
  'আষাঢ়',
  'শ্রাবণ',
  'ভাদ্র',
  'আশ্বিন',
  'কার্তিক',
  'অগ্রহায়ণ',
  'পৌষ',
  'মাঘ',
  'ফাল্গুন',
  'চৈত্র',
];

/// Sanskrit names of the corresponding solar months (guide Sec 3.1).
const List<String> kBengaliSanskritNames = [
  'Vaishakha',
  'Jyeshtha',
  'Ashadha',
  'Shravana',
  'Bhadrapada',
  'Ashwin',
  'Kartika',
  'Margashirsha',
  'Pausha',
  'Magha',
  'Phalguna',
  'Chaitra',
];

/// Sankranti starting each month, e.g. index 0 = Mesha Sankranti.
/// Appendix A: boundary longitude = index * 30 (Mesha = 0 deg).
const List<String> kBengaliSankrantiNames = [
  'Mesha Sankranti',
  'Vrishabha Sankranti',
  'Mithuna Sankranti',
  'Karkataka Sankranti',
  'Simha Sankranti',
  'Kanya Sankranti',
  'Tula Sankranti',
  'Vrishchika Sankranti',
  'Dhanu Sankranti',
  'Makara Sankranti',
  'Kumbha Sankranti',
  'Meena Sankranti',
];

/// The six Bengali seasons/ritu (guide Sec 6), each spanning two months.
const List<String> kBengaliSeasons = [
  'Grishsho', // Summer: Boishakh, Joishtho
  'Borsha', // Monsoon: Asharh, Shrabon
  'Shorot', // Autumn: Bhadro, Ashshin
  'Hemonto', // Late Autumn: Kartik, Ogrohayon
  'Sheet', // Winter: Poush, Magh
  'Bosonto', // Spring: Falgun, Choitro
];

/// Bengali-script season names (guide Sec 6).
const List<String> kBengaliSeasonsBn = [
  'গ্রীষ্ম',
  'বর্ষা',
  'শরৎ',
  'হেমন্ত',
  'শীত',
  'বসন্ত',
];

/// English glosses for the six seasons.
const List<String> kBengaliSeasonGlosses = [
  'Summer',
  'Monsoon',
  'Autumn',
  'Late Autumn',
  'Winter',
  'Spring',
];

/// Transliterated weekday names, Sunday-first (guide Sec 7).
const List<String> kBengaliWeekdays = [
  'Robibar',
  'Shombar',
  'Monggolbar',
  'Budhbar',
  'Brihospotibar',
  'Shukrobar',
  'Shonibar',
];

/// Bengali-script weekday names, Sunday-first (guide Sec 7).
const List<String> kBengaliWeekdaysBn = [
  'রবিবার',
  'সোমবার',
  'মঙ্গলবার',
  'বুধবার',
  'বৃহস্পতিবার',
  'শুক্রবার',
  'শনিবার',
];

/// Season (0-5 into [kBengaliSeasons]) for a 0-based month index.
String bengaliSeasonForMonthIndex(int monthIndex) {
  return kBengaliSeasons[(monthIndex ~/ 2) % 6];
}

/// Bengali-script digits (০১২৩৪৫৬৭৮৯) for calendar display, e.g. the hero
/// header's `৩০ ভাদ্র ১৩৩৩`. Non-digit characters pass through unchanged.
String toBengaliDigits(int value) {
  const digits = '০১২৩৪৫৬৭৮৯';
  return value.toString().split('').map((c) {
    final d = int.tryParse(c);
    return d == null ? c : digits[d];
  }).join();
}

/// Lowercase lookup covering guide spellings plus legacy/app variants
/// ('Jyoishtho', 'Ashar', 'Srabon', 'Ashwin', 'Agrahayan', 'Chaitra') and
/// Sanskrit names, so persisted/older strings still resolve. Returns -1
/// when unknown.
int bengaliMonthIndexOf(String name) {
  final key = name.trim().toLowerCase();
  return _bengaliMonthAliases[key] ?? -1;
}

const Map<String, int> _bengaliMonthAliases = {
  // Guide spellings (Sec 3.1).
  'boishakh': 0,
  'baishakh': 0,
  'joishtho': 1,
  'asharh': 2,
  'shrabon': 3,
  'bhadro': 4,
  'ashshin': 5,
  'kartik': 6,
  'ogrohayon': 7,
  'poush': 8,
  'magh': 9,
  'falgun': 10,
  'choitro': 11,
  // Legacy app spellings (pre-guide-alignment).
  'jyoishtho': 1,
  'ashar': 2,
  'srabon': 3,
  'ashwin': 5,
  'agrahayan': 7,
  'chaitra': 11,
  // Sanskrit names (Sec 3.1 table).
  'vaishakha': 0,
  'jyeshtha': 1,
  'ashadha': 2,
  'shravana': 3,
  'bhadrapada': 4,
  'kartika': 6,
  'margashirsha': 7,
  'pausha': 8,
  'magha': 9,
  'phalguna': 10,
};
