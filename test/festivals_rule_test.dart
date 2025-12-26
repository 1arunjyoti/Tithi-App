// ignore_for_file: avoid_print

import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:tithi/services/panchang_service.dart';
import 'package:flutter/services.dart';

/// Manual test for Panchang Service with Festivals Rule
///
/// This test verifies:
/// 1. Tithi calculation works correctly
/// 2. Festivals can be matched based on paksha and tithi
/// 3. Specific known festival dates are correctly identified

// Festival model for testing
class Festival {
  final String id;
  final String name;
  final String description;
  final String masa;
  final String paksha;
  final int tithi;
  final String conditions;

  Festival({
    required this.id,
    required this.name,
    required this.description,
    required this.masa,
    required this.paksha,
    required this.tithi,
    required this.conditions,
  });

  factory Festival.fromJson(Map<String, dynamic> json) {
    return Festival(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      masa: json['masa'] ?? '',
      paksha: json['paksha'] ?? '',
      tithi: json['tithi'] ?? 0,
      conditions: json['conditions'] ?? '',
    );
  }
}

// Helper to get Paksha and Tithi number from raw tithi value
Map<String, dynamic> getTithiDetails(double rawTithi) {
  final tithiIndex = rawTithi.floor();

  // Shukla Paksha: Tithi 1-15 (Pratipada to Purnima)
  // Krishna Paksha: Tithi 16-30 (Pratipada to Amavasya)
  if (tithiIndex <= 15) {
    return {
      'paksha': 'Shukla',
      'tithi': tithiIndex,
      'name': _getTithiName(tithiIndex),
    };
  } else {
    return {
      'paksha': 'Krishna',
      'tithi': tithiIndex - 15,
      'name': _getTithiName(tithiIndex - 15),
    };
  }
}

String _getTithiName(int tithiNum) {
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

// Check if a festival matches the given tithi details
bool matchesFestival(Festival festival, Map<String, dynamic> tithiDetails) {
  // For Diwali: Krishna Paksha, Tithi 15 (Amavasya)
  return festival.paksha == tithiDetails['paksha'] &&
      festival.tithi == tithiDetails['tithi'];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Panchang Service - Festivals Rule Tests', () {
    late PanchangService service;
    late List<Festival> festivals;

    setUpAll(() async {
      service = PanchangService();
      await service.init();

      // Load festivals from JSON
      final jsonString = await rootBundle.loadString('assets/festivals.json');
      final List<dynamic> jsonList = json.decode(jsonString);
      festivals = jsonList.map((j) => Festival.fromJson(j)).toList();

      print('=== Test Setup Complete ===');
      print('Loaded ${festivals.length} festivals from festivals.json');
      for (var f in festivals) {
        print(
          '  - ${f.name}: ${f.paksha} Paksha, Tithi ${f.tithi} (${f.conditions})',
        );
      }
      print('');
    });

    test('Calculate Tithi for today', () async {
      final now = DateTime.now();
      final tithi = await service.calculateTithi(now);
      final details = getTithiDetails(tithi);

      print('=== Today\'s Panchang ===');
      print('Date: $now');
      print('Raw Tithi Value: $tithi');
      print('Paksha: ${details['paksha']}');
      print('Tithi: ${details['tithi']} (${details['name']})');
      print('');

      // Check for matching festivals
      final matchingFestivals = festivals
          .where((f) => matchesFestival(f, details))
          .toList();
      if (matchingFestivals.isNotEmpty) {
        print('🎉 Matching Festivals:');
        for (var f in matchingFestivals) {
          print('  - ${f.name}: ${f.description}');
        }
      } else {
        print('No festivals match today\'s tithi.');
      }
      print('');

      expect(tithi, greaterThan(0));
      expect(tithi, lessThanOrEqualTo(31));
    });

    test('Verify Diwali 2024 - October 31, 2024 (Known Amavasya)', () async {
      // Diwali 2024 was on October 31, 2024 - Krishna Paksha Amavasya
      final diwali2024 = DateTime(2024, 10, 31, 18, 0); // Evening time
      final tithi = await service.calculateTithi(diwali2024);
      final details = getTithiDetails(tithi);

      print('=== Diwali 2024 Verification ===');
      print('Date: $diwali2024');
      print('Raw Tithi Value: $tithi');
      print('Paksha: ${details['paksha']}');
      print('Tithi: ${details['tithi']} (${details['name']})');

      // Find Diwali in festivals
      final diwali = festivals.firstWhere((f) => f.id == 'diwali');
      final matches = matchesFestival(diwali, details);
      print('Expected: ${diwali.paksha} Paksha, Tithi ${diwali.tithi}');
      print('Match: ${matches ? "✅ YES" : "❌ NO"}');
      print('');

      // Diwali should be Krishna Paksha, Tithi 15 (or close to it due to astronomical variations)
      expect(details['paksha'], equals('Krishna'));
      // Tithi should be around 15 (Amavasya) - allowing some tolerance
      expect(details['tithi'], greaterThanOrEqualTo(14));
      expect(details['tithi'], lessThanOrEqualTo(15));
    });

    test(
      'Verify Diwali 2025 - November 20, 2025 (Expected Amavasya)',
      () async {
        // Diwali 2025 is expected on November 20, 2025
        final diwali2025 = DateTime(2025, 11, 20, 18, 0);
        final tithi = await service.calculateTithi(diwali2025);
        final details = getTithiDetails(tithi);

        print('=== Diwali 2025 Prediction ===');
        print('Date: $diwali2025');
        print('Raw Tithi Value: $tithi');
        print('Paksha: ${details['paksha']}');
        print('Tithi: ${details['tithi']} (${details['name']})');

        final diwali = festivals.firstWhere((f) => f.id == 'diwali');
        final matches = matchesFestival(diwali, details);
        print('Expected: ${diwali.paksha} Paksha, Tithi ${diwali.tithi}');
        print('Match: ${matches ? "✅ YES" : "❌ NO"}');
        print('');
      },
    );

    test('Test date range to find Diwali window', () async {
      print('=== Searching for Diwali Window (Oct-Nov 2025) ===');

      final diwali = festivals.firstWhere((f) => f.id == 'diwali');
      final startDate = DateTime(2025, 10, 15);
      final endDate = DateTime(2025, 11, 25);

      DateTime? diwaliDate;

      for (
        var date = startDate;
        date.isBefore(endDate);
        date = date.add(const Duration(days: 1))
      ) {
        final tithi = await service.calculateTithi(date);
        final details = getTithiDetails(tithi);

        if (matchesFestival(diwali, details)) {
          print('🪔 Diwali match found: $date');
          print('   Paksha: ${details['paksha']}, Tithi: ${details['tithi']}');
          diwaliDate = date;
        }
      }

      if (diwaliDate != null) {
        print('\n✅ Diwali 2025 predicted: $diwaliDate');
      } else {
        print('\n⚠️ No exact match found - may need to adjust search criteria');
      }
      print('');
    });

    test('Print Tithi for a week from today', () async {
      print('=== Weekly Tithi Report ===');

      final today = DateTime.now();

      for (var i = 0; i < 7; i++) {
        final date = today.add(Duration(days: i));
        final tithi = await service.calculateTithi(date);
        final details = getTithiDetails(tithi);

        final matchingFestivals = festivals
            .where((f) => matchesFestival(f, details))
            .toList();
        final festivalStr = matchingFestivals.isNotEmpty
            ? ' 🎉 ${matchingFestivals.map((f) => f.name).join(", ")}'
            : '';

        print(
          '${date.toString().substring(0, 10)}: ${details['paksha']} ${details['name']} (T${details['tithi']})$festivalStr',
        );
      }
      print('');
    });
  });
}
