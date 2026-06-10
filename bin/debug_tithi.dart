// Quick debug script to test Sankashti Chaturthi dates
// Run with: flutter test bin/debug_tithi.dart

// ignore_for_file: avoid_print, depend_on_referenced_packages

import 'package:flutter_test/flutter_test.dart';
import 'package:tithi/services/panchang_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Debug Sankashti Chaturthi Dates', () {
    late PanchangService service;

    setUpAll(() async {
      service = PanchangService();
      await service.init();
      print('\n=== Sankashti Chaturthi Debug ===\n');
    });

    test('Check April 2025 dates around expected Sankashti', () async {
      // Testing April 15, 16, 17 at different times
      print('APRIL 2025 - Expected: 16 April');
      print('-' * 50);

      for (int day = 15; day <= 18; day++) {
        for (int hour in [0, 6, 12, 18]) {
          final date = DateTime(2025, 4, day, hour);
          final tithi = await service.calculateTithi(date);
          final tithiNum = tithi.floor();
          final paksha = tithiNum <= 15 ? 'Shukla' : 'Krishna';
          final displayTithi = tithiNum <= 15 ? tithiNum : tithiNum - 15;

          if (paksha == 'Krishna' && displayTithi >= 3 && displayTithi <= 5) {
            print(
              'Apr $day ${hour.toString().padLeft(2, '0')}:00 -> Tithi=$tithiNum ($paksha $displayTithi)',
            );
          }
        }
      }
      print('');
    });

    test('Check June 2025 dates around expected Sankashti', () async {
      print('JUNE 2025 - Expected: 14 June');
      print('-' * 50);

      for (int day = 13; day <= 16; day++) {
        for (int hour in [0, 6, 12, 18]) {
          final date = DateTime(2025, 6, day, hour);
          final tithi = await service.calculateTithi(date);
          final tithiNum = tithi.floor();
          final paksha = tithiNum <= 15 ? 'Shukla' : 'Krishna';
          final displayTithi = tithiNum <= 15 ? tithiNum : tithiNum - 15;

          if (paksha == 'Krishna' && displayTithi >= 3 && displayTithi <= 5) {
            print(
              'Jun $day ${hour.toString().padLeft(2, '0')}:00 -> Tithi=$tithiNum ($paksha $displayTithi)',
            );
          }
        }
      }
      print('');
    });

    test('Check May 2025 dates (working correctly)', () async {
      print('MAY 2025 - Expected: 16 May');
      print('-' * 50);

      for (int day = 15; day <= 17; day++) {
        for (int hour in [0, 6, 12, 18]) {
          final date = DateTime(2025, 5, day, hour);
          final tithi = await service.calculateTithi(date);
          final tithiNum = tithi.floor();
          final paksha = tithiNum <= 15 ? 'Shukla' : 'Krishna';
          final displayTithi = tithiNum <= 15 ? tithiNum : tithiNum - 15;

          if (paksha == 'Krishna' && displayTithi >= 3 && displayTithi <= 5) {
            print(
              'May $day ${hour.toString().padLeft(2, '0')}:00 -> Tithi=$tithiNum ($paksha $displayTithi)',
            );
          }
        }
      }
      print('');
    });
  });
}
