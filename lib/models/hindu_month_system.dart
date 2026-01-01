/// Hindu Month System enum for Amanta/Purnimant calendar support
///
/// - **Amanta**: Month ends at Amavasya (New Moon) - South India, Maharashtra, Gujarat
/// - **Purnimant**: Month ends at Purnima (Full Moon) - North India (Vikram Samvat)
///
/// Only Krishna Paksha month names differ between systems.
/// Shukla Paksha month names are identical in both systems.
library;

enum HinduMonthSystem { amanta, purnimant }

extension HinduMonthSystemExt on HinduMonthSystem {
  String get label => switch (this) {
    HinduMonthSystem.amanta => 'Amanta',
    HinduMonthSystem.purnimant => 'Purnimant',
  };

  String get description => switch (this) {
    HinduMonthSystem.amanta =>
      'Month ends at Amavasya (South India, Maharashtra, Gujarat)',
    HinduMonthSystem.purnimant =>
      'Month ends at Purnima (North India - Vikram Samvat)',
  };

  String get shortDescription => switch (this) {
    HinduMonthSystem.amanta => 'New Moon ending',
    HinduMonthSystem.purnimant => 'Full Moon ending',
  };
}

/// List of Hindu months in order (used for conversion)
const List<String> hinduMonthsOrder = [
  'Chaitra',
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
];

/// Converts an Amanta month name to Purnimant equivalent during Krishna Paksha.
///
/// In Purnimant system, Krishna Paksha belongs to the NEXT month.
/// Example: Phalguna Krishna (Amanta) = Chaitra Krishna (Purnimant)
String convertAmantaToPurnimant(String amantaMasa, String paksha) {
  if (paksha != 'Krishna') return amantaMasa; // No change for Shukla

  final index = hinduMonthsOrder.indexOf(amantaMasa);
  if (index == -1) return amantaMasa; // Unknown month, return as-is

  // Krishna Paksha in Purnimant = next month
  final nextIndex = (index + 1) % 12;
  return hinduMonthsOrder[nextIndex];
}

/// Converts a Purnimant month name to Amanta equivalent during Krishna Paksha.
///
/// This is the reverse of convertAmantaToPurnimant.
/// Example: Chaitra Krishna (Purnimant) = Phalguna Krishna (Amanta)
String convertPurnimantToAmanta(String purnimantMasa, String paksha) {
  if (paksha != 'Krishna') return purnimantMasa; // No change for Shukla

  final index = hinduMonthsOrder.indexOf(purnimantMasa);
  if (index == -1) return purnimantMasa; // Unknown month, return as-is

  // Krishna Paksha in Amanta = previous month
  final prevIndex = (index - 1 + 12) % 12;
  return hinduMonthsOrder[prevIndex];
}

// --- Hindu Year Era ---

/// Hindu Year Era for calendar display
/// - Vikram Samvat: Starts 57 BCE (North India, Nepal)
/// - Shaka Samvat: Starts 78 CE (Official Indian Calendar, South India)
enum HinduYearEra { vikramSamvat, shakaSamvat }

extension HinduYearEraExt on HinduYearEra {
  String get label => switch (this) {
    HinduYearEra.vikramSamvat => 'Vikram Samvat',
    HinduYearEra.shakaSamvat => 'Shaka Samvat',
  };

  String get shortLabel => switch (this) {
    HinduYearEra.vikramSamvat => 'VS',
    HinduYearEra.shakaSamvat => 'Shaka',
  };

  String get description => switch (this) {
    HinduYearEra.vikramSamvat => 'Starts 57 BCE (North India, Nepal, Gujarat)',
    HinduYearEra.shakaSamvat =>
      'Starts 78 CE (Official Indian Calendar, South India)',
  };

  /// Calculate the year in this era from a Gregorian year
  /// Note: This is a simplified calculation; actual transition depends on masa
  int fromGregorianYear(int gregorianYear, {bool afterNewYear = true}) {
    return switch (this) {
      HinduYearEra.vikramSamvat =>
        afterNewYear ? gregorianYear + 57 : gregorianYear + 56,
      HinduYearEra.shakaSamvat =>
        afterNewYear ? gregorianYear - 78 : gregorianYear - 79,
    };
  }
}
