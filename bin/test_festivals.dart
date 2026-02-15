// Simple command-line test for Panchang Service with Festivals Rule
// Run with: dart run bin/test_festivals.dart

// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';

/// Festival model
class Festival {
  final String id;
  final String name;
  final String description;
  final String masa;
  final String paksha;
  final int tithi;
  final String conditions;
  final String category;
  final bool recurring;

  Festival({
    required this.id,
    required this.name,
    required this.description,
    required this.masa,
    required this.paksha,
    required this.tithi,
    required this.conditions,
    this.category = '',
    this.recurring = false,
  });

  factory Festival.fromJson(Map<String, dynamic> json) => Festival(
    id: json['id'] ?? '',
    name: json['name'] ?? '',
    description: json['description'] ?? '',
    masa: json['masa'] ?? '',
    paksha: json['paksha'] ?? '',
    tithi: json['tithi'] ?? 0,
    conditions: json['conditions'] ?? '',
    category: json['category'] ?? '',
    recurring: json['recurring'] ?? false,
  );
}

/// Get Paksha and Tithi details from raw tithi value (1-30)
Map<String, dynamic> getTithiDetails(double rawTithi) {
  final tithiIndex = rawTithi.floor();

  const tithiNames = [
    '',
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

  if (tithiIndex <= 15) {
    return {
      'paksha': 'Shukla',
      'tithi': tithiIndex,
      'name': tithiIndex >= 1 && tithiIndex <= 15
          ? tithiNames[tithiIndex]
          : 'Unknown',
    };
  } else {
    final krishnaTithi = tithiIndex - 15;
    return {
      'paksha': 'Krishna',
      'tithi': krishnaTithi,
      'name': krishnaTithi >= 1 && krishnaTithi <= 15
          ? tithiNames[krishnaTithi]
          : 'Unknown',
    };
  }
}

/// Check if festival matches given tithi details
/// Supports wildcard '*' for paksha (recurring festivals)
bool matchesFestival(Festival festival, Map<String, dynamic> details) {
  // Skip solar-based festivals (like Makar Sankranti) - they need date matching
  if (festival.conditions == 'Solar') return false;

  // Check paksha match (or wildcard '*')
  final pakshaMatch =
      festival.paksha == '*' || festival.paksha == details['paksha'];

  // Check tithi match
  final tithiMatch = festival.tithi == details['tithi'];

  return pakshaMatch && tithiMatch;
}

/// Simulate tithi calculation (Sun-Moon angle / 12)
/// In real app, this uses Jyotish library with Swiss Ephemeris
/// For testing, we'll use approximate values
double simulateTithiForDate(DateTime date) {
  // This is a simplified simulation for testing the festivals matching logic
  // Real calculation uses Swiss Ephemeris via Jyotish library

  // Known reference: Diwali 2024 was Oct 31 (Krishna Amavasya = tithi ~30)
  // New Moon cycle is ~29.5 days
  final diwali2024 = DateTime(2024, 10, 31);
  final daysSinceDiwali = date.difference(diwali2024).inDays;

  // Each day advances tithi by ~1 (approximately)
  // Tithi 30 = Amavasya (New Moon)
  double tithi = 30.0 + daysSinceDiwali.toDouble();

  // Normalize to 1-30 range
  while (tithi > 30) {
    tithi -= 30;
  }
  while (tithi < 1) {
    tithi += 30;
  }

  return tithi;
}

void main() async {
  print('╔══════════════════════════════════════════════════════════════╗');
  print('║     PANCHANG SERVICE - FESTIVALS RULE TEST                   ║');
  print('╚══════════════════════════════════════════════════════════════╝\n');

  // Load festivals from JSON
  final festivalsFile = File('assets/festivals.json');
  if (!festivalsFile.existsSync()) {
    print('❌ Error: assets/festivals.json not found!');
    print(
      '   Run from project root directory: dart run bin/test_festivals.dart',
    );
    exit(1);
  }

  final jsonString = festivalsFile.readAsStringSync();
  final List<dynamic> jsonList = json.decode(jsonString);
  final festivals = jsonList.map((j) => Festival.fromJson(j)).toList();

  print('📋 Loaded ${festivals.length} festival(s) from festivals.json:\n');
  for (var f in festivals) {
    print('   • ${f.name}');
    print('     Paksha: ${f.paksha}, Tithi: ${f.tithi}');
    print('     Condition: ${f.conditions}');
    print('     Masa: ${f.masa}\n');
  }

  print('─' * 60);
  print('\n📅 TODAY\'S PANCHANG');
  print('─' * 60);

  final now = DateTime.now();
  final todayTithi = simulateTithiForDate(now);
  final todayDetails = getTithiDetails(todayTithi);

  print('Date: ${now.toString().substring(0, 10)}');
  print('Simulated Tithi: ${todayTithi.toStringAsFixed(2)}');
  print('Paksha: ${todayDetails['paksha']}');
  print('Tithi: ${todayDetails['tithi']} (${todayDetails['name']})');

  final todayFestivals = festivals
      .where((f) => matchesFestival(f, todayDetails))
      .toList();
  if (todayFestivals.isNotEmpty) {
    print('\n🎉 FESTIVALS TODAY:');
    for (var f in todayFestivals) {
      print('   🪔 ${f.name} - ${f.description}');
    }
  } else {
    print('\nNo festivals match today\'s tithi.');
  }

  print('\n${'─' * 60}');
  print('\n🔍 DIWALI 2024 VERIFICATION (Oct 31, 2024)');
  print('─' * 60);

  final diwali2024 = DateTime(2024, 10, 31);
  final diwaliTithi = simulateTithiForDate(diwali2024);
  final diwaliDetails = getTithiDetails(diwaliTithi);

  print('Date: 2024-10-31');
  print('Simulated Tithi: ${diwaliTithi.toStringAsFixed(2)}');
  print('Paksha: ${diwaliDetails['paksha']}');
  print('Tithi: ${diwaliDetails['tithi']} (${diwaliDetails['name']})');

  final diwali = festivals.firstWhere(
    (f) => f.id == 'diwali',
    orElse: () => throw 'Diwali not found',
  );
  final diwaliMatches = matchesFestival(diwali, diwaliDetails);
  print('\nExpected: ${diwali.paksha} Paksha, Tithi ${diwali.tithi}');
  print('Match: ${diwaliMatches ? "✅ YES" : "❌ NO"}');

  print('\n${'─' * 60}');
  print('\n📆 WEEKLY TITHI FORECAST');
  print('─' * 60);

  for (var i = 0; i < 7; i++) {
    final date = now.add(Duration(days: i));
    final tithi = simulateTithiForDate(date);
    final details = getTithiDetails(tithi);

    final matching = festivals
        .where((f) => matchesFestival(f, details))
        .toList();
    final festivalStr = matching.isNotEmpty
        ? ' 🎉 ${matching.map((f) => f.name).join(", ")}'
        : '';

    print(
      '${date.toString().substring(0, 10)}: ${details['paksha']} ${details['name']} (T${details['tithi']})$festivalStr',
    );
  }

  print('\n${'─' * 60}');
  print('\n🔎 SEARCHING FOR DIWALI 2025 (Oct-Nov 2025)');
  print('─' * 60);

  final diwaliDef = festivals.firstWhere((f) => f.id == 'diwali');
  final searchStart = DateTime(2025, 10, 15);
  final searchEnd = DateTime(2025, 11, 25);

  print(
    'Looking for: ${diwaliDef.paksha} Paksha, Tithi ${diwaliDef.tithi} (${diwaliDef.conditions})',
  );
  print(
    'Search range: ${searchStart.toString().substring(0, 10)} to ${searchEnd.toString().substring(0, 10)}\n',
  );

  DateTime? foundDiwali;
  for (
    var date = searchStart;
    date.isBefore(searchEnd);
    date = date.add(const Duration(days: 1))
  ) {
    final tithi = simulateTithiForDate(date);
    final details = getTithiDetails(tithi);

    if (matchesFestival(diwaliDef, details)) {
      print('🪔 Diwali match: ${date.toString().substring(0, 10)}');
      print('   ${details['paksha']} Paksha, Tithi ${details['tithi']}');
      foundDiwali = date;
    }
  }

  if (foundDiwali != null) {
    print(
      '\n✅ Diwali 2025 predicted: ${foundDiwali.toString().substring(0, 10)}',
    );
  } else {
    print('\n⚠️ No exact match found in search range');
  }

  print('\n${'═' * 60}');
  print('TEST COMPLETE');
  print('═' * 60 + '\n');

  print('ℹ️  Note: This test uses a simplified tithi simulation.');
  print('    Real calculations use Swiss Ephemeris via Jyotish library.');
  print('    Run on device/emulator for accurate astronomical calculations.\n');
}
