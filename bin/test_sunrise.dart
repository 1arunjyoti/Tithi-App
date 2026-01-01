// ignore_for_file: avoid_print

import 'package:tithi/services/sunrise_calculator.dart';

/// Test script to verify sunrise calculator accuracy
/// Run with: dart run bin/test_sunrise.dart
void main() {
  print('=== Sunrise Calculator Verification ===\n');

  // Test locations
  final testCases = [
    // Delhi - well-known sunrise times
    (
      name: 'Delhi - Winter Solstice (Dec 21)',
      date: DateTime(2025, 12, 21),
      lat: 28.6139,
      lng: 77.2090,
      expectedRange: (6, 50, 7, 15), // Expected: ~7:10 AM IST
    ),
    (
      name: 'Delhi - Summer Solstice (Jun 21)',
      date: DateTime(2025, 6, 21),
      lat: 28.6139,
      lng: 77.2090,
      expectedRange: (5, 20, 5, 35), // Expected: ~5:24 AM IST
    ),
    (
      name: 'Delhi - Equinox (Mar 20)',
      date: DateTime(2025, 3, 20),
      lat: 28.6139,
      lng: 77.2090,
      expectedRange: (6, 15, 6, 30), // Expected: ~6:20 AM IST
    ),
    (
      name: 'Delhi - Apr 16 (Sankashti check)',
      date: DateTime(2025, 4, 16),
      lat: 28.6139,
      lng: 77.2090,
      expectedRange: (5, 35, 5, 55), // Expected: ~5:45 AM IST
    ),
    // Mumbai
    (
      name: 'Mumbai - Dec 21',
      date: DateTime(2025, 12, 21),
      lat: 19.0760,
      lng: 72.8777,
      expectedRange: (6, 55, 7, 15), // Expected: ~7:04 AM IST
    ),
    // Chennai (South India)
    (
      name: 'Chennai - Dec 21',
      date: DateTime(2025, 12, 21),
      lat: 13.0827,
      lng: 80.2707,
      expectedRange: (6, 20, 6, 40), // Expected: ~6:30 AM IST
    ),
    // Kolkata (East India - earlier sunrise)
    (
      name: 'Kolkata - Dec 21',
      date: DateTime(2025, 12, 21),
      lat: 22.5726,
      lng: 88.3639,
      expectedRange: (6, 05, 6, 25), // Expected: ~6:12 AM IST
    ),
  ];

  int passed = 0;
  int failed = 0;

  for (final test in testCases) {
    final sunrise = SunriseCalculator.calculateSunriseIST(
      date: test.date,
      latitude: test.lat,
      longitude: test.lng,
    );

    final hour = sunrise.hour;
    final minute = sunrise.minute;

    final minExpected = test.expectedRange.$1 * 60 + test.expectedRange.$2;
    final maxExpected = test.expectedRange.$3 * 60 + test.expectedRange.$4;
    final actual = hour * 60 + minute;

    final inRange = actual >= minExpected && actual <= maxExpected;

    final status = inRange ? '✅' : '❌';
    print('$status ${test.name}');
    print('   Calculated: ${_formatTime(hour, minute)}');
    print(
      '   Expected:   ${_formatTime(test.expectedRange.$1, test.expectedRange.$2)} - ${_formatTime(test.expectedRange.$3, test.expectedRange.$4)}',
    );
    print('');

    if (inRange) {
      passed++;
    } else {
      failed++;
    }
  }

  print('=== Results: $passed passed, $failed failed ===');

  // Additional: Show sunrise progression through the year for Delhi
  print('\n=== Delhi Sunrise Through Year ===');
  final months = [
    DateTime(2025, 1, 15),
    DateTime(2025, 2, 15),
    DateTime(2025, 3, 15),
    DateTime(2025, 4, 15),
    DateTime(2025, 5, 15),
    DateTime(2025, 6, 15),
    DateTime(2025, 7, 15),
    DateTime(2025, 8, 15),
    DateTime(2025, 9, 15),
    DateTime(2025, 10, 15),
    DateTime(2025, 11, 15),
    DateTime(2025, 12, 15),
  ];

  for (final date in months) {
    final sunrise = SunriseCalculator.calculateSunriseIST(
      date: date,
      latitude: 28.6139,
      longitude: 77.2090,
    );
    final monthName = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ][date.month - 1];
    print('$monthName 15: ${_formatTime(sunrise.hour, sunrise.minute)}');
  }
}

String _formatTime(int hour, int minute) {
  final h = hour.toString().padLeft(2, '0');
  final m = minute.toString().padLeft(2, '0');
  return '$h:$m';
}
