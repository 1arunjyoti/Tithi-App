/// Shared test utilities for Tithi panchang calculations
/// 
/// This file contains common helper functions used across unit tests
/// and integration tests to avoid code duplication.
library;

/// Helper to get Paksha and Tithi number from raw tithi value
/// 
/// The raw tithi value from Swiss Ephemeris is a number from 1-30:
/// - 1-15: Shukla Paksha (waxing moon)
/// - 16-30: Krishna Paksha (waning moon)
Map<String, dynamic> getTithiDetails(double rawTithi) {
  final tithiIndex = rawTithi.floor();

  // Shukla Paksha: Tithi 1-15 (Pratipada to Purnima)
  // Krishna Paksha: Tithi 16-30 (Pratipada to Amavasya)
  if (tithiIndex <= 15) {
    return {
      'paksha': 'Shukla',
      'tithi': tithiIndex,
      'name': getTithiName(tithiIndex),
    };
  } else {
    return {
      'paksha': 'Krishna',
      'tithi': tithiIndex - 15,
      'name': getTithiName(tithiIndex - 15),
    };
  }
}

/// Get the Sanskrit name for a tithi number (1-15)
String getTithiName(int tithiNum) {
  const tithiNames = [
    '', // 0 - unused
    'Pratipada',
    'Dwitiya',
    'Tritiya',
    'Chaturthi',
    'Panchami',
    'Shashthi',
    'Saptami',
    'Ashtami',
    'Navami',
    'Dashami',
    'Ekadashi',
    'Dwadashi',
    'Trayodashi',
    'Chaturdashi',
    'Purnima/Amavasya',
  ];
  if (tithiNum >= 1 && tithiNum <= 15) {
    return tithiNames[tithiNum];
  }
  return 'Unknown';
}

/// Festival model for testing
class TestFestival {
  final String id;
  final String name;
  final String description;
  final String masa;
  final String paksha;
  final int tithi;
  final String conditions;

  TestFestival({
    required this.id,
    required this.name,
    this.description = '',
    this.masa = '',
    required this.paksha,
    required this.tithi,
    this.conditions = '',
  });

  factory TestFestival.fromJson(Map<String, dynamic> json) {
    // Helper to safely get nested values
    dynamic getNested(Map<String, dynamic> data, List<String> path) {
      dynamic current = data;
      for (var key in path) {
        if (current is Map && current.containsKey(key)) {
          current = current[key];
        } else {
          return null;
        }
      }
      return current;
    }

    return TestFestival(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      description:
          getNested(json, ['purpose', 'description']) ??
          json['description'] ??
          '',
      masa: getNested(json, ['panchang_rules', 'masa']) ?? json['masa'] ?? '',
      paksha:
          getNested(json, ['panchang_rules', 'paksha']) ?? json['paksha'] ?? '',
      tithi: getNested(json, ['panchang_rules', 'tithi']) ?? json['tithi'] ?? 0,
      conditions:
          getNested(json, ['panchang_rules', 'conditions']) ??
          json['conditions'] ??
          '',
    );
  }

  /// Check if this festival matches the given tithi details
  bool matchesTithiDetails(Map<String, dynamic> tithiDetails) {
    return paksha == tithiDetails['paksha'] && tithi == tithiDetails['tithi'];
  }
}
