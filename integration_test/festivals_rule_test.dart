// ignore_for_file: avoid_print

import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter/services.dart';
import 'package:tithi/services/panchang_service.dart';

/// Integration test for Panchang Service with Festivals Rule
///
/// Run with: flutter test integration_test/festivals_rule_test.dart

class Festival {
  final String id;
  final String name;
  final String paksha;
  final int tithi;

  Festival({
    required this.id,
    required this.name,
    required this.paksha,
    required this.tithi,
  });

  factory Festival.fromJson(Map<String, dynamic> json) {
    final rules = json['panchang_rules'] is Map ? json['panchang_rules'] : {};
    return Festival(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      paksha: rules['paksha'] ?? json['paksha'] ?? '',
      tithi: rules['tithi'] ?? json['tithi'] ?? 0,
    );
  }
}

Map<String, dynamic> getTithiDetails(double rawTithi) {
  final tithiIndex = rawTithi.floor();

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
  if (tithiNum >= 1 && tithiNum <= 15) {
    return tithiNames[tithiNum];
  }
  return 'Unknown';
}

bool matchesFestival(Festival festival, Map<String, dynamic> tithiDetails) {
  return festival.paksha == tithiDetails['paksha'] &&
      festival.tithi == tithiDetails['tithi'];
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late PanchangService service;
  late List<Festival> festivals;

  setUpAll(() async {
    service = PanchangService();
    await service.init();

    final jsonString = await rootBundle.loadString('assets/festivals.json');
    final List<dynamic> jsonList = json.decode(jsonString);
    festivals = jsonList.map((j) => Festival.fromJson(j)).toList();

    print('\n=== Test Setup Complete ===');
    print('Loaded ${festivals.length} festivals');
  });

  testWidgets('Calculate Tithi for today', (WidgetTester tester) async {
    final now = DateTime.now();
    final tithi = await service.calculateTithi(now);
    final details = getTithiDetails(tithi);

    print('\n=== Today\'s Panchang (${now.toString().substring(0, 10)}) ===');
    print('Raw Tithi Value: ${tithi.toStringAsFixed(2)}');
    print('Paksha: ${details['paksha']}');
    print('Tithi: ${details['tithi']} (${details['name']})');

    final matchingFestivals = festivals
        .where((f) => matchesFestival(f, details))
        .toList();
    if (matchingFestivals.isNotEmpty) {
      print(
        '🎉 Matching Festivals: ${matchingFestivals.map((f) => f.name).join(", ")}',
      );
    }

    expect(tithi, greaterThan(0));
    expect(tithi, lessThanOrEqualTo(31));
  });

  testWidgets('Verify Diwali 2024 (Oct 31)', (WidgetTester tester) async {
    final diwali2024 = DateTime(2024, 10, 31, 18, 0);
    final tithi = await service.calculateTithi(diwali2024);
    final details = getTithiDetails(tithi);

    print('\n=== Diwali 2024 (Oct 31) ===');
    print('Paksha: ${details['paksha']}, Tithi: ${details['tithi']}');

    final diwali = festivals.firstWhere((f) => f.id == 'diwali');
    final matches = matchesFestival(diwali, details);
    print('Match: ${matches ? "✅ YES" : "❌ NO"}');

    expect(details['paksha'], equals('Krishna'));
  });

  testWidgets('Weekly Tithi Report', (WidgetTester tester) async {
    print('\n=== Weekly Tithi Report ===');

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
  });
}
