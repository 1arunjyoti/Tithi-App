import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../core/format/bounded_cache.dart';
import '../l10n/app_localizations.dart';

// Bounded (Phase 1): previously an unbounded global map.
final BoundedCache<String, DateFormat> _dateFormatters =
    BoundedCache<String, DateFormat>();

Future<void> initializeLocalizedDateFormatting() async {
  await Future.wait([
    initializeDateFormatting('en'),
    initializeDateFormatting('bn'),
    initializeDateFormatting('hi'),
    initializeDateFormatting('sa'),
  ]);
}

String formatLocalizedDate(DateTime date, String pattern, String locale) {
  // intl ships no Sanskrit date symbols, so 'sa' would silently fall back
  // to English below. Format explicitly from the arb-backed tables instead
  // (same spellings as weekdaySundayShort.. and monthJanuary..).
  if (locale.split(RegExp(r'[_-]')).first == 'sa') {
    return _formatSanskritDate(date, pattern);
  }
  final key = '$locale|$pattern';
  final cached = _dateFormatters.get(key);
  if (cached != null) return cached.format(date);

  try {
    final formatter = DateFormat(pattern, locale);
    _dateFormatters.set(key, formatter);
    return formatter.format(date);
  } catch (_) {
    final formatter = DateFormat(pattern);
    _dateFormatters.set(key, formatter);
    return formatter.format(date);
  }
}

/// Sunday-first short weekday names (arb weekday*Short).
const List<String> kSanskritWeekdaysShort = [
  'रविः',
  'सोमः',
  'मङ्गलः',
  'बुधः',
  'गुरुः',
  'शुक्रः',
  'शनिः',
];

/// Sunday-first full weekday names.
const List<String> kSanskritWeekdaysFull = [
  'रविवासरः',
  'सोमवासरः',
  'मङ्गलवासरः',
  'बुधवासरः',
  'गुरुवासरः',
  'शुक्रवासरः',
  'शनिवासरः',
];

/// Gregorian month names (arb monthJanuary..).
const List<String> kSanskritMonths = [
  'जनवरी',
  'फरवरी',
  'मार्च',
  'अप्रैल',
  'मई',
  'जून',
  'जुलाई',
  'अगस्त',
  'सितम्बर',
  'अक्टोबर',
  'नवम्बर',
  'दिसम्बर',
];

/// Minimal Sanskrit date formatter covering the patterns used across the
/// app ('EEEE', 'EEE', 'd MMMM y', 'MMM d', 'EEE, d MMM', 'EEE, MMM d',
/// 'h:mm a, MMM d', 'jm'). Numbers stay Latin per CLDR sa numbering.
String _formatSanskritDate(DateTime date, String pattern) {
  final hour12 = date.hour % 12 == 0 ? 12 : date.hour % 12;
  final dayPeriod = date.hour < 12 ? 'पूर्वाह्ण' : 'अपराह्ण';
  String two(int n) => n.toString().padLeft(2, '0');
  var out = pattern == 'jm' ? 'h:mm a' : pattern;
  // Longest tokens first so EEEE/MMMM/yyyy/hh/dd win over their prefixes.
  out = out.replaceAll('EEEE', kSanskritWeekdaysFull[date.weekday % 7]);
  out = out.replaceAll('EEE', kSanskritWeekdaysShort[date.weekday % 7]);
  out = out.replaceAll('MMMM', kSanskritMonths[date.month - 1]);
  out = out.replaceAll('MMM', kSanskritMonths[date.month - 1]);
  out = out.replaceAll('MM', two(date.month));
  out = out.replaceAll('yyyy', '${date.year}');
  out = out.replaceAll('y', '${date.year}');
  out = out.replaceAll('dd', two(date.day));
  out = out.replaceAll('d', '${date.day}');
  out = out.replaceAll('hh', two(hour12));
  out = out.replaceAll('h', '$hour12');
  out = out.replaceAll('mm', two(date.minute));
  out = out.replaceAll('a', dayPeriod);
  return out;
}

final BoundedCache<String, NumberFormat> _numberFormatters =
    BoundedCache<String, NumberFormat>(maxSize: 32);

/// Formats a standalone integer (e.g. countdown day counts) with the
/// locale's digits: Devanagari for hi/sa, Bengali for bn, Latin for en.
/// Falls back to [value.toString] when the locale has no number symbols.
String formatLocalizedNumber(int value, String locale) {
  final cached = _numberFormatters.get(locale);
  if (cached != null) return cached.format(value);

  try {
    final formatter = NumberFormat.decimalPattern(locale);
    _numberFormatters.set(locale, formatter);
    return formatter.format(value);
  } catch (_) {
    return value.toString();
  }
}

String localizedTithiName(
  int tithiNumber,
  String paksha,
  AppLocalizations l10n,
) {
  return switch (tithiNumber) {
    1 => l10n.tithiPratipada,
    2 => l10n.tithiDwitiya,
    3 => l10n.tithiTritiya,
    4 => l10n.tithiChaturthi,
    5 => l10n.tithiPanchami,
    6 => l10n.tithiShashthi,
    7 => l10n.tithiSaptami,
    8 => l10n.tithiAshtami,
    9 => l10n.tithiNavami,
    10 => l10n.tithiDashami,
    11 => l10n.tithiEkadashi,
    12 => l10n.tithiDwadashi,
    13 => l10n.tithiTrayodashi,
    14 => l10n.tithiChaturdashi,
    15 => paksha == 'Shukla' ? l10n.tithiPurnima : l10n.tithiAmavasya,
    _ => l10n.tithiUnknown,
  };
}

/// Vimshottari lord name for a Vedic-order nakshatra index (0-26) in the UI
/// language. The 9-graha sequence repeats three times, so only the
/// index-mod-9 lord matters.
String localizedNakshatraLord(int nakshatraIndex, AppLocalizations l10n) {
  return switch (nakshatraIndex % 9) {
    0 => l10n.lordKetu,
    1 => l10n.lordVenus,
    2 => l10n.lordSun,
    3 => l10n.lordMoon,
    4 => l10n.lordMars,
    5 => l10n.lordRahu,
    6 => l10n.lordJupiter,
    7 => l10n.lordSaturn,
    _ => l10n.lordMercury,
  };
}

/// Hindu lunar masa name in the UI script: Bengali script for bn,
/// Devanagari for hi/sa, transliterated otherwise. Delegates to
/// [localizeMasaName], which also handles Adhika_/Nija_ prefixes (the old
/// solar-correspondence lookup passed those through unconverted).
String localizedHinduMonthName(String masa, AppLocalizations l10n) {
  return localizeMasaName(masa, l10n.localeName);
}

/// Gregorian month name in the UI language (January..December localized).
/// Falls back to English for out-of-range input.
String gregorianMonthName(int month, AppLocalizations l10n) {
  return switch (month) {
    1 => l10n.monthJanuary,
    2 => l10n.monthFebruary,
    3 => l10n.monthMarch,
    4 => l10n.monthApril,
    5 => l10n.monthMay,
    6 => l10n.monthJune,
    7 => l10n.monthJuly,
    8 => l10n.monthAugust,
    9 => l10n.monthSeptember,
    10 => l10n.monthOctober,
    11 => l10n.monthNovember,
    12 => l10n.monthDecember,
    _ => 'Month $month',
  };
}

final Map<String, String> _localeZeroDigits = <String, String>{};

/// The digit-zero glyph for [locale], derived from its CLDR number symbols
/// (Bengali for bn, Latin for en/hi/sa). Cached; falls back to '0'.
String _zeroDigitFor(String locale) {
  return _localeZeroDigits.putIfAbsent(locale, () {
    try {
      final zero = NumberFormat.decimalPattern(locale).format(0);
      return zero.length == 1 ? zero : '0';
    } catch (_) {
      return '0';
    }
  });
}

/// Rewrites ASCII digits inside free text (years, day counts, date labels)
/// into the locale's digits. No-op for locales using Latin digits.
String localizeDigits(String text, String locale) {
  final zero = _zeroDigitFor(locale);
  if (zero == '0') return text;
  final zeroCode = zero.codeUnitAt(0);
  final buffer = StringBuffer();
  for (var i = 0; i < text.length; i++) {
    final c = text.codeUnitAt(i);
    if (c >= 0x30 && c <= 0x39) {
      buffer.writeCharCode(zeroCode + (c - 0x30));
    } else {
      buffer.writeCharCode(c);
    }
  }
  return buffer.toString();
}

/// Hindu lunar masa names in Bengali script, keyed by the transliterated
/// canonical names used across services and headers.
const Map<String, String> kHinduMasaNamesBn = {
  'Chaitra': 'চৈত্র',
  'Vaishakha': 'বৈশাখ',
  'Jyeshtha': 'জ্যৈষ্ঠ',
  'Ashadha': 'আষাঢ়',
  'Shravana': 'শ্রাবণ',
  'Bhadrapada': 'ভাদ্র',
  'Ashwin': 'আশ্বিন',
  'Kartika': 'কার্তিক',
  'Margashirsha': 'মার্গশীর্ষ',
  'Pausha': 'পৌষ',
  'Magha': 'মাঘ',
  'Phalguna': 'ফাল্গুন',
};

/// Hindu lunar masa names in Devanagari, shared by the Hindi and Sanskrit
/// UI locales. Keyed by the transliterated canonical names.
const Map<String, String> kHinduMasaNamesDeva = {
  'Chaitra': 'चैत्र',
  'Vaishakha': 'वैशाख',
  'Jyeshtha': 'ज्येष्ठ',
  'Ashadha': 'आषाढ़',
  'Shravana': 'श्रावण',
  'Bhadrapada': 'भाद्रपद',
  'Ashwin': 'आश्विन',
  'Kartika': 'कार्तिक',
  'Margashirsha': 'मार्गशीर्ष',
  'Pausha': 'पौष',
  'Magha': 'माघ',
  'Phalguna': 'फाल्गुन',
};

/// Script-converts Hindu lunar month labels for the Bengali (Bengali script)
/// and Hindi/Sanskrit (Devanagari) UI locales — the same app-language script
/// rule as [localizedHinduMonthName]. Handles single months, 'A - B' ranges,
/// and Adhika_/Nija_ prefixes (with '_' or ' ' separators). Other locales
/// pass through unchanged.
String localizeMasaName(String text, String locale) {
  final table = switch (locale) {
    'bn' => kHinduMasaNamesBn,
    'hi' || 'sa' => kHinduMasaNamesDeva,
    _ => null,
  };
  if (table == null) return text;
  final extra = locale == 'bn' ? 'অধিক' : 'अधिक';
  final real = locale == 'bn' ? 'নিজ' : 'निज';
  var out = text.replaceAll('_', ' ');
  out = out.replaceAll('Adhika', extra).replaceAll('Nija', real);
  for (final entry in table.entries) {
    out = out.replaceAll(entry.key, entry.value);
  }
  return out;
}
